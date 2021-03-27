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
unit TxtWind;

interface
	uses Video;
	const
		MAX_TEXT_WINDOW_LINES = 1024;
		MAX_RESOURCE_DATA_FILES = 24;
		TextWindowX = 5;
		TextWindowY = 3;
		TextWindowWidth = 50;
		TextWindowHeight = 18;
	type
		TTextWindowLine = string[50];
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
			EntryCount: integer;
			Name: array[1 .. MAX_RESOURCE_DATA_FILES] of string[50];
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
		ResourceDataFileName: string[50];
		ResourceDataHeader: TResourceDataHeader;
		OrderPrintId: ^string;
	procedure TextWindowInitState(var state: TTextWindowState);
	procedure TextWindowDrawOpen(var state: TTextWindowState);
	procedure TextWindowDrawClose(var state: TTextWindowState);
	procedure TextWindowDraw(var state: TTextWindowState; withoutFormatting, viewingFile: boolean);
	procedure TextWindowAppend(var state: TTextWindowState; line: TTextWindowLine);
	procedure TextWindowFree(var state: TTextWindowState);
	procedure TextWindowSelect(var state: TTextWindowState; hyperlinkAsSelect, viewingFile: boolean);
	procedure TextWindowOpenFile(filename: TTextWindowLine; var state: TTextWindowState);
	procedure TextWindowDisplayFile(filename, title: string);
	procedure TextWindowInit;
	procedure DrawInventoryItem(x,y: integer; InvItem: string);

implementation
uses Crt, Input, Printer;

function UpCaseString(input: string): string;
	var
		i: integer;
	begin
		for i := 1 to Length(input) do
			input[i] := UpCase(input[i]);
		UpCaseString := input;
	end;

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

procedure TextWindowDrawOpen(var state: TTextWindowState);
	var
		ix, iy: integer;
	begin
		SlowInput;
		InputKeyPressed := #0;
		TrueDelay(200);
		with state do begin
			for iy := 1 to (TextWindowHeight + 1) do
				VideoMove(TextWindowX, iy + TextWindowY - 1, TextWindowWidth, @ScreenCopy[iy], false);

			for iy := (TextWindowHeight div 2) downto 0 do begin
				VideoWriteText(TextWindowX, TextWindowY + iy + 1, $0F, TextWindowStrText);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy - 1, $0F, TextWindowStrText);
				VideoWriteText(TextWindowX, TextWindowY + iy, $0F, TextWindowStrTop);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy, $0F, TextWindowStrBottom);
				TrueDelay(17);
			end;

			VideoWriteText(TextWindowX, TextWindowY + 2, $0F, TextWindowStrSep);
			TextWindowDrawTitle($1E, Title);
		end;
	end;

