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
unit Oop;

interface
	uses GameVars;
	function WorldGetFlagPosition(name: TString50): integer;
	function WorldGetFlagCount: integer;
	procedure WorldSetFlag(name: TString50);
	procedure WorldClearFlag(name: TString50);
	function OopSend(statId: integer; sendLabel: string; ignoreLock: boolean): boolean;
	procedure OopExecute(statId: integer; var position: integer; name: TString50);
	procedure WorldGetFlagList;

implementation
uses Sounds, TxtWind, Game, Elements;

procedure OopError(statId: integer; message: string);
	begin
		with Board.Stats[statId] do begin
			DisplayMessage(200, 'ERR: ' + message);
			SoundQueue(5, #80#1);
			DataPos := -1;
		end;
	end;

procedure OopReadChar(statId: integer; var position: integer);
	begin
		with Board.Stats[statId] do begin
{ ## GLOBAL OBJECT }
			if GlobalRead then begin
				if (position >= 0) and (position < GlobalLen) then begin
					{$IFNDEF FPC}
					{ On Turbo Pascal, the array pointer is actually }
					{ a poiter to a string. }
					OopChar := GlobalData^[position];
					{$ELSE}
					OopChar := GlobalData[position];
					{$ENDIF}
					Inc(position);
				end else begin
					OopChar := #0;
				end;
			end else begin
{ ## END GLOBAL OBJECT }
				if (position >= 0) and (position < DataLen) then begin
					{$IFNDEF FPC}
					{ On Turbo Pascal, the array pointer is actually }
					{ a poiter to a string. }
					OopChar := Data^[position];
					{$ELSE}
					OopChar := Data[position];
					{$ENDIF}
					Inc(position);
				end else begin
					OopChar := #0
				end;
{ ## GLOBAL OBJECT }
			end;
{ ## END GLOBAL OBJECT }
		end;
	end;

procedure OopReadWord(statId: integer; var position: integer);
	var
		wordPos: byte;
	begin
		wordPos := 0;
		repeat
			OopReadChar(statId, position);
		until OopChar <> ' ';
		OopChar := UpCase(OopChar);
		if (OopChar < '0') or (OopChar > '9') then begin
			while ((OopChar >= 'A') and (OopChar <= 'Z')) or (OopChar = ':')
				or ((OopChar >= '0') and (OopChar <= '9')) or (OopChar = '_') do
			begin
				if wordPos <= OOP_TOKEN_LENGTH then begin
					Inc(wordPos);
					OopWord[wordPos] := OopChar;
				end;
				OopReadChar(statId, position);
				OopChar := UpCase(OopChar);
			end;
		end;
		OopWord[0] := Chr(wordPos);
		if position > 0 then
			Dec(position);
	end;

procedure OopReadValue(statId: integer; var position: integer);
	var
		s: string[OOP_TOKEN_LENGTH];
		code: integer;
		wordPos: byte;
	begin
		wordPos := 0;
		repeat
			OopReadChar(statId, position)
		until OopChar <> ' ';

		OopChar := UpCase(OopChar);
		while (OopChar >= '0') and (OopChar <= '9') do begin
			if wordPos <= OOP_TOKEN_LENGTH then begin
				Inc(wordPos);
				s[wordPos] := OopChar;
			end;
			OopReadChar(statId, position);
			OopChar := UpCase(OopChar);
		end;

		s[0] := Chr(wordPos);
		if position > 0 then
			position := position - 1;

		if Length(s) <> 0 then
			Val(s, OopValue, code)
		else
			OopValue := -1;
	end;

procedure OopSkipLine(statId: integer; var position: integer);
	begin
		repeat
			OopReadChar(statId, position);
		until (OopChar = #0) or (OopChar = #13);
	end;

function OopParseDirection(statId: integer; var position: integer; var dx, dy: integer): boolean;
	begin
		with Board.Stats[statId] do begin
			OopParseDirection := true;

			if (OopWord = 'N') or (OopWord = 'NORTH') then begin
				dx := 0;
				dy := -1;
			end else if (OopWord = 'S') or (OopWord = 'SOUTH') then begin
				dx := 0;
				dy := 1;
			end else if (OopWord = 'E') or (OopWord = 'EAST') then begin
				dx := 1;
				dy := 0;
			end else if (OopWord = 'W') or (OopWord = 'WEST') then begin
				dx := -1;
				dy := 0;
			end else if (OopWord = 'I') or (OopWord = 'IDLE') then begin
				dx := 0;
				dy := 0;
			end else if (OopWord = 'NW') then begin
				dx := -1;
				dy := -1;
			end else if (OopWord = 'NE') then begin
				dx := 1;
				dy := -1;
			end else if (OopWord = 'SW') then begin
				dx := -1;
				dy := 1;
			end else if (OopWord = 'SE') then begin
				dx := 1;
				dy := 1;
			end else if (OopWord = 'WNW') then begin
				dx := -2;
				dy := -1;
			end else if (OopWord = 'ENE') then begin
				dx := 2;
				dy := -1;
			end else if (OopWord = 'WSW') then begin
				dx := -2;
				dy := 1;
			end else if (OopWord = 'ESE') then begin
				dx := 2;
				dy := 1;
			end else if (OopWord = 'NNW') then begin
				dx := -1;
				dy := -2;
			end else if (OopWord = 'NNE') then begin
				dx := 1;
				dy := -2;
			end else if (OopWord = 'SSW') then begin
				dx := -1;
				dy := 2;
			end else if (OopWord = 'SSE') then begin
				dx := 1;
				dy := 2;
			end else if (OopWord = 'N2') then begin
				dx := 0;
				dy := -2;
			end else if (OopWord = 'E2') then begin
				dx := 2;
				dy := 0;
			end else if (OopWord = 'W2') then begin
				dx := -2;
				dy := 0;
			end else if (OopWord = 'E3') then begin
				dx := 3;
				dy := 0;
			end else if (OopWord = 'W3') then begin
				dx := -3;
				dy := 0;
			end else if (OopWord = 'S2') then begin
				dx := 0;
				dy := 2;
			end else if (OopWord = 'SEEK') then begin
				CalcDirectionSeek(X, Y, dx, dy);
			end else if (OopWord = 'FLOW') then begin
				dx := StepX;
				dy := StepY;
			end else if (OopWord = 'RND') then begin
				CalcDirectionRnd(dx, dy)
			end else if (OopWord = 'RNDNS') then begin
				dx := 0;
				dy := Random(2) * 2 - 1;
			end else if (OopWord = 'RNDNE') then begin
				dx := Random(2);
				if dx = 0 then dy := -1 else dy := 0;
			end else if (OopWord = 'CW') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dy, dx);
				dx := -dx;
			end else if (OopWord = 'CCW') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dy, dx);
				dy := -dy;
			end else if (OopWord = 'RNDP') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dy, dx);
				if Random(2) = 0 then
					dx := -dx
				else
					dy := -dy;
			end else if (OopWord = 'OPP') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dx, dy);
				dx := -dx;
				dy := -dy;
			end else begin
				dx := 0;
				dy := 0;
				OopParseDirection := false;
			end;
		end;
	end;

procedure OopReadDirection(statId: integer; var position: integer; var dx, dy: integer);
	begin
		OopReadWord(statId, position);
		if not OopParseDirection(statId, position, dx, dy) then
			OopError(statId, 'Bad direction');
	end;

function OopFindString(statId: integer; startPos: integer; s: string): integer;
	var
		pos, wordPos, cmpPos: integer;
		maxPos: integer;
	label NoMatch;
	begin
		for pos := 1 to Length(s) do
			s[pos] := UpCase(s[pos]);
		with Board.Stats[statId] do begin
			pos := startPos;
			if GlobalRead then
				maxPos := GlobalLen - Length(s)
			else
				maxPos := DataLen - Length(s);
			while pos <= maxPos do begin
				wordPos := 1;
				cmpPos := pos;
				if GlobalRead then begin
					repeat
						{$IFNDEF FPC}
						{ On Turbo Pascal, the array pointer is actually }
						{ a poiter to a string. }
						OopChar := GlobalData^[cmpPos];
						{$ELSE}
						OopChar := GlobalData[cmpPos];
						{$ENDIF}
						if s[wordPos] <> UpCase(OopChar) then
							goto NoMatch;
						Inc(wordPos);
						Inc(cmpPos);
					until wordPos > Length(s);
				end else begin
					repeat
						{$IFNDEF FPC}
						{ On Turbo Pascal, the array pointer is actually }
						{ a poiter to a string. }
						OopChar := Data^[cmpPos];
						{$ELSE}
						OopChar := Data[cmpPos];
						{$ENDIF}
						if s[wordPos] <> UpCase(OopChar) then
							goto NoMatch;
						Inc(wordPos);
						Inc(cmpPos);
					until wordPos > Length(s);
				end;

				{ string matches }
				OopReadChar(statId, cmpPos);
				OopChar := UpCase(OopChar);
				if ((OopChar >= 'A') and (OopChar <= 'Z')) or (OopChar = '_') then begin
					{ word continues, match invalid }
				end else begin
					{ word complete, match valid }
					OopFindString := pos;
					exit;
				end;

			NoMatch:
				pos := pos + 1;
			end;
			OopFindString := -1;
		end;
	end;

function OopIterateStat(statId: integer; var iStat: integer; lookup: string): boolean;
	var
		pos: integer;
		found: boolean;
	begin
		iStat := iStat + 1;
		found := false;

		if lookup = 'ALL' then begin
			if iStat <= Board.StatCount then
				found := true;
		end else if lookup = 'OTHERS' then begin
			if iStat <= Board.StatCount then begin
				if iStat <> statId then
					found := true
				else begin
					iStat := iStat + 1;
					found := (iStat <= Board.StatCount);
				end;
			end;
		end else if lookup = 'SELF' then begin
			if (statId > 0) and (iStat <= statId) then begin
				iStat := statId;
				found := true;
			end;
		end else begin
			while (iStat <= Board.StatCount) and not found do begin
				if Board.Stats[iStat].Data <> nil then begin
					pos := 0;
					OopReadChar(iStat, pos);
					if OopChar = '@' then begin
						OopReadWord(iStat, pos);
						if OopWord = lookup then
							found := true;
					end;
				end;

				if not found then
					iStat := iStat + 1;
			end;
		end;

		OopIterateStat := found;
	end;

function OopFindLabel(statId: integer; sendLabel: string; var iStat, iDataPos: integer; labelPrefix: string): boolean;
	var
		targetSplitPos: integer;
		unk1: integer;
		targetLookup: string[20];
		objectMessage: string[20];
		foundStat: boolean;
	label FindNextStat;
	begin
		foundStat := false;
		targetSplitPos := Pos(':', sendLabel);
		if targetSplitPos <= 0 then begin
			{ if there is no target, we only check statId }
			if iStat < statId then begin
				objectMessage := sendLabel;
				iStat := statId;
				targetSplitPos := 0;
				foundStat := true;
			end;
		end else begin
			targetLookup := Copy(sendLabel, 1, targetSplitPos - 1);
			objectMessage := Copy(sendLabel, targetSplitPos + 1, Length(sendLabel) - targetSplitPos);
		FindNextStat:
			foundStat := OopIterateStat(statId, iStat, targetLookup);
		end;

		if foundStat then begin
			if objectMessage = 'RESTART' then begin
				iDataPos := 0;
			end else begin
				iDataPos := OopFindString(iStat, 0, labelPrefix + objectMessage);
				{ if lookup target exists, there may be more stats }
				if (iDataPos < 0) and (targetSplitPos > 0) then
					goto FindNextStat;
			end;
			foundStat := iDataPos >= 0;
		end;

		OopFindLabel := foundStat;
	end;

function WorldGetFlagPosition(name: TString50): integer;
	var
		i: integer;
		shortname: string[8];
	begin
		shortname := Copy(name,1,8);
		WorldGetFlagPosition := -1;
		for i := 1 to 24 do begin
			if World.Info.Flags[i] = shortname then
				WorldGetFlagPosition := i;
		end;
	end;

procedure WorldGetFlagList;
	var
		i: integer;
		state: TTextWindowState;
	begin
		TextWindowInitState(state);
		TextWindowAppend(state, 'FLAGS');
		TextWindowAppend(state, '---------------------------------');
		for i := 1 to 24 do
			if World.Info.Flags[i] <> '' then
				TextWindowAppend(state, World.Info.Flags[i]);
		state.Title := 'FLAGS';
		TextWindowDrawOpen(state);
		TextWindowSelect(state, false, false);
		TextWindowDrawClose(state);
		TextWindowFree(state);
	end;

function WorldGetFlagCount: integer;
	var
		i: integer;
		count: integer;
	begin
		count := 0;
		for i := 1 to 24 do
			if World.Info.Flags[i] <> '' then
				Inc(count);
		WorldGetFlagCount := count;
	end;

procedure WorldSetFlag(name: TString50);
	var
		i: integer;
		shortname: string[8];
	begin
		shortname := Copy(name,1,8);
		if WorldGetFlagPosition(shortname) < 0 then begin
			i := 1;
			while (i < 25) and (Length(World.Info.Flags[i]) <> 0) do
				i := i + 1;
			World.Info.Flags[i] := shortname;
		end;
	end;

procedure WorldClearFlag(name: TString50);
	var
		i: integer;
		shortname: string[8];
	begin
		shortname := Copy(name,1,8);
		if WorldGetFlagPosition(shortname) >= 0 then
			World.Info.Flags[WorldGetFlagPosition(shortname)] := '';
	end;

function OopStringToWord(input: TString50): TString50;
	var
		output: TString50;
		i: integer;
		outPos: byte;
	begin
		output := '';
		outPos := 0;
		for i := 1 to Length(input) do begin
			if ((input[i] >= 'A') and (input[i] <= 'Z'))
				or ((input[i] >= '0') and (input[i] <= '9')) then begin
				Inc(outPos);
				output := output + input[i];
			end else if ((input[i] >= 'a') and (input[i] <= 'z')) then begin
				Inc(outPos);
				output := output + Chr(Ord(input[i]) - $20);
			end;
		end;
		output[0] := Chr(outPos);
		OopStringToWord := output;
	end;

function OopParseTile(var statId, position: integer; var tile: TTile): boolean;
	var
		i: integer;
	label ColorFound;
	begin
		OopParseTile := false;
		tile.Color := 0;

		OopReadWord(statId, position);
		for i := 1 to 7 do begin
			if OopWord = OopStringToWord(ColorNames[i]) then begin
				tile.Color := i + $08;
				OopReadWord(statId, position);
				goto ColorFound;
			end;
		end;
		if OopWord = OopStringToWord('Wet') then begin
			case Random(5) of
				0,3: tile.Color := $01;
				1,4: tile.Color := $31;
			else tile.Color := $10 end;
			OopReadWord(statId, position);
			goto ColorFound;
		end else if OopWord = OopStringToWord('Bleeding') then begin
			case Random(8) of
				1,4: tile.Color := $04;
				2,3: tile.Color := $4C;
				5: tile.Color := $0C;
			else tile.Color := $40 end;
			OopReadWord(statId, position);
			goto ColorFound;
		end else if OopWord = OopStringToWord('Watery') then begin
			case Random(20) of
				0,3: tile.Color := $01;
				1,4: tile.Color := $31;
				2: tile.Color := $71;
				5: tile.Color := $10;
			else tile.Color := $11 end;
			OopReadWord(statId, position);
			goto ColorFound;
		end else if OopWord = OopStringToWord('Burning') then begin
			case Random(25) of
				0,3,9: tile.Color := $0E;
				1,4: tile.Color := $4C;
				2: tile.Color := $08;
				5: tile.Color := $68;
				6,7,8: tile.Color := $0C;
			else tile.Color := $4E end;
			OopReadWord(statId, position);
			goto ColorFound;
		end else if OopWord = OopStringToWord('Leafy') then begin
			case Random(8) of
				0,2,4,6: tile.Color := $20;
				1,7,3: tile.Color := $2A;
			else tile.Color := $02 end;
			OopReadWord(statId, position);
			goto ColorFound;
		end else if OopWord = OopStringToWord('Wooden') then begin
			case Random(3) of
				0: tile.Color := $76;
				1: tile.Color := $68;
			else tile.Color := $60 end;
			OopReadWord(statId, position);
			goto ColorFound;
		end else if OopWord = OopStringToWord('Rusty') then begin
			case Random(3) of
				1: tile.Color := $06;
			else tile.Color := $08 end;
			OopReadWord(statId, position);
			goto ColorFound;
		end else if OopWord = OopStringToWord('Bblack') then begin
			tile.Color := $80;
			OopReadWord(statId, position);
			goto ColorFound;
		end else if OopWord = OopStringToWord('Drab') then begin
			tile.Color := $08;
			OopReadWord(statId, position);
			goto ColorFound;
		end else if OopWord = OopStringToWord('Bloody') then begin
			tile.Color := $04;
			OopReadWord(statId, position);
			goto ColorFound;
		end else if OopWord = OopStringToWord('Canvas') then begin
			case Random(4) of
				0: tile.Color := $76;
				1: tile.Color := $77;
			else tile.Color := $7F end;
			OopReadWord(statId, position);
			goto ColorFound;
		end;
	ColorFound:

		for i := 0 to MAX_ELEMENT do begin
			if OopWord = OopStringToWord(ElementDefs[i].Name) then begin
				OopParseTile := true;
				tile.Element := i;
				exit;
			end;
		end;
	end;

function GetColorForTileMatch(var tile: TTile): byte;
	begin
		GetColorForTileMatch := (tile.Color and $0F);
	end;

procedure ChangeWater;
	var
		x, y: integer;
	begin
		x := 0;
		y := 1;
		while y < BOARD_HEIGHT do begin
			x := x + 1;
			if x > BOARD_WIDTH then begin
				x := 1;
				y := y + 1;
			end;
			if Board.Tiles[x][y].Element = E_TEXT_CYAN then begin
				case Random(20) of
					0,3: Board.Tiles[x][y].Color := $85;
					1,4: Board.Tiles[x][y].Color := $86;
					2: Board.Tiles[x][y].Color := $80;
					5: Board.Tiles[x][y].Color := $81;
				else Board.Tiles[x][y].Color := $DB end;
			end;
		end;
	end;

function FindTileOnBoard(var x, y: integer; tile: TTile): boolean;
	begin
		FindTileOnBoard := false;
		while true do begin
			x := x + 1;
			if x > BOARD_WIDTH then begin
				x := 1;
				y := y + 1;
				if y > BOARD_HEIGHT then
					exit;
			end;

			if Board.Tiles[x][y].Element = tile.Element then
				if ((tile.Color = 0) or (GetColorForTileMatch(Board.Tiles[x][y]) = tile.Color)) then begin
					FindTileOnBoard := true;
					exit;
				end;
		end;
	end;

function FindTileUnderPlayer(var tile: TTile): boolean;
	begin
		FindTileUnderPlayer := false;
		if Board.Stats[0].Under.Element = tile.Element then
			if ((tile.Color = 0) or (GetColorForTileMatch(Board.Stats[0].Under) = tile.Color)) then 
				FindTileUnderPlayer := true;
	end;

function FindTileAtLocation(x, y: integer; var tile: TTile): boolean;
	begin
		FindTileAtLocation := false;
		if Board.Tiles[x][y].Element = tile.Element then
			if ((tile.Color = 0) or (GetColorForTileMatch(Board.Tiles[x][y]) = tile.Color)) then 
				FindTileAtLocation := true;
	end;

procedure OopPlaceTile(x, y: integer; var tile: TTile);
	var
		color: byte;
	begin
		if ( Board.Tiles[x][y].Element <> E_PLAYER ) or ( tile.Element = E_MONITOR ) then begin
			color := tile.Color;
			if color = 0 then
				color := Board.Tiles[x][y].Color;

			if Board.Tiles[x][y].Element = tile.Element then
				Board.Tiles[x][y].Color := color
			else begin
				BoardDamageTile(x, y);
				if ( ElementDefs[tile.Element].Cycle >= 0 ) and ( tile.Element <> E_MONITOR ) then begin
					AddStat(x, y, tile.Element, color, ElementDefs[tile.Element].Cycle, StatTemplateDefault);
				end else begin
					Board.Tiles[x][y].Element := tile.Element;
					Board.Tiles[x][y].Color := color;
				end;
			end;

			BoardDrawTile(x, y);
		end;
	end;

function OopCheckCondition(statId: integer; var position: integer): boolean;
	var
		deltaX, deltaY: integer;
		tile: TTile;
		ix, iy: integer;
	begin
		with Board.Stats[statId] do begin
			if OopWord = 'NOT' then begin
				OopReadWord(statId, position);
				OopCheckCondition := not OopCheckCondition(statId, position);
			end else if OopWord = 'ALLIGNED' then begin
				OopCheckCondition := (X = Board.Stats[0].X) or (Y = Board.Stats[0].Y);
			end else if OopWord = 'PLAYERHELD' then begin
				OopCheckCondition := (Board.Stats[0].P2 = 1);
			end else if OopWord = 'TIMEDBOARD' then begin
				OopCheckCondition := (Board.Stats[0].P3 = 0);
			end else if OopWord = 'GUARD' then begin
				OopCheckCondition := (World.Info.Register[5] > 0);
			end else if OopWord = 'BAGFULL' then begin
				OopCheckCondition := (World.Info.Register[7] > 6);
			end else if OopWord = 'III' then begin
				OopCheckCondition := (World.Info.Register[1] > 0);
			end else if OopWord = 'LIT' then begin
				OopCheckCondition := (World.Info.TorchTicks > 10);
			end else if OopWord = 'ISDARK' then begin
				OopCheckCondition := (Board.Info.IsDark = 1);
			end else if OopWord = 'ICE' then begin
				OopCheckCondition := (World.Info.Torches > 0);
			end else if OopWord = 'HOT' then begin
				OopCheckCondition := (World.Info.Ammo > 0);
			end else if OopWord = 'CONTACT' then begin
				OopCheckCondition := (Sqr(X - Board.Stats[0].X) + Sqr(Y - Board.Stats[0].Y)) = 1;
			end else if OopWord = 'HASSAVEGAME' then begin
				OopCheckCondition := SaveTest;
			end else if OopWord = 'WORLD' then begin
				OopReadValue(statId, position);
				ix := OopValue;
				if (ix > 0) and (ix < 10) then
					OopCheckCondition := WorldTest(ix)
				else
					OopCheckCondition := false;
			end else if OopWord = 'WITHIN' then begin
				OopReadValue(statId, position);
					ix := OopValue;
				OopCheckCondition := ((Sqr(Board.Stats[0].X - x) + Sqr(Board.Stats[0].Y - y) * 7 / 4) <= (Sqr(ix)));
			end else if OopWord = 'BLOCKED' then begin
				OopReadDirection(statId, position, deltaX, deltaY);
				OopCheckCondition := not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable;
			end else if OopWord = 'UNDERPLAYER' then begin
				if not OopParseTile(statId, position, tile) then
					OopError(statId, 'Bad object kind');
				OopCheckCondition := FindTileUnderPlayer(tile);
			end else if OopWord = 'ISREGISTER' then begin
				OopReadValue(statId, position);
					ix := OopValue;
				OopReadValue(statId, position);
					iy := OopValue;
				OopCheckCondition := (Board.Info.Register[ix] = iy);
			end else if OopWord = 'ISGLOBAL' then begin
				OopReadValue(statId, position);
					ix := OopValue;
				OopReadValue(statId, position);
					iy := OopValue;
				OopCheckCondition := (World.Info.Register[ix] = iy);
			end else if OopWord = 'DETECT' then begin
				OopReadDirection(statId, position, deltaX, deltaY);
				if not OopParseTile(statId, position, tile) then
					OopError(statId, 'Bad object kind');
				OopCheckCondition := FindTileAtLocation(X + deltaX, Y + deltaY, tile);
			end else if OopWord = 'ANY' then begin
				if not OopParseTile(statId, position, tile) then
					OopError(statId, 'Bad object kind');
				ix := 0;
				iy := 1;
				OopCheckCondition := FindTileOnBoard(ix, iy, tile);
			end else begin
				OopCheckCondition := WorldGetFlagPosition(OopWord) >= 0;
			end;
		end;
	end;

function OopReadLineToEnd(statId: integer; var position: integer) : string;
	var
		s: string;
		sPos: byte;
	begin
		sPos := 0;
		OopReadChar(statId, position);
		while (OopChar <> #0) and (OopChar <> #13) do begin
			if sPos < 255 then begin
				Inc(sPos);
				s[sPos] := OopChar;
			end;
			OopReadChar(statId, position);
		end;
		s[0] := Chr(sPos);
		OopReadLineToEnd := s;
	end;

function OopReadLineToChar(statId: integer; var position: integer; echar: char) : string;
	var
		s: string;
	begin
		s := '';
		OopReadChar(statId, position);
		while (OopChar <> echar) and (OopChar <> #13) do begin
			s := s + OopChar;
			OopReadChar(statId, position);
		end;
		OopReadLineToChar := s;
	end;

function OopSend(statId: integer; sendLabel: string; ignoreLock: boolean): boolean;
	var
		iDataPos, iStat: integer;
		ignoreSelfLock: boolean;
	begin
		if statId < 0 then begin
			{ if statId is negative, label send will always succeed on self }
			{ this is used for in-game events (f.e. TOUCH, SHOT) }
			statId := -statId;
			ignoreSelfLock := true;
		end else begin
			ignoreSelfLock := false;
		end;

		OopSend := false;
		iStat := 0;

		while OopFindLabel(statId, sendLabel, iStat, iDataPos, #13':') do begin
			if ((Board.Stats[iStat].P2 = 0) or (ignoreLock)) or ((statId = iStat) and not ignoreSelfLock) then begin
				if iStat = statId then
					OopSend := true;
				Board.Stats[iStat].DataLast := Board.Stats[iStat].DataPos;
				Board.Stats[iStat].DataPos := iDataPos;
			end;
		end;
	end;

procedure OopExecute(statId: integer; var position: integer; name: TString50);
	var
		textWindow: TTextWindowState;
		textLine: string;
		deltaX, deltaY: integer;
		ix, iy: integer;
		ia, ib: integer;
		stopRunning: boolean;
		replaceStat: boolean;
		endOfProgram: boolean;
		replaceTile: TTile;
		namePosition: integer;
		lastPosition: integer;
		repeatInsNextTick: boolean;
		lineFinished: boolean;
		labelPtr: pointer;
		labelDataPos: integer;
		labelStatId: integer;
		counterPtr: ^integer;
		counterSubtract: boolean;
		bindStatId: integer;
		insCount: integer;
		argTile: TTile;
		argTile2: TTile;
	label StartParsing;
	label ReadInstruction;
	label ReadCommand;
	label StopExecution;
	begin
		with Board.Stats[statId] do begin
		StartParsing:
			TextWindowInitState(textWindow);
			textWindow.Selectable := false;
			stopRunning := false;
			repeatInsNextTick := false;
			replaceStat := false;
			endOfProgram := false;
			insCount := 0;
			repeat
		ReadInstruction:
				lineFinished := true;
				lastPosition := position;
				OopReadChar(statId, position);

				{ skip labels }
				while OopChar = ':' do begin
					repeat
						OopReadChar(statId, position);
					until (OopChar = #0) or (OopChar = #13);
					OopReadChar(statId, position);
				end;

				if (OopChar = #39) or (OopChar = #3) then begin
					OopSkipLine(statId, position);
				end else if OopChar = '@' then begin
					OopSkipLine(statId, position);
				end else if (OopChar = '/') or (OopChar = '?') then begin
					if OopChar = '/' then
						repeatInsNextTick := true;

					OopReadWord(statId, position);
					if OopParseDirection(statId, position, deltaX, deltaY) then begin
						if (deltaX <> 0) or (deltaY <> 0) then begin
							if not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then
								ElementPushablePush(X + deltaX, Y + deltaY, deltaX, deltaY);

							if ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then begin
								MoveStat(statId, X + deltaX, Y + deltaY);
								repeatInsNextTick := false;
							end;
						end else begin
							repeatInsNextTick := false;
						end;

						OopReadChar(statId, position);
						if OopChar <> #13 then begin
							Dec(position);
						end;
						stopRunning := true;
					end else begin
						OopError(statId, 'Bad direction');
					end;
				end else if OopChar = '#' then begin
		ReadCommand:
					OopReadWord(statId, position);
					if OopWord = 'THEN' then
						OopReadWord(statId, position);
					if Length(OopWord) = 0 then
						goto ReadInstruction;
					Inc(insCount);
					if Length(OopWord) <> 0 then begin
						if OopWord = 'GO' then begin
							OopReadDirection(statId, position, deltaX, deltaY);

							if not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then
								ElementPushablePush(X + deltaX, Y + deltaY, deltaX, deltaY);

							if ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then begin
								MoveStat(statId, X + deltaX, Y + deltaY);
							end else begin
								repeatInsNextTick := true;
							end;

							stopRunning := true;
						end else if OopWord = 'SHADOWGO' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then
								MoveStat(statId, X + deltaX, Y + deltaY);
						end else if OopWord = 'TRY' then begin
							OopReadDirection(statId, position, deltaX, deltaY);

							if not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then
								ElementPushablePush(X + deltaX, Y + deltaY, deltaX, deltaY);

							if ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then begin
								MoveStat(statId, X + deltaX, Y + deltaY);
								stopRunning := true;
							end else begin
								goto ReadCommand;
							end;
						end else if OopWord = 'WALK' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							StepX := deltaX;
							StepY := deltaY;
						end else if OopWord = 'ITEMSET' then begin
							OopReadWord(statId, position);
							if World.Info.Register[7] > 6 then begin
								SoundQueue(-1, SoundParse('--gc#c'));
								DisplayMessage(80,'Bag full!');
								goto ReadCommand;
							end else begin
								if WorldGetFlagPosition(OopWord) < 0 then begin
									Inc(World.Info.Register[7]);
									WorldSetFlag(OopWord);
									SoundQueue(-1, SoundParse('geg+gfefg'));
									DisplayMessage(130,Chr(P1) + ' ' +  Chr(P1) + ' Got the ' + OopWord + '! ' + Chr(P1) + ' ' + Chr(P1));
									GameUpdateSidebar;
								end else begin
									SoundQueue(-1, SoundParse('--gc#c'));
									DisplayMessage(80,'You already have a ' + OopWord + '!');
									goto ReadCommand;
								end;
							end;
						end else if OopWord = 'DIM' then begin
							Board.Info.IsDark := 3;
							TransitionDrawToBoard;
						end else if OopWord = 'DANK' then begin
							Board.Info.IsDark := 4;
							TransitionDrawToBoard;
						end else if OopWord = 'DEEP' then begin
							Board.Info.IsDark := 5;
							TransitionDrawToBoard;
						end else if OopWord = 'POISONED' then begin
							Board.Info.IsDark := 6;
							TransitionDrawToBoard;
						end else if OopWord = 'LIGHT' then begin
							Board.Info.IsDark := 0;
							TransitionDrawToBoard;
						end else if OopWord = 'BRIGHT' then begin
							Board.Info.IsDark := 2;
							TransitionDrawToBoard;
						end else if OopWord = 'DARK' then begin
							Board.Info.IsDark := 1;
							TransitionDrawToBoard;
						end else if OopWord = 'FADEOUT' then begin
							GameFadeOut(Board.Info.IsDark);
						end else if OopWord = 'FADEWHITE' then begin
							GameFadeWhite(Board.Info.IsDark);
						end else if OopWord = 'FADEIN' then begin
							GameFadeIn(Board.Info.IsDark);							
						end else if OopWord = 'FADEDOWN' then begin
							GameFadeDown(Board.Info.IsDark);							
						end else if OopWord = 'SET' then begin
							OopReadWord(statId, position);
							if OopWord = 'III' then begin
								World.Info.Register[1] := 1;
								GameUpdateSidebar;
							end else WorldSetFlag(OopWord);
						end else if OopWord = 'CLEAR' then begin
							OopReadWord(statId, position);
							if OopWord = 'III' then begin
								World.Info.Register[1] := 0;
								GameUpdateSidebar;
							end else WorldClearFlag(OopWord);
						end else if OopWord = 'ITEMCLEAR' then begin
							if World.Info.Register[7] > 0 then
								Dec(World.Info.Register[7]);
							OopReadWord(statId, position);
							WorldClearFlag(OopWord);
							GameUpdateSidebar;
						end else if OopWord = 'SHOVE' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							OopReadDirection(statId, position, ix, iy);
							ia := GetStatIdAt(X + deltaX, Y + deltaY);
							if (GetStatIdAt(X + ix + deltaX, Y + iy + deltaY) < 0) and (ia > 0) then
								MoveStat(ia, X + ix + deltaX, Y + iy + deltaY);
						end else if OopWord = 'WARP' then begin
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							if (Board.Stats[0].X <> ix) or (Board.Stats[0].Y <> iy) then
								MoveStat(0, ix, iy);
							stopRunning := true;
						end else if OopWord = 'SHADOWSTEP' then begin
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							if ((ix <> X) or (iy <> y)) and ((Board.Stats[0].X <> ix) or (Board.Stats[0].Y <> iy)) then
								MoveStat(statId, ix, iy);
						end else if OopWord = 'JUMP' then begin
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							if ((ix <> X) or (iy <> y)) and ((Board.Stats[0].X <> ix) or (Board.Stats[0].Y <> iy)) then
								MoveStat(statId, ix, iy);
							stopRunning := true;
						end else if OopWord = 'SWAPWORLD' then begin
							ix := 0;
							iy := 0;
							OopReadValue(statId, position);
							ia := OopValue;
							OopReadValue(statId, position);
							ib := OopValue;
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							if ia < 10 then
								GameFadeOut(Board.Info.IsDark);
							WorldSwap((ia mod 10),ib);
							TransitionDrawToBoard;
							BoardEnter;
							if (( ix > 0 ) and ( iy > 0 )) and ((Board.Stats[0].X <> ix) or (Board.Stats[0].Y <> iy)) then
								MoveStat(0, ix, iy);
							if ia < 10 then
								GameFadeIn(Board.Info.IsDark);
							stopRunning := true;
						end else if OopWord = 'BOARD' then begin
							OopReadValue(statId, position);
							ia := OopValue;
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							BoardChange(ia);
							TransitionDrawToBoard;
							BoardEnter;
							if (( ix > 0 ) and ( iy > 0 )) and ((Board.Stats[0].X <> ix) or (Board.Stats[0].Y <> iy)) then
								MoveStat(0, ix, iy);
							stopRunning := true;
						end else if OopWord = 'PAUSE' then begin
							GamePaused := true;
							stopRunning := true;
						end else if OopWord = 'DUPLICATE' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if Board.Tiles[X + deltaX][Y + deltaY].Element <> E_EMPTY then
								ElementPushablePush(X + deltaX, Y + deltaY, deltaX, deltaY);
							if Board.Tiles[X + deltaX][Y + deltaY].Element = E_EMPTY then begin
								if Board.StatCount < (MAX_STAT - 2) then begin
									AddStat(X + deltaX, Y + deltaY,
										Board.Tiles[X][Y].Element,
										Board.Tiles[X][Y].Color,
										Board.Stats[statId].Cycle, Board.Stats[statId]);
									BoardDrawTile(X + deltaX, Y + deltaY);
								end;
							end;
						end else if OopWord = 'WEAVE' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							ElementWeave(X + deltaX, Y + deltaY, deltaX, deltaY);
						end else if OopWord = 'SETEXPR' then begin
							OopReadValue(statId, position);
							ix := OopValue;
							if (World.Info.PlayerAppearance > 0) and (World.Info.PlayerAppearance < 3) then
								iy := World.Info.PlayerAppearance
							else
								iy := 1;
							if (( ix > -1 ) and ( ix < 7 )) then
								SetExpr(iy, ix)
							else
								SetExpr(iy, 0);
						end else if OopWord = 'PLAYERCOLOR' then begin
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							if (( ix > -1 ) and ( ix < 16 )) then
								if (( iy > -1 ) and ( iy < 16 )) then
									World.Info.PlayerColor := ((ix * 16) + iy) + $00;
						end else if OopWord = 'PRONOUN' then begin
							OopReadValue(statId, position);
							if (( OopValue > 0 ) and ( OopValue < 4 )) then
								World.Info.PlayerPronoun := OopValue;
						end else if OopWord = 'APPEARANCE' then begin
							OopReadValue(statId, position);
							if (( OopValue > 0 ) and ( OopValue < 3 )) then
								World.Info.PlayerAppearance := OopValue;
						end else if (OopWord = 'NAMECHAR') or (OopWord = 'CHARNAME') then begin
							OopReadValue(statId, position);
							if (( OopValue > 0 ) and ( OopValue < 8 )) then
								if OopWord = 'NAMECHAR' then
									World.Info.PlayerName[OopValue] := P1
								else
									P1 := World.Info.PlayerName[OopValue];
						end else if (OopWord = 'PUSH') or (OopWord = 'FETCH') then begin
							OopReadValue(statId, position);
							if ( OopValue > 0 ) and ( OopValue < 9 ) then
								if OopWord = 'FETCH' then
									Board.Info.Register[OopValue] := World.Info.Register[OopValue]
								else
									World.Info.Register[OopValue] := Board.Info.Register[OopValue];
						end else if OopWord = 'IF' then begin
							OopReadWord(statId, position);
							if OopCheckCondition(statId, position) then
								goto ReadCommand;
						end else if (OopWord = 'GIVE') or (OopWord = 'TAKE') then begin
							if OopWord = 'TAKE' then
								counterSubtract := true
							else
								counterSubtract := false;

							OopReadWord(statId, position);
							if OopWord = 'HEALTH' then
								counterPtr := @World.Info.Health
							else if OopWord = 'AMMO' then
								counterPtr := @World.Info.Ammo
							else if OopWord = 'GEMS' then
								counterPtr := @World.Info.Gems
							else if OopWord = 'TORCHES' then
								counterPtr := @World.Info.Torches
							else if OopWord = 'SCORE' then
								counterPtr := @World.Info.Score
							else if OopWord = 'TORCHTICKS' then
								counterPtr := @World.Info.TorchTicks
							else if (OopWord = 'CUSTOM') or (OopWord = 'Z') then
								counterPtr := @World.Info.CustomZ
							else if OopWord = 'LOCAL' then
								counterPtr := @Board.Info.Local
							else if OopWord = 'MYLOCAL' then begin
								OopReadValue(statId, position);
								if ( OopValue > 0 ) and ( OopValue < 4 ) then begin
									counterPtr := @MyLocal[OopValue];
								end;
							end else if ( OopWord = 'REGISTER' ) or ( OopWord = 'GLOBAL' ) then begin
								OopReadValue(statId, position);
								if ( OopValue > 0 ) and ( OopValue < 11 ) then begin
									if OopWord = 'REGISTER' then begin
										counterPtr := @Board.Info.Register[OopValue];
									end else begin
										counterPtr := @World.Info.Register[OopValue];
									end;
								end else begin
									counterPtr := nil;
								end;
							end else begin
								counterPtr := nil;
							end;
							if counterPtr <> nil then begin
								OopReadValue(statId, position);
								if OopValue > 0 then begin
									if counterSubtract then
										OopValue := -OopValue;

									if (counterPtr^ + OopValue) >= 0 then begin
										counterPtr^ := counterPtr^ + OopValue;
									end else begin
										goto ReadCommand;
									end;
								end;
							end;
							GameUpdateSidebar;
						end else if OopWord = 'END' then begin
							position := -1;
							OopChar := #0;
						end else if OopWord = 'ENDGAME' then begin
							World.Info.Health := 0;
						end else if OopWord = 'IDLE' then begin
							stopRunning := true;
						end else if OopWord = 'RESTART' then begin
							position := 0;
							lineFinished := false;
						end else if OopWord = 'BACK' then begin
							position := DataLast;
							lineFinished := false;
						end else if OopWord = 'DROP' then begin
							OopReadWord(statId, position);

							labelStatId := 0;
							while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13'!') do begin
								labelPtr := Board.Stats[labelStatId].Data;
								AdvancePointer(labelPtr, labelDataPos + 1);

								Char(labelPtr^) := #3;
							end;
						end else if OopWord = 'UNDROP' then begin
							OopReadWord(statId, position);

							labelStatId := 0;
							while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13#3) do begin
								labelPtr := Board.Stats[labelStatId].Data;
								AdvancePointer(labelPtr, labelDataPos + 1);

								Char(labelPtr^) := '!';
							end;
						end else if OopWord = 'ZAP' then begin
							OopReadWord(statId, position);
							labelStatId := 0;
							while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13':') do begin
								labelPtr := Board.Stats[labelStatId].Data;
								AdvancePointer(labelPtr, labelDataPos + 1);
								while ( Char(labelPtr^) <> #13 ) do begin
									AdvancePointer(labelPtr, 1);
								end;
								while Char(labelPtr^) <> ':' do begin
									AdvancePointer(labelPtr, -1);
								end;
								Char(labelPtr^) := #39;
							end;
						end else if OopWord = 'RESTORE' then begin
							OopReadWord(statId, position);

							labelStatId := 0;
							while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13#39) do
								repeat
									labelPtr := Board.Stats[labelStatId].Data;
									
									AdvancePointer(labelPtr, labelDataPos + 1);

									Char(labelPtr^) := ':';

									labelDataPos := OopFindString(labelStatId, labelDataPos + 1, #13#39 + OopWord + #13);
								until labelDataPos <= 0;
						end else if OopWord = 'HOLDPLAYER' then begin
							Board.Stats[0].P2 := 1;
						end else if OopWord = 'RELEASEPLAYER' then begin
							Board.Stats[0].P2 := 0;
						end else if OopWord = 'GRAV' then begin
							OopReadValue(statId, position);
							Board.Stats[0].P1 := OopValue;
						end else if OopWord = 'LOCK' then begin
							P2 := 1;
						end else if OopWord = 'UNLOCK' then begin
							P2 := 0;
						end else if OopWord = 'RANGE' then begin
							OopReadValue(statId, position);
							if OopValue > 0 then
								if (Sqr(X - Board.Stats[0].X) + Sqr((Y - Board.Stats[0].Y) * 7 / 4)) > Sqr(OopValue) then
									goto ReadCommand;
						end else if OopWord = 'IRANGE' then begin
							OopReadValue(statId, position);
							if OopValue > 0 then begin
								if (Sqr(X - Board.Stats[0].X) + Sqr((Y - Board.Stats[0].Y) * 7 / 4)) <= Sqr(OopValue) then begin
									if OopSend(0,'INV:A', false) then begin end;
									SoundQueue(2, SoundParse('667'));
								end else begin
									goto ReadCommand;
								end;
							end;
						end else if OopWord = 'KEYSET' then begin
							OopReadValue(statId, position);
							if ( OopValue > 0 ) and ( OopValue < 7 ) then begin
								OopReadWord(statId, position);
								World.Info.Keys[OopValue] := Ord(OopWord[1]);
							end;
						end else if OopWord = 'KEYGO' then begin
							OopReadValue(statId, position);
							if ( OopValue > 0 ) and ( OopValue < 7 ) then begin
								Str(OopValue, OopWord);
								if OopSend(statId, 'SELF:KEY' + OopWord + Chr(World.Info.Keys[OopValue]), false) then
									lineFinished := false;
							end;
						end else if OopWord = 'SEND' then begin
							OopReadWord(statId, position);
							if OopSend(statId, OopWord, false) then
								lineFinished := false;
						end else if OopWord = 'BECOME' then begin
							if OopParseTile(statId, position, argTile) then begin
								replaceStat := true;
								replaceTile.Element := argTile.Element;
								if argTile.Color = 0 then
									replaceTile.Color := Board.Tiles[X][Y].Color
								else
									replaceTile.Color := argTile.Color;
							end else begin
								OopError(statId, 'Bad #BECOME');
							end;
						end else if OopWord = 'COLORDIR' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							if (( ix > -1 ) and ( ix < 16 )) then begin
								if (( iy > -1 ) and ( iy < 16 )) then begin
									Board.Tiles[X + deltaX][Y + deltaY].Color := ((ix * 16) + iy) + $00;
									BoardDrawTile(X + deltaX, Y + deltaY);
								end;
							end;
						end else if OopWord = 'PUT' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if (deltaX = 0) and (deltaY = 0) then
								OopError(statId, 'Bad #PUT')
							else if not OopParseTile(statId, position, argTile) then
								OopError(statId, 'Bad #PUT')
							else if ((X + deltaX) > 0)
								and ((X + deltaX) <= BOARD_WIDTH)
								and ((Y + deltaY) > 0)
								and ((Y + deltaY) < BOARD_HEIGHT) then
							begin
								if not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then
									ElementPushablePush(X + deltaX, Y + deltaY, deltaX, deltaY);

								OopPlaceTile(X + deltaX, Y + deltaY, argTile);
							end;
						end else if OopWord = 'CRED' then begin
							textLine := OopReadLineToEnd(statId, position);
							for ix := 1 to Length(textLine) do
								Board.Tiles[((60 - Length(textLine)) div 2) + ix][24].Color := Ord(textLine[ix]);
							stopRunning := true;
						end else if OopWord = 'LASERBEAM' then begin
							OopLaserBeam(X + 1, Y, 1, 0);
						end else if OopWord = 'CHANGEWATER' then begin
							ChangeWater;
						end else if OopWord = 'DRAW' then begin
							if not OopParseTile(statId, position, argTile) then
								OopError(statId, 'Bad #DRAW');

							ix := 0;
							iy := 1;

							while FindTileOnBoard(ix, iy, argTile) do
								BoardDrawTile(ix, iy)
						end else if OopWord = 'CHANGE' then begin
							if not OopParseTile(statId, position, argTile) then
								OopError(statId, 'Bad #CHANGE');
							if not OopParseTile(statId, position, argTile2) then
								OopError(statId, 'Bad #CHANGE');

							ix := 0;
							iy := 1;

							while FindTileOnBoard(ix, iy, argTile) do
								OopPlaceTile(ix, iy, argTile2);
						end else if OopWord = 'PLAY' then begin
							textLine := SoundParse(OopReadLineToEnd(statId, position));
							if Length(textLine) <> 0 then
								SoundQueue(-1, textLine);
							lineFinished := false;
						end else if OopWord = 'BGPLAY' then begin
							textLine := SoundParse(OopReadLineToEnd(statId, position));
							if Length(textLine) <> 0 then
								SoundQueue(4, textLine);
							lineFinished := false;
						end else if OopWord = 'FLASHINV' then begin
							FlashInv := 12;
						end else if OopWord = 'HINT' then begin
							P3 := 1;
						end else if OopWord = 'UNHINT' then begin
							P3 := 0;
						end else if OopWord = 'CYCLE' then begin
							OopReadValue(statId, position);
							if OopValue > 0 then
								Cycle := OopValue;
						end else if OopWord = 'CHAR' then begin
							OopReadValue(statId, position);
							if (OopValue > 0) and (OopValue <= 255) then begin
								P1 := OopValue;
								BoardDrawTile(X, Y);
							end;
						end else if OopWord = 'DIE' then begin
							replaceStat := true;
							replaceTile.Element := Under.Element;
							replaceTile.Color := Under.Color;
						end else if OopWord = 'BIND' then begin
							OopReadWord(statId, position);
							bindStatId := 0;
							if OopIterateStat(statId, bindStatId, OopWord) then begin
								FreeMem(Data, DataLen);
								Data := Board.Stats[bindStatId].Data;
								DataLen := Board.Stats[bindStatId].DataLen;
								position := 0;
							end;
						end else begin
							textLine := OopWord;
							if OopSend(statId, OopWord, false) then begin
								lineFinished := false;
							end else begin
								if Pos(':', textLine) <= 0 then begin
									OopError(statId, 'Bad command ' + textLine);
								end;
							end;
						end;
					end;

					if lineFinished then
						OopSkipLine(statId, position);
                end else if OopChar = #6 then begin
					textLine := OopReadLineToChar(statId, position, '@');
					for ix := 1 to 7 do
						if (Chr(World.Info.PlayerName[ix]) <> #7) and (Chr(World.Info.PlayerName[ix]) <> #0) then
							textLine := textLine + Chr(World.Info.PlayerName[ix]);
					textLine := textLine + OopReadLineToEnd(statId, position);
					TextWindowAppend(textWindow, textLine);
                end else if OopChar = #254 then begin
					textLine := OopReadLineToChar(statId, position, '@');
					if World.Info.PlayerPronoun = 1 then
						textLine := textLine + 'he';
					if World.Info.PlayerPronoun = 2 then
						textLine := textLine + 'she';
					if World.Info.PlayerPronoun = 3 then
						textLine := textLine + 'they';
					textLine := textLine + OopReadLineToChar(statId, position, '@');
					if World.Info.PlayerPronoun <> 3 then
						textLine := textLine + 'is'
					else
						textLine := textLine + 'are';
					textLine := textLine + OopReadLineToEnd(statId, position);
					TextWindowAppend(textWindow, textLine);
                end else if OopChar = #253 then begin
					textLine := OopReadLineToChar(statId, position, '@');
					if World.Info.PlayerPronoun = 1 then
						textLine := textLine + 'him';
					if World.Info.PlayerPronoun = 2 then
						textLine := textLine + 'her';
					if World.Info.PlayerPronoun = 3 then
						textLine := textLine + 'them';
					textLine := textLine + OopReadLineToEnd(statId, position);
					TextWindowAppend(textWindow, textLine);
				end else if OopChar = #13 then begin
					if textWindow.LineCount > 0 then
						TextWindowAppend(textWindow, '');
				end else if OopChar = #0 then begin
					endOfProgram := true;
				end else begin
					textLine := OopChar + OopReadLineToEnd(statId, position);
					TextWindowAppend(textWindow, textLine);
				end;
			until endOfProgram or stopRunning or repeatInsNextTick or replaceStat or (insCount > 32);


			if (OopWord = 'BOARD') or (OopWord = 'SWAPWORLD') then
				goto StopExecution;
				
			if repeatInsNextTick then
				position := lastPosition;

			if OopChar = #0 then
				position := -1;

			if textWindow.LineCount > 1 then begin
				namePosition := 0;
				OopReadChar(statId, namePosition);
				if OopChar = '@' then begin
					name := OopReadLineToEnd(statId, namePosition);
				end;

				if Length(name) = 0 then
					name := 'Interaction';

				textWindow.Title := name;
				TextWindowDrawOpen(textWindow);
				TextWindowSelect(textWindow, true, false);
				TextWindowDrawClose(textWindow);
				TextWindowFree(textWindow);

				if Length(textWindow.Hyperlink) <> 0 then
					if OopSend(statId, textWindow.Hyperlink, false) then
						goto StartParsing;
			end else if textWindow.LineCount = 1 then begin
				DisplayMessage(200, textWindow.Lines[1]^);
				TextWindowFree(textWindow);
			end;

			if replaceStat then begin
				ix := X;
				iy := Y;
				DamageStat(statId);
				OopPlaceTile(ix, iy, replaceTile);
			end;
		end;

		StopExecution:
	end;

end.
