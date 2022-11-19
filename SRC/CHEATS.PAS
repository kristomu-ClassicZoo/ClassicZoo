{
	Copyright (c) 2020 Adrian Siekierka

	Based on a reconstruction of code from ZZT and Super ZZT,
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
unit Cheats;

interface
	uses GameVars;
	procedure GameDebugPrompt;

implementation
uses DebugWnd, GameSh, Game, Sidebar, Oop, TxtWind, ZVideo, ZInput, Sounds, Editor;

function DebugPromptParseInt(input: TString50; offset: integer; defaultValue: integer): integer;
	var
		substr: TString50;
		result, code: integer;
	begin
		if Length(input) >= (offset + 2) then begin
			substr := Copy(input, offset + 2, Length(input));
			Val(substr, result, code);
			DebugPromptParseInt := result;
		end else begin
			DebugPromptParseInt := defaultValue;
		end;
	end;

function DebugPromptParseElem(input: TString50; offset: integer): integer;
	var
		substr: TString50;
		i: integer;
		j: byte;
	begin
		j := 0;
		for i := offset + 2 to Length(input) do begin
			Inc(j);
			substr[j] := UpCase(input[i]);
		end;
		substr[0] := Chr(j);
		if substr = 'ALL' then begin
			DebugPromptParseElem := -1;
			exit;
		end;
		for i := 0 to MAX_ELEMENT do begin
			if substr = OopStringToWord(ElementDefs[i].Name) then begin
				DebugPromptParseElem := i;
				exit;
			end;
		end;
		DebugPromptParseElem := E_BOARD_EDGE;
	end;

function DebugPromptParseColor(input: TString50; var offset: integer): integer;
	var
		substr: TString50;
		i, newOffset: integer;
		j: byte;
	begin
		j := 0;
		newOffset := offset + 1;
		while (newOffset < Length(input)) and (input[newOffset + 1] <> ' ') do begin
			Inc(j);
			Inc(newOffset);
			substr[j] := UpCase(input[newOffset]);
		end;
		substr[0] := Chr(j);
		for i := 1 to 7 do begin
			if substr = OopStringToWord(ColorNames[i]) then begin
				DebugPromptParseColor := i;
				offset := newOffset;
				exit;
			end;
		end;
		DebugPromptParseColor := -1;
	end;

function DebugPromptStarts(input: TString50; cmp: TString50): boolean;
	var
		i: integer;
	begin
		DebugPromptStarts := Length(input) >= Length(cmp);
		for i := 1 to Length(cmp) do begin
			if input[i] <> cmp[i] then begin
				DebugPromptStarts := false;
				exit;
			end;
		end;
	end;

procedure DebugPromptFlagWindow;
	var
		i: integer;
		flagId: string[11];
		textWindow: TTextWindowState;
	begin
		textWindow.Title := 'Flags';
		TextWindowInitState(textWindow);
		for i := 1 to MAX_FLAG do begin
			Str(i, flagId);
			TextWindowAppend(textWindow, flagId + ': ' + World.Info.Flags[i]);
		end;

		TextWindowDrawOpen(textWindow);
		TextWindowSelect(textWindow, 0);
		TextWindowDrawClose(textWindow);
		TextWindowFree(textWindow);
	end;

procedure DebugPromptTouchAll(ielem, icolor: integer);
	var
		ix, iy, dx, dy: integer;
	begin
		for ix := 1 to BOARD_WIDTH do begin
			for iy := 1 to BOARD_HEIGHT do with Board.Tiles[ix][iy] do begin
				if (Element = ielem) and ((icolor < 0) or ((icolor and $07) = (Color and $07))) then begin
					dx := 0;
					dy := 0;
					ElementDefs[Element].TouchProc(ix, iy, 0, dx, dy);
					BoardDrawTile(ix, iy);
				end;
			end;
		end;
	end;

procedure GameDebugPrompt;
	var
		input: TSmallString;
		i, iMin, iMax: integer;
		btmp: byte;
		failed: boolean;
		isYes: boolean; { True if not 'NO[cheat]' }
		isYesMultiplier: integer; { -1 if 'NO[cheat]', 1 otherwise }
	begin
		input := '';

{$IFDEF E_SUPERZ}
		ClearDisplayMessage;
		PromptString(15, VideoRows - 1, $1E, $0F, 11, 50, PROMPT_ANY, input);
		ClearDisplayMessage;
{$ELSE}
		SidebarClearLine(4);
		SidebarClearLine(5);
		PromptString(63, 5, $1E, $0F, 11, 50, PROMPT_ANY, input);
{$ENDIF}

		for i := 1 to Length(input) do
			input[i] := UpCase(input[i]);

		isYes := true;
		isYesMultiplier := 1;
		failed := false;
		if Length(input) <= 0 then begin
			{ No-op. }
		end else if input[1] = '?' then begin
			{ Open help file. }
			if Length(input) >= 2 then
				input := Copy(input, 2, Length(input) - 1)
			else
				input := 'CHEAT';
			TextWindowDisplayFile(input, 'View file');
		end else if (input[1] = '+') or (input[1] = '-') then begin
			isYes := input[1] = '+';
			input := Copy(input, 2, Length(input) - 1);

			if isYes then
				WorldSetFlag(input)
			else
				WorldClearFlag(input);
		end else begin
			if (Length(input) >= 2) and (input[1] = 'N') and (input[2] = 'O') then begin
				input := Copy(input, 3, Length(input) - 2);
				isYes := false;
				isYesMultiplier := -1;
			end;

			if DebugPromptStarts(input, 'HEALTH') then
				Inc(World.Info.Health, DebugPromptParseInt(input, 6, 50) * isYesMultiplier)
			else if DebugPromptStarts(input, 'AMMO') then
				Inc(World.Info.Ammo, DebugPromptParseInt(input, 4,
					{$IFDEF E_SUPERZ}20{$ELSE}5{$ENDIF}) * isYesMultiplier)
			else if DebugPromptStarts(input, 'KEYS') then begin
				iMin := 4;
				i := DebugPromptParseColor(input, iMin);
				if i > 0 then World.Info.Keys[i] := isYes
				else for i := 1 to 7 do World.Info.Keys[i] := isYes;
{$IFDEF E_ZZT}
			end else if DebugPromptStarts(input, 'TORCHES') then begin
				Inc(World.Info.Torches, DebugPromptParseInt(input, 7, 3) * isYesMultiplier);
			end else if DebugPromptStarts(input, 'ENERGIZE') then begin
				Inc(World.Info.EnergizerTicks, DebugPromptParseInt(input, 8, 75) * isYesMultiplier);
{$ELSE}
			end else if DebugPromptStarts(input, 'Z') then begin
				if isYes then Inc(World.Info.StonesOfPower, DebugPromptParseInt(input, 1, 1))
				else World.Info.StonesOfPower := -1;
{$ENDIF}
			end else if DebugPromptStarts(input, 'TIME') then begin
				Dec(World.Info.BoardTimeSec, DebugPromptParseInt(input, 4, 30) * isYesMultiplier);
			end else if DebugPromptStarts(input, 'GEMS') then begin
				Inc(World.Info.Gems, DebugPromptParseInt(input, 4, 5) * isYesMultiplier);
{$IFDEF E_ZZT}
			end else if input = 'DARK' then begin
				Board.Info.IsDark := isYes;
				TransitionDrawToBoard;
{$ENDIF}
			end else if input = 'BLINK' then begin
				VideoSetBlink(isYes);
			end else if input = 'DEBUG' then begin
				DebugEnabled := isYes;
{$IFDEF E_ZZT}
				if GameStateElement = E_PLAYER then begin
					SidebarClearLine(3);
					SidebarClearLine(4);
				end;
{$ENDIF}
{$IFDEF EXTCHEAT}
			end else if DebugPromptStarts(input, 'SHOW') then begin
				i := DebugPromptParseElem(input, 4);
				if i >= 0 then begin
					iMin := i;
					iMax := i;
				end else begin
					iMin := 0;
					if isYes then
						iMax := -1 { Block SHOW ALL }
					else
						iMax := MAX_ELEMENT;
				end;
				for i := iMin to iMax do begin
					btmp := Byte(isYes) shl 7;
					if btmp <> CheatColorModifiers[i] then begin
						CheatColorModifiers[i] := btmp;
						btmp := Byte(CheatCharModifiers[i]);
						CheatCharModifiers[i] := ElementDefs[i].Character;
						ElementDefs[i].Character := Char(btmp);
					end;
				end;
				TransitionDrawToBoard;
			end else if input = 'CLIP' then begin
				CheatNoClip := not isYes;
			end else if input = 'STAR' then begin
				CheatNoStar := not isYes;
			end else if input = 'SHOOT' then begin
				CheatNoShoot := not isYes;
			end else if input = 'FREEZE' then begin
				CheatFreeze := isYes;
			end else if input = 'FLAGS' then begin
				DebugPromptFlagWindow;
{$ENDIF}
			end else if isYes then begin
				{ Non-toggleables. }
{$IFDEF EXTCHEAT}
				if input = 'PASSAGE' then begin
					if GameStateElement = E_PLAYER then begin
						i := EditorSelectBoard('Teleport to', World.Info.CurrentBoard, false, false, false, false);
						if (not TextWindowRejected) then begin
							BoardChange(i);
							GamePaused := true;
							TransitionDrawBoardChange;
							BoardEnter;
						end;
					end;
				end else if DebugPromptStarts(input, 'TOUCH') then begin
					i := 5;
					iMin := DebugPromptParseColor(input, i);
					iMax := DebugPromptParseElem(input, i);
					DebugPromptTouchAll(iMax, iMin);
				end else
{$ENDIF}
{$IFDEF E_ZZT}
				if DebugPromptStarts(input, 'SPEED') then begin
					i := DebugPromptParseInt(input, 5, -1);
					if (i >= 1) and (i <= 9) then begin
						TickSpeed := i - 1;
					end else begin
						SidebarPromptSlider(true, 63, 3, 'Game speed:;FS', TickSpeed);
						SidebarClearLine(3);
					end;
					TickTimeDuration := TickSpeed * 2;
					SoundBlockQueueing := false;
					InputKeyPressed := #0;
				end else
{$ENDIF}
				if (input = 'ZAP') then begin
					for i := 0 to 3 do begin
						BoardDamageTile(Board.Stats[0].X + NeighborDeltaX[i], Board.Stats[0].Y + NeighborDeltaY[i]);
						Board.Tiles[Board.Stats[0].X + NeighborDeltaX[i]][Board.Stats[0].Y + NeighborDeltaY[i]].Element := E_EMPTY;
						BoardDrawTile(Board.Stats[0].X + NeighborDeltaX[i], Board.Stats[0].Y + NeighborDeltaY[i]);
					end;
				end else failed := true;
			end else failed := true;
		end;

		if failed then SoundQueue(10, #23#4)
		else SoundQueue(10, #39#4);
{$IFDEF E_ZZT}
		SidebarClearLine(4);
		SidebarClearLine(5);
{$ENDIF}
		GameUpdateSidebar;
	end;

end.