procedure TextWindowDrawClose(var state: TTextWindowState);
	var
		ix, iy: integer;
		unk1, unk2: integer;
	begin
		with state do begin
			for iy := 0 to (TextWindowHeight div 2) do begin
				VideoWriteText(TextWindowX, TextWindowY + iy, $0F, TextWindowStrTop);
				VideoWriteText(TextWindowX, TextWindowY + TextWindowHeight - iy, $0F, TextWindowStrBottom);
				TrueDelay(7);
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
				VideoWriteText(TextWindowX + 2, lineY, $1C, TextWindowStrInnerArrows)
			else
				VideoWriteText(TextWindowX + 2, lineY, $1E, TextWindowStrInnerEmpty);
			if (lpos > 0) and (lpos <= LineCount) then begin
				if withoutFormatting then begin
					VideoWriteText(TextWindowX + 4, lineY, $1E, Lines[lpos]^);
				end else begin
					textOffset := 1;
					textColor := $1E;
					textX := TextWindowX + 4;
					if Length(state.Lines[lpos]^) > 0 then begin
						case state.Lines[lpos]^[1] of
							'!': begin
								textOffset := Pos(';', Lines[lpos]^) + 1;
								VideoWriteText(textX + 2, lineY, $1D, #16);
								textX := textX + 5;
								textColor := $1F;
							end;
							':': begin
								textOffset := Pos(';', Lines[lpos]^) + 1;
								textColor := $1F;
							end;
							'$': begin
								textOffset := 2;
								textColor := $1F;
								textX := (textX - 4) + ((TextWindowWidth - Length(Lines[lpos]^)) div 2);
							end;
							'%': begin
								textOffset := 2;
								textColor := $1C;
								if Length(Lines[lpos]^) < 21 then
									textX := ((TextWindowWidth div 2) - Length(Lines[lpos]^)) + 4;
							end;
							'&': begin
								textOffset := 2;
								textColor := $1D;
								if Length(Lines[lpos]^) > 20 then
									textX := (TextWindowWidth - Length(Lines[lpos]^)) + 2
								else
									textX := (TextWindowWidth div 2) + 5;
							end;
						end;
					end;
					if textOffset > 0 then begin
						VideoWriteText(textX, lineY, textColor,
							Copy(Lines[lpos]^, textOffset,Length(Lines[lpos]^) - textOffset + 1));
					end;
				end;
			end else if (lpos = 0) or (lpos = (state.LineCount + 1)) then begin
				VideoWriteText(TextWindowX + 2, lineY, $1E, TextWindowStrInnerSep);
			end else if (lpos = -4) and viewingFile then begin
				VideoWriteText(TextWindowX + 2, lineY, $1A, '   Use            to view text,');
				VideoWriteText(TextWindowX + 2 + 7, lineY, $1F, #24' '#25', Enter');
			end else if (lpos = -3) and viewingFile then begin
				VideoWriteText(TextWindowX + 2 + 1, lineY, $1A, '                 to print.');
				VideoWriteText(TextWindowX + 2 + 12, lineY, $1F, 'Alt-P');
			end;
		end;
	end;

procedure TextWindowDraw(var state: TTextWindowState; withoutFormatting, viewingFile: boolean);
	var
		i: integer;
		unk1: integer;
	begin
		for i := 0 to (TextWindowHeight - 4) do
			TextWindowDrawLine(state, state.LinePos - (TextWindowHeight div 2) + i + 2,
				withoutFormatting, viewingFile);
		TextWindowDrawTitle($1E, state.Title);
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

procedure TextWindowSelect(var state: TTextWindowState; hyperlinkAsSelect, viewingFile: boolean);
	var
		newLinePos: integer;
		iLine, iChar: integer;
		pointerStr: string[20];
		FirstInput: boolean;
	label LabelMatched;
	label LabelNotMatched;
	begin
		FirstInput := true;
		SlowInput;
		with state do begin
			TextWindowRejected := false;
			Hyperlink := '';
			TextWindowDraw(state, false, viewingFile);
			repeat
				InputUpdate;
				if FirstInput then begin
					InputKeyPressed := #0;
					TrueDelay(200);
					FirstInput := false;
				end;
				newLinePos := LinePos;
				if InputDeltaY <> 0 then begin
					newLinePos := newLinePos + InputDeltaY;
					TrueDelay(35);
				end else if InputKeyPressed = KEY_ENTER then begin
					if (Lines[LinePos]^[1]) = '!' then begin
						pointerStr := Copy(Lines[LinePos]^, 2, Length(Lines[LinePos]^) - 1);

						if Pos(';', pointerStr) > 0 then begin
							pointerStr := Copy(pointerStr, 1, Pos(';', pointerStr) - 1);
						end;

						if pointerStr[1] = '-' then begin
							Delete(pointerStr, 1, 1);
							TextWindowFree(state);
							TextWindowOpenFile(pointerStr, state);
							if state.LineCount = 0 then
								exit
							else begin
								viewingFile := true;
								newLinePos := LinePos;
								TextWindowDraw(state, false, viewingFile);
								InputKeyPressed := #0;
							end;
						end else begin
							if hyperlinkAsSelect then begin
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
										goto LabelMatched;
									LabelNotMatched:
									end;
								end;
							end;
						end;
					end;
				end else begin
					if InputKeyPressed = KEY_PAGE_UP then
						newLinePos := LinePos - TextWindowHeight + 4
					else if InputKeyPressed = KEY_PAGE_DOWN then
						newLinePos := LinePos + TextWindowHeight - 4
				end;

			LabelMatched:
				if newLinePos < 1 then
					newLinePos := 1
				else if newLinePos > state.LineCount then
					newLinePos := LineCount;

				if newLinePos <> LinePos then begin
					LinePos := newLinePos;
					TextWindowDraw(state, false, viewingFile);
					if ((Lines[LinePos]^[1]) = '!') or ((Lines[LinePos]^[1]) = '^') then
						if hyperlinkAsSelect then
							TextWindowDrawTitle($1E, #26'Press ENTER to select this'#27)
						else
							TextWindowDrawTitle($1E, #26'Press ENTER for more info'#27);
				end;
				if InputJoystickMoved then begin
					TrueDelay(35);
				end;
			until ((InputKeyPressed = KEY_ENTER) and (InputDeltaY = 0)) or (InputKeyPressed = KEY_ESCAPE);
			if InputKeyPressed = KEY_ESCAPE then begin
				InputKeyPressed := #0;
				TextWindowRejected := true;
			end;
		end;
		{FastInput;}
	end;

procedure TextWindowOpenFile(filename: TTextWindowLine; var state: TTextWindowState);
	var
		f: file;
		tf: text;
		i: integer;
		entryPos: integer;
		retVal: boolean;
		line: ^string;
		lineLen: byte;
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
				if IOResult <> 0 then
					ResourceDataHeader.EntryCount := -1;
				Close(f);
			end;

			if entryPos = 0 then begin
				for i := 1 to ResourceDataHeader.EntryCount do begin
					if UpCaseString(ResourceDataHeader.Name[i]) = UpCaseString(filename) then
						entryPos := i;
				end;
			end;

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
						New(Lines[LineCount]);

						BlockRead(f, Lines[LineCount]^, 1);
						line := Ptr(Seg(Lines[LineCount]^), Ofs(Lines[LineCount]^) + 1);
						lineLen := Ord(Lines[LineCount]^[0]);
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
					Close(f);
				end;
			end;
		end;
	end;

procedure TextWindowDisplayFile(filename, title: string);
	var
		state: TTextWindowState;
	begin
		state.Title := title;
		TextWindowOpenFile(filename, state);
		state.Selectable := false;
		if state.LineCount > 0 then begin
			TextWindowDrawOpen(state);
			TextWindowSelect(state, false, true);
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
			TextWindowStrInnerLine[i] := #127;
		end;
		TextWindowStrTop    := #222#29 + TextWindowStrInnerLine  + #31#221;
		TextWindowStrBottom := #222#18 + TextWindowStrInnerLine  + #12#221;
		TextWindowStrSep    :=  ' '#222 + TextWindowStrInnerLine  + #221' ';
		TextWindowStrText   :=  ' '#222 + TextWindowStrInnerEmpty + #221' ';
		TextWindowStrInnerArrows := TextWindowStrInnerEmpty;
		TextWindowStrInnerArrows[1] := #26;
		TextWindowStrInnerArrows[Length(TextWindowStrInnerArrows)] := #27;
		TextWindowStrInnerSep := TextWindowStrInnerEmpty;
		for i := 1 to (TextWindowWidth div 5) do
			TextWindowStrInnerSep[i * 5 + ((TextWindowWidth mod 5) div 2)] := #7;
	end;

procedure DrawInventoryItem(x,y: integer; InvItem: string);
    var
		ix, iy: integer;
	begin
		ix := (x * 10) + 1;
		iy := (y * 6 ) + 2;

		if InvItem = 'SCONCE' then begin
			VideoWriteText(ix, iy, $16, #222);
			VideoWriteText(ix + 1, iy, $0E, #219);
			VideoWriteText(ix + 2, iy, $16, #221);
			VideoWriteText(ix + 3, iy, $6E, #222#221);
			VideoWriteText(ix + 5, iy, $16, #222);
			VideoWriteText(ix + 6, iy, $0E, #219);
			VideoWriteText(ix + 7, iy, $16, #221);
			Inc(iy);
			VideoWriteText(ix, iy, $71, #11);
			VideoWriteText(ix + 1, iy, $F7, #32#18#32#32#12#32);
			VideoWriteText(ix + 7, iy, $71, #10);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $18, #94);
			VideoWriteText(ix + 2, iy, $71, #31);
			VideoWriteText(ix + 3, iy, $7F, #5#4);
			VideoWriteText(ix + 5, iy, $71, #29);
			VideoWriteText(ix + 6, iy, $18, #94);
		end else if InvItem = 'PLANT' then begin
			VideoWriteText(ix, iy, $12, #5);
			VideoWriteText(ix + 1, iy, $2A, #42);
			VideoWriteText(ix + 2, iy, $A2, #42);
			VideoWriteText(ix + 3, iy, $21, #42#223);
			VideoWriteText(ix + 5, iy, $A2, #94);
			VideoWriteText(ix + 6, iy, $21, #94);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $12, #232);
			VideoWriteText(ix + 2, iy, $24, #132);
			VideoWriteText(ix + 3, iy, $AC, #132#132);
			VideoWriteText(ix + 5, iy, $24, #132);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $16, #42);
			VideoWriteText(ix + 3, iy, $6E, #223#223);
			VideoWriteText(ix + 5, iy, $16, #250);
		end else if InvItem = 'MAP' then begin
			VideoWriteText(ix, iy, $16, #222);
			VideoWriteText(ix + 1, iy, $E6, #94);
			VideoWriteText(ix + 2, iy, $6E, #31);
			VideoWriteText(ix + 3, iy, $E6, #94);
			VideoWriteText(ix + 4, iy, $A6, #94#94);
			VideoWriteText(ix + 6, iy, $E6, #94);
			VideoWriteText(ix + 7, iy, $16, #221);
			Inc(iy);
			VideoWriteText(ix, iy, $16, #222);
			VideoWriteText(ix + 1, iy, $AE, #221#42#146);
			VideoWriteText(ix + 4, iy, $AF, #132);
			VideoWriteText(ix + 5, iy, $AE, #18#219);
			VideoWriteText(ix + 7, iy, $16, #221);
			Inc(iy);
			VideoWriteText(ix, iy, $16, #222);
			VideoWriteText(ix + 1, iy, $E6, #132);
			VideoWriteText(ix + 2, iy, $6E, #18#12);
			VideoWriteText(ix + 4, iy, $E6, #132);
			VideoWriteText(ix + 5, iy, $6E, #12);
			VideoWriteText(ix + 6, iy, $E6, #132);
			VideoWriteText(ix + 7, iy, $16, #221);
		end else if InvItem = 'SOCKS' then begin
			VideoWriteText(ix + 2, iy, $C1, #250);
			VideoWriteText(ix + 3, iy, $14, #240#227);
			VideoWriteText(ix + 5, iy, $0C, #219);
			VideoWriteText(ix + 6, iy, $14, #11);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $14, #234);
			VideoWriteText(ix + 2, iy, $4C, #232);
			VideoWriteText(ix + 3, iy, $14, #219#222#219#221);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $41, #248#227);
			VideoWriteText(ix + 3, iy, $14, #248);
			VideoWriteText(ix + 5, iy, $14, #42);
			VideoWriteText(ix + 6, iy, $41, #132);
		end else if InvItem = 'SHIRT' then begin
			VideoWriteText(ix + 1, iy, $31, #250);
			VideoWriteText(ix + 2, iy, $B3, #250);
			VideoWriteText(ix + 3, iy, $3B, #220#220#220);
			VideoWriteText(ix + 6, iy, $31, #42);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $31, #132);
			VideoWriteText(ix + 2, iy, $03, #219);
			VideoWriteText(ix + 3, iy, $3B, #219#219#221);
			VideoWriteText(ix + 6, iy, $31, #132);
			VideoWriteText(ix + 7, iy, $13, #4);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $3B, #32#223#223#4);
		end else if InvItem = 'PANTS' then begin
			VideoWriteText(ix + 2, iy, $A2, #144);
			VideoWriteText(ix + 3, iy, $2A, #94#94#144);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $2A, #221);
			VideoWriteText(ix + 3, iy, $A1, #10#240);
			VideoWriteText(ix + 5, iy, $2A, #222);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $2A, #221);
			VideoWriteText(ix + 3, iy, $1A, #221#222);
			VideoWriteText(ix + 5, iy, $2A, #222);
		end else if InvItem = 'CANDLE' then begin
			VideoWriteText(ix + 3, iy, $1E, #222#240);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $16, #234);
			VideoWriteText(ix + 3, iy, $E1, #146#147);
			VideoWriteText(ix + 5, iy, $16, #233);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $61, #250);
			VideoWriteText(ix + 3, iy, $6E, #18#12);
			VideoWriteText(ix + 5, iy, $61, #42);
		end else if InvItem = 'BUCKET' then begin
			VideoWriteText(ix + 1, iy, $16, #10);
			VideoWriteText(ix + 2, iy, $6E, #142#127#127#141);
			VideoWriteText(ix + 6, iy, $16, #11);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $16, #222);
			VideoWriteText(ix + 2, iy, $6E, #139#127#127#140);
			VideoWriteText(ix + 6, iy, $16, #221);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $16, #5);
			VideoWriteText(ix + 2, iy, $68, #232#94#94#248);
			VideoWriteText(ix + 6, iy, $16, #4);
		end else if ((InvItem = 'WATER') or (InvItem = 'ICE')) or (InvItem = 'HOTWATER') then begin
			VideoWriteText(ix + 1, iy, $16, #10);
			VideoWriteText(ix + 2, iy, $E6, #250);
			VideoWriteText(ix + 3, iy, $6B, #220#220);
			VideoWriteText(ix + 5, iy, $E6, #42);
			VideoWriteText(ix + 6, iy, $16, #11);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $16, #222);
			VideoWriteText(ix + 2, iy, $6E, #232);
			VideoWriteText(ix + 3, iy, $6B, #223#223);
			VideoWriteText(ix + 5, iy, $6E, #248);
			VideoWriteText(ix + 6, iy, $16, #221);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $16, #5);
			VideoWriteText(ix + 2, iy, $68, #232#94#94#248);
			VideoWriteText(ix + 6, iy, $16, #4);
		end else if InvItem = 'SHIELD' then begin
			VideoWriteText(ix + 2, iy, $31, #94);
			VideoWriteText(ix + 3, iy, $B3, #94);
			VideoWriteText(ix + 4, iy, $C6, #94);
			VideoWriteText(ix + 5, iy, $61, #94);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $36, #220);
			VideoWriteText(ix + 3, iy, $BC, #220#223);
			VideoWriteText(ix + 5, iy, $36, #223);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $16, #232);
			VideoWriteText(ix + 3, iy, $61, #240);
			VideoWriteText(ix + 4, iy, $B1, #227);
			VideoWriteText(ix + 5, iy, $13, #248);
		end else if InvItem = 'LADDER' then begin
			VideoWriteText(ix, iy, $16, #220#220#220#220#220#220#220#220);
			Inc(iy);
			VideoWriteText(ix, iy, $16, #222#32#221#222#32#221#222);
			Inc(iy);
			VideoWriteText(ix, iy, $16, #223#223#223#223#223#223#223#223);
		end else if InvItem = 'MEAT' then begin
			VideoWriteText(ix, iy, $17, #10);
			VideoWriteText(ix + 1, iy, $1F, #220);
			VideoWriteText(ix + 3, iy, $16, #227#220#220#240);
			Inc(iy);
			VideoWriteText(ix, iy, $17, #232);
			VideoWriteText(ix + 1, iy, $F7, #11#94);
			VideoWriteText(ix + 3, iy, $6F, #221#32#32#32);
			VideoWriteText(ix + 7, iy, $16, #221);
			Inc(iy);
			VideoWriteText(ix, iy, $17, #5);
			VideoWriteText(ix + 1, iy, $F1, #132);
			VideoWriteText(ix + 2, iy, $17, #94);
			VideoWriteText(ix + 3, iy, $16, #42);
			VideoWriteText(ix + 4, iy, $61, #132#132#132);
			VideoWriteText(ix + 7, iy, $16, #248);
		end else if InvItem = 'PAINTING' then begin
			VideoWriteText(ix, iy, $6B, #10);
			VideoWriteText(ix + 1, iy, $B6, #94#94);
			VideoWriteText(ix + 3, iy, $C6, #94);
			VideoWriteText(ix + 4, iy, $B6, #94#94#94);
			VideoWriteText(ix + 7, iy, $6B, #11);
			Inc(iy);
			VideoWriteText(ix, iy, $6B, #222);
			VideoWriteText(ix + 1, iy, $BC, #139);
			VideoWriteText(ix + 2, iy, $CB, #94#32#94#94);
			VideoWriteText(ix + 6, iy, $BC, #4);
			VideoWriteText(ix + 7, iy, $6B, #221);
			Inc(iy);
			VideoWriteText(ix, iy, $63, #5);
			VideoWriteText(ix + 1, iy, $36, #132#132#132#132#132#132);
			VideoWriteText(ix + 7, iy, $63, #4);
		end else if InvItem = 'FLASK' then begin
			VideoWriteText(ix + 3, iy, $12, #220#220);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $2E, #127);
			VideoWriteText(ix + 3, iy, $AE, #127#127);
			VideoWriteText(ix + 5, iy, $26, #127);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $12, #223#223#223#223);
		end else if InvItem = 'PLATTER' then begin
			Inc(iy);
			VideoWriteText(ix, iy, $18, #227);
			VideoWriteText(ix + 1, iy, $1F, #220#220#220#220#220#220);
			VideoWriteText(ix + 7, iy, $18, #240);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $17, #94#94#94#94);
		end else if InvItem = 'MIRROR' then begin
			VideoWriteText(ix + 1, iy, $1E, #144);
			VideoWriteText(ix + 2, iy, $7E, #223#223);
			VideoWriteText(ix + 4, iy, $EF, #220);
			VideoWriteText(ix + 5, iy, $E8, #144);
			VideoWriteText(ix + 6, iy, $18, #248);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $1E, #222);
			VideoWriteText(ix + 2, iy, $F7, #219#227);
			VideoWriteText(ix + 4, iy, $7F, #157);
			VideoWriteText(ix + 5, iy, $8E, #221);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $1E, #145);
			VideoWriteText(ix + 2, iy, $EF, #223);
			VideoWriteText(ix + 3, iy, $E7, #223);
			VideoWriteText(ix + 4, iy, $EF, #223);
			VideoWriteText(ix + 5, iy, $E8, #145);
			VideoWriteText(ix + 6, iy, $18, #240);
		end else if InvItem = 'MILPOR' then begin
			VideoWriteText(ix + 1, iy, $1F, #144);
			VideoWriteText(ix + 2, iy, $7F, #223#223);
			VideoWriteText(ix + 4, iy, $FF, #220);
			VideoWriteText(ix + 5, iy, $F8, #144);
			VideoWriteText(ix + 6, iy, $18, #248);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $1F, #222);
			VideoWriteText(ix + 2, iy, $F7, #219#227);
			VideoWriteText(ix + 4, iy, $7F, #157);
			VideoWriteText(ix + 5, iy, $8F, #221);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $1F, #145);
			VideoWriteText(ix + 2, iy, $FF, #223);
			VideoWriteText(ix + 3, iy, $F7, #223);
			VideoWriteText(ix + 4, iy, $FF, #223);
			VideoWriteText(ix + 5, iy, $F8, #145);
			VideoWriteText(ix + 6, iy, $18, #240);
		end else if InvItem = 'SCRYER' then begin
			VideoWriteText(ix + 1, iy, $18, #144);
			VideoWriteText(ix + 2, iy, $08, #223#223);
			VideoWriteText(ix + 4, iy, $87, #220);
			VideoWriteText(ix + 5, iy, $80, #144);
			VideoWriteText(ix + 6, iy, $10, #248);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $18, #222);
			VideoWriteText(ix + 2, iy, $70, #219#227);
			VideoWriteText(ix + 4, iy, $07, #157);
			VideoWriteText(ix + 5, iy, $08, #221);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $18, #145);
			VideoWriteText(ix + 2, iy, $87, #223);
			VideoWriteText(ix + 3, iy, $80, #223);
			VideoWriteText(ix + 4, iy, $87, #223);
			VideoWriteText(ix + 5, iy, $80, #145);
			VideoWriteText(ix + 6, iy, $10, #240);
		end else if InvItem = 'LANTERN' then begin
			VideoWriteText(ix + 2, iy, $81, #146);
			VideoWriteText(ix + 3, iy, $87, #29#233);
			VideoWriteText(ix + 5, iy, $18, #233);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $18, #10);
			VideoWriteText(ix + 2, iy, $78, #221);
			VideoWriteText(ix + 3, iy, $FC, #5);
			VideoWriteText(ix + 4, iy, $7F, #221);
			VideoWriteText(ix + 5, iy, $81, #232);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $18, #227);
			VideoWriteText(ix + 2, iy, $87, #147);
			VideoWriteText(ix + 3, iy, $7F, #5);
			VideoWriteText(ix + 4, iy, $78, #234);
			VideoWriteText(ix + 5, iy, $81, #5);
		end else if InvItem = 'GOBLET' then begin
			VideoWriteText(ix + 2, iy, $6E, #234#127#233);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $16, #42);
			VideoWriteText(ix + 3, iy, $64, #94);
			VideoWriteText(ix + 4, iy, $16, #250);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $16, #132#219#132);
		end else if InvItem = 'AMETHISP' then begin
			VideoWriteText(ix + 2, iy, $15, #227);
			VideoWriteText(ix + 3, iy, $D5, #250);
			VideoWriteText(ix + 4, iy, $51, #42#94);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $51, #240);
			VideoWriteText(ix + 2, iy, $D5, #42#32#157);
			VideoWriteText(ix + 5, iy, $15, #250);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $15, #234);
			VideoWriteText(ix + 2, iy, $5D, #18);
			VideoWriteText(ix + 3, iy, $D5, #132);
			VideoWriteText(ix + 4, iy, $5D, #250);
			VideoWriteText(ix + 5, iy, $15, #4);
		end else if InvItem = 'HELMET' then begin
			VideoWriteText(ix + 2, iy, $17, #227);
			VideoWriteText(ix + 3, iy, $71, #233#234);
			VideoWriteText(ix + 5, iy, $17, #240);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $87, #94);
			VideoWriteText(ix + 3, iy, $78, #240#227);
			VideoWriteText(ix + 5, iy, $87, #94);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $18, #42);
			VideoWriteText(ix + 3, iy, $81, #132#132);
			VideoWriteText(ix + 5, iy, $18, #250);
		end else if InvItem = 'ANVIL' then begin
			VideoWriteText(ix + 1, iy, $87, #10);
			VideoWriteText(ix + 2, iy, $78, #94#94#94#94#94);
			VideoWriteText(ix + 7, iy, $18, #11);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $18, #42);
			VideoWriteText(ix + 2, iy, $87, #94#94#94);
			VideoWriteText(ix + 5, iy, $18, #223#94);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $87, #12#127#18);
		end else if InvItem = 'REDWHEN' then begin
			VideoWriteText(ix + 3, iy, $C6, #42#250);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $1C, #227#219#219#240);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $1C, #222);
			VideoWriteText(ix + 3, iy, $CE, #223#223);
			VideoWriteText(ix + 5, iy, $1C, #221);
		end else if InvItem = 'BLUEWHEN' then begin
			VideoWriteText(ix + 3, iy, $B6, #42#250);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $1B, #227#219#219#240);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $1B, #222);
			VideoWriteText(ix + 3, iy, $BE, #223#223);
			VideoWriteText(ix + 5, iy, $1B, #221);
		end else if InvItem = 'VIOLETTA' then begin
			VideoWriteText(ix + 1, iy, $15, #227);
			VideoWriteText(ix + 2, iy, $51, #250);
			VideoWriteText(ix + 3, iy, $D1, #94);
			VideoWriteText(ix + 4, iy, $51, #42);
			VideoWriteText(ix + 5, iy, $15, #240);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $15, #5);
			VideoWriteText(ix + 2, iy, $D1, #132);
			VideoWriteText(ix + 3, iy, $ED, #132);
			VideoWriteText(ix + 4, iy, $D1, #132);
			VideoWriteText(ix + 5, iy, $15, #4);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $12, #42);
			VideoWriteText(ix + 2, iy, $2A, #12);
			VideoWriteText(ix + 3, iy, $AD, #94);
			VideoWriteText(ix + 4, iy, $2A, #18);
			VideoWriteText(ix + 5, iy, $12, #250);
		end else if InvItem = 'PLANKS' then begin
			VideoWriteText(ix + 2, iy, $19, #132#132#132#132#240);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $69, #234#32#32#32#233);
			VideoWriteText(ix + 6, iy, $19, #221);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $69, #234#32#32#32#233);
			VideoWriteText(ix + 6, iy, $19, #4);
		end else if InvItem = 'TOWEL' then begin
			VideoWriteText(ix + 1, iy, $1D, #227#132#132#132#132#132);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $0D, #219#219#219#251#219);
			VideoWriteText(ix + 6, iy, $D1, #147);
			Inc(iy);
			VideoWriteText(ix + 1, iy, $D5, #234#220#220#220#220#220);
		end else if InvItem = 'COIN' then begin
			VideoWriteText(ix + 3, iy, $17, #171#170);
			Inc(iy);
			VideoWriteText(ix + 2, iy, $71, #148);
			VideoWriteText(ix + 3, iy, $17, #156#155);
			VideoWriteText(ix + 5, iy, $71, #149);
			Inc(iy);
			VideoWriteText(ix + 3, iy, $17, #168#169);

		{
		end else if InvItem = '' then begin
			VideoWriteText(ix, iy, $, #);
			VideoWriteText(ix + 1, iy, $, #);
			VideoWriteText(ix + 2, iy, $, #);
			VideoWriteText(ix + 3, iy, $, #);
			VideoWriteText(ix + 4, iy, $, #);
			VideoWriteText(ix + 5, iy, $, #);
			VideoWriteText(ix + 6, iy, $, #);
			VideoWriteText(ix + 7, iy, $, #);
			Inc(iy);
			VideoWriteText(ix, iy, $, #);
			VideoWriteText(ix + 1, iy, $, #);
			VideoWriteText(ix + 2, iy, $, #);
			VideoWriteText(ix + 3, iy, $, #);
			VideoWriteText(ix + 4, iy, $, #);
			VideoWriteText(ix + 5, iy, $, #);
			VideoWriteText(ix + 6, iy, $, #);
			VideoWriteText(ix + 7, iy, $, #);
			Inc(iy);
			VideoWriteText(ix, iy, $, #);
			VideoWriteText(ix + 1, iy, $, #);
			VideoWriteText(ix + 2, iy, $, #);
			VideoWriteText(ix + 3, iy, $, #);
			VideoWriteText(ix + 4, iy, $, #);
			VideoWriteText(ix + 5, iy, $, #);
			VideoWriteText(ix + 6, iy, $, #);
			VideoWriteText(ix + 7, iy, $, #);
		}

		end;
		Inc(iy);
		VideoWriteText(ix + ((8 - Length(invitem)) div 2), iy, $17, invitem);
	end;

begin
	ResourceDataFileName := '';
	ResourceDataHeader.EntryCount := 0;
end.
