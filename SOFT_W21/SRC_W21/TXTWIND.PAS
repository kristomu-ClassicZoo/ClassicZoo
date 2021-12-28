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
{$V-}
unit TxtWind;

interface
	uses Gamevars,Video;
	const
		MAX_TEXT_WINDOW_LINES = 1024;
		MAX_RESOURCE_DATA_FILES = 24;
		TextWindowX = 5;
		TextWindowY = 3;
		TextWindowWidth = 50;
		TextWindowHeight = 18;
		MAX_LINE_LENGTH_EDIT = 58;
		MAX_LINE_LENGTH = 50;
		TWS_HYPERLINK_AS_SELECT = $01;
		TWS_VIEWING_FILE = $02;
		TWS_IGNORE_HYPERLINKS = $04;
	type
		TExtensionString = string[4];
		TTextWindowLine = string[MAX_LINE_LENGTH_EDIT];
		TTextWindowState = record
			Selectable: boolean;
			LineCount: integer;
			LinePos: integer;
			Lines: array[1 .. MAX_TEXT_WINDOW_LINES] of ^TTextWindowLine;
			Hyperlink: string[20];
			Title: TTextWindowLine;
			LoadedFilename: string[50];
			ScreenCopy: array[1 .. 25] of string[160];
		end;
		TResourceDataHeader = record
			Version: integer;
			EntryCount: integer;
			Name: array[1 .. MAX_RESOURCE_DATA_FILES] of string[12];
			FileOffset: array[1 .. MAX_RESOURCE_DATA_FILES] of longint;
		end;
	var
		TextWindowStrInnerEmpty: TVideoLine;
		TextWindowStrText: TVideoLine;
		TextWindowStrInnerLine: TVideoLine;
		TextWindowStrTop: TVideoLine;
		TextWindowStrBottom: TVideoLine;
		TextWindowStrSep: TVideoLine;
		TextWindowStrInnerSep: TVideoLine;
		TextWindowStrInnerArrows: TVideoLine;
		TextWindowRejected: boolean;
		ResourceDataFileName: TFilenameString;
		ResourceDataHeader: TResourceDataHeader;
	procedure TextWindowInitState(var state: TTextWindowState);
	procedure TextWindowDrawOpen(var state: TTextWindowState);
	procedure TextWindowDrawClose(var state: TTextWindowState);
	procedure TextWindowDraw(var state: TTextWindowState; withoutFormatting, viewingFile: boolean);
	procedure TextWindowAppend(var state: TTextWindowState; line: TTextWindowLine);
	procedure TextWindowFree(var state: TTextWindowState);
	procedure TextWindowSelect(var state: TTextWindowState; flags: byte);
	procedure TextWindowOpenFile(filename: TFilenameString; var state: TTextWindowState; editing, showError: boolean);
	procedure TextWindowDisplayFile(filename: TFilenameString; title: TTextWindowLine);
	procedure TextWindowInit;

implementation
uses Crt, Sounds, Input, Keys, FileSel, Game;

procedure TextWindowInitState(var state: TTextWindowState);
	begin
		with state do begin
			LineCount := 0;
			LinePos := 1;
			LoadedFilename := '';
		end;
	end;

procedure TextWindowDrawTitle(color: integer; title: TTextWindowLine);
	begin
		VideoWriteText(TextWindowX + 2, TextWindowY + 1, color, TextWindowStrInnerEmpty);
		VideoWriteText(TextWindowX + ((TextWindowWidth - Length(title)) div 2), TextWindowY + 1, color, title);
	end;

function AsColor(fg, bg: integer): byte;
	begin
		AsColor := ((bg * 16) + fg) + $00;
	end;

procedure TextWindowDrawOpen(var state: TTextWindowState);
	var
		ix, iy: integer;
	begin
		with state do begin
			for iy := 1 to (TextWindowHeight + 1) do
				VideoMove(TextWindowX, iy + TextWindowY - 1, TextWindowWidth, @ScreenCopy[iy], false);

			for iy := (TextWindowHeight div 2) downto 0 do begin
				VideoWriteText(TextWindowX, TextWindowY + iy + 1,
					AsColor(ParamList[THEME_START + 1],0), TextWindowStrText);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy - 1,
					AsColor(ParamList[THEME_START + 1],0), TextWindowStrText);
				VideoWriteText(TextWindowX, TextWindowY + iy,
					AsColor(ParamList[THEME_START + 1],0), TextWindowStrTop);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy,
					AsColor(ParamList[THEME_START + 1],0), TextWindowStrBottom);
				Delay(25);
			end;

			VideoWriteText(TextWindowX, TextWindowY + 2, AsColor(ParamList[THEME_START + 1],0), TextWindowStrSep);
			TextWindowDrawTitle(AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), Title);
		end;
	end;

