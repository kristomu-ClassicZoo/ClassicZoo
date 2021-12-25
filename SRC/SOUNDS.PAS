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

unit Sounds;

interface
	uses TimerSys;
	var
		SoundEnabled: boolean;
		SoundBlockQueueing: boolean;
		SoundCurrentPriority: integer;
		SoundDurationMultiplier: byte;
		SoundDurationCounter: byte;
		SoundBuffer: string;
		SoundBufferPos: integer;
		SoundIsPlaying: boolean;
	procedure SoundIdle(mode: TIdleMode);
	procedure SoundQueue(priority: integer; pattern: string);
	procedure SoundClearQueue;
	function SoundCountTicks(pattern: string): integer;
	function SoundHasTimeElapsed(var counter: integer; duration: integer): boolean;
	procedure SoundUninstall;
	function SoundParse(input: string): string;

implementation

const
	SoundParseNoteTable: array['A' .. 'G'] of byte = (9, 11, 0, 2, 4, 5, 7);

procedure SoundIdle(mode: TIdleMode);
	begin
		TimerSysIdle(mode);
	end;

procedure SoundQueue(priority: integer; pattern: string);
	begin
		TimerSysLockSoundBuffer;

		if not SoundBlockQueueing and
			(not SoundIsPlaying or (((priority >= SoundCurrentPriority) and (SoundCurrentPriority <> -1)) or (priority = -1))) then
		begin
			if (priority >= 0) or not SoundIsPlaying then begin
				SoundCurrentPriority := priority;
				SoundBuffer := pattern;
				SoundBufferPos := 1;
				SoundDurationCounter := 1;
{$IFDEF SDL2}
				TimerSysQueueSound(pattern, true);
{$ENDIF}
			end else begin
				SoundBuffer := Copy(SoundBuffer, SoundBufferPos, Length(SoundBuffer) - SoundBufferPos + 1);
				SoundBufferPos := 1;
				if (Length(SoundBuffer) + Length(pattern)) < 255 then begin
					SoundBuffer := SoundBuffer + pattern;
{$IFDEF SDL2}
					TimerSysQueueSound(pattern, false);
{$ENDIF}
				end;
			end;
			SoundIsPlaying := true;
		end;

		TimerSysUnlockSoundBuffer;
	end;

procedure SoundClearQueue;
	begin
		TimerSysLockSoundBuffer;
		SoundBuffer := '';
		SoundIsPlaying := false;
		TimerSysUnlockSoundBuffer;

		TimerSysStopSound;
	end;

function SoundCountTicks(pattern: string): integer;
	var
		i, ticks: integer;
	begin
		ticks := 0;
		i := 2;
		while i <= Length(pattern) do begin
			Inc(ticks, Ord(pattern[i]));
			Inc(i, 2);
		end;
		SoundCountTicks := ticks;
	end;

{ TODO: Can we get rid of the modulo here again? }
function SoundHasTimeElapsed(var counter: integer; duration: integer): boolean;
	var
		hSecsDiff: word;
		hSecsTotal: integer;
	begin
		hSecsTotal := TimerSysGetHsecs;
		hSecsDiff := Word((hSecsTotal - counter) + 6000) mod 6000;

		if hSecsDiff >= duration then begin
			SoundHasTimeElapsed := true;
			counter := hSecsTotal;
		end else begin
			SoundHasTimeElapsed := false;
		end;
	end;

function SoundParse(input: string): string;
	var
		noteOctave: integer;
		noteDuration: integer;
		output: string;
		noteTone: integer;
		inPos, outPos: byte;
	label SoundParseFinish;
	begin
		noteOctave := 3;
		noteDuration := 1;
		inPos := 1;
		outPos := 0;

		while (inPos <= Length(input)) do begin
			noteTone := -1;
			case UpCase(input[inPos]) of
				'T': begin
					noteDuration := 1;
					Inc(inPos);
				end;
				'S': begin
					noteDuration := 2;
					Inc(inPos);
				end;
				'I': begin
					noteDuration := 4;
					Inc(inPos);
				end;
				'Q': begin
					noteDuration := 8;
					Inc(inPos);
				end;
				'H': begin
					noteDuration := 16;
					Inc(inPos);
				end;
				'W': begin
					noteDuration := 32;
					Inc(inPos);
				end;
				'.': begin
					noteDuration := (noteDuration * 3) div 2;
					Inc(inPos);
				end;
				'3': begin
					noteDuration := noteDuration div 3;
					Inc(inPos);
				end;
				'+': begin
					if noteOctave < 6 then
						Inc(noteOctave);
					Inc(inPos);
				end;
				'-': begin
					if noteOctave > 1 then
						Dec(noteOctave);
					Inc(inPos);
				end;
				'A'..'G': begin
					noteTone := SoundParseNoteTable[UpCase(input[inPos])];
					Inc(inPos);

					if inPos <= Length(input) then case UpCase(input[inPos]) of
						'!': begin
							Dec(noteTone);
							Inc(inPos);
						end;
						'#': begin
							Inc(noteTone);
							Inc(inPos);
						end;
					end;

					Inc(outPos);
					output[outPos] := Chr((noteOctave shl 4) + noteTone);
					if outPos = 255 then goto SoundParseFinish;
					Inc(outPos);
					output[outPos] := Chr(noteDuration);
				end;
				'X': begin
					Inc(outPos);
					output[outPos] := #0;
					if outPos = 255 then goto SoundParseFinish;
					Inc(outPos);
					output[outPos] := Chr(noteDuration);

					Inc(inPos);
				end;
				'0'..'2','4'..'9': begin
					Inc(outPos);
					output[outPos] := Chr(Ord(input[inPos]) + $F0 - Ord('0'));
					if outPos = 255 then goto SoundParseFinish;
					Inc(outPos);
					output[outPos] := Chr(noteDuration);
					Inc(inPos);
				end;
			else Inc(inPos) end;
		end;
SoundParseFinish:
		output[0] := Chr(outPos);
		SoundParse := output;
	end;

procedure SoundUninstall;
	begin
		TimerSysUninstall;
	end;

begin
	TimerSysInstall;

	SoundEnabled := true;
	SoundBlockQueueing := false;
	SoundClearQueue;
	SoundDurationMultiplier := 1;
	SoundIsPlaying := false;
end.
