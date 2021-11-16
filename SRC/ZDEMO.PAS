{
	Copyright (c) 2021 Adrian Siekierka

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
	ZDemo is a prototype implementation of a demo recording hook/call set for ZZT.
	Special thanks to Mr_Alert for the initial proof of concept.

	TODO:
	- Rewrite some commands (like TickSpeed?, RandSeed and PitTicks) to be acted
	  upon during DemoFetchCommand. This will make the code a bit more versatile.
}

{$I-}
{$V-}
unit ZDemo;

interface
	const
		DEMO_MAX_COMMAND_SIZE = 7; { Shouldn't be here }
	var
		DemoErrorCode: byte;
		DemoCommandsFetched: word;
		DemoFastForward: boolean;
		DemoPitTicks: longint;
	{ Library }
	function DemoStartRecord(filename: string): boolean;
	function DemoStartPlay(filename: string): boolean;
	procedure DemoStop;
	function DemoIsComplete: boolean;
	function DemoIsPlaying: boolean;
	function DemoIsRecording: boolean;
	procedure DemoAddPitTicksBeforeInputUpdate(count: word);
	{ Hooks }
	procedure DemoInputUpdate(isGameplaySensitive: boolean); { Replaces InputUpdate; }
	procedure DemoReseedUpdate; { Replaces CurrentTick := ... }
	procedure DemoOnTickSpeedUpdate; { Replaces TickSpeed := ... }
	procedure DemoOnPitTick;

implementation
uses GameVars, Input;

type
	DemoMode = (
		DModeNone,
		DModeRecord,
		DModePlay,
		DModeComplete
	);
	DemoCommandType = (
		DCmdInput,
		DCmdTickSpeed,
		DCmdRandSeed,
		DCmdGameStart,
		DCmdPitTicks
		{ TODO: DCmdCheat }
	);
	DemoFetchMode = (
		DFetchAny,
		DFetchExpected
	);
	DemoHeader = record
		Magic: word;
		Version: word;
		Name: string[20];
		Flags: byte;
	end;
	DemoCommand = record
		case cmdType: DemoCommandType of
		DCmdInput: (
			count: word;
			deltaX, deltaY: shortint;
			shiftPressed: boolean;
			keyPressed: char;
		);
		DCmdTickSpeed: (
			tickSpeed: integer;
		);
		DCmdRandSeed: (
			randSeed: longint;
		);
		DCmdPitTicks: (
			pitTicks: word;
		);
	end;

const
	DEMO_MAGIC = $D327;
	DEMO_VERSION = $0001;
	DEMO_BUFFER_SIZE = 512;
	DEMO_COMMAND_OPTIONAL = $01;
	DemoCommandLengths: array[DCmdInput .. DCmdPitTicks] of byte = (
		7,
		3,
		5,
		1,
		3
	);
	DemoCommandFlags: array[DCmdInput .. DCmdPitTicks] of byte = (
		0,
		DEMO_COMMAND_OPTIONAL,
		DEMO_COMMAND_OPTIONAL,
		0,
		DEMO_COMMAND_OPTIONAL
	);
var
	DemoBufferPos: integer;
	DemoBuffer: array[1 .. DEMO_BUFFER_SIZE] of byte;
	DemoCurrentCommand: DemoCommand;
	DemoCurrentMode: DemoMode;
	DemoFile: file;
	DemoLastGameplaySensitive: boolean;

function DemoIsPlaying: boolean;
	begin
		DemoIsPlaying := (DemoCurrentMode = DModePlay);
	end;

function DemoIsRecording: boolean;
	begin
		DemoIsRecording := (DemoCurrentMode = DModeRecord);
	end;

function DemoIsComplete: boolean;
	begin
		DemoIsComplete := (DemoCurrentMode = DModeComplete);
	end;

procedure DemoFlushRecordBuffer;
	begin
		BlockWrite(DemoFile, DemoBuffer, DemoBufferPos - 1);
		DemoBufferPos := 1;
	end;

procedure DemoAddPitTicksBeforeInputUpdate(count: word);
	begin
		if DemoLastGameplaySensitive then
			Inc(DemoPitTicks, count);
	end;

procedure DemoAppendCommand(var cmd: DemoCommand);
	var
		cmdLen: byte;
	begin
		if (cmd.cmdType <> DCmdInput) and (DemoCurrentCommand.Count > 0) then begin
			DemoAppendCommand(DemoCurrentCommand);
			DemoCurrentCommand.Count := 0;
		end;

		cmdLen := DemoCommandLengths[cmd.cmdType];
		if DemoBufferPos > (DEMO_BUFFER_SIZE - cmdLen) then
			DemoFlushRecordBuffer; 
		Move(cmd, DemoBuffer[DemoBufferPos], cmdLen);
		Inc(DemoBufferPos, cmdLen);
		Inc(DemoCommandsFetched);
	end;

function DemoFetchCommand(expectedType: DemoCommandType; fetchMode: DemoFetchMode): boolean;
	var
		startPos: longint;
	label FetchNext;
	begin
		DemoFetchCommand := false;
		if DemoErrorCode <> 0 then exit;

		if (DemoCurrentCommand.cmdType = DCmdInput) and (DemoCurrentCommand.count > 0) then begin
			DemoErrorCode := 20 + (Ord(expectedType));
			exit;
		end;

		startPos := FilePos(DemoFile);

	FetchNext:
		if Eof(DemoFile) then begin
			{ TODO: This doesn't interact well with optionality logic below. }
			DemoCurrentMode := DModeComplete;
			exit;
		end;

		BlockRead(DemoFile, DemoCurrentCommand, 1);
		if DemoCommandLengths[DemoCurrentCommand.cmdType] > 1 then
			BlockRead(DemoFile, DemoCurrentCommand.count, DemoCommandLengths[DemoCurrentCommand.cmdType] - 1);
		if IOResult <> 0 then begin
			DemoErrorCode := 1;
			exit;
		end;

		if (fetchMode = DFetchAny) or (DemoCurrentCommand.cmdType = expectedType) then begin
			Inc(DemoCommandsFetched);
			DemoFetchCommand := true;
		end else begin
			{ If the fetched command is optional, fetch another command. }
			{ If the expected command is optional, unfetch all and return. }
			{ Otherwise, fail. }
			if (DemoCommandFlags[DemoCurrentCommand.cmdType] and DEMO_COMMAND_OPTIONAL) <> 0 then
				goto FetchNext
			else if (DemoCommandFlags[expectedType] and DEMO_COMMAND_OPTIONAL) <> 0 then
				Seek(DemoFile, startPos)
			else
				DemoErrorCode := 100 + (Ord(expectedType) * 10) + Ord(DemoCurrentCommand.cmdType);
		end;
	end;

function DemoStartRecord(filename: string): boolean;
	var
		hdr: DemoHeader;
		cmd: DemoCommand;
	begin
		DemoStartRecord := false;

		hdr.Magic := DEMO_MAGIC;
		hdr.Version := DEMO_VERSION;
		hdr.Name := World.Info.Name;
		hdr.Flags := 0;

		DemoBufferPos := 1;
		FillChar(DemoCurrentCommand, SizeOf(DemoCurrentCommand), 0);
		Assign(DemoFile, filename);
		Rewrite(DemoFile, 1);
		if IOResult <> 0 then begin
			Close(DemoFile);
			exit;
		end;

		BlockWrite(DemoFile, hdr, SizeOf(DemoHeader));
		if IOResult <> 0 then begin
			Close(DemoFile);
			exit;
		end;

		DemoCurrentMode := DModeRecord;
		DemoErrorCode := 0;
		DemoPitTicks := 0;
		DemoCommandsFetched := 0;
		DemoStartRecord := true;

		{ Record the initial commands. }
		cmd.cmdType := DCmdTickSpeed;
		cmd.tickSpeed := TickSpeed;
		DemoAppendCommand(cmd);

		cmd.cmdType := DCmdRandSeed;
		cmd.randSeed := RandSeed;
		DemoAppendCommand(cmd);

		cmd.cmdType := DCmdGameStart;
		DemoAppendCommand(cmd);
	end;

function DemoStartPlay(filename: string): boolean;
	var
		hdr: DemoHeader;
		cmd: DemoCommand;
	begin
		DemoStartPlay := false;
		Assign(DemoFile, filename);
		Reset(DemoFile, 1);
		if IOResult <> 0 then begin
			Close(DemoFile);
			exit;
		end;

		BlockRead(DemoFile, hdr, SizeOf(DemoHeader));
		if (IOResult <> 0) or (hdr.Magic <> DEMO_MAGIC) or (hdr.Version <> DEMO_VERSION) then begin
			Close(DemoFile);
			exit;
		end;

		DemoCurrentMode := DModePlay;
		DemoErrorCode := 0;
		DemoPitTicks := 0;
		DemoCommandsFetched := 0;
		DemoStartPlay := true;

		repeat
			if DemoFetchCommand(DCmdGameStart, DFetchAny) then begin end;
			case DemoCurrentCommand.cmdType of
				DCmdInput: DemoErrorCode := 3;
				DCmdRandSeed: RandSeed := DemoCurrentCommand.randSeed;
				DCmdTickSpeed: TickSpeed := DemoCurrentCommand.tickSpeed;
				DCmdPitTicks: begin { TODO: Take into account. } end;
			end;
		until DemoCurrentCommand.cmdType = DCmdGameStart;

		InputDeltaX := 0;
		InputDeltaY := 0;
		InputShiftPressed := false;
		InputKeyPressed := #0;
	end;

procedure DemoStop;
	begin
		if DemoCurrentMode = DModeRecord then begin
			if DemoCurrentCommand.count > 0 then
				DemoAppendCommand(DemoCurrentCommand);
			DemoFlushRecordBuffer;
		end;

		if DemoCurrentMode <> DModeNone then begin
			Close(DemoFile);
			DemoCurrentMode := DModeNone;
		end;
	end;

{
  The isGameplaySensitive flag culls dummy cycles from calls whose idle cycles
  do not affect gameplay.
}
procedure DemoInputUpdate(isGameplaySensitive: boolean);
	var
		cmd: DemoCommand;
	label PlayFoundInput;
	begin
		if DemoCurrentMode = DModePlay then begin
			if DemoLastGameplaySensitive <> isGameplaySensitive then begin
				if isGameplaySensitive then begin
					if DemoFetchCommand(DCmdPitTicks, DFetchExpected) then begin
						{ TODO: Take into account. }						
					end;
				end;

				DemoLastGameplaySensitive := isGameplaySensitive;
			end;

			if (DemoCurrentCommand.cmdType = DCmdInput) then begin
	PlayFoundInput:
				if DemoCurrentCommand.count > 0 then begin
					InputDeltaX := DemoCurrentCommand.deltaX;
					InputDeltaY := DemoCurrentCommand.deltaY;
					InputShiftPressed := DemoCurrentCommand.shiftPressed;
					InputKeyPressed := DemoCurrentCommand.keyPressed;
					Dec(DemoCurrentCommand.count);
					exit;
				end;
			end;
			
			if DemoFetchCommand(DCmdInput, DFetchExpected) then begin
				goto PlayFoundInput;
			end;

			exit;
		end;

		InputUpdate;
		if DemoCurrentMode = DModeRecord then begin
			if DemoLastGameplaySensitive <> isGameplaySensitive then begin
				if (isGameplaySensitive) and (DemoPitTicks > 0) then begin
					cmd.cmdType := DCmdPitTicks;
					cmd.pitTicks := DemoPitTicks;	
					DemoAppendCommand(cmd);
				end;

				DemoPitTicks := 0;
				DemoLastGameplaySensitive := isGameplaySensitive;
			end;

			if (DemoCurrentCommand.deltaX <> InputDeltaX)
			or (DemoCurrentCommand.deltaY <> InputDeltaY)
			or (DemoCurrentCommand.shiftPressed <> InputShiftPressed)
			or (DemoCurrentCommand.keyPressed <> InputKeyPressed)
			then begin
				if DemoCurrentCommand.count > 0 then
					DemoAppendCommand(DemoCurrentCommand);
				DemoCurrentCommand.deltaX := InputDeltaX;
				DemoCurrentCommand.deltaY := InputDeltaY;
				DemoCurrentCommand.shiftPressed := InputShiftPressed;
				DemoCurrentCommand.keyPressed := InputKeyPressed;
				DemoCurrentCommand.count := 1;
			end else begin
				if (isGameplaySensitive) or (DemoCurrentCommand.count <= 0) then begin
					if DemoCurrentCommand.count = 65535 then begin
						DemoAppendCommand(DemoCurrentCommand);
						DemoCurrentCommand.count := 1;
					end else begin
						Inc(DemoCurrentCommand.count);
					end;
				end;
			end;
		end;
	end;

procedure DemoReseedUpdate;
	var
		cmd: DemoCommand;
	begin
		if DemoCurrentMode = DModePlay then begin
			if DemoFetchCommand(DCmdRandSeed, DFetchExpected) then begin
				if RandSeed <> DemoCurrentCommand.randSeed then begin
					WriteLn(RandSeed);
					WriteLn(DemoCurrentCommand.RandSeed);
					DemoErrorCode := 4;
				end;
			end;
		end else if DemoCurrentMode = DModeRecord then begin
			cmd.cmdType := DCmdRandSeed;
			cmd.randSeed := RandSeed;
			DemoAppendCommand(cmd);
		end;

		CurrentTick := Random(100);

	end;

procedure DemoOnTickSpeedUpdate;
	var
		cmd: DemoCommand;
	begin
		if DemoCurrentMode = DModePlay then begin
			if DemoFetchCommand(DCmdTickSpeed, DFetchExpected) then begin
				TickSpeed := DemoCurrentCommand.tickSpeed;
			end;
		end else if DemoCurrentMode = DModeRecord then begin
			cmd.cmdType := DCmdTickSpeed;
			cmd.tickSpeed := TickSpeed;
			DemoAppendCommand(cmd);
		end;
	end;

procedure DemoOnPitTick;
	begin
		if not DemoLastGameplaySensitive then
			Inc(DemoPitTicks);
	end;

begin
	DemoCurrentMode := DModeNone;
	DemoErrorCode := 0;
	DemoFastForward := false;
end.
