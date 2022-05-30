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
	type
		cInt = ^integer;
		cShort = ^shortint;
	function WorldGetFlagPosition(name: TString50): integer;
	procedure WorldSetFlag(name: TString50);
	procedure WorldClearFlag(name: TString50);
	procedure InspectObjectCode(statId, PointPos: integer; ErrMsg: string);
	function OopSend(statId: integer; sendLabel: string; ignoreLock: boolean): boolean;
	function OopExecute(statId: integer; var position: integer; name: TString50): boolean;
	function ShortWord(s: string): boolean;
	procedure OopGetShort(statId: integer; s: string; var cPtr: cShort);
	function OopGetCounter(statId: integer; s: string; var cPtr: cInt): boolean;
	procedure GetBoardStats;

implementation
uses Sounds, TxtWind, Game, Elements;

procedure OopError(statId, position: integer; message: string);
	begin
		if DebugEnabled then begin
			SoundQueue(5, SoundParse(ConfigList[58])); {Error sound}
			InspectObjectCode(statId, position, ConfigList[57] + message);
			Board.Stats[statId].DataPos := -1;
		end else if ConfigList[57] <> '' then begin
			DisplayMessage(200, ConfigList[57] + message); {"ERR: "}
			SoundQueue(5, SoundParse(ConfigList[58])); {Error sound}
			Board.Stats[statId].DataPos := -1;
		end;
	end;

procedure OopReadChar(statId: integer; var position: integer);
	begin
		with Board.Stats[statId] do begin
			if (position >= 0) and (position < DataLen) then begin
				OopChar := Data^[position];
				Inc(position);
			end else begin
				OopChar := #0
			end;
		end;
	end;

procedure OopReadWord(statId: integer; var position: integer);
	var
		s: string;
		i: integer;
	begin
		OopWord := '';
		repeat
			OopReadChar(statId, position);
		until OopChar <> ' ';
		OopChar := UpCase(OopChar);
		while ((OopChar >= 'A') and (OopChar <= 'Z'))
			or ((OopChar >= '0') and (OopChar <= '9'))
			or (OopChar = '_')
			or (OopChar = ':')
			or (OopChar = '-')
			or (OopChar = '^')
		do begin
			if OopChar = '^' then begin
				Str(Board.Stats[statId].elseCheck and $7F, s);
				OopWord := OopWord + s;
			end else
				OopWord := OopWord + OopChar;
			OopReadChar(statId, position);
			OopChar := UpCase(OopChar);
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
	var
		i: integer;
	begin
		ShortWord := false;
		for i := 5 to 19 do
			if s = OopStringToWord(Ooplist[i]) then ShortWord := true;
		for i := 7 to 9 do
			if s = CustomObjList[i] then ShortWord := true;
		if s = 'ARRAY' then ShortWord := true;
	end;

procedure OopGetShort(statId: integer; s: string; var cPtr: cShort);
	var
		i: integer;
	begin
		if s = OopStringToWord(Ooplist[5]) then
			cPtr := @Board.Info.IsDark
		else if s = OopStringToWord(Ooplist[6]) then
			cPtr := @World.Info.Keys[1]
		else if s = OopStringToWord(Ooplist[7]) then
			cPtr := @World.Info.Keys[2]
		else if s = OopStringToWord(Ooplist[8]) then
			cPtr := @World.Info.Keys[3]
		else if s = OopStringToWord(Ooplist[9]) then
			cPtr := @World.Info.Keys[4]
		else if s = OopStringToWord(Ooplist[10]) then
			cPtr := @World.Info.Keys[5]
		else if s = OopStringToWord(Ooplist[11]) then
			cPtr := @World.Info.Keys[6]
		else if s = OopStringToWord(Ooplist[12]) then
			cPtr := @World.Info.Keys[7]
		else if s = OopStringToWord(Ooplist[13]) then
			cPtr := @World.Info.KeySpeed
		else if s = OopStringToWord(Ooplist[14]) then
			cPtr := @PMouseX
		else if s = OopStringToWord(Ooplist[15]) then
			cPtr := @PMouseY
		else if s = OopStringToWord(Ooplist[16]) then
			cPtr := @PPosX
		else if s = OopStringToWord(Ooplist[17]) then
			cPtr := @PPosY
		else if s = OopStringToWord(OOPList[18]) then
			cPtr := @OPosX
		else if s = OopStringToWord(OOPList[19]) then
			cPtr := @OPosY
		else if s = 'ARRAY' then
			cPtr := @Board.Stats[statId].elseCheck
		else
			for i := 7 to 9 do
				if s = CustomObjList[i] then
					cPtr := @Board.Stats[statId].ObjTiny[i - 6];
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
		else if s = OopStringToWord(Ooplist[3]) then
			cPtr := @World.Info.EnergizerTicks
		else if s = OopStringToWord(Ooplist[4]) then
			cPtr := @World.Info.TorchTicks
		else begin
			OopGetCounter := false;
			for i := 1 to 7 do
				if s = CustomBoardList[i] then begin
					cPtr := @Board.Info.Local[i];
					OopGetCounter := true;
				end;
			for i := 1 to 4 do
				if s = CustomObjList[i] then begin
					cPtr := @Board.Stats[statId].ObjLocal[i];
					OopGetCounter := true;
				end;
			if s = CustomObjList[5] then begin
				cPtr := @Board.Stats[statId].Leader;
				OopGetCounter := true;
			end;		
			if s = CustomObjList[6] then begin
				cPtr := @Board.Stats[statId].Follower;
				OopGetCounter := true;
			end;		
			for i := 1 to CUSTOM_FLAG_COUNT do
				if s = CustomFlagList[i] then begin
					cPtr := @World.Info.CustomFlags[i];
					OopGetCounter := true;
				end;
			
		end;
	end;

