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

{$I-}
{$V-}
unit DebugWnd;

interface
	uses GameVars;
	procedure DebugBoardIllegalElements;
	procedure DebugShowElementMessage(msg: string; x, y: integer);
	procedure DebugShowSizeTooLarge(expected, actual: word; id: integer; name, desc: TString50);

implementation
uses Game, GameSh, Sounds, ZInput, TxtWind;

const
	PARTIAL_STAT_LINES_AROUND = 2;

procedure DebugBoardIllegalElements;
	var
		textWindow: TTextWindowState;
		xStr, yStr, zStr: string[11];
		count, ix, iy: integer;
	begin
		count := 0;
		for iy := 1 to BOARD_HEIGHT do
			for ix := 1 to BOARD_WIDTH do
				with Board.Tiles[ix][iy] do
{ TODO: Are these safe? What about Super ZZT? }
{ and (not (Element in [238, 239, 240, 241, 244, 246, 248, 250, 252, 254])) then begin }
					if (Element > SAFE_MAX_ELEMENT) then begin
						if count = 0 then begin
							textWindow.Title := '[Debug] Illegal Elements';
							TextWindowInitState(textWindow);
							TextWindowAppend(textWindow, 'Illegal elements detected on board at:');
							TextWindowAppend(textWindow, '');
						end;
						Str(ix, xStr);
						Str(iy, yStr);
						Str(Element, zStr);
						TextWindowAppend(textWindow, xStr + ', ' + yStr + ': ID ' + zStr);
						Inc(count);
					end;
		if count > 0 then begin
			TextWindowDrawOpen(textWindow);
			TextWindowSelect(textWindow, 0);
			TextWindowDrawClose(textWindow);
			TextWindowFree(textWindow);
		end;
	end;

procedure CopyPartialStatDataToTextWindow(statId: integer; var state: TTextWindowState);
	var
		prevLinePos: array[1 .. PARTIAL_STAT_LINES_AROUND] of integer;
		curLinePos: integer;
		firstLine: integer;
		{}
		dataStr: string;
		dataNum: string[8];
		dataChr: char;
		i, j, k: integer;
		dataStrLen: byte;
	procedure PrepLine;
		begin
			if k = PARTIAL_STAT_LINES_AROUND then dataStr := '>> '
			else dataStr := '';
			Str(k + firstLine - 1, dataNum);
			dataStr := dataStr + dataNum + '. ';
			dataStrLen := Length(dataStr);
		end; 
	label LineFound;
	begin
		with Board.Stats[statId] do begin
			for j := 1 to PARTIAL_STAT_LINES_AROUND do
				prevLinePos[j] := 0;
			curLinePos := 0;
			firstLine := 1 - PARTIAL_STAT_LINES_AROUND;

			for i := 0 to (DataLen - 1) do begin
				{$IFNDEF FPC}
				dataChr := Data^[i];
				{$ELSE}
				dataChr := Data[i];
				{$ENDIF}
				if dataChr = KEY_ENTER then begin
					if (i >= DataPos) and (curLinePos <= DataPos) then
						goto LineFound;
					for j := 2 to PARTIAL_STAT_LINES_AROUND do
						prevLinePos[j - 1] := prevLinePos[j];
					prevLinePos[PARTIAL_STAT_LINES_AROUND] := curLinePos;
					Inc(firstLine);
				end;
			end;

		LineFound:
			if firstLine < 1 then firstLine := 1;

			k := 0;
			PrepLine;

			if prevLinePos[1] > 0 then
				TextWindowAppend(state, '...');

			dataStrLen := 0;
			for i := prevLinePos[1] to (DataLen - 1) do begin 
				{$IFNDEF FPC}
				dataChr := Data^[i];
				{$ELSE}
				dataChr := Data[i];
				{$ENDIF}
				if dataChr = KEY_ENTER then begin
					dataStr[0] := Chr(dataStrLen);
					TextWindowAppend(state, dataStr);
					dataStrLen := 0;
					Inc(k);
					if k >= (2 * PARTIAL_STAT_LINES_AROUND + 1) then begin
						TextWindowAppend(state, '...');
						exit;
					end else PrepLine;
				end else begin
					Inc(dataStrLen);
					dataStr[dataStrLen] := dataChr;
				end;
			end;

			if dataStrLen > 0 then begin
				dataStr[0] := Chr(dataStrLen);
				TextWindowAppend(state, dataStr);
			end;
		end;
	end;

procedure DebugShowElementMessage(msg: string; x, y: integer);
var
	statId: integer;
	xStr, yStr, zStr: string[11];
	textWindow: TTextWindowState;
begin
	Str(x, xStr);
	Str(y, yStr);

	textWindow.Title := '[Debug] Element Error';
	TextWindowInitState(textWindow);
	TextWindowAppend(textWindow, '$' + msg);
	TextWindowAppend(textWindow, '');
	TextWindowAppend(textWindow, 'Position: ' + xStr + ', ' + yStr);

	Str(World.Info.CurrentBoard, xStr);
	TextWindowAppend(textWindow, 'Board: #' + xStr);

	Str(Board.Tiles[x][y].Element, xStr);
	TextWindowAppend(textWindow, 'Element: ' + ElementDefs[Board.Tiles[x][y].Element].Name + ' (' + xStr + ')');

	statId := GetStatIdAt(x, y);
	if statId >= 0 then begin
		with Board.Stats[statId] do begin
			Str(statId, xStr);
			TextWindowAppend(textWindow, 'Stat: #' + xStr);
			Str(StepX, xStr);
			Str(StepY, yStr);
			TextWindowAppend(textWindow, '- Step: ' + xStr + ', ' + yStr);
			Str(Cycle, xStr);
			TextWindowAppend(textWindow, '- Cycle: ' + xStr);
			Str(P1, xStr);
			Str(P2, yStr);
			Str(P3, zStr);
			TextWindowAppend(textWindow, '- Param: ' + xStr + ', ' + yStr + ', ' + zStr);
			if (Follower <> -1) or (Leader <> -1) then begin
				Str(Follower, xStr);
				Str(Leader, yStr);
				TextWindowAppend(textWindow, '- Follower: ' + xStr + ', Leader: ' + yStr);
			end;
			if DataLen <> 0 then begin
				Str(DataPos, xStr);
				Str(DataLen, yStr);
				TextWindowAppend(textWindow, '- DataPos: ' + xStr + '/' + yStr);
				if DataPos >= 0 then begin
					TextWindowAppend(textWindow, '');
					CopyPartialStatDataToTextWindow(statId, textWindow);
				end;
			end;
		end;
	end;

	SoundQueue(5, #80#10);
	TextWindowDrawOpen(textWindow);
	TextWindowSelect(textWindow, 0);
	TextWindowDrawClose(textWindow);
	TextWindowFree(textWindow);
end;

procedure DebugShowSizeTooLarge(expected, actual: word; id: integer; name, desc: TString50);
var
	xStr, yStr: string[11];
	textWindow: TTextWindowState;
begin
	textWindow.Title := '[Debug] ' + name + ' size too large';
	TextWindowInitState(textWindow);
	Str(id, xStr);
	TextWindowAppend(textWindow, '$The size of ' + name + ' ' + xStr);
	TextWindowAppend(textWindow, '$' + desc);
	Str(expected, xStr);
	Str(actual, yStr);
	TextWindowAppend(textWindow, '$(' + yStr + '/' + xStr + ' bytes)');

	TextWindowDrawOpen(textWindow);
	TextWindowSelect(textWindow, 0);
	TextWindowDrawClose(textWindow);
	TextWindowFree(textWindow);
end;

end.
