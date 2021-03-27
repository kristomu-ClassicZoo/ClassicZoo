{
	Copyright (c) 2020 Adrian Siekierka

	Based on a reconstruction of code from ZZT,
	Copyright 1991 Epic MegaGames, used with permission.

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
}

{$I-}

unit AccDelay;

interface
	procedure AccurateDelayCalibrate;
	procedure AccurateDelay(ms: word);

implementation
uses Crt, Sounds;

{$IFNDEF FPC}
const
	DELAY_LOOP_MAX_ITERATIONS = $7FFFFFFF;
var
	DelayLoopIterations: longint;

function AccurateDelayLoop(iterations: longint; var monitor: word): longint;
	begin
		inline(
			$8B/$BE/monitor/ { MOV DI, SS:[monitor] }
			$8B/$86/monitor+2/ { MOV AX, SS:[monitor+2] }
			$8E/$C0/ { MOV ES, AX }
			$8B/$86/iterations/ { MOV AX, SS:[iterations] }
			$8B/$96/iterations+2/ { MOV DX, SS:[iterations+2] }
			$8B/$1D/ { MOV BX, [ES:DI] }
		{ loop: }
			$90/$90/ { NOP x 2 }
			$83/$E8/$01/ { SUB AX, 1 }
			$83/$DA/$00/ { SBB DX, 0 }
			$72/$04/ { JC done }
			$3B/$1D/ { CMP BX, [ES:DI] }
			$74/$F2/ { JE loop }
		{ done: }
			$89/$86/AccurateDelayLoop/ { MOV AX, SS:[AccurateDelayLoop] }
			$89/$96/AccurateDelayLoop+2 { MOV DX, SS:[AccurateDelayLoop+2] }
		);
	end;

procedure AccurateDelayCalibrate;
	var
		iterations: longint;
		ticks: word;
	begin
		ticks := TimerTicks;
		repeat until TimerTicks <> ticks;
		iterations := AccurateDelayLoop(DELAY_LOOP_MAX_ITERATIONS, TimerTicks);
		DelayLoopIterations := (DELAY_LOOP_MAX_ITERATIONS - iterations) div 55;
	end;

procedure AccurateDelay(ms: word);
	var
		iterations: longint;
		unchanged: word;
	begin
		iterations := DelayLoopIterations * ms;
		if iterations <> 0 then
			iterations := AccurateDelayLoop(iterations, unchanged);
	end;
{$ELSE}
procedure AccurateDelayCalibrate;
	begin
		{ I'm not sure if Free Pascal lets you do this, though. }
	end;

procedure AccurateDelay(ms: word);
	begin
		{ Free Pascal contains properly calibrated delay logic. }
		Delay(ms);
	end;
{$ENDIF}

end.