function OopRunFunc(statId: integer; var position: integer): integer;
	var
		ix, iy: integer;
		labelPtr: pointer;
		tmpcond: byte;
	begin
		OopReadWord(statId, position);
		OopFuncReturn := -1;
		with Board.Stats[statId] do begin
			tmpcond := elseCheck and $80;
			labelPtr := Data;
			ix := DataPos;
			iy := DataLen;
			Data := nil;
			DataLen := 0;
			if FileLoadStatData(OopWord,statId) then begin
				if OopExecute(statId,DataPos,'%%Function') then begin end;
				FreeMem(Data,DataLen);
				Data := labelPtr;
				DataPos := ix;
				DataLen := iy;
				elseCheck := (elseCheck and $7F) + tmpcond;
			end else 
				OopError(statId,position, 'File not found ' + OopWord + '.OBJ');
		end;
		OopRunFunc := OopFuncReturn;
	end;

procedure OopReadValue(statId: integer; var position: integer);
	var
		s: string[20];
		t: string;
		ix, iy, code: integer;
		isNumeric: boolean;
		counterPtr: cInt;
		shortPtr: cShort;
		tmpCond: boolean;
	begin
		s := '';
		repeat
			OopReadChar(statId, position)
		until OopChar <> ' ';

		OopChar := UpCase(OopChar);
		isNumeric := true;
		while ((((OopChar >= 'A') and (OopChar <= 'Z'))
			or ((OopChar >= '0') and (OopChar <= '9')))
			or (OopChar = '-')) or (OopChar = '^')
		do begin
			if (((OopChar < '0') or (OopChar > '9'))
				and (OopChar <> '-')) and (OopChar <> '^')
			then
				isNumeric := false;
			if OopChar = '^' then begin
				Str(Board.Stats[statId].elseCheck and $7F, t);
				s := s + t;
			end else
				s := s + OopChar;
			OopReadChar(statId, position);
			OopChar := UpCase(OopChar);
		end;

		if position > 0 then
			Dec(position);

		OopValue := -128;
		if Length(s) <> 0 then begin
			if isNumeric then
				Val(s, OopValue, code)
			else if s = OopStringToWord(Ooplist[2]) then begin {'RANDOM'}
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
			end else if s = 'TRUE' then
				OopValue := 1
			else if s = 'FALSE' then
				OopValue := 0				
			else if s = 'RUN' then begin
				s := OopWord;
				OopValue := OopRunFunc(statId, position);
				OopWord := s;
			end else if s = 'BOARDID' then
				OopValue := World.Info.CurrentBoard
			else if ShortWord(s) then begin
				OopGetShort(statId, s, shortPtr);
				OopValue := shortPtr^;
			end else if OopGetCounter(statId, s, counterPtr) then
				OopValue := counterPtr^
			else OopValue := ColorNumber(s, -1);
		end;
	end;

procedure OopSkipLine(statId: integer; var position: integer);
	begin
		repeat
			OopReadChar(statId, position);
		until (OopChar = #0) or (OopChar = #13);
	end;

function OopParseDirection(statId: integer; var position: integer; var dx, dy: integer): boolean;
	var
		ix, iy: integer;
	begin
		with Board.Stats[statId] do begin
			OopParseDirection := true;
			if OopWord = 'PLAYER' then begin
				dx := Board.Stats[0].X - X;
				dy := Board.Stats[0].Y - Y;
			end else if
				(OopWord = 'BY') {}
				or (OopWord = 'AT') {}
				or (OopWord = 'TOWARD') {}
			then begin
				OopReadValue(statId, position);
				dx := OopValue;
				OopReadValue(statId, position);
				dy := OopValue;
				if ((dx <> -128) and (dy <> -128)) then begin
					if (OopWord = 'AT') then begin 
						dx := dx - X;
						dy := dy - Y;
					end;
					if (OopWord = 'TOWARD') then 
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
			end else if (OopWord = 'FIND') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dx, dy);
				Inc(dx,X);
				Inc(dy,Y);
				CalcDirectionFind(X, Y, dx, dy);
			end else if (OopWord = 'TO') then begin
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dx, dy);
				ix := dx;
				iy := dy;
				OopReadWord(statId, position);
				OopParseDirection := OopParseDirection(statId, position, dx, dy);
				Inc(dx,ix);
				Inc(dy,iy);
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
			OopError(statId,position, 'Bad direction ' + OopWord);
	end;

function OopFindString(statId: integer; s: string): integer;
	var
		pos, wordPos, cmpPos: integer;
		maxPos: integer;
	label NoMatch;
	begin
		for pos := 1 to Length(s) do
			s[pos] := UpCase(s[pos]);
		with Board.Stats[statId] do begin
			pos := 0;
			maxPos := DataLen - Length(s);
			while pos <= maxPos do begin
				wordPos := 1;
				cmpPos := pos;
				repeat
					OopChar := Data^[cmpPos];
					if s[wordPos] <> UpCase(OopChar) then
						goto NoMatch;
					Inc(wordPos);
					Inc(cmpPos);
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
				Inc(pos);
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

