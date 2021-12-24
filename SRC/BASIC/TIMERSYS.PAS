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
	procedure AccurateDelay(ms: word);
	procedure TimerSysIdle(mode: TIdleMode);
	procedure TimerSysLockSoundBuffer;
	procedure TimerSysUnlockSoundBuffer;
	procedure TimerSysStopSound;
	function TimerSysGetHsecs: word;
	procedure TimerSysInstall;
	procedure TimerSysUninstall;

implementation
uses
Dos, SysUtils, {$IFDEF DEMO} ZDemo, {$ENDIF} Sounds;

{$I SNDFREQ.INC}

var
	TimerHsecs: word;

procedure AccurateDelayCalibrate;
	begin
	end;

procedure AccurateDelay(ms: word);
	begin
{$IFDEF DEMO}
		if DemoFastForward then exit;
{$ENDIF}
		Sleep(ms);
	end;

procedure TimerSysIdle(mode: TIdleMode);
	begin
	end;

procedure SoundPlayDrum(var drum: TDrumData);
	var
		i: integer;
	begin
		{ TODO }
		{for i := 1 to drum.Len do begin
			Sound(drum.Data[i]);
			AccurateDelay(1);
		end;
		NoSound; }
	end;

procedure TimerSysLockSoundBuffer;
	begin
	end;

procedure TimerSysUnlockSoundBuffer;
	begin
	end;

procedure TimerSysStopSound;
	begin
		{ TODO }
		{ NoSound; }
	end;

function TimerSysGetHsecs: word;
	var
		ms: Uint64;
	begin
		ms := Uint64(TimestamptoMsecs(DateTimeToTimestamp(Now)));
		TimerSysGetHsecs := Word(((ms div 55) * 11) shr 1);
	end;

{ procedure SoundTimerHandler;
	interrupt;
	begin
		Inc(TimerTicks);
		Inc(TimerHsecs, 11);

		DemoOnPitTick;

		if not SoundEnabled then begin
			SoundIsPlaying := false;
			NoSound;
		end else if SoundIsPlaying then begin
			Dec(SoundDurationCounter);
			if SoundDurationCounter <= 0 then begin
				NoSound;
				if SoundBufferPos >= Length(SoundBuffer) then begin
					SoundIsPlaying := false;
				end else begin
					if (SoundBuffer[SoundBufferPos] >= #16) and (SoundBuffer[SoundBufferPos] < #112) then
						Sound(SoundFreqTable[Ord(SoundBuffer[SoundBufferPos])])
					else if (SoundBuffer[SoundBufferPos] >= #240) and (SoundBuffer[SoundBufferPos] < #250) then
						SoundPlayDrum(SoundDrumTable[Ord(SoundBuffer[SoundBufferPos]) - 240]);
					Inc(SoundBufferPos);

					SoundDurationCounter := SoundDurationMultiplier * Ord(SoundBuffer[SoundBufferPos]);
					Inc(SoundBufferPos);
				end;
			end;
		end;
	end; }

procedure TimerSysInstall;
	begin
		TimerTicks := 0;
		TimerHsecs := 0;
	end;

procedure TimerSysUninstall;
	begin
	end;

end.
