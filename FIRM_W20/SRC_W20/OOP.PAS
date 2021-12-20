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
	procedure WorldSetFlag(name: TString50);
	procedure WorldClearFlag(name: TString50);
	function OopSend(statId: integer; sendLabel: string; ignoreLock: boolean): boolean;
	function OopExecute(statId: integer; var position: integer; name: TString50): boolean;

implementation
uses Sounds, TxtWind, Game, Elements;
type
	cInt = ^integer;
	cShort = ^shortint;

procedure OopError(statId: integer; message: string);
	begin
		if ConfigList[57] <> '' then
			with Board.Stats[statId] do begin
				DisplayMessage(200, ConfigList[57] + message);
				SoundQueue(5, SoundParse(ConfigList[58]));
				DataPos := -1;
			end;
	end;

procedure OopReadChar(statId: integer; var position: integer);
	begin
		with Board.Stats[statId] do begin
			if (position >= 0) and (position < DataLen) then begin
				Move(Ptr(Seg(Data^), Ofs(Data^) + position)^, OopChar, 1);
				Inc(position);
			end else begin
				OopChar := #0
			end;
		end;
	end;

procedure OopReadWord(statId: integer; var position: integer);
	begin
		OopWord := '';
		repeat
			OopReadChar(statId, position);
		until OopChar <> ' ';
		OopChar := UpCase(OopChar);
		if (OopChar < '0') or (OopChar > '9') then begin
			while ((OopChar >= 'A') and (OopChar <= 'Z')) or (OopChar = ':')
				or ((OopChar >= '0') and (OopChar <= '9')) or (OopChar = '_') do
			begin
				OopWord := OopWord + OopChar;
				OopReadChar(statId, position);
				OopChar := UpCase(OopChar);
			end;
		end;
		if position > 0 then
			Dec(position);
	end;

function OopNextWord(statId: integer; var position: integer): string;
	var
		s: string;
		iPos: integer;
	begin
		iPos := position;
		s := OopWord;
		OopReadWord(statId, position);
		OopNextWord := OopWord;
		OopWord := s;
		position := iPos;
	end;

function OopStringToWord(input: TString50): TString50;
	var
		output: TString50;
		i: integer;
	begin
		output := '';
		for i := 1 to Length(input) do begin
			if ((input[i] >= 'A') and (input[i] <= 'Z'))
				or ((input[i] >= '0') and (input[i] <= '9')) then
				output := output + input[i]
			else if ((input[i] >= 'a') and (input[i] <= 'z')) then
				output := output + Chr(Ord(input[i]) - $20);
		end;
		OopStringToWord := output;
	end;

function ShortWord(s: string): boolean;
	begin
		ShortWord := false;
		if s = OopStringToWord(OOPList[20]) then
			ShortWord := true
		else if s = OopStringToWord(OOPList[21]) then
			ShortWord := true
		else if s = OopStringToWord(OOPList[22]) then
			ShortWord := true
		else if s = OopStringToWord(OOPList[23]) then
			ShortWord := true
		else if s = OopStringToWord(OOPList[24]) then
			ShortWord := true
		else if s = OopStringToWord(OOPList[25]) then
			ShortWord := true
		else if s = OopStringToWord(OOPList[26]) then
			ShortWord := true
		else if s = OopStringToWord(OOPList[19]) then
			ShortWord := true;
	end;

procedure OopGetShort(s: string; var cPtr: cShort);
	begin
		if s = OopStringToWord(OOPList[20]) then
			cPtr := @World.Info.Keys[1]
		else if s = OopStringToWord(OOPList[21]) then
			cPtr := @World.Info.Keys[2]
		else if s = OopStringToWord(OOPList[22]) then
			cPtr := @World.Info.Keys[3]
		else if s = OopStringToWord(OOPList[23]) then
			cPtr := @World.Info.Keys[4]
		else if s = OopStringToWord(OOPList[24]) then
			cPtr := @World.Info.Keys[5]
		else if s = OopStringToWord(OOPList[25]) then
			cPtr := @World.Info.Keys[6]
		else if s = OopStringToWord(OOPList[26]) then
			cPtr := @World.Info.Keys[7]
		else if s = OopStringToWord(OOPList[19]) then
			cPtr := @Board.Info.IsDark;
	end;