function WorldGetBoardPosition(statId: integer; var position: integer): integer;
	var
		zpos, bpos, ix, iy: integer;
	begin
		ix := 0;
		zpos := position;
		bpos := -1;
		OopReadWord(statId, position);
		while ((ix <= World.BoardCount) and (bpos = -1)) do begin
			if BoardNames[ix][1] = ':' then begin
				bpos := ix;
				for iy := 1 to Length(OopWord) do
					if UpCase(BoardNames[ix][iy + 1]) <> OopWord[iy] then
						bpos := -1;
					if (((BoardNames[ix][Length(OopWord) + 2] >= 'A') and
						(BoardNames[ix][Length(OopWord) + 2] <= 'Z')) or
						((BoardNames[ix][Length(OopWord) + 2] >= '0') and
						(BoardNames[ix][Length(OopWord) + 2] <= '9'))) then
						bpos := -1;
			end;
			Inc(ix);
		end;
		if bpos = -1 then begin
			position := zpos;
			OopReadValue(statId, position);
			WorldGetBoardPosition := OopValue;
		end else
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

function ElementNumber(s: string): shortint;
	var 
		i: integer;
	begin
		ElementNumber := -1;
		for i := 0 to MAX_ELEMENT do
			if s = ElementDefs[i].Name then ElementNumber := i;
	end;

function OopParseTile(var statId, position: integer; var tile: TMatchTile): boolean;
	var
		i, j, elem: integer;
	label FindElement;
	begin
		OopParseTile := false;
		tile.Color := 0;
		tile.setBG := false;
		tile.setFG := false;

		OopReadWord(statId, position);
		elem := ElementNumber(OopWord);
		if elem <> -1 then goto FindElement;
		i := ColorNumber(OopWord, statId);
		if i = -128 then begin
			Val(OopWord, i, elem);
			if not ((i > 15) and (i < 256)) then exit;
		end;
		if i = 0 then tile.SetFG := true;
		tile.Color := AsColor(i,0);

		OopReadWord(statId, position);
		elem := ElementNumber(OopWord);
		if elem <> -1 then goto FindElement;
		if i < 16 then begin
			j := ColorNumber(OopWord, statId);
			if (j = -128) or (j > 15) then exit;
		end;
		if j = 0 then tile.SetBG := true;
		tile.Color := AsColor(i,j);

		OopReadWord(statId, position);
		elem := ElementNumber(OopWord);
		if elem = -1 then exit;

	FindElement:
		OopParseTile := true;
		tile.Element := elem;
	end;

function MatchTiles(sourceTile: TTile; searchTile: TMatchTile): boolean;
	begin
		MatchTiles := false;
		if (sourceTile.Element = searchTile.Element) or (searchTile.Element = 2) then
			if (searchTile.Color <> 0) or (searchTile.SetFG = true) then begin
				if (searchTile.Color and $F0 > 0) or (searchTile.SetBG = true) then
					MatchTiles := (searchTile.Color = sourceTile.Color)
				else
					MatchTiles := (searchTile.Color = (sourceTile.Color and $0F));
			end else
				MatchTiles := true;
	end;

function FindTileOnBoard(var x, y: integer; tile: TMatchTile): boolean;
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

procedure SwapRelative(var dx, dy: integer; x, y: integer; line: string);
	begin
		if (line = 'AT')
			or (line = 'FIND')
		then begin
			Dec(dx,x);
			Dec(dy,y);
		end;
	end;

function OopCheckCondition(statId: integer; var position: integer): boolean;
	var
		deltaX, deltaY: integer;
		tile: TMatchTile;
		code, ix, iy: integer;
		isCounter: boolean;
		counterPtr: cInt;
		shortPtr: cShort;
		tmpcond: byte;
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
			end else if OopWord = 'COLOR' then begin
				OopReadDirection(statId, position, deltaX, deltaY);
				OopReadValue(statId, position);
				ix := OopValue;
				if ix = 0 then
					tile.setFG := true
				else
					tile.setFG := false;
				code := position;
				OopReadValue(statId, position);
				if OopValue = 0 then
					tile.setBG := true
				else
					tile.setBG := false;
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
					if (deltaX = 0) and (deltaY = 0) then
						OopCheckCondition := MatchTiles(Under, tile)
					else
						OopCheckCondition := MatchTiles(Board.Tiles[X + deltaX][Y + deltaY], tile);
				end else OopError(statId,position,'Unknown color');
			end else if OopWord = 'RND' then begin
				OopCheckCondition := Random(2) = 0;
			end else if OopWord = 'AT' then begin
				OopReadValue(statId, position);
				ix := OopValue;
				OopReadValue(statId, position);
				iy := OopValue;
				if ((ix <> -128) and (iy <> -128)) then
					OopCheckCondition := (X = ix) and (Y = iy)
				else
					OopError(statId,position, 'Bad condition');
			end else if ShortWord(OopWord) then begin
				tmpcond := elseCheck and $80;
				elseCheck := elseCheck and $7F;
				OopGetShort(statId, OopWord, shortPtr);				
				ix := position;
				OopReadWord(statId, position);
				if (OopWord = 'ABOVE') or ((OopWord = 'BELOW') or (OopWord = 'IS')) then begin
					OopReadValue(statId, position);
					if OopValue = -128 then
						OopError(statId,position, 'Could not read ' + OopWord + ' value');
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
				elseCheck := elseCheck + tmpcond;
			end else if OopGetCounter(statId, OopWord, counterPtr) then begin
				ix := position;
				OopReadWord(statId, position);
				if (OopWord = 'ABOVE') or ((OopWord = 'BELOW') or (OopWord = 'IS')) then begin
					OopReadValue(statId, position);
					if OopValue = -128 then
						OopError(statId,position, 'Could not read ' + OopWord + ' value');
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
			end else if OopWord = 'RUN' then
				OopCheckCondition := OopRunFunc(statId, position) > 0
			else if OopWord = 'WITHIN' then begin
				OopReadValue(statId, position);
				OopCheckCondition := ((Sqr(Board.Stats[0].X - x) + Sqr(Board.Stats[0].Y - y) * 7 / 4) <= (Sqr(OopValue)));
			end else if OopWord = 'DETECT' then begin
				if OopNextWord(statId, position) = 'PLAYER' then begin
					OopReadWord(statId, position);
					if not OopParseTile(statId, position, tile) then
						OopError(statId,position, 'Bad object kind');
					OopCheckCondition := MatchTiles(Board.Stats[0].Under, tile);
				end else begin
					OopReadDirection(statId, position, deltaX, deltaY);
					if not OopParseTile(statId, position, tile) then
						OopError(statId,position, 'Bad object kind');
					if (deltaX = 0) and (deltaY = 0) then
						OopCheckCondition := MatchTiles(Under, tile)
					else
						OopCheckCondition := MatchTiles(Board.Tiles[X + deltaX][Y + deltaY], tile);
				end;					
			end else if OopWord = 'ANY' then begin
				if not OopParseTile(statId, position, tile) then
					OopError(statId,position, 'Bad object kind');
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