procedure TextWindowDrawClose(var state: TTextWindowState);
	var
		ix, iy: integer;
	begin
		with state do begin
			for iy := 0 to (TextWindowHeight div 2) do begin
				VideoWriteText(TextWindowX, TextWindowY + iy,	
					AsColor(ParamList[THEME_START + 1],0), TextWindowStrTop);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy,
					AsColor(ParamList[THEME_START + 1],0), TextWindowStrBottom);
				Delay(18);
				VideoMove(TextWindowX, TextWindowY + iy, TextWindowWidth,
					@ScreenCopy[iy + 1], true);
				VideoMove(TextWindowX, TextWindowY + TextWindowHeight - iy, TextWindowWidth,
					@ScreenCopy[(TextWindowHeight - iy) + 1], true);
			end;
		end;
	end;

procedure TextWindowDrawLine(var state: TTextWindowState; lpos: integer; withoutFormatting, viewingFile: boolean);
	var
		lineY: integer;
		textOffset, textColor, textX: integer;
	begin
		with state do begin
			lineY := ((TextWindowY + lpos) - LinePos) + (TextWindowHeight div 2) + 1;
			if lpos = LinePos then
				VideoWriteText(TextWindowX + 2, lineY,
					AsColor(ParamList[THEME_START + 6],ParamList[THEME_START]), TextWindowStrInnerArrows)
			else
				VideoWriteText(TextWindowX + 2, lineY,
					AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), TextWindowStrInnerEmpty);
			if (lpos > 0) and (lpos <= LineCount) then begin
				if withoutFormatting then begin
					VideoWriteText(TextWindowX + 4, lineY,
						AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), Lines[lpos]^);
				end else begin
					textOffset := 1;
					textColor := AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]);
					textX := TextWindowX + 4;
					if Length(state.Lines[lpos]^) > 0 then begin
						case state.Lines[lpos]^[1] of
							'!': begin
								textOffset := Pos(';', Lines[lpos]^) + 1;
								VideoWriteText(textX + 2, lineY,
									AsColor(ParamList[THEME_START + 6],ParamList[THEME_START]), #16);
								textX := textX + 5;
								textColor := AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]);
							end;
							':': begin
								textOffset := Pos(';', Lines[lpos]^) + 1;
								textColor := AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]);
							end;
							'$': begin
								textOffset := 2;
								textColor := AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]);
								textX := (textX - 4) + ((TextWindowWidth - Length(Lines[lpos]^)) div 2);
							end;
							'@': begin
								textColor := AsColor(ParamList[THEME_START + 4],ParamList[THEME_START]);
							end;
							#255: begin
								textOffset := 3;
								VideoWriteText(textX - 1, lineY,
									AsColor(ParamList[THEME_START + 3],
									ParamList[THEME_START]), state.Lines[lpos]^[2]);
								textColor := AsColor(ParamList[THEME_START + 6], ParamList[THEME_START]);
							end;
						end;
					end;
					if textOffset > 0 then begin
						VideoWriteText(textX, lineY, textColor,
							Copy(Lines[lpos]^, textOffset,Length(Lines[lpos]^) - textOffset + 1));
					end;
				end;
			end else if (lpos = 0) or (lpos = (state.LineCount + 1)) then begin
				VideoWriteText(TextWindowX + 2, lineY, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), TextWindowStrInnerSep);
			end else if (lpos = -4) and viewingFile then begin
				VideoWriteText(TextWindowX + 2, lineY,
					AsColor(ParamList[THEME_START + 6],ParamList[THEME_START]), '   Use            to view text,');
				VideoWriteText(TextWindowX + 2 + 7, lineY,
					AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), #24' '#25', Enter');
			end;
		end;
	end;

procedure TextWindowDraw(var state: TTextWindowState; withoutFormatting, viewingFile: boolean);
	var
		i: integer;
	begin
		for i := 0 to (TextWindowHeight - 4) do
			TextWindowDrawLine(state, state.LinePos - (TextWindowHeight div 2) + i + 2,
				withoutFormatting, viewingFile);
		TextWindowDrawTitle(AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), state.Title);
	end;

