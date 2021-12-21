{
	Copyright (c) 2020 Adrian Siekierka

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

{
  Known issues:
  - currently hardcoded to 48000Hz unsigned 8-bit samples
}

unit AudioSim;

interface
	var
		AudioSimSoundBufferStopTicks: integer;
		AudioSimSoundBuffer: string;
		AudioSimSoundBufferPos: integer;
		AudioSimulationAllowed: boolean;
	{ Volume range: 0-127 }
	function AudioGetVolume: byte;
	procedure AudioSetVolume(volume: byte);
	procedure AudioSimulateClear;
	procedure AudioSimulate(stream: PUint8; len: Int32);

implementation
uses Sounds, TimerSys, Math;

const
	PIT_DIVISOR = 1193182.0;
	AUDIO_FREQUENCY = 48000.0;
	SAMPLES_PER_PIT = 2640;
	SAMPLES_PER_DRUM = 48;
	SAMPLES_NOTE_DELAY = 16;
var
	AudioSampleMin, AudioSampleNone, AudioSampleMax: byte;
	CurrentNote: Int32;
	CurrentNotePos: Uint32;
	CurrentNoteMax: Uint32;

function AudioGetVolume: byte;
	begin
		AudioGetVolume := AudioSampleMax - 128;
	end;

procedure AudioSetVolume(volume: byte);
	begin
		if volume > 127 then volume := 127;
		AudioSampleNone := 128;
		AudioSampleMin := 128 - volume;
		AUdioSampleMax := 128 + volume;
	end;

procedure AudioSimulateClear;
	begin
		CurrentNote := -1;
	end;

function AudioSimCalcJump(targetNotePos: Uint32; streamPos: Int32; streamLen: Int32): Uint32;
	var
		maxStreamChange: Int32;
		maxTargetChange: Int32;
	begin
		maxTargetChange := targetNotePos - CurrentNotePos;
		if maxTargetChange < 0 then begin
			AudioSimCalcJump := 0;
			exit;
		end;
		maxStreamChange := streamLen - streamPos;
		if maxTargetChange < maxStreamChange then AudioSimCalcJump := maxTargetChange else AudioSimCalcJump := maxStreamChange;
	end;

procedure AudioSimJumpBy(amount: Uint32; var streamPos: Int32);
	begin
		CurrentNotePos := CurrentNotePos + amount;
		streamPos := streamPos + amount;
		if CurrentNotePos >= CurrentNoteMax then CurrentNote := -1;
	end;

procedure AudioSimNoteTo(targetNotePos: Uint32; frequency: Uint32; stream: PUint8; var streamPos: Int32; streamLen: Int32);
	var
		i, iMax, samplePos: Uint32;
		samplesPerChange: Double;
	begin
		iMax := AudioSimCalcJump(targetNotePos, streamPos, streamLen);
		samplesPerChange := AUDIO_FREQUENCY / (PIT_DIVISOR / Floor(PIT_DIVISOR / frequency));
		if iMax > 0 then for i := 0 to iMax - 1 do begin
			samplePos := CurrentNotePos + i;
			if (samplePos mod samplesPerChange) < (samplesPerChange / 2.0) then
				stream[streamPos + i] := AudioSampleMin
			else
				stream[streamPos + i] := AudioSampleMax;
		end;
		AudioSimJumpBy(iMax, streamPos);
	end;

procedure AudioSimSilenceTo(targetNotePos: Uint32; stream: PUint8; var streamPos: Int32; streamLen: Int32);
	var
		i, iMax: Uint32;
		v: byte;
	begin
		v := AudioSampleNone;
		iMax := AudioSimCalcJump(targetNotePos, streamPos, streamLen);
		if iMax > 0 then for i := 0 to iMax - 1 do
			stream[streamPos + i] := AudioSampleNone;
		AudioSimJumpBy(iMax, streamPos);
	end;

procedure AudioSimulate(stream: PUint8; len: Int32);
	var
		i, pos: Int32;
		drum: ^TDrumData;
		drumPos: Uint32;
		posStr: string;
	begin
		TimerSysLockSoundBuffer;

		if (not SoundEnabled) or (not SoundIsPlaying) or (not AudioSimulationAllowed) then begin
			CurrentNote := -1;
			for i := 0 to len - 1 do
				stream[i] := AudioSampleNone;
		end else begin
			pos := 0;
			while pos < len do begin
				if CurrentNote < 0 then begin
					if AudioSimSoundBufferPos >= Length(AudioSimSoundBuffer) then begin
						SoundIsPlaying := false;
						for i := pos to len - 1 do
							stream[i] := AudioSampleNone;
						break;
					end else begin
						{ pop note }
						CurrentNote := Uint8(AudioSimSoundBuffer[AudioSimSoundBufferPos]);
						CurrentNotePos := 0;
						Inc(AudioSimSoundBufferPos);
						CurrentNoteMax := SoundDurationMultiplier * Uint8(AudioSimSoundBuffer[AudioSimSoundBufferPos]) * SAMPLES_PER_PIT;
						Inc(AudioSimSoundBufferPos);
					end;
				end;
			
				if (CurrentNote > 0) and (CurrentNote < 240) then begin
					{ note }
					if CurrentNotePos < SAMPLES_NOTE_DELAY then
						AudioSimSilenceTo(SAMPLES_NOTE_DELAY, stream, pos, len)
					else begin
						if SoundFreqTable[CurrentNote] > 0 then
							AudioSimNoteTo(CurrentNoteMax, SoundFreqTable[CurrentNote], stream, pos, len)
						else
							AudioSimSilenceTo(CurrentNoteMax, stream, pos, len);
					end;
				end else if (CurrentNote >= 240) and (CurrentNote < 250) then begin
					{ drum }
					drum := @SoundDrumTable[CurrentNote - 240];
					drumPos := CurrentNotePos div SAMPLES_PER_DRUM;
					if drumPos < drum^.Len then
						AudioSimNoteTo((drumPos + 1) * SAMPLES_PER_DRUM, drum^.Data[drumPos + 1], stream, pos, len)
					else
						AudioSimSilenceTo(CurrentNoteMax, stream, pos, len);
				end else begin
					{ silence }
					AudioSimSilenceTo(CurrentNoteMax, stream, pos, len);
				end;
			end;
		end;

		TimerSysUnlockSoundBuffer;
	end;

begin
	CurrentNote := -1;
	AudioSimulationAllowed := false;
	AudioSetVolume(48);
end.