procedure GetBoardStats;
	var
		i: integer;
		s, t: string;
		textWindow: TTextWindowState;
	begin
		with Board.Info do begin
			TextWindowInitState(textWindow);
			textWindow.Selectable := false;
			TextWindowAppend(textWindow, '$** Board Stats: **');
			s := 'Board is: ';
			if IsDark > 0 then
				s := s + 'Dark, '
			else
				s := s + 'Not Dark, ';
			if ReenterWhenZapped then
				s := s + 'Zappy'
			else
				s := s + 'Not Zappy';
			TextWindowAppend(textWindow, s);
			Str(StartPlayerX,t);
			Str(StartPlayerY,s);
			TextWindowAppend(textWindow, 'Re-enter at: ' + t + ', ' + s);
			Str(MaxShots,s);
			TextWindowAppend(textWindow, 'Max Shots: ' + s);
			if (TimeLimitSec > 0) and (World.Info.BoardTimeSec >= 0) then begin
				Str(TimeLimitSec,s);
				Str(TimeLimitSec - World.Info.BoardTimeSec,t);
				TextWindowAppend(textWindow, 'Time: ' + t + 's remains of ' + s + 's limit');
			end else
				TextWindowAppend(textWindow, 'Time: No time limit');
			Str(Board.StatCount, s);
			TextWindowAppend(textWindow, 'Stat Count: ' + s);
			Str(World.Info.PlayerColor, s);
			TextWindowAppend(textWindow, 'Player Color: ' + s);
			TextWindowAppend(textWindow, 'Player Char: ' + World.Info.PlayerChar);
			for i := 1 to 7 do begin
				Str(Local[i],s);
				TextWindowAppend(textWindow, CustomBoardList[i] + ': ' + s);
			end;
			TextWindowAppend(textWindow, '$** Board connections: **');
			for i := 0 to 3 do
				if NeighborBoards[i] <> 0 then
					TextWindowAppend(textWindow, '  ' + NeighborArrowList[i] + '  ' +  BoardNames[NeighborBoards[i]])
				else
					TextWindowAppend(textWindow, '  ' + NeighborArrowList[i] + '  None');
			textWindow.Title := 'Inspecting Board';
			TextWindowDrawOpen(textWindow);
			TextWindowSelect(textWindow, TWS_IGNORE_HYPERLINKS);
			TextWindowDrawClose(textWindow);
			TextWindowFree(textWindow);
		end;
	end;