procedure TextWindowAppend(var state: TTextWindowState; line: TTextWindowLine);
	begin
		with state do begin
			LineCount := LineCount + 1;
			New(Lines[LineCount]);
			Lines[LineCount]^ := line;
		end;
	end;

procedure TextWindowFree(var state: TTextWindowState);
	begin
		with state do begin
			while LineCount > 0 do begin
				Dispose(Lines[LineCount]);
				LineCount := LineCount - 1;
			end;
			LoadedFilename := '';
		end;
	end;

procedure TextWindowSelect(var state: TTextWindowState; flags: byte);
	var
		newLinePos: integer;
		viewingFile: boolean;
		iLine, iChar: integer;
		pointerStr: string[20];
	label LabelMatched;
	label LabelNotMatched;
	begin
		viewingFile := (flags and TWS_VIEWING_FILE) <> 0;

		with state do begin
			TextWindowRejected := false;
			Hyperlink := '';
			TextWindowDraw(state, false, viewingFile);
			repeat
				InputUpdate;
				newLinePos := LinePos;
				if InputDeltaY <> 0 then begin
					Inc(newLinePos, InputDeltaY);
				end else if InputShiftPressed or (InputKeyPressed = KEY_ENTER) then begin
					InputShiftAccepted := true;
					if ((flags and TWS_IGNORE_HYPERLINKS) = 0) and ((Lines[LinePos]^[1]) = '!') then begin
						pointerStr := Copy(Lines[LinePos]^, 2, Length(Lines[LinePos]^) - 1);

						if Pos(';', pointerStr) > 0 then begin
							pointerStr := Copy(pointerStr, 1, Pos(';', pointerStr) - 1);
						end;

						if pointerStr[1] = '-' then begin
							Delete(pointerStr, 1, 1);
							TextWindowFree(state);
							TextWindowOpenFile(pointerStr, state, false, false);
							if state.LineCount = 0 then
								exit
							else begin
								viewingFile := true;
								newLinePos := LinePos;
								TextWindowDraw(state, false, viewingFile);
								InputKeyPressed := #0;
								InputShiftPressed := false;
							end;
						end else begin
							if (flags and TWS_HYPERLINK_AS_SELECT) <> 0 then begin
								Hyperlink := pointerStr;
							end else begin
								pointerStr := ':' + pointerStr;
								for iLine := 1 to LineCount do begin
									if Length(pointerStr) > Length(Lines[iLine]^) then begin
									end else begin
										for iChar := 1 to Length(pointerStr) do begin
											if UpCase(pointerStr[iChar]) <> UpCase(Lines[iLine]^[iChar]) then
												goto LabelNotMatched;
										end;
										newLinePos := iLine;
										InputKeyPressed := #0;
										InputShiftPressed := false;
										goto LabelMatched;
									LabelNotMatched:
									end;
								end;
							end;
						end;
					end;
				end else begin
					if InputKeyPressed = KEY_PAGE_UP then begin
						newLinePos := LinePos - TextWindowHeight + 4;
					end else if InputKeyPressed = KEY_PAGE_DOWN then begin
						newLinePos := LinePos + TextWindowHeight - 4;
					end;
				end;

			LabelMatched:
				if newLinePos < 1 then
					newLinePos := 1
				else if newLinePos > state.LineCount then
					newLinePos := LineCount;

				if newLinePos <> LinePos then begin
					LinePos := newLinePos;
					TextWindowDraw(state, false, viewingFile);
					if (Lines[LinePos]^[1]) = '!' then
						if (flags and TWS_HYPERLINK_AS_SELECT) <> 0 then
							TextWindowDrawTitle(AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), #174'Press ENTER to select this'#175)
						else
							TextWindowDrawTitle(AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), #174'Press ENTER for more info'#175);
				end;
				if InputJoystickMoved then begin
					Delay(35);
				end;
			until (InputKeyPressed = KEY_ESCAPE) or (InputKeyPressed = KEY_ENTER) or InputShiftPressed;
			if InputKeyPressed = KEY_ESCAPE then begin
				InputKeyPressed := #0;
				TextWindowRejected := true;
			end;
		end;
	end;