function OopGetCounter(statId: integer; s: string; var cPtr: cInt): boolean;
	var
		i: integer;
	begin
		OopGetCounter := true;
		if s = 'HEALTH' then
			cPtr := @World.Info.Health
		else if s = 'AMMO' then
			cPtr := @World.Info.Ammo
		else if s = 'GEMS' then
			cPtr := @World.Info.Gems
		else if s = 'TORCHES' then
			cPtr := @World.Info.Torches
		else if s = 'SCORE' then
			cPtr := @World.Info.Score
		else if s = 'TIME' then
			cPtr := @World.Info.BoardTimeSec
		else if s = OopStringToWord(OOPList[17]) then
			cPtr := @World.Info.EnergizerTicks
		else if s = OopStringToWord(OOPList[18]) then
			cPtr := @World.Info.TorchTicks
		else begin
			OopGetCounter := false;
			if s = CustomFlagList[1] then begin
				cPtr := @Board.Info.Local;
				OopGetCounter := true;
			end;
			for i := 1 to 4 do
				if s = CustomFlagList[i + 1] then begin
					cPtr := @Board.Stats[statId].ObjLocal[i];
					OopGetCounter := true;
				end;
			for i := 1 to CUSTOM_FLAG_COUNT do
				if s = CustomFlagList[i + 5] then begin
					cPtr := @World.Info.CustomFlags[i];
					OopGetCounter := true;
				end;
		end;
	end;

procedure OopReadValue(statId: integer; var position: integer);
	var
		s: string[20];
		ix, iy, code: integer;
		isNumeric: boolean;
		counterPtr: cInt;
		shortPtr: cShort;
	begin
		s := '';
		repeat
			OopReadChar(statId, position)
		until OopChar <> ' ';

		OopChar := UpCase(OopChar);
		isNumeric := true;
		while ((((OopChar >= 'A') and (OopChar <= 'Z'))
			or ((OopChar >= '0') and (OopChar <= '9')))
			or (OopChar = '-')) do begin

			if (((OopChar < '0') or (OopChar > '9'))
				and (OopChar <> '-')) then
				isNumeric := false;
			s := s + OopChar;
			OopReadChar(statId, position);
			OopChar := UpCase(OopChar);
		end;

		if position > 0 then
			position := position - 1;

		OopValue := -128;
		if Length(s) <> 0 then begin
			if isNumeric then
				Val(s, OopValue, code)
			else if s = OopStringToWord(OOPList[27]) then begin
				OopReadValue(statId, position);
				if OopValue <> -128 then begin
					ix := OopValue;
					OopReadValue(statId, position);
					if OopValue <> -128 then begin
						iy := OopValue;
						if ix > iy then
							OopValue := Random((ix - iy) + 1) + iy
						else if iy > ix then
							OopValue := Random((iy - ix) + 1) + ix
						else
							OopValue := ix;
					end;
				end;
			end else if ShortWord(s) then begin
				OopGetShort(s, shortPtr);
				OopValue := shortPtr^;
			end else if OopGetCounter(statId, s, counterPtr) then
				OopValue := counterPtr^
			else OopValue := ColorNumber(s);
		end;
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
			if OopWord = OopStringToWord(OOPList[16]) then begin
				dx := Board.Stats[0].X - X;
				dy := Board.Stats[0].Y - Y;
			end else if (((OopWord = OopStringToWord(OOPList[13]))
				or (OopWord = OopStringToWord(OOPList[14])))
				or (OopWord = OopStringToWord(OOPList[15]))) then begin
				OopReadValue(statId, position);
				dx := OopValue;
				OopReadValue(statId, position);
				dy := OopValue;
				if ((dx <> -128) and (dy <> -128)) then begin
					if (OopWord = OopStringToWord(OOPList[14])) then begin
						dx := dx - X;
						dy := dy - Y;
					end;
					if (OopWord = OopStringToWord(OOPList[15])) then
						CalcDirectionToward(X, Y, dx, dy);
				end else begin
					dx := 0;
					dy := 0;
					OopParseDirection := false;
				end;
			end else if (OopWord = 'N') or (OopWord = 'NORTH') then begin
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
			OopError(statId, 'Bad direction ' + OopWord);
	end;

