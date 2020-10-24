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
		TimerTicks: word;
		TimerSubTicks: word;
	procedure TimerDelay(ms: word);
	procedure TimerSysIdle(mode: TIdleMode);
	procedure TimerSysLockSoundBuffer;
	procedure TimerSysUnlockSoundBuffer;
	procedure TimerSysStopSound;
	function TimerSysGetHsecs: word;
	procedure TimerSysInstall;
	procedure TimerSysUninstall;

implementation
uses Dos, PC98, Sounds;
var
	SoundNewVector: pointer;
	SoundOldVector: pointer;
	SoundOldVector07: pointer;
	SoundFreqDivisor: longint;
	SpeakerActive: boolean;

procedure TimerDelay(ms: word);
	begin
		Delay98(ms);
	end;

procedure Sound98(hz: word);
	var
		convHz: word;
	begin
		convHz := SoundFreqDivisor div hz;
		if not SpeakerActive then begin
			Port[$77] := $76;
			SpeakerActive := true;
		end;
		Port[$73] := convHz and $FF;
		Port[$73] := convHz shr 8;

		Port[$37] := $08;
		Port[$35] := Port[$35] and $F7;
	end;

procedure NoSound98;
	begin
		Port[$35] := Port[$35] or $08;
		Port[$37] := $09;
		SpeakerActive := false;
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
			Sound98(drum.Data[i]);
			Delay98(1);
		end;
		NoSound98;
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
		NoSound98;
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
		if (Mem[0:$0501] and $80) = 0 then begin
			Port[$71] := $D1;
			Port[$71] := $83;
		end else begin
			Port[$71] := $1A;
			Port[$71] := $6B;
		end;

		Inc(TimerSubTicks);
		if (TimerSubTicks and 3) <> 0 then
			Exit;

		Inc(TimerTicks);

		if not SoundEnabled then begin
			SoundIsPlaying := false;
			NoSound98;
		end else if SoundIsPlaying then begin
			Dec(SoundDurationCounter);
			if SoundDurationCounter <= 0 then begin
				NoSound98;
				if SoundBufferPos >= Length(SoundBuffer) then begin
					NoSound98;
					SoundIsPlaying := false;
				end else begin
					if (SoundBuffer[SoundBufferPos] >= #16) and (SoundBuffer[SoundBufferPos] < #112) then
						Sound98(SoundFreqTable[Ord(SoundBuffer[SoundBufferPos])])
					else if (SoundBuffer[SoundBufferPos] >= #240) and (SoundBuffer[SoundBufferPos] < #250) then
						SoundPlayDrum(SoundDrumTable[Ord(SoundBuffer[SoundBufferPos]) - 240])
					else
						NoSound98;

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
		GetIntVec($08, SoundOldVector);
		GetIntVec($07, SoundOldVector07);
		SetIntVec($08, SoundNewVector);
		SetIntVec($07, SoundOldVector);

		{ configure timing }
	{$IFNDEF FPC}
		inline($FA); { CLI }
	{$ELSE}
		asm
			cli
		end;
	{$ENDIF}
		Port[$77] := $36;
		if (Mem[0:$0501] and $80) = 0 then begin
			Port[$71] := $D1;
			Port[$71] := $83;
			SoundFreqDivisor := 2457600;
		end else begin
			Port[$71] := $1A;
			Port[$71] := $6B;
			SoundFreqDivisor := 1996800; 
		end;
		Port[$02] := (Port[$02] and $FE);
	{$IFNDEF FPC}
		inline($FB); { STI }
	{$ELSE}
		asm
			sti
		end;
	{$ENDIF}

		NoSound98;
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