procedure TextWindowOpenFile(filename: TFilenameString; var state: TTextWindowState; editing, showError: boolean);
	var
		f: file;
		tf: text;
		i: integer;
		entryPos: integer;
		retVal: boolean;
		line: ^string;
		lineLen: byte;
	label EntryPosFoundResData;
	begin
		with state do begin
			retVal := true;
			for i := 1 to Length(filename) do
				retVal := retVal and (filename[i] <> '.');
			if retVal then
				filename := filename + '.HLP';

			if filename[1] = '*' then begin
				filename := Copy(filename, 2, Length(filename) - 1);
				entryPos := -1;
			end else begin
				entryPos := 0;
			end;

			TextWindowInitState(state);
			LoadedFilename := UpCaseString(filename);
			if ResourceDataHeader.EntryCount = 0 then begin
				Assign(f, ResourceDataFileName);
				Reset(f, 1);
				if IOResult = 0 then
					BlockRead(f, ResourceDataHeader, SizeOf(ResourceDataHeader));
				if (IOResult <> 0) or (ResourceDataHeader.Version <> -2) then
					ResourceDataHeader.EntryCount := -1;
				Close(f);
			end;

			if entryPos = 0 then begin
				for i := 1 to ResourceDataHeader.EntryCount do begin
					{ assumption: LoadedFilename is UpCaseString(filename) }
					if UpCaseString(ResourceDataHeader.Name[i]) = LoadedFilename then begin
						entryPos := i;
						goto EntryPosFoundResData;
					end;
				end;
			end;
			EntryPosFoundResData:

			if entryPos <= 0 then begin
				Assign(tf, filename);
				Reset(tf);
				while (IOResult = 0) and (not Eof(tf)) do begin
					Inc(LineCount);
					New(Lines[LineCount]);
					ReadLn(tf, Lines[LineCount]^);
				end;
				Close(tf);
			end else begin
				Assign(f, ResourceDataFilename);
				Reset(f, 1);
				Seek(f, ResourceDataHeader.FileOffset[entryPos]);
				if IOResult = 0 then begin
					retVal := true;
					while (IOResult = 0) and retVal do begin
						Inc(LineCount);

						BlockRead(f, lineLen, 1);
						if editing then
							New(Lines[LineCount])
						else
							GetMem(Lines[LineCount], lineLen + 1);
						Lines[LineCount]^[0] := Chr(lineLen);
						line := Ptr(Seg(Lines[LineCount]^), Ofs(Lines[LineCount]^) + 1);

						if lineLen = 0 then begin
							Lines[LineCount]^ := '';
						end else begin
							BlockRead(f, line^, lineLen);
							if Lines[LineCount]^ = '@' then begin
								retVal := false;
								Lines[LineCount]^ := '';
							end;
						end;
					end;
				end;
				Close(f);
			end;
		end;
	end;

procedure TextWindowDisplayFile(filename: TFilenameString; title: TTextWindowLine);
	var
		state: TTextWindowState;
	begin
		state.Title := title;
		TextWindowOpenFile(filename, state, false, false);
		state.Selectable := false;
		if state.LineCount > 0 then begin
			TextWindowDrawOpen(state);
			TextWindowSelect(state, TWS_VIEWING_FILE);
			TextWindowDrawClose(state);
		end;
		TextWindowFree(state);
	end;

procedure TextWindowInit;
	var
		i: integer;
	begin
		TextWindowStrInnerEmpty[0] := Chr(TextWindowWidth - 5);
		TextWindowStrInnerLine[0] := Chr(TextWindowWidth - 5);
		for i := 1 to (TextWindowWidth - 5) do begin
			TextWindowStrInnerEmpty[i] := ' ';
			TextWindowStrInnerLine[i] := #205;
		end;
		TextWindowStrTop    := #198#209 + TextWindowStrInnerLine  + #209#181;
		TextWindowStrBottom := #198#207 + TextWindowStrInnerLine  + #207#181;
		TextWindowStrSep    :=  ' '#198 + TextWindowStrInnerLine  + #181' ';
		TextWindowStrText   :=  ' '#179 + TextWindowStrInnerEmpty + #179' ';
		TextWindowStrInnerArrows := TextWindowStrInnerEmpty;
		TextWindowStrInnerArrows[1] := #175;
		TextWindowStrInnerArrows[Length(TextWindowStrInnerArrows)] := #174;
		TextWindowStrInnerSep := TextWindowStrInnerEmpty;
		for i := 1 to (TextWindowWidth div 5) do
			TextWindowStrInnerSep[i * 5 + ((TextWindowWidth mod 5) shr 1)] := #7;
	end;

begin
	ResourceDataFileName := '';
	ResourceDataHeader.EntryCount := 0;
end.