function OopFindString(statId: integer; s: string): integer;
	var
		pos, wordPos, cmpPos: integer;
	label NoMatch;
	begin
		with Board.Stats[statId] do begin
			pos := 0;
			while pos <= DataLen do begin
				wordPos := 1;
				cmpPos := pos;
				repeat
					OopReadChar(statId, cmpPos);
					if UpCase(s[wordPos]) <> UpCase(OopChar) then
						goto NoMatch;
					wordPos := wordPos + 1;
				until wordPos > Length(s);

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
				iDataPos := OopFindString(iStat, labelPrefix + objectMessage);
				{ if lookup target exists, there may be more stats }
				if (iDataPos < 0) and (targetSplitPos > 0) then
					goto FindNextStat;
			end;
			foundStat := iDataPos >= 0;
		end;

		OopFindLabel := foundStat;
	end;

function WorldGetBoardPosition(s: TString20): integer;
	var
		bpos, ix, iy: integer;
	begin
		bpos := -1;
		ix := 0;
		while ((ix <= World.BoardCount) and (bpos = -1)) do begin
			if BoardNames[ix][1] = ':' then begin
				bpos := ix;
				for iy := 1 to Length(s) do
					if UpCase(BoardNames[ix][iy + 1]) <> UpCase(s[iy]) then
						bpos := -1;
					if (((BoardNames[ix][Length(s) + 2] >= 'A') and
						(BoardNames[ix][Length(s) + 2] <= 'Z')) or
						((BoardNames[ix][Length(s) + 2] >= '0') and
						(BoardNames[ix][Length(s) + 2] <= '9'))) then
						bpos := -1;
			end;
			Inc(ix);
		end;
		WorldGetBoardPosition := bpos;
	end;

function WorldGetFlagPosition(name: TString50): integer;
	var
		i: integer;
	begin
		WorldGetFlagPosition := -1;
		for i := 1 to MAX_FLAG do begin
			if World.Info.Flags[i] = name then
				WorldGetFlagPosition := i;
		end;
	end;

procedure WorldSetFlag(name: TString50);
	var
		i: integer;
	begin
		if WorldGetFlagPosition(name) < 0 then begin
			i := 1;
			while (i < MAX_FLAG) and (Length(World.Info.Flags[i]) <> 0) do
				i := i + 1;
			World.Info.Flags[i] := name;
		end;
	end;

procedure WorldClearFlag(name: TString50);
	var
		i: integer;
	begin
		if WorldGetFlagPosition(name) >= 0 then
			World.Info.Flags[WorldGetFlagPosition(name)] := '';
	end;

function OopParseTile(var statId, position: integer; var tile: TTile): boolean;
	var		
		i: integer;
	label FindElement;
	begin
		OopParseTile := false;
		tile.Color := 0;

		OopReadWord(statId, position);
		i := ColorNumber(OopWord);
		if i = -128 then goto FindElement;
		tile.Color := AsColor(i,0);
		OopReadWord(statId, position);
		if ColorNumber(OopWord) = -128 then goto FindElement;
		tile.Color := AsColor(i,ColorNumber(OopWord));
		OopReadWord(statId, position);

	FindElement:
		for i := 0 to MAX_ELEMENT do begin
			if OopWord = OopStringToWord(ElementDefs[i].Name) then begin
				OopParseTile := true;
				tile.Element := i;
				exit;
			end;
		end;
	end;

function MatchTiles(sourceTile, searchTile: TTile): boolean;
	begin
		MatchTiles := false;
		if (sourceTile.Element = searchTile.Element) or (searchTile.Element = 2) then
			if searchTile.Color <> 0 then begin
				if searchTile.Color and $F0 > 0 then
					MatchTiles := (searchTile.Color = sourceTile.Color)
				else
					MatchTiles := (searchTile.Color = (sourceTile.Color and $0F));
			end else
				MatchTiles := true;
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

			if MatchTiles(Board.Tiles[x][y],tile) then begin
				FindTileOnBoard := true;
				exit;
			end;
		end;
	end;

