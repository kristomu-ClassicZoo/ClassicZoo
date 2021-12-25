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

unit TimerSys;

interface
	type
		TIdleMode = (IMUntilPit, IMUntilFrame);
		TDrumData = record
			Len: integer;
			Data: array[1 .. 15] of word;
		end;
	var
		TimerTicks: word;
		TimerSubTicks: word;
		SoundFreqDivisor: longint;
		SpeakerActive: boolean;
	procedure AccurateDelayCalibrate;
	procedure AccurateDelay(ms: word);
	procedure TimerSysIdle(mode: TIdleMode);
	procedure TimerSysLockSoundBuffer;
	procedure TimerSysUnlockSoundBuffer;
	procedure TimerSysStopSound;
	function TimerSysGetHsecs: word;
	procedure TimerSysInstall;
	procedure TimerSysUninstall;

implementation
uses Dos, PC98, ZDemo, Sounds;
var
	SoundOldVector: pointer;
	SoundOldVector07: pointer;

{$I SNDFREQ.INC}
	DELAY_LOOP_MAX_ITERATIONS = $7FFFFFFF;

var
	DelayLoopIterations: longint;

function AccurateDelayLoop(iterations: longint; var monitor: word): longint;
	label ADLoop;
	label ADDone;
	begin
		asm
			MOV DI, SS:[monitor]
			MOV AX, SS:[monitor+2]
			MOV ES, AX
			MOV AX, SS:[iterations]
			MOV DX, SS:[iterations+2]
			MOV BX, [ES:DI]
		ADLoop:
			NOP
			NOP
			SUB AX, 1
			SBB DX, 0
			JC ADDone
			CMP BX, [ES:DI]
			JE ADLoop
		ADDone:
			MOV SS:[AccurateDelayLoop], AX
			MOV SS:[AccurateDelayLoop+2], DX
		end;
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
		if DemoFastForward then exit;
		iterations := DelayLoopIterations * ms;
		if iterations <> 0 then
			iterations := AccurateDelayLoop(iterations, unchanged);
	end;

procedure SoundUpdateFreqDivisor;
	begin
		if (Mem[0:$0501] and $80) = 0 then begin
			Port[$71] := $D1;
			Port[$71] := $83;
			SoundFreqDivisor := 2457600;
		end else begin
			Port[$71] := $1A;
			Port[$71] := $6B;
			SoundFreqDivisor := 1996800; 
		end;
	end;

procedure TimerSysIdle(mode: TIdleMode);
	begin
		{ no-op? }
	end;

procedure SoundPlayDrum(var drum: TDrumData);
	var
		i: integer;
	begin
		for i := 1 to drum.Len do begin
			Sound(drum.Data[i]);
			AccurateDelay(1);
		end;
		NoSound;
	end;

procedure TimerSysLockSoundBuffer;
	begin
		{ no-op? }
	end;

procedure TimerSysUnlockSoundBuffer;
	begin
		{ no-op? }
	end;

procedure TimerSysStopSound;
	begin
		NoSound;
	end;

function TimerSysGetHsecs: word;
	begin
		TimerSysGetHsecs := Word((LongInt(TimerTicks) * 93) shr 4);
	end;

procedure SoundTimerHandler;
	interrupt;
	var
		regs: Registers;
	begin
		Intr($07, regs);
		SoundUpdateFreqDivisor;

		Inc(TimerSubTicks);
		if (TimerSubTicks and 3) <> 0 then
			Exit;

		Inc(TimerTicks);

		DemoOnPitTick;

		if not SoundEnabled then begin
			SoundIsPlaying := false;
			NoSound;
		end else if SoundIsPlaying then begin
			Dec(SoundDurationCounter);
			if SoundDurationCounter <= 0 then begin
				NoSound;
				if SoundBufferPos >= Length(SoundBuffer) then begin
					NoSound;
					SoundIsPlaying := false;
				end else begin
					if (SoundBuffer[SoundBufferPos] >= #16) and (SoundBuffer[SoundBufferPos] < #112) then
						Sound(SoundFreqTable[Ord(SoundBuffer[SoundBufferPos])])
					else if (SoundBuffer[SoundBufferPos] >= #240) and (SoundBuffer[SoundBufferPos] < #250) then
						SoundPlayDrum(SoundDrumTable[Ord(SoundBuffer[SoundBufferPos]) - 240])
					else
						NoSound;

					Inc(SoundBufferPos);

					SoundDurationCounter := SoundDurationMultiplier * Ord(SoundBuffer[SoundBufferPos]);
					Inc(SoundBufferPos);
				end;
			end;
		end;
	end;

procedure TimerSysInstall;
	begin
		GetIntVec($08, SoundOldVector);
		GetIntVec($07, SoundOldVector07);
		SetIntVec($08, @SoundTimerHandler);
		SetIntVec($07, SoundOldVector);

		{ configure timing }
		asm cli end;
		Port[$77] := $36;
		SoundUpdateFreqDivisor;
		Port[$02] := (Port[$02] and $FE);
		asm sti end;

		NoSound;

		DelayLoopIterations := 0;
		AccurateDelayCalibrate;
	end;

procedure TimerSysUninstall;
	begin
		SetIntVec($08, SoundOldVector);
		SetIntVec($07, SoundOldVector07);
	end;

begin
	TimerTicks := 0;
	TimerSubTicks := 0;
end.