procedure InspectObjectCode(statId, PointPos: integer; ErrMsg: string);
	var
		s, t: string;
		ch: char;
		i, pos: integer;
		textWindow: TTextWindowState;
		isCurLine: boolean;
	begin
		with Board.Stats[statId] do begin
			pos := 0;
			s := '';
			isCurLine := false;
			TextWindowInitState(textWindow);
			textWindow.Selectable := false;
			if ErrMsg <> '' then
				TextWindowAppend(textWindow, #255#32 + ErrMsg)
			else begin
				TextWindowAppend(textWindow, '$** Object Stats: **');
				Str(P1,s);
				t := s + ', ';
				Str(P2,s);
				t := t + s + ', ';
				Str(P3,s);
				TextWindowAppend(textWindow, 'Params: ' + t + s);
				Str(StepX,s);
				t := s + ', ';
				Str(StepY,s);
				TextWindowAppend(textWindow, 'Step: ' + t + s);
				Str(Cycle,s);
				TextWindowAppend(textWindow, 'Cycle: ' + s);
				for i := 1 to 4 do begin
					Str(ObjLocal[i],s);
					TextWindowAppend(textWindow, CustomObjList[i] + ': ' + s);
				end;
				Str(Leader,s);
				TextWindowAppend(textWindow, CustomObjList[5] + ': ' + s);
				Str(Follower,s);
				TextWindowAppend(textWindow, CustomObjList[6] + ': ' + s);
				for i := 7 to 9 do begin
					Str(ObjTiny[i - 6],s);
					TextWindowAppend(textWindow, CustomObjList[i] + ': ' + s);
				end;
				s := '';
				TextWindowAppend(textWindow, '$** Object Data: **');
			end;
			while pos <= DataLen do begin
				Move(Ptr(Seg(Data^), Ofs(Data^) + pos)^, ch, 1);
				if ch = #13 then begin
					if isCurLine then begin
						TextWindowAppend(textWindow, #255#16 + s);
						if ErrMsg <> '' then
							TextWindowAppend(textWindow, #255#32 + ErrMsg);
					end else
						TextWindowAppend(textWindow, s);
					s := '';
					isCurLine := false;
				end else
					s := s + ch;
				Inc(pos);
				if pos = PointPos then
					isCurLine := true;
			end;
			if DataLen = 0 then
				TextWindowAppend(textWindow, 'There is no object data.');
			textWindow.Title := 'Inspecting Object';
			TextWindowDrawOpen(textWindow);
			TextWindowSelect(textWindow, TWS_IGNORE_HYPERLINKS);
			TextWindowDrawClose(textWindow);
			TextWindowFree(textWindow);
		end;
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
		replaceStat, replaceForce, dieItem: boolean;
		MatchFG, MatchBG: boolean;
		lineFinished: boolean;
		labelPtr: pointer;
		labelDataPos: integer;
		labelStatId: integer;
		counterPtr: cInt;
		shortPtr: cShort;
		counterSubtract: boolean;
		bindStatId: integer;
		insCount: integer;
		argTile: TMatchTile;
		argTile2: TMatchTile;
		tmpcond: byte;
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
			replaceForce := false;
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
						if OopChar <> #13 then
							Dec(position);

						stopRunning := true;
					end else
						OopError(statId,position, 'Bad direction ' + OopWord);
				end else if OopChar = '#' then begin
		ReadCommand:
					OopReadWord(statId, position);
					if OopWord = 'THEN' then
						OopReadWord(statId, position);
					if Length(OopWord) = 0 then
						goto ReadInstruction;
					if name <> '%%Function' then Inc(insCount);
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
								tmpcond := elseCheck and $80;
								OopGetShort(statId, OopWord, shortPtr);
								OopReadValue(statId, position);
								if OopValue <> -128 then
									shortPtr^ := OopValue
								else
									shortPtr^ := 1;
								elsecheck := (elsecheck and $7F) + tmpcond;
								GameUpdateSidebar;
							end else if OopGetCounter(statId, OopWord, counterPtr) then begin
								OopReadValue(statId, position);
								if OopValue <> -128 then
									counterPtr^ := OopValue
								else
									counterPtr^ := 1;
								GameUpdateSidebar;
							end else if OopNextWord(statId, position) = '' then
								WorldSetFlag(OopWord)
							else
								OopError(statId,position, 'Unknown counter ' + OopWord);
							if textLine = OopStringToWord(Ooplist[13]) then KeyRepeat;
							if (textLine = OopStringToWord(Ooplist[5])) or
								(textLine = OopStringToWord(Ooplist[4]))
							then TransitionDrawToBoard;
						end else if OopWord = 'CLEAR' then begin
							OopReadWord(statId, position);
							textLine := OopWord;
							if ShortWord(OopWord) then begin
								OopGetShort(statId, OopWord, shortPtr);
								shortPtr^ := 0;
								GameUpdateSidebar;
							end else if OopGetCounter(statId, OopWord, counterPtr) then begin
								counterPtr^ := 0;
								GameUpdateSidebar;
							end else
								WorldClearFlag(OopWord);
							if textLine = OopStringToWord(Ooplist[13]) then KeyRepeat;
							if (textLine = OopStringToWord(Ooplist[5])) or
								(textLine = OopStringToWord(Ooplist[4]))
							then TransitionDrawToBoard;
						end else if OopWord = 'IF' then begin
							elseCheck := (elseCheck and $7F);
							OopReadWord(statId, position);
							if OopCheckCondition(statId, position) then
								goto ReadCommand
							else
								elseCheck := (elseCheck and $7F) + $80;
						end else if OopWord = 'ELSE' then begin
							if (elseCheck and $80) = $80 then
								goto ReadCommand;
						end else if OopWord = 'AND' then begin
							if (elseCheck and $80) = 0 then
								goto ReadCommand;
						end else if OopWord = 'RUN' then begin
							ix := OopRunFunc(statId, position);
						end else if OopWord = 'LOAD' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							OopReadWord(statId, position);
							if Board.Tiles[X + deltaX][Y + deltaY].element = E_OBJECT then begin
								bindStatId := GetStatIdAt(X + deltaX, Y + deltaY);
								textLine := OopWord;
								if textLine = 'APPEND' then
									OopReadWord(statId, position);
								if (OopWord <> '') and (bindStatId > 0) then begin
									if (textLine = 'APPEND') then begin
										if FileAppendStatData(OopWord,bindStatId) then
											goto ReadCommand
										else
											OopError(statId,position, 'File not found ' + OopWord + '.OBJ');
									end else if FileLoadStatData(OopWord,bindStatId) then begin
										Board.Stats[bindStatId].DataPos := 0;
										goto ReadCommand;
									end else
										OopError(statId,position, 'File not found ' + OopWord + '.OBJ');
								end else
									OopError(statId,position, 'LOAD needs a filename');
							end;
						end else if OopWord = 'PALETTE' then begin
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							OopReadValue(statId, position);
							deltaX := OopValue;
							OopReadValue(statId, position);
							deltaY := OopValue;
							if (((ix >= 0) and (ix <= 15))
								and ((iy >= 0) and (iy <= 63)))
								and (((deltaX >= 0) and (deltaX <= 63))
								and ((deltaY >= 0) and (deltaY <= 63)))
							then begin
								if (iy + deltaX + deltaY = 0) then begin
									iy := ParamList[PALETTE_START + (ix * 3)];
									deltaX := ParamList[PALETTE_START + (ix * 3) + 1];
									deltaY := ParamList[PALETTE_START + (ix * 3) + 2];
								end;
								World.Info.CustomPalette[(ix * 3)] := iy;
								World.Info.CustomPalette[(ix * 3) + 1] := deltaX;
								World.Info.CustomPalette[(ix * 3) + 2] := deltaY;
								BlockPalette(ix,iy,deltaX,deltaY);
							end else
								OopError(statId,position, 'Bad PALETTE Command');
						end else if OopWord = 'PLAYER' then begin
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							OopReadValue(statId, position);
							if ((( ix > -1 ) and ( ix < 16 ))
								and (( iy > -1 ) and ( iy < 16 )))
								and (( OopValue > -1 ) and ( OopValue < 256 ))
							then begin
								World.Info.PlayerColor := AsColor( ix, iy );
								World.Info.PlayerChar := Chr(OopValue);
							end else
								OopError(statId,position, 'Bad PLAYER Command');
						end else if OopWord = 'QUICKSAVE' then begin
							OopReadWord(statId, position);
							if OopWord <> '' then begin
								if Length(OopWord) < 9 then
									WorldSave(OopWord,'.SAV');
							end else begin
								if CurrentSave = '' then
									CurrentSave := World.Info.Name;
								WorldSave(CurrentSave,'.SAV');
							end;
							stopRunning := true;
						end else if OopWord = 'QUICKLOAD' then begin
							OopReadWord(statId, position);
							if OopWord <> '' then begin
								if WorldLoad(OopWord, '.SAV') then begin
									ReturnBoardId := World.Info.CurrentBoard;
									BoardChange(ReturnBoardId);
									TransitionDrawToBoard;
								end;
							end else if CurrentSave = '' then begin
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
							if BoardShoot(E_BULLET, X, Y, deltaX, deltaY, ElementDefs[E_BULLET].Param3) then
								SoundQueue(2, SoundParse(ConfigList[43])); {Object shoot}
							stopRunning := true;
						end else if OopWord = 'THROWSTAR' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if BoardShoot(E_STAR, X, Y, deltaX, deltaY, SHOT_SOURCE_ENEMY) then
								begin end;
							stopRunning := true;
						end else if OopWord = 'PSET' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							ix := GetStatIdAt( X + deltaX, Y + deltaY );
							if ix > -1 then begin
								OopReadWord(statId, position);
								OopReadValue(statId, position);
								iy := OopValue;
								if OopWord = 'P1' then
									Board.Stats[ix].P1 := iy
								else if OopWord = 'P2' then
									Board.Stats[ix].P2 := iy
								else if OopWord = 'P3' then
									Board.Stats[ix].P3 := iy
								else if OopWord = 'CYCLE' then
									Board.Stats[ix].Cycle := iy
								else if ShortWord(OopWord) then begin
									OopGetShort(ix, OopWord, shortPtr);
									shortPtr^ := iy;
								end else if OopGetCounter(ix, OopWord, counterPtr) then
									counterPtr^ := iy;
							end;
						{ end else if OopWord = 'ELEMENT' then begin
							OopReadWord(statId, position);
							ix := ElementNumber(OopWord);
							if ix > -1 then begin
								OopReadWord(statId, position);
								textLine := OopWord;
								OopReadWord(statId, position);
								ElementMod(ix, textLine, OopWord, statId);
								if (textLine = 'CHAR') or (textLine = 'VISIBLEINDARK') then
									TransitionDrawToBoard;
								if (textLine = 'CHAR') or (textLine = 'FG') or (textLine = 'BG') then
									GameUpdateSidebar;
							end else
								OopError(statId,position, 'ERR: Unknown element ' + OopWord); }
						end else if (OopWord = 'GIVE') or (OopWord = 'TAKE') then begin
							if OopWord = 'TAKE' then
								counterSubtract := true
							else
								counterSubtract := false;

							OopReadWord(statId, position);
							textLine := OopWord;

							if ShortWord(OopWord) then begin
								tmpcond := elseCheck and $80;
								elseCheck := elseCheck and $7F;
								OopGetShort(statId, OopWord, shortPtr);
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
										elsecheck := (elsecheck and $7F) + tmpcond;
										goto ReadCommand;
									end;
								end;
								elsecheck := (elsecheck and $7F) + tmpcond;
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
							end else
								OopError(statId,position, 'Unknown counter ' + OopWord);
							if textLine = OopStringToWord(Ooplist[13]) then KeyRepeat;
							if (textLine = OopStringToWord(Ooplist[5])) or
								(textLine = OopStringToWord(Ooplist[4]))
							then TransitionDrawToBoard;
							GameUpdateSidebar;
						end else if OopWord = 'EDGE' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if (Sqr(deltaX) + Sqr(deltaY)) = 1 then begin
								ix := WorldGetBoardPosition(statId, position);
								if (ix > -1) and (ix <= World.BoardCount) then begin
									if deltaY = -1 then
										Board.Info.NeighborBoards[0] := ix
									else if deltaY = 1 then
										Board.Info.NeighborBoards[1] := ix
									else if deltaX = -1 then
										Board.Info.NeighborBoards[2] := ix
									else Board.Info.NeighborBoards[3] := ix;
								end else
									OopError(statId,position, 'No board label :' + OopWord);
							end else
								OopError(statId,position, 'Bad board direction');
						end else if OopWord = 'BOARD' then begin
							deltaX := WorldGetBoardPosition(statId, position);
							if (deltaX > -1) and (deltaX <= World.BoardCount) then begin
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
								if statId <= Board.StatCount then begin
									if Board.Stats[statId].Datalen > 0 then begin
										position := Board.Stats[statId].DataPos;
										if position <> -1 then
											lineFinished := false;
									end;
								end else
									stopRunning := true;
								if OopSend(0, 'ALL:' + Ooplist[1], false) then begin end;
							end else
								OopError(statId,position, 'No board label :' + OopWord);
						end else if OopWord = 'END' then begin
							OopReadValue(statId, position);
							OopFuncReturn := OopValue;
							position := -1;
							OopChar := #0;
						end else if OopWord = 'ENDGAME' then begin
							World.Info.Health := 0;
							World.Info.GracePeriod := ParamList[11];
						end else if OopWord = 'IDLE' then begin
							stopRunning := true;
						end else if OopWord = 'RESTART' then begin
							position := 0;
							lineFinished := false;
						end else if OopWord = 'ZAP' then begin
							labelStatId := 0;
							repeat
								OopReadChar(statId, position);
							until OopChar <> ' ';
							if OopChar = '!' then begin
								OopReadWord(statId, position);
								while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13'!') do begin
									labelPtr := Board.Stats[labelStatId].Data;
									AdvancePointer(labelPtr, labelDataPos + 1);

									Char(labelPtr^) := '@';
								end;
							end else begin
								Dec(position);
								OopReadWord(statId, position);
								while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13':') do begin
									labelPtr := Board.Stats[labelStatId].Data;
									AdvancePointer(labelPtr, labelDataPos + 1);

									Char(labelPtr^) := #39;
								end;
							end;
						end else if OopWord = 'RESTORE' then begin
							labelStatId := 0;
							repeat
								OopReadChar(statId, position);
							until OopChar <> ' ';
							if OopChar = '!' then begin
								OopReadWord(statId, position);
								while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13'@') do begin
									labelPtr := Board.Stats[labelStatId].Data;
									AdvancePointer(labelPtr, labelDataPos + 1);

									Char(labelPtr^) := '!';
								end;
							end else begin
								Dec(position);
								OopReadWord(statId, position);
								while OopFindLabel(statId, OopWord, labelStatId, labelDataPos, #13#39) do
									repeat
										labelPtr := Board.Stats[labelStatId].Data;
										AdvancePointer(labelPtr, labelDataPos + 1);

										Char(labelPtr^) := ':';

										labelDataPos := OopFindString(labelStatId, #13#39 + OopWord + #13);
									until labelDataPos <= 0;
							end;
						end else if (OopWord = 'UNLOCK') or (OopWord = 'LOCK') then begin
							if OopWord = 'UNLOCK' then
								iy := 0
							else
								iy := 1;
							OopReadWord(statId, position);
							if not OopParseDirection(statId, position, deltaX, deltaY) then
								P2 := iy
							else begin
								ix := GetStatIdAt( X + deltaX, Y + deltaY );
								if ix <> -1 then
									Board.Stats[ix].P2 := iy;
							end;
						end else if OopWord = 'SEND' then begin
							repeat
								OopReadChar(statId, position);
							until OopChar <> ' ';
							if OopChar = '/' then begin
								OopReadWord(statId, position);
								if OopParseDirection(statId, position, deltaX, deltaY) then begin
									OopReadWord(statId, position);
									ix := GetStatIdAt(X + deltaX, Y + deltaY);
									if ix > 0 then
										if OopSend(-ix, OopWord, false) then lineFinished := false;
								end;
							end else begin
								Dec(position);
								OopReadWord(statId, position);
								if OopSend(statId, OopWord, false) then lineFinished := false;
							end;
						end else if OopWord = 'BECOME' then begin
							if OopParseTile(statId, position, argTile) then begin
								replaceStat := true;
								if (argTile.SetFG = true) or (argTile.SetBG = true) then
									replaceForce := true;
								replaceTile.Element := argTile.Element;
								replaceTile.Color := argTile.Color;
							end else begin
								OopError(statId,position, 'Bad #BECOME');
							end;
						end else if OopWord = 'STEP' then begin
							OopReadDirection(statId, position, ix, iy);
							textLine := OopNextWord(statId, position);
							OopReadDirection(statId, position, deltaX, deltaY);
							SwapRelative(deltaX,deltaY,ix,iy,textLine);
							bindStatId := GetStatIdAt(X + ix, Y + iy);
							if (bindStatId > -1) then begin
								Board.Stats[bindStatId].StepX := deltaX;
								Board.Stats[bindStatId].StepY := deltaY;
							end;
						end else if OopWord = 'DUPLICATE' then begin
							OopReadDirection(statId, position, ix, iy);
							textLine := OopNextWord(statId, position);
							OopReadDirection(statId, position, deltaX, deltaY);
							if ElementDuplicate(ix, iy, deltaX, deltaY, statId) then
								BoardDrawTile(X + deltaX, Y + deltaY);
						end else if OopWord = 'SHOVE' then begin
							OopReadDirection(statId, position, ix, iy);
							textLine := OopNextWord(statId, position);
							OopReadDirection(statId, position, deltaX, deltaY);
							SwapRelative(deltaX,deltaY,ix,iy,textLine);
							Inc(ix,X);
							Inc(iy,Y);
							argTile.Element := Board.Tiles[ix][iy].Element;
							if (((deltaX <> 0) or (deltaY <> 0)) and (argTile.Element <> E_EMPTY))
								and (((ix + deltaX > 0) and (ix + deltaX <= BOARD_WIDTH))
								and ((iy + deltaY > 0) and (iy + deltaY <= BOARD_HEIGHT)))
							then begin
								ElementPushablePush(ix, iy, deltaX, deltaY);
								if (argTile.Element = Board.Tiles[ix][iy].Element)
									and (Board.Tiles[ix + deltaX][iy + deltaY].Element <> E_PLAYER)
								then begin
									ElementPushablePush(ix + deltaX, iy + deltaY, deltaX, deltaY);
									bindStatId := GetStatIdAt(ix,iy);
									if (bindStatId > -1) then begin
										if GetStatIdAt(ix + deltaX, iy + deltaY) < 0 then
											MoveStat(bindStatId, ix + deltaX, iy + deltaY);
									end else begin
										Board.Tiles[ix + deltaX][iy + deltaY] := Board.Tiles[ix][iy];
										Board.Tiles[ix][iy].Element := E_EMPTY;
									end;
									BoardDrawTile(ix, iy);
									BoardDrawTile(ix + deltaX, iy + deltaY);
								end;
							end;
						end else if OopWord = 'PUT' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							if (deltaX = 0) and (deltaY = 0) then
								OopError(statId,position, 'Bad #PUT')
							else if not OopParseTile(statId, position, argTile) then
								OopError(statId,position, 'Bad #PUT')
							else if ((X + deltaX) > 0)
								and ((X + deltaX) <= BOARD_WIDTH)
								and ((Y + deltaY) > 0)
								and ((Y + deltaY) <= BOARD_HEIGHT) then
							begin
								if not ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then
									ElementPushablePush(X + deltaX, Y + deltaY, deltaX, deltaY);
								replaceTile.Element := argTile.Element;
								replaceTile.Color := argTile.Color;
								if (argTile.setFG = true) or (argTile.setBG = true) then
									OopForceTile(X + deltaX, Y + deltaY, replaceTile)
								else
									OopPlaceTile(X + deltaX, Y + deltaY, replaceTile);
							end;
						end else if OopWord = 'COLOR' then begin
							OopReadDirection(statId, position, deltaX, deltaY);
							OopReadValue(statId, position);
							ix := OopValue;
							OopReadValue(statId, position);
							iy := OopValue;
							if ( iy < 1 ) or ( iy > 15 ) then
								iy := 0;
							if ((ix + (iy * 16)) > -1) and ((ix + (iy * 16)) < 256) then begin
								Board.Tiles[X + deltaX][Y + deltaY].Color := AsColor(ix, iy);
								BoardDrawTile(X + deltaX, Y + deltaY);
							end else
								OopError(statId,position, 'Unknown color.');
						end else if OopWord = 'CHANGE' then begin
							if not OopParseTile(statId, position, argTile) then
								OopError(statId,position, 'Bad #CHANGE to ' + OopWord)
							else begin
								textLine := OopWord;
								if not OopParseTile(statId, position, argTile2) then
									OopError(statId,position, 'Bad #CHANGE from ' + textLine + ' to ' + OopWord)
								else begin

									ix := 0;
									iy := 1;
									if (argTile2.Color = 0) and (argtile2.SetFG = false) then
										argTile2.Color := ElementDefs[argTile2.Element].Color;
									replaceTile.Element := argTile2.Element;
									replaceTile.Color := argTile2.Color;

									while FindTileOnBoard(ix, iy, argTile) do begin
										if ElementDefs[argTile.Element].Cycle < 0 then
											Board.Tiles[ix][iy].Element := E_EMPTY;
										if (argTile2.SetFG = true) or (argTile2.SetBG = true) then
											OopForceTile(ix, iy, replaceTile)
										else
											OopPlaceTile(ix, iy, replaceTile);
									end;
								end;
							end;
						end else if OopWord = 'PLAY' then begin
							OopReadChar(statId, position);
							if OopChar = #13 then
								SoundClearQueue;
							Dec(position);
							textLine := SoundParse(OopReadLineToEnd(statId, position));
							if Length(textLine) <> 0 then
								SoundQueue(-1, textLine);
							lineFinished := false;
						end else if OopWord = 'BGPLAY' then begin
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
									OopError(statId,position, 'Bad command ' + textLine);
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
				
			until endOfProgram or stopRunning or repeatInsNextTick or replaceStat or (insCount > ParamList[10]);

			if OopWord = 'SAVEDGAMES' then goto StopExecution;

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

			if replaceStat and (name <> '%%Function') then begin
				ix := X;
				iy := Y;
				DamageStat(statId);
				if replaceForce then
					OopForceTile(ix, iy, replaceTile)
				else
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