function OopCheckCondition(statId: integer; var position: integer): boolean;
	var
		deltaX, deltaY: integer;
		tile: TTile;
		code, ix, iy: integer;
		isCounter: boolean;
		counterPtr: cInt;
		shortPtr: cShort;
	begin
		with Board.Stats[statId] do begin
			if OopWord = 'NOT' then begin
				OopReadWord(statId, position);
				OopCheckCondition := not OopCheckCondition(statId, position);
			end else if OopWord = 'ALLIGNED' then begin
				OopCheckCondition := (X = Board.Stats[0].X) or (Y = Board.Stats[0].Y);
			end else if OopWord = 'CONTACT' then begin
				OopCheckCondition := (Sqr(X - Board.Stats[0].X) + Sqr(Y - Board.Stats[0].Y)) = 1;
			end else if OopWord = 'BLOCKED' then begin
				OopReadDirection(statId, position, deltaX, deltaY);
				OopCheckCondition := not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable;
			end else if OopWord = OopStringToWord(OOPList[35]) then begin
				OopReadDirection(statId, position, deltaX, deltaY);
				OopReadValue(statId, position);
				ix := OopValue;
				code := position;
				OopReadValue(statId, position);
				if OopValue = -128 then begin
					position := code;
					OopValue := 0;
				end;
				iy := OopValue;
				if ( ix > -1 ) and ( ix < 16 ) then begin
					if ( iy < 1 ) or ( iy > 15 ) then
						iy := 0;
					tile.Element := 2;
					tile.Color := AsColor( ix, iy );
					if deltaX + deltaY = 0 then
						OopCheckCondition := MatchTiles(Under, tile)
					else
						OopCheckCondition := MatchTiles(Board.Tiles[X + DeltaX][Y + DeltaY], tile);
				end else OopError(statId,'Unknown color');
			end else if OopWord = OopStringToWord(OOPList[10]) then begin
				OopCheckCondition := Random(2) = 0;
			end else if OopWord = OopStringToWord(OOPList[11]) then begin
				OopReadValue(statId, position);
				ix := OopValue;
				OopReadValue(statId, position);
				iy := OopValue;
				if ((ix <> -128) and (iy <> -128)) then
					OopCheckCondition := (X = ix) and (Y = iy)
				else
					OopError(statId, 'Bad condition');
			end else if ShortWord(OopWord) then begin
				OopGetShort(OopWord, shortPtr);
				ix := position;
				OopReadWord(statId, position);
				if (OopWord = 'ABOVE') or ((OopWord = 'BELOW') or (OopWord = 'IS')) then begin
					OopReadValue(statId, position);
					if OopValue = -128 then
						OopError(statId, 'Bad condition');
				end;
				if (OopWord = 'ABOVE') then
					OopCheckCondition := (shortPtr^ > OopValue)
				else if (OopWord = 'BELOW') then
					OopCheckCondition := (shortPtr^ < OopValue)
				else if (OopWord = 'IS') then
					OopCheckCondition := (shortPtr^ = OopValue)
				else begin
					position := ix;
					OopCheckCondition := (shortPtr^ > 0);
				end;
			end else if OopGetCounter(statId, OopWord, counterPtr) then begin
				ix := position;
				OopReadWord(statId, position);
				if (OopWord = 'ABOVE') or ((OopWord = 'BELOW') or (OopWord = 'IS')) then begin
					OopReadValue(statId, position);
					if OopValue = -128 then
						OopError(statId, 'Bad condition');
				end;
				if (OopWord = 'ABOVE') then
					OopCheckCondition := (counterPtr^ > OopValue)
				else if (OopWord = 'BELOW') then
					OopCheckCondition := (counterPtr^ < OopValue)
				else if (OopWord = 'IS') then
					OopCheckCondition := (counterPtr^ = OopValue)
				else begin
					position := ix;
					OopCheckCondition := (counterPtr^ > 0);
				end;
			end else if OopWord = OopStringToWord(OOPList[12]) then begin
				OopReadValue(statId, position);
				OopCheckCondition := ((Sqr(Board.Stats[0].X - x) + Sqr(Board.Stats[0].Y - y) * 7 / 4) <= (Sqr(OopValue)));
			end else if OopWord = OopStringToWord(OOPList[9]) then begin
				OopReadDirection(statId, position, deltaX, deltaY);
				if not OopParseTile(statId, position, tile) then
					OopError(statId, 'Bad object kind');
				if deltaX + deltaY = 0 then
					OopCheckCondition := MatchTiles(Under, tile)
				else
					OopCheckCondition := MatchTiles(Board.Tiles[X + DeltaX][Y + DeltaY], tile);
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
	begin
		s := '';
		OopReadChar(statId, position);
		while (OopChar <> #0) and (OopChar <> #13) do begin
			s := s + OopChar;
			OopReadChar(statId, position);
		end;
		OopReadLineToEnd := s;
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

				Board.Stats[iStat].DataPos := iDataPos;
			end;
		end;
	end;

function OopExecute(statId: integer; var position: integer; name: TString50): boolean;
	var
		textWindow: TTextWindowState;
		textLine: string;
		deltaX, deltaY: integer;
		code, ix, iy: integer;
		stopRunning: boolean;
		endOfProgram: boolean;
		replaceTile: TTile;
		namePosition: integer;
		lastPosition: integer;
		repeatInsNextTick: boolean;
		replaceStat, dieItem: boolean;
		lineFinished: boolean;
		labelPtr: pointer;
		labelDataPos: integer;
		labelStatId: integer;
		counterPtr: cInt;
		shortPtr: cShort;
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
			dieItem := false;
			endOfProgram := false;
			insCount := 1;
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

				if OopChar = #39 { apostrophe } then begin
					OopSkipLine(statId, position);
				end else if (OopChar = '@') or (OopChar = UpCase(OOPList[8][1])) then begin
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
						if OopChar <> #13 then
							Dec(position);

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
						end else if OopWord = 'SET' then begin							
							OopReadWord(statId, position);
							textLine := OopWord;
							if ShortWord(OopWord) then begin
								OopGetShort(OopWord, shortPtr);
								OopReadValue(statId, position);
								if OopValue <> -128 then
									shortPtr^ := OopValue
								else
									shortPtr^ := 1;
								GameUpdateSidebar;
							end else if OopGetCounter(statId, OopWord, counterPtr) then begin
								OopReadValue(statId, position);
								if OopValue <> -128 then
									counterPtr^ := OopValue
								else
									counterPtr^ := 1;
								GameUpdateSidebar;
							end else
								WorldSetFlag(OopWord);
							if textLine = OopStringToWord(OOPList[19]) then
								TransitionDrawToBoard;
							if textLine = OopStringToWord(OOPList[18]) then
								DrawPlayerSurroundings(Board.Stats[0].X,Board.Stats[0].Y);
						end else if OopWord = 'CLEAR' then begin
							OopReadWord(statId, position);
							textLine := OopWord;
							if ShortWord(OopWord) then begin
								OopGetShort(OopWord, shortPtr);
								shortPtr^ := 0;
								GameUpdateSidebar;
							end else if OopGetCounter(statId, OopWord, counterPtr) then begin
								counterPtr^ := 0;
								GameUpdateSidebar;
							end else
								WorldClearFlag(OopWord);
							if textLine = OopStringToWord(OOPList[19]) then
								TransitionDrawToBoard;
							if textLine = OopStringToWord(OOPList[18]) then
								DrawPlayerSurroundings(Board.Stats[0].X,Board.Stats[0].Y);
						end else if OopWord = 'IF' then begin
							OopReadWord(statId, position);
							if OopCheckCondition(statId, position) then
								goto ReadCommand;
						end else if OopWord = OopStringToWord(OOPList[29]) then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							OopReadWord(statId, position);
							if Board.Tiles[X + deltaX][Y + deltaY].element = E_OBJECT then begin
								bindStatId := GetStatIdAt(X + deltaX, Y + deltaY);
								if (OopWord <> '') and (bindStatId > 0) then begin
									FileLoadStatData(OopWord,bindStatId);
									Board.Stats[bindStatId].DataPos := 0;
								end;
							end;
						end else if OopWord = OopStringToWord(OOPList[34]) then begin
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							OopReadValue(statId, position);
							if ( ix > -1 ) and ( ix < 16 ) then begin
								if ( iy > -1 ) and ( iy < 16 ) then begin
									if ( OopValue > -1 ) and ( OopValue < 256 ) then begin
										World.Info.PlayerColor := AsColor( ix, iy );
										World.Info.PlayerChar := Chr(OopValue);
									end;
								end;
							end;
						end else if OopWord = OopStringToWord(OOPList[33]) then begin
							if CurrentSave = '' then
								CurrentSave := World.Info.Name;
							WorldSave(CurrentSave,'.SAV');
							stopRunning := true;
						end else if OopWord = OopStringToWord(OOPList[32]) then begin
							if CurrentSave = '' then begin
								if GameWorldLoad('.SAV') then begin
									ReturnBoardId := World.Info.CurrentBoard;
									BoardChange(ReturnBoardId);
									TransitionDrawToBoard;
								end;
							end else if WorldLoad(CurrentSave, '.SAV') then
								TransitionDrawToBoard;
							stopRunning := true;
						end else if OopWord = 'SHOOT' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if BoardShoot(E_BULLET, X, Y, deltaX, deltaY, SHOT_SOURCE_ENEMY) then
								SoundQueue(2, SoundParse(ConfigList[43]));
							stopRunning := true;
						end else if OopWord = 'THROWSTAR' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if BoardShoot(E_STAR, X, Y, deltaX, deltaY, SHOT_SOURCE_ENEMY) then
								begin end;
							stopRunning := true;
						end else if OopWord = OopStringToWord(OOPList[6]) then begin
							OopReadWord(statId, position);

							labelStatId := 0;
							while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13'!') do begin
								labelPtr := Board.Stats[labelStatId].Data;
								AdvancePointer(labelPtr, labelDataPos + 1);

								Char(labelPtr^) := UpCase(OOPList[8][1]);
							end;
						end else if OopWord = OopStringToWord(OOPList[7]) then begin
							OopReadWord(statId, position);

							labelStatId := 0;
							while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13 + UpCase(OOPList[8][1])) do begin
								labelPtr := Board.Stats[labelStatId].Data;
								AdvancePointer(labelPtr, labelDataPos + 1);

								Char(labelPtr^) := '!';
							end;
						end else if (OopWord = 'GIVE') or (OopWord = 'TAKE') then begin
							if OopWord = 'TAKE' then
								counterSubtract := true
							else
								counterSubtract := false;

							OopReadWord(statId, position);
							textLine := OopWord;

							if ShortWord(OopWord) then begin
								OopGetShort(OopWord, shortPtr);
								code := position;
								OopReadValue(statId, position);
								if OopValue = -128 then begin
									position := code;
									OopValue := 1;
								end;
								if OopValue > 0 then begin
									if counterSubtract then
										OopValue := -OopValue;

									if (shortPtr^ + OopValue) >= 0 then begin
										shortPtr^ := shortPtr^ + OopValue;
									end else begin
										goto ReadCommand;
									end;
								end;
							end else if OopGetCounter(statId, OopWord, counterPtr) then begin
								code := position;
								OopReadValue(statId, position);
								if OopValue = -128 then begin
									position := code;
									OopValue := 1;
								end;
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
							if textLine = OopStringToWord(OOPList[19]) then
								TransitionDrawToBoard;
							if textLine = OopStringToWord(OOPList[18]) then
								DrawPlayerSurroundings(Board.Stats[0].X,Board.Stats[0].Y);
							GameUpdateSidebar;
						end else if OopWord = OopStringToWord(OOPList[5]) then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if (Sqr(deltaX) + Sqr(deltaY)) = 1 then begin
								OopReadWord(statId, position);
								ix := WorldGetBoardPosition(OopWord);
								if ix > -1 then
									if deltaY = -1 then
										Board.Info.NeighborBoards[0] := ix
									else if deltaY = 1 then
										Board.Info.NeighborBoards[1] := ix
									else if deltaX = -1 then
										Board.Info.NeighborBoards[2] := ix
									else Board.Info.NeighborBoards[3] := ix;
							end;
						end else if OopWord = OopStringToWord(OOPList[1]) then begin
							OopReadWord(statId, position);
							deltaX := WorldGetBoardPosition(OopWord);
							if deltaX > -1 then begin
								OopReadValue(statId, position);
								ix := OopValue;
								OopReadValue(statId, position);
								iy := OopValue;
								BoardChange(deltaX);
								TransitionDrawToBoard;
								BoardEnter;
								if (( ix > 0 ) and ( iy > 0 )) and
									((Board.Stats[0].X <> ix) or
										(Board.Stats[0].Y <> iy)) then
									MoveStat(0, ix, iy);
								if OopSend(0, 'ALL:' + OOPList[28], false) then begin end;
							end;
							stopRunning := true;
						end else if OopWord = 'END' then begin
							position := -1;
							OopChar := #0;
						end else if OopWord = 'ENDGAME' then begin
							World.Info.Health := 0;
							World.Info.GracePeriod := ParamList[118];
						end else if OopWord = 'IDLE' then begin
							stopRunning := true;
						end else if OopWord = 'RESTART' then begin
							position := 0;
							lineFinished := false;
						end else if OopWord = 'ZAP' then begin
							OopReadWord(statId, position);

							labelStatId := 0;
							while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13':') do begin
								labelPtr := Board.Stats[labelStatId].Data;
								AdvancePointer(labelPtr, labelDataPos + 1);

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

									labelDataPos := OopFindString(labelStatId, #13#39 + OopWord + #13);
								until labelDataPos <= 0;
						end else if OopWord = 'LOCK' then begin
							P2 := 1;
						end else if OopWord = 'UNLOCK' then begin
							P2 := 0;
						end else if OopWord = 'SEND' then begin
							OopReadWord(statId, position);
							if OopSend(statId, OopWord, false) then
								lineFinished := false;
						end else if OopWord = 'BECOME' then begin
							if OopParseTile(statId, position, argTile) then begin
								replaceStat := true;
								replaceTile.Element := argTile.Element;
								replaceTile.Color := argTile.Color;
							end else begin
								OopError(statId, 'Bad #BECOME');
							end;
						end else if OopWord = OopStringToWord(OOPList[2]) then begin
							OopReadDirection(statId, position, ix, iy);
							textLine := OopNextWord(statId, position);
							OopReadDirection(statId, position, deltaX, deltaY);
							if textLine = OopStringToWord(OOPList[14]) then begin
								deltaX := deltaX - ix;
								deltaY := deltaY - iy;
							end;
							bindStatId := GetStatIdAt(X + ix, Y + iy);
							if (bindStatId > -1) then begin
								Board.Stats[bindStatId].StepX := deltaX;
								Board.Stats[bindStatId].StepY := deltaY;
							end;
						end else if OopWord = OopStringToWord(OOPList[30]) then begin
							OopReadDirection(statId, position, ix, iy);
							textLine := OopNextWord(statId, position);
							OopReadDirection(statId, position, deltaX, deltaY);
							if textLine = OopStringToWord(OOPList[14]) then begin
								deltaX := deltaX - ix;
								deltaY := deltaY - iy;
							end;
							if ElementDuplicate(ix, iy, deltaX, deltaY, statId) then
								BoardDrawTile(X + deltaX, Y + deltaY);
						end else if OopWord = OopStringToWord(OOPList[4]) then begin
							OopReadDirection(statId, position, ix, iy);
							textLine := OopNextWord(statId, position);
							OopReadDirection(statId, position, deltaX, deltaY);
							if textLine = OopStringToWord(OOPList[14]) then begin
								deltaX := deltaX - ix;
								deltaY := deltaY - iy;
							end;
							if ((deltaX <> 0) or (deltaY <> 0))
								and (Board.Tiles[X + ix][Y + iy].Element <> E_EMPTY)
							then begin
								if (((X + ix + deltaX) > 0) and ((X + ix + deltaX) <= BOARD_WIDTH))
									and (((Y + iy + deltaY) > 0) and ((Y + iy + deltaY) <= BOARD_HEIGHT + 1))
								then begin
									ElementPushablePush(X + ix, Y + iy, deltaX, deltaY);
									if not ElementDefs[Board.Tiles[X + ix][Y + iy].Element].Walkable then begin
										if not ElementDefs[Board.Tiles[X + ix + deltaX][Y + iy + deltaY].Element].Walkable then
											ElementPushablePush(X + ix + deltaX, Y + iy + deltaY, deltaX, deltaY);
										bindStatId := GetStatIdAt(X + ix, Y + iy);
										if bindStatId > -1 then begin
											if GetStatIdAt(X + ix + deltaX, Y + iy + deltaY) < 0 then
												MoveStat(bindStatId, X + ix + deltaX, Y + iy + deltaY);
										end else begin
											OopPlaceTile(X + ix + deltaX, Y + iy + deltaY, Board.Tiles[X + ix][Y + iy]);
											Board.Tiles[X + ix][Y + iy].Element := E_EMPTY;
										end;
									end;
									BoardDrawTile(X + ix, Y + iy);
									BoardDrawTile(X + ix + deltaX, Y + iy + deltaY);
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
						end else if OopWord = OopStringToWord(OOPList[3]) then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							if ( ix > -1 ) and ( ix < 16 ) then begin
								if ( iy < 1 ) or ( iy > 15 ) then
									iy := 0;
								Board.Tiles[X + deltaX][Y + deltaY].Color := AsColor(ix, iy);
								BoardDrawTile(X + deltaX, Y + deltaY);
							end;							
						end else if OopWord = 'CHANGE' then begin
							if not OopParseTile(statId, position, argTile) then
								OopError(statId, 'Bad #CHANGE');
							if not OopParseTile(statId, position, argTile2) then
								OopError(statId, 'Bad #CHANGE');

							ix := 0;
							iy := 1;
							if argTile2.Color = 0 then
								argTile2.Color := ElementDefs[argTile2.Element].Color;

							while FindTileOnBoard(ix, iy, argTile) do
								OopPlaceTile(ix, iy, argTile2);
						end else if OopWord = 'PLAY' then begin
							OopReadChar(statId, position);
							if OopChar = #13 then
								SoundClearQueue;
							Dec(position);
							textLine := SoundParse(OopReadLineToEnd(statId, position));
							if Length(textLine) <> 0 then
								SoundQueue(-1, textLine);
							lineFinished := false;
						end else if OopWord = OopStringToWord(OOPList[31]) then begin
							textLine := SoundParse(OopReadLineToEnd(statId, position));
							if Length(textLine) <> 0 then
								SoundQueue(2, textLine);
							lineFinished := false;
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
							OopReadWord(statId, position);
							if OopWord = 'ITEM' then
								dieItem := true;
						end else if OopWord = 'BIND' then begin
							OopReadWord(statId, position);
							bindStatId := 0;
							if OopIterateStat(statId, bindStatId, OopWord) then begin
								if statId <> bindStatId then begin
									FreeStatDataMem(statId);
									Data := Board.Stats[bindStatId].Data;
									DataLen := Board.Stats[bindStatId].DataLen;
								end;
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
				end else if OopChar = #13 then begin
					if textWindow.LineCount > 0 then
						TextWindowAppend(textWindow, '');
				end else if OopChar = #0 then begin
					endOfProgram := true;
				end else begin
					textLine := OopChar + OopReadLineToEnd(statId, position);
					TextWindowAppend(textWindow, textLine);
				end;
			until endOfProgram or stopRunning or repeatInsNextTick or replaceStat or (insCount > ParamList[116]);

			if (OopWord = OopStringToWord(OOPList[1])) or (OopWord = 'SAVEDGAMES') then
				goto StopExecution;

			if repeatInsNextTick then
				position := lastPosition;

			if OopChar = #0 then
				position := -1;

			if textWindow.LineCount > 1 then begin
				namePosition := 0;
				OopReadChar(statId, namePosition);
				if (OopChar = '@') then begin
					name := OopReadLineToEnd(statId, namePosition);
				end;

				if Length(name) = 0 then
					name := 'Interaction';

				textWindow.Title := name;
				TextWindowDrawOpen(textWindow);
				TextWindowSelect(textWindow, TWS_HYPERLINK_AS_SELECT);
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
				if dieItem then
					MoveStat(0, ix, iy);
			end;
		end;

		StopExecution:
		OopExecute := not replaceStat;
	end;

begin
end.
