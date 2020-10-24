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
			Data: array[1 .. 63] of word;
		end;
	var
		SoundNewVector: pointer;
		SoundOldVector: pointer;
		TimerTicks: word;
	procedure TimerDelay(ms: word);
	procedure TimerSysIdle(mode: TIdleMode);
	procedure TimerSysLockSoundBuffer;
	procedure TimerSysUnlockSoundBuffer;
	function TimerSysGetHsecs: word;
	procedure TimerSysInstall;
	procedure TimerSysUninstall;

implementation
uses Crt, Dos, Sounds;

var
	TimerHsecs: word;
	Int2FPointer: pointer;

procedure TimerDelay(ms: word);
	begin
		Delay(ms);
	end;

procedure TimerSysIdle(mode: TIdleMode);
	var
		regs: Registers;
	begin
		if Int2FPointer <> nil then begin
			regs.AX := $1680;
			Intr($2F, regs);
		end;
	end;

procedure SoundPlayDrum(var drum: TDrumData);
	var
		i: integer;
	begin
		for i := 1 to drum.Len do begin
			Sound(drum.Data[i]);
			Delay(1);
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

function TimerSysGetHsecs: word;
	begin
		TimerSysGetHsecs := TimerHsecs shr 1; { 11 / 2 = 5.5 hsecs }
	end;

procedure SoundTimerHandler;
	interrupt;
	begin
		Inc(TimerTicks);
		TimerHsecs := TimerHsecs + 11;

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
					if SoundBuffer[SoundBufferPos] = #0 then
						NoSound
					else if SoundBuffer[SoundBufferPos] < #240 then
						Sound(SoundFreqTable[Ord(SoundBuffer[SoundBufferPos])])
					else
						SoundPlayDrum(SoundDrumTable[Ord(SoundBuffer[SoundBufferPos]) - 240]);
					Inc(SoundBufferPos);

					SoundDurationCounter := SoundDurationMultiplier * Ord(SoundBuffer[SoundBufferPos]);
					Inc(SoundBufferPos);
				end;
			end;
		end;
	end;

procedure TimerSysInstall;
	begin
		SoundNewVector := @SoundTimerHandler;
		GetIntVec($1C, SoundOldVector);
		SetIntVec($1C, SoundNewVector);
	end;

procedure TimerSysUninstall;
	begin
		SetIntVec($1C, SoundOldVector);
	end;

begin
	TimerTicks := 0;
	TimerHsecs := 0;
	GetIntVec($2F, Int2FPointer);
end.
