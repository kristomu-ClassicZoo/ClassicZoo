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
unit Game;

interface
	uses GameVars, TxtWind;
	const
		PROMPT_NUMERIC = 0;
		PROMPT_ALPHANUM = 1;
		PROMPT_ANY = 2;
	function ColorNumber(s: string; statId: integer): integer;
	procedure SidebarClearLine(y: integer);
	procedure SidebarClear;
	procedure GenerateTransitionTable;
	function EnsureIoTmpBufSize(newSize: word): integer;
	procedure AdvancePointer(var address: pointer; count: integer);
	procedure BoardClose;
	procedure BoardOpen(boardId: integer);
	procedure BoardChange(boardId: integer);
	procedure BoardCreate;
	procedure WorldCreate;
	procedure TransitionDrawToFill(chr: char; color: integer);
	procedure BoardDrawTile(x, y: integer);
	procedure BoardDrawRow(row: integer);
	procedure BoardDrawBorder;
	procedure TransitionDrawToBoard;
	procedure SidebarPromptSlider(editable: boolean; x, y: integer; prompt: string; var value: byte);
	procedure PromptString(x, y, arrowColor, color, width: integer; mode: byte; var buffer: TString50);
	function SidebarPromptYesNo(message: string; defaultReturn: boolean): boolean;
	procedure SidebarPromptString(prompt: string; extension: TString50; var filename: string; promptMode: byte);
	procedure PauseOnError;
	procedure WorldUnload;
	function DisplayIOError(filename: TString50): boolean;
	function WorldLoad(filename, extension: TString50): boolean;
	procedure WorldSave(filename, extension: TString50);
	procedure GameWorldSave(prompt: TString50; var filename: TString50; extension: TString50);
	function GameWorldLoad(extension: TString50): boolean;
	procedure AddStat(tx, ty: integer; txelement, txcolor: byte; tcycle: integer; template: TStat);
	function FileLoadStatData(s: TString8; statId: integer): boolean;
	procedure FreeStatDataMem(statId: integer);
	procedure RemoveStat(statId: integer);
	function GetStatIdAt(x, y: integer): integer;
	function BoardPrepareTileForPlacement(x, y: integer): boolean;
	procedure MoveStat(statId: integer; newX, newY: integer);
	procedure PopupPromptString(question: string; var buffer: TString50);
	function Signum(val: integer): integer;
	function Difference(a, b: integer): integer;
	procedure DamageStat(attackerStatId: integer);
	procedure BoardDamageTile(x, y: integer);
	procedure BoardAttack(attackerStatId: integer; x, y: integer);
	procedure OopPlaceTile(x, y: integer; var tile: TTile);
	procedure OopForceTile(x, y: integer; tile: TTile);
	function BoardShoot(txelement: byte; tx, ty, deltaX, deltaY: integer; source: integer): boolean;
	procedure CalcDirectionRnd(var deltaX, deltaY: integer);
	procedure CalcDirectionSeek(x, y: integer; var deltaX, deltaY: integer);
	procedure CalcDirectionToward(x, y: integer; var deltaX, deltaY: integer);
	procedure TransitionDrawBoardChange;
	procedure GameUpdateSidebar;
	procedure GameDrawCustomSidebar;
	procedure GamePlayLoop(boardChanged: boolean);
	procedure DisplayMessage(time: integer; message: string);
	procedure BoardEnter;
	procedure BoardPassageTeleport(x, y: integer);
	procedure GameDebugPrompt;
	procedure GameTitleLoop;
	procedure ResetCachedLinePos;
	procedure BlockPalette(c,r,g,b: byte);
	procedure KeyRepeat;

const
	ColorNames: array[0 .. 7] of TString8 =
		('Black', 'Blue', 'Green', 'Cyan', 'Red', 'Purple', 'Yellow', 'White');
	DefaultConfigList: array[1 .. CONFIG_FILE_COUNT] of string[50] = (
		'Bomb activated!', 'tcf+cf+c', 't5', 't8', 't+++c-c-c-c-c-c',
		'Energizer - You are invincible', 's.-cd#e',
		's.-f+f-fd#c+c-d#ef+f-fd#c+c-d#e', 's.-f+f-fd#c+c-d#ef+f-fd#c+c-d#e',
		's.-f+f-fd#c+c-d#e', 's.-c-a#gf#fd#c',
		'You now have the ', ' key.', 't+cegcegceg+sc',
		'You already have a ', ' key!', 'sc-c',
		'The ', ' door is now open.', 'tcgbcgb+ic',
		'The ', ' door is locked!', 't--gc',
		'Ammunition - 5 shots per container.', 'tcc#d',
		'Gems give you Health!', 't+c-gec',
		'Torch - used for lighting in the underground.', 'tcase', 'tc-c-c',
		'You are blocked by an invisible wall.', 't--dc',
		'A path is cleared through the forest.', 'ta',
		'A fake wall - secret passage!',
		'Your way is blocked by water.', 't+c+c',
		' Game over  -  Press ESCAPE', 's.-cd#g+c-ga#+dgfg#+cf---w3c',
		'Can'#39't shoot in this place!', 'You don'#39't have any ammo!',
		't+c-c-c', 'tc-f#',
		'Don'#39't need torch - room is not dark!',
		'You don'#39't have any torches!',
		'Room is dark - you need to light a torch!',
		't+c---c++++c--c', 'Ouch!', 't--c+c---c+d#',
		'scdefg', 't--g#f#', 't--f', 't9',
		'Running out of time!', 'i.+cfc-f+cfq.c',
		't-c', 'ERR: ', '++w3c', 'i-g',
		'tc-c+d-d+e-e+f-f+g-g', 'tcegc#fg#df#ad#ga#eg#+c', 'tc+d-e+f#-g#+a#c+d',
		' Health:','   Ammo:','Torches:','   Gems:','  Score:','   Keys:',
		'   Time:', 'T', 'Torch', 'B', 'Be quiet', 'Be noisy', 'H', 'Help',
		'S', 'Save game', 'P', 'Pause', 'Pausing...', 'Pick a command:', '?',
		'Interaction','Scroll'
	);
	DefaultParamList: array[1 .. PARAM_FILE_COUNT] of integer = (
		15,1,2,  3,0,132,5,  6,0,157,1,200,  4,1,10,1,  12,  10,  240,  11,6,
		5,0,127,75,  1,  15,0,248,1,  176,  0,2,176,  219,  178,  177,  254,  18,  29,
		178,  32,22,  206,186,205,  10,0,42,  6,0,153,3,1,0,  13,0,5,1,2,0,0,
		42,3,0,  7,0,94,3,0,  2,0,0,  12,0,234,2,1,0,  11,0,227,2,2,0,0,
		233,2,1,0,0,  79,2,3,  0,7,  7,0,  232,  1,10,  0,  7,0,176,
		32,  0,0,  8,5,50,  8,5,50,  150,  33,  1,  0,  1,  100,1,0,
		15,1,0,0,0,  15,2,0,0,0,  15,3,0,0,0,  15,4,0,0,0, 
		15,5,0,0,0,  15,6,0,0,0,  15,0,0,0,0,
		1,15,14,0,7,3,12,  0,  -1,
		0,0,0, 0,0,42, 0,42,0, 0,42,42,
		42,0,0, 42,0,42, 42,21,0, 42,42,42,
		21,21,21, 21,21,63, 21,63,21, 21,63,63,
		63,21,21, 63,21,63, 63,63,21, 63,63,63
	);
	ColorList: array[0..15] of byte = (
		0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63
	);
	NeighborArrowList: array[0..3] of char = (
		#30, #31, #17, #16
	);

	{}
	DiagonalDeltaX: array[0 .. 7] of integer = (-1, 0, 1, 1, 1, 0, -1, -1);
	DiagonalDeltaY: array[0 .. 7] of integer = (1, 1, 1, 0, -1, -1, -1, 0);
	NeighborDeltaX: array[0 .. 3] of integer = (0, 0, -1, 1);
	NeighborDeltaY: array[0 .. 3] of integer = (-1, 1, 0, 0);
	{}
	TileBorder: TTile = (Element: E_NORMAL; Color: $0E);
	TileBoardEdge: TTile = (Element: E_BOARD_EDGE; Color: $00);
	StatTemplateDefault: TStat = (
		X: 0; Y: 0; StepX: 0; StepY: 0;
		Cycle: 255; P1: 0; P2: 0; P3: 0;
		Follower: -1; Leader: -1
	);
	LineChars: string[16] = #249#208#210#186#181#188#187#185#198#200#201#204#205#202#203#206;

implementation
uses Dos, FileSel, Crt, ExtMem, Video, Sounds, Input, Elements, Oop;

procedure KeyRepeat;
	begin
		RepeatSpeed(World.Info.Keyspeed);
	end;

function ColorNumber(s: string; statId: integer): integer;
	var
		counterPtr: cInt;
		shortPtr: cShort;
	begin
        if (s = 'BLACK') or (s = '0') then ColorNumber := 0
		else if (s = 'DKBLUE') or (s = '1') then ColorNumber := 1
		else if (s = 'DKGREEN') or (s = '2') then ColorNumber := 2
		else if (s = 'DKCYAN') or (s = '3') then ColorNumber := 3
		else if (s = 'DKRED') or (s = '4') then ColorNumber := 4
		else if (s = 'DKPURPLE') or (s = '5') then ColorNumber := 5
		else if (s = 'BROWN') or (s = '6') then ColorNumber := 6
		else if (s = 'GRAY') or ((s = 'GREY') or (s = '7')) then ColorNumber := 7
		else if (s = 'DKGRAY') or ((s = 'DKGREY') or (s = '8')) then ColorNumber := 8
		else if (s = 'BLUE') or (s = '9') then ColorNumber := 9
		else if (s = 'GREEN') or (s = '10') then ColorNumber := 10
		else if (s = 'CYAN') or (s = '11') then ColorNumber := 11
		else if (s = 'RED') or (s = '12') then ColorNumber := 12
		else if (s = 'PURPLE') or (s = '13') then ColorNumber := 13
		else if (s = 'YELLOW') or (s = '14') then ColorNumber := 14
		else if (s = 'WHITE') or (s = '15') then ColorNumber := 15
		else ColorNumber := -128;

		if statId <> -1 then begin
			if ShortWord(s) then begin
				OopGetShort(s, shortPtr);
				if (shortPtr^ >= 0) and (shortPtr^ <= 15) then
					ColorNumber := shortPtr^;
			end else if OopGetCounter(statId, s, counterPtr) then begin
				if (counterPtr^ >= 0) and (counterPtr^ <= 15) then
					ColorNumber := counterPtr^;
			end;
		end;
	end;
	
procedure CustomFlagsLoad;
	var
		f: text;
		i: integer;
		s: TString20;
	begin
		if World.Info.Name <> '' then
			s := World.Info.Name
		else
			s := 'TEMPLATE';
		Assign(f, s + '.FLG');
		Reset(f);
		if IOResult = 0 then begin
			i := 1;
			while i <= (CUSTOM_FLAG_COUNT + 5) do begin
				ReadLn(f, s);
				if s <> '' then begin
					if s[1] = '#' then
						Dec(i)
					else
						CustomFlagList[i] := UpCaseString(s);
				end else begin
					Str(i,s);
					CustomFlagList[i] := 'FLAG' + s;
				end;
				Inc(i);
			end;
		end else
			for i := 1 to (CUSTOM_FLAG_COUNT + 5) do begin
				Str(i,s);
				CustomFlagList[i] := 'FLAG' + s;
			end;
		Close(f);
		if IOResult <> 0 then begin end;
	end;

procedure BlockPalette(c,r,g,b: byte);
	var
		arr: array[0..2] of byte;
		regs: Registers;
	begin
		arr[0] := r;
		arr[1] := g;
		arr[2] := b;
		regs.ax := $1012;
		regs.bx := ColorList[c];
		regs.cx := 1;
		regs.es := Seg(arr);        (* segment of table *)
		regs.dx := Ofs(arr);        (* offset of the table *)
		intr($10, regs);
	end;

procedure InitPalette;
	var
		doInit: boolean;
		c,r,g,b: byte;
	begin
		doInit := true;
		for c := 0 to 47 do
			if World.Info.CustomPalette[c] <> 0 then
				doInit := false;
		if doInit then
			for c := 0 to 15 do begin
				r := ParamList[PALETTE_START + (c * 3)];
				g := ParamList[PALETTE_START + (c * 3) + 1];
				b := ParamList[PALETTE_START + (c * 3) + 2];
				World.Info.CustomPalette[(c * 3)] := r;
				World.Info.CustomPalette[(c * 3) + 1] := g;
				World.Info.CustomPalette[(c * 3) + 2] := b;
				BlockPalette(c,r,g,b);
			end;
	end;

procedure ParamsLoad;
	var
		f: text;
		i: integer;
		s: TString8;
		code: integer;
	begin
		if World.Info.Name <> '' then
			s := World.Info.Name
		else
			s := 'TEMPLATE';
		Assign(f, s + '.PAR');
		Reset(f);
		if IOResult = 0 then begin
			i := 1;
			while i <= PARAM_FILE_COUNT do begin
				ReadLn(f, s);
				if s <> '' then begin
					if s[1] <> '#' then begin
						ParamList[i] := ColorNumber(UpCaseString(s), -1);
						if (ParamList[i] = -128) then
							Val(s, ParamList[i], code);
					end else
						Dec(i);
				end else
					ParamList[i] := DefaultParamList[i];
				Inc(i);
			end;
		end else
			for i := 1 to PARAM_FILE_COUNT do
				ParamList[i] := DefaultParamList[i];
		Close(f);
		if IOResult <> 0 then begin end;
		if ParamList[THEME_START + 7] = 0 then
			SetBlink(true)
		else
			SetBlink(false);
		if (ParamList[THEME_START + 8] <> -1) and (World.Info.IsSave = false) then
			World.Info.CurrentBoard := ParamList[THEME_START + 8];
	end;

procedure ConfigStringsLoad;
	var
		f: text;
		i: integer;
	begin
		Assign(f, World.Info.Name + '.CFG');
		Reset(f);
		if IOResult = 0 then begin
			i := 1;
			while i <= CONFIG_FILE_COUNT do begin
				ReadLn(f, ConfigList[i]);
				if ConfigList[i] = '' then begin
					ConfigList[i] := #1;
					ConfigList[i] := '';
				end else if ConfigList[i][1] = '#' then
					Dec(i);
				Inc(i);
			end;
		end else
			for i := 1 to CONFIG_FILE_COUNT do
				ConfigList[i] := DefaultConfigList[i];
		Close(f);
		if IOResult <> 0 then begin end;
	end;

procedure CustomOOPLoad;
	var
		f: text;
		i: integer;
		s: TString8;
	begin
		if World.Info.Name <> '' then
			s := World.Info.Name
		else
			s := 'TEMPLATE';
		Assign(f, s + '.OOP');
		Reset(f);
		if IOResult = 0 then begin
			i := 1;
			while i <= CUSTOM_OOP_COUNT do begin
				ReadLn(f, OOPList[i]);
				if OOPList[i] = '' then 
					OOPList[i] := '_nil'
				else if OOPList[i][1] = '#' then
					Dec(i);
				Inc(i);
			end;
		end else
			for i := 1 to CUSTOM_OOP_COUNT do
				OOPList[i] := '_nil';
		Close(f);
		if IOResult <> 0 then begin end;
	end;

procedure CustomKeyLoad;
	var
		f: text;
		i, j: integer;
		s: TString8;
	begin
		if World.Info.Name <> '' then
			s := World.Info.Name
		else
			s := 'TEMPLATE';
		Assign(f, s + '.KB');
		Reset(f);
		KeyLimit := CUSTOM_KEY_COUNT div 3;
		if IOResult = 0 then begin
			InputTerminal := '#';
			while InputTerminal[1] = '#' do begin
				ReadLn(f, InputTerminal);
				if (InputTerminal = '') then
					InputTerminal := '_nil';
			end;
			i := 0;
			j := 0;
			while (i < (KeyLimit * 3)) do begin
				ReadLn(f, KeyList[i]);
				if (KeyList[i] <> '') and (KeyList[i][1] = '#') then
					Dec(i)
				else if j > 0 then begin
					Dec(j);
					Dec(i);
				end else if ((KeyList[i] = '') and ((i mod 3) = 0)) then begin
					Dec(i);
					j := 2;
					Dec(KeyLimit);
				end;
				Inc(i);
			end;
		end else begin
			InputTerminal := '_nil';
			KeyLimit := 0;
		end;
		Close(f);
		if IOResult <> 0 then begin end;
	end;

procedure HighScoresLoad;
	var
		f: file of THighScoreList;
		i: integer;
	begin
		Assign(f, World.Info.Name + '.HI');
		Reset(f);
		if IOResult = 0 then begin
			Read(f, HighScoreList);
		end;
		Close(f);
		if IOResult <> 0 then begin
			for i := 1 to HIGH_SCORE_COUNT do begin
				HighScoreList[i].Name := '';
				HighScoreList[i].Score := -1;
			end;
		end;
	end;

procedure HighScoresSave;
	var
		f: file of THighScoreList;
	begin
		Assign(f, World.Info.Name + '.HI');
		Rewrite(f);
		Write(f, HighScoreList);
		Close(f);
		if DisplayIOError(World.Info.Name + '.HI') then begin
		end else begin
		end;
	end;

{$F+}

procedure HighScoresInitTextWindow(var state: TTextWindowState);
	var
		i: integer;
		scoreStr: string;
	begin
		TextWindowInitState(state);
		TextWindowAppend(state, 'Score  Name');
		TextWindowAppend(state, '-----  ----------------------------------');
		for i := 1 to HIGH_SCORE_COUNT do begin
			if Length(HighScoreList[i].Name) <> 0 then begin
				Str(HighScoreList[i].Score:5, scoreStr);
				TextWindowAppend(state, scoreStr + '  ' + HighScoreList[i].Name);
			end;
		end;
	end;

procedure HighScoresDisplay(linePos: integer);
	var
		state: TTextWindowState;
	begin
		state.LinePos := linePos;
		HighScoresInitTextWindow(state);
		if (state.LineCount > 2) then begin
			state.Title := 'High scores for ' + World.Info.Name;
			TextWindowDrawOpen(state);
			TextWindowSelect(state, TWS_VIEWING_FILE);
			TextWindowDrawClose(state);
		end;
		TextWindowFree(state);
	end;

procedure HighScoresAdd(score: integer);
	var
		textWindow: TTextWindowState;
		name: TString50;
		i, listPos: integer;
	begin
		listPos := 1;
		while (listPos <= HIGH_SCORE_COUNT) and (score < HighScoreList[listPos].Score) do
			listPos := listPos + 1;
		if (listPos <= HIGH_SCORE_COUNT) and (score > 0) then begin
			for i := (HIGH_SCORE_COUNT - 1) downto listPos do
				HighScoreList[i + 1] := HighScoreList[i];
			HighScoreList[listPos].Score := score;
			HighScoreList[listPos].Name := '-- You! --';

			HighScoresInitTextWindow(textWindow);
			textWindow.LinePos := listPos;
			textWindow.Title := 'New high score for ' + World.Info.Name;
			TextWindowDrawOpen(textWindow);
			TextWindowDraw(textWindow, false, false);

			name := '';
			PopupPromptString('Congratulations!  Enter your name:', name);
			HighScoreList[listPos].Name := name;
			HighScoresSave;

			TextWindowDrawClose(textWindow);
			TransitionDrawToBoard;
			TextWindowFree(textWindow);
		end;
	end;

procedure SidebarClearLine(y: integer);
	begin
		VideoWriteText(60, y, AsColor(ParamList[THEME_START],ParamList[THEME_START]), #179'                   ');
	end;

procedure SidebarClear;
	var
		i: integer;
	begin
		for i := 3 to 24 do
			SidebarClearLine(i);
	end;

procedure GenerateTransitionTable;
	var
		ix, iy: integer;
		t: TCoord;
	begin
		TransitionTableSize := 0;
		for iy := 1 to BOARD_HEIGHT do
			for ix := 1 to BOARD_WIDTH do begin
				TransitionTableSize := TransitionTableSize + 1;
				TransitionTable[TransitionTableSize].X := ix;
				TransitionTable[TransitionTableSize].Y := iy;
			end;

		{ shuffle }
		for ix := 1 to TransitionTableSize do begin
			iy := Random(TransitionTableSize) + 1;
			t := TransitionTable[iy];
			TransitionTable[iy] := TransitionTable[ix];
			TransitionTable[ix] := t;
		end;
	end;

function EnsureIoTmpBufSize(newSize: word): integer;
	var
		oldSize: word;
	begin
		if newSize > IO_BUFFER_MAXIMUM_SIZE then begin
			EnsureIoTmpBufSize := 2;
			exit;
		end;
		oldSize := IoTmpBufSize;
		EnsureIoTmpBufSize := 0;
		while IoTmpBufSize < newSize do
			Inc(IoTmpBufSize, IO_BUFFER_SIZE_INCREMENT);
		if oldSize <> IoTmpBufSize then begin
			FreeMem(IoTmpBuf, oldSize);
			GetMem(IoTmpBuf, IoTmpBufSize);
			EnsureIoTmpBufSize := 1;
		end;
	end;

procedure AdvancePointer(var address: pointer; count: integer);
	begin
		address := Ptr(Seg(address^), Ofs(address^) + count);
	end;

procedure BoardClose;
	var
		ix, iy: integer;
		ptr: pointer;
		rle: TRleTile;
	label RestartWrite;
	begin
		{ Bind stats early. }
		for ix := 0 to Board.StatCount do begin
			with Board.Stats[ix] do begin
				if DataLen > 0 then begin
					for iy := 1 to (ix - 1) do begin
						if Board.Stats[iy].Data = Data then
							DataLen := -iy;
					end;
				end;
			end;
		end;

	RestartWrite:
		ptr := IoTmpBuf;

		Move(Board.Name, ptr^, SizeOf(Board.Name));
		AdvancePointer(ptr, SizeOf(Board.Name));

		ix := 1;
		iy := 1;
		rle.Count := 1;
		rle.Tile := Board.Tiles[ix][iy];
		repeat
			Inc(ix);
			if ix > BOARD_WIDTH then begin
				ix := 1;
				Inc(iy);
			end;
			if (Board.Tiles[ix][iy].Color = rle.Tile.Color) and
				(Board.Tiles[ix][iy].Element = rle.Tile.Element) and
				(rle.Count < 255) and (iy <= BOARD_HEIGHT) then
			begin
				Inc(rle.Count);
			end else begin
				Move(rle, ptr^, SizeOf(rle));
				AdvancePointer(ptr, SizeOf(rle));
				rle.Tile := Board.Tiles[ix][iy];
				rle.Count := 1;
			end;
		until iy > BOARD_HEIGHT;

		Move(Board.Info, ptr^, SizeOf(Board.Info));
		AdvancePointer(ptr, SizeOf(Board.Info));

		Move(Board.StatCount, ptr^, SizeOf(Board.StatCount));
		AdvancePointer(ptr, SizeOf(Board.StatCount));

		{ We will always have enough size to store the above in the default IoTmpBuf. }
		{ From here, do size estimation. }
		iy := (Ofs(ptr^) - Ofs(IoTmpBuf^)) + ((Board.StatCount + 1) * SizeOf(TStat));

		for ix := 0 to Board.StatCount do begin
			with Board.Stats[ix] do begin
				if DataLen > 0 then
					Inc(iy, DataLen);
			end;
		end;

		case EnsureIoTmpBufSize(iy) of
			0: begin end; { We good. }
			1: goto RestartWrite; { Not so good. }
			2: RunError(203);
		end;

		for ix := 0 to Board.StatCount do begin
			with Board.Stats[ix] do begin
				Move(Board.Stats[ix], ptr^, SizeOf(TStat));
				AdvancePointer(ptr, SizeOf(TStat));
				if DataLen > 0 then begin
					Move(Data^, ptr^, DataLen);
					FreeMem(Data, DataLen);
					AdvancePointer(ptr, DataLen);
				end;
			end;
		end;

		ExtMemFree(World.BoardData[World.Info.CurrentBoard], World.BoardLen[World.Info.CurrentBoard]);
		World.BoardLen[World.Info.CurrentBoard] := Ofs(ptr^) - Ofs(IoTmpBuf^);
		if ExtMemGet(World.BoardData[World.Info.CurrentBoard], World.BoardLen[World.Info.CurrentBoard]) then begin
			ExtMemWrite(World.BoardData[World.Info.CurrentBoard], IoTmpBuf^, World.BoardLen[World.Info.CurrentBoard]);
		end else RunError(203);
	end;

procedure BoardOpen(boardId: integer);
	var
		ptr: pointer;
		ix, iy: integer;
		rle: TRleTile;
	begin
		if boardId > World.BoardCount then
			boardId := World.Info.CurrentBoard;

		case EnsureIoTmpBufSize(World.BoardLen[boardId]) of
			0, 1: begin end;
			2: RunError(203);
		end;

		ExtMemRead(World.BoardData[boardId], IoTmpBuf^, World.BoardLen[boardId]);

		ptr := IoTmpBuf;

		Move(ptr^, Board.Name, SizeOf(Board.Name));
		AdvancePointer(ptr, SizeOf(Board.Name));

		ix := 1;
		iy := 1;
		rle.Count := 0;
		repeat
			if rle.Count <= 0 then begin
				Move(ptr^, rle, SizeOf(rle));
				AdvancePointer(ptr, SizeOf(rle));
			end;
			Board.Tiles[ix][iy] := rle.Tile;
			ix := ix + 1;
			if ix > BOARD_WIDTH then begin
				ix := 1;
				iy := iy + 1;
			end;
			rle.Count := rle.Count - 1;
		until iy > BOARD_HEIGHT;

		Move(ptr^, Board.Info, SizeOf(Board.Info));
		AdvancePointer(ptr, SizeOf(Board.Info));

		Move(ptr^, Board.StatCount, SizeOf(Board.StatCount));
		AdvancePointer(ptr, SizeOf(Board.StatCount));

		for ix := 0 to Board.StatCount do
			with Board.Stats[ix] do begin
				Move(ptr^, Board.Stats[ix], SizeOf(TStat));
				AdvancePointer(ptr, SizeOf(TStat));
				if DataLen > 0 then begin
					if MaxAvail < DataLen then begin
					end;

					GetMem(Data, DataLen);
					Move(ptr^, Data^, DataLen);
					AdvancePointer(ptr, DataLen);
				end;
			end;

		for ix := 0 to Board.StatCount do
			with Board.Stats[ix] do begin
				if DataLen < 0 then begin
					Data := Board.Stats[-DataLen].Data;
					DataLen := Board.Stats[-DataLen].DataLen;
				end;
			end;

		World.Info.CurrentBoard := boardId;
	end;

procedure BoardChange(boardId: integer);
	begin
		with Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y] do begin
			if Element = E_PLAYER then
				Color := ElementDefs[E_PLAYER].Color;
		end;
		BoardClose;
		BoardOpen(boardId);
	end;

procedure BoardCreate;
	var
		ix, iy, i: integer;
	begin
		Board.Name := '';
		Board.Info.Message := '';
		Board.Info.MaxShots := 255;
		Board.Info.IsDark := 0;
		Board.Info.ReenterWhenZapped := false;
		Board.Info.TimeLimitSec := 0;
		Board.Info.BoardTicks := 0;
		for i := 0 to 3 do
			Board.Info.NeighborBoards[i] := 0;

		for ix := 0 to BOARD_WIDTH+1 do begin
			Board.Tiles[ix][0] := TileBoardEdge;
			Board.Tiles[ix][BOARD_HEIGHT+1] := TileBoardEdge;
		end;
		for iy := 0 to BOARD_HEIGHT+1 do begin
			Board.Tiles[0][iy] := TileBoardEdge;
			Board.Tiles[BOARD_WIDTH+1][iy] := TileBoardEdge;
		end;

		for ix := 1 to BOARD_WIDTH do
			for iy := 1 to BOARD_HEIGHT do begin
				Board.Tiles[ix][iy].Element := E_EMPTY;
				Board.Tiles[ix][iy].Color := 0;
			end;

		for ix := 1 to BOARD_WIDTH do begin
			Board.Tiles[ix][1] := TileBorder;
			Board.Tiles[ix][BOARD_HEIGHT] := TileBorder;
		end;
		for iy := 1 to BOARD_HEIGHT do begin
			Board.Tiles[1][iy] := TileBorder;
			Board.Tiles[BOARD_WIDTH][iy] := TileBorder;
		end;

		Board.Tiles[BOARD_WIDTH div 2][BOARD_HEIGHT div 2].Element := E_PLAYER;
		Board.Tiles[BOARD_WIDTH div 2][BOARD_HEIGHT div 2].Color := ElementDefs[E_PLAYER].Color;
		Board.StatCount := 0;
		Board.Stats[0].X := BOARD_WIDTH div 2;
		Board.Stats[0].Y := BOARD_HEIGHT div 2;
		Board.Stats[0].Cycle := 1;
		Board.Stats[0].Under.Element := E_EMPTY;
		Board.Stats[0].Under.Color := 0;
		Board.Stats[0].Data := nil;
		Board.Stats[0].DataLen := 0;
	end;

procedure WorldCreate;
	var
		i: integer;
	begin
		ParamsLoad;
		InitPalette;
		InitElementsGame;
		World.BoardCount := 0;
		World.BoardLen[0] := 0;
		ResetMessageNotShownFlags;
		BoardCreate;
		World.Info.IsSave := false;
		World.Info.CurrentBoard := 0;
		World.Info.Ammo := 0;
		World.Info.Gems := 0;
		World.Info.Health := 100;
		World.Info.EnergizerTicks := 0;
		World.Info.Torches := 0;
		World.Info.TorchTicks := 0;
		World.Info.Score := 0;
		World.Info.BoardTimeSec := 0;
		World.Info.BoardTimeHsec := 0;
		for i := 1 to 7 do
			World.Info.Keys[i] := 0;
		for i := 1 to MAX_FLAG do
			World.Info.Flags[i] := '';
		BoardChange(0);
		Board.Name := 'Title screen';
		LoadedGameFileName := '';
		World.Info.Name := '';
		for i := 1 to CUSTOM_FLAG_COUNT do
			World.Info.CustomFlags[i] := 0;
		ConfigStringsLoad;
		CustomFlagsLoad;
	end;

procedure TransitionDrawToFill(chr: char; color: integer);
	var
		i: integer;
	begin
		for i := 1 to TransitionTableSize do
			VideoWriteText(TransitionTable[i].X - 1, TransitionTable[i].Y - 1, color, chr);
	end;

procedure BoardDrawTile(x, y: integer);
	var
		ch: byte;
	begin
		with Board.Tiles[x][y] do begin
			if (Board.Info.IsDark < 1)
				or (ElementDefs[Board.Tiles[x][y].Element].VisibleInDark)
				or (
					(World.Info.TorchTicks <> 0)
					and ((Sqr(Board.Stats[0].X - x) + Sqr(Board.Stats[0].Y - y) * 2) < ParamList[111]) {Torch Radius}
				) or ForceDarknessOff then
			begin
				if Element = E_EMPTY then
					VideoWriteText(x - 1, y - 1, $0F, ' ')
				else if ElementDefs[Element].HasDrawProc then begin
					ElementDefs[Element].DrawProc(x, y, ch);
					VideoWriteText(x - 1, y - 1, Color, Chr(ch));
				end else if Element < E_TEXT_MIN then
					VideoWriteText(x - 1, y - 1, Color, ElementDefs[Element].Character)
				else
					VideoWriteText(x - 1, y - 1, ElementDefs[Element].Color, Chr(Board.Tiles[x][y].Color));
			end else begin
				{ Darkness }
				VideoWriteText(x - 1, y - 1, AsColor(ParamList[103],ParamList[104]), Chr(ParamList[105])); {Darkness}
			end;
		end;
	end;

procedure BoardDrawRow(row: integer);
	var
		ix: integer;
	begin
		for ix := 1 to BOARD_WIDTH do
			BoardDrawTile(ix, row);
	end;

procedure BoardDrawBorder;
	var
		iy: integer;
	begin
		BoardDrawRow(1);
		BoardDrawRow(BOARD_HEIGHT);

		for iy := 1 to BOARD_HEIGHT do begin
			BoardDrawTile(1, iy);
			BoardDrawTile(BOARD_WIDTH, iy);
		end;
	end;

procedure TransitionDrawToBoard;
	var
		i: integer;
	begin
		BoardDrawBorder;

		for i := 1 to TransitionTableSize do
			with TransitionTable[i] do
				BoardDrawTile(X, Y);
	end;


procedure SidebarPromptSlider(editable: boolean; x, y: integer; prompt: string; var value: byte);
	var
		newValue: integer;
		startChar, endChar: char;
	begin
		if prompt[Length(prompt) - 2] = ';' then begin
			startChar := prompt[Length(prompt) - 1];
			endChar := prompt[Length(prompt)];
			prompt := Copy(prompt, 1, Length(prompt) - 3);
		end else begin
			startChar := '1';
			endChar := '9';
		end;

		SidebarClearLine(y);
		VideoWriteText(x, y, AsColor(ParamList[THEME_START + 2 - Integer(editable)],ParamList[THEME_START]), prompt);
		SidebarClearLine(y + 1);
		SidebarClearLine(y + 2);
		VideoWriteText(x, y + 2, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), startChar + '....:....' + endChar);

		repeat
			if editable then begin
				if InputJoystickMoved then
					Delay(45);
				VideoWriteText(x + value + 1, y + 1, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START] + 8), #31);

				InputUpdate;
				if (InputKeyPressed >= '1') and (InputKeyPressed <= '9') then begin
					value := Ord(InputKeyPressed) - 49;
					SidebarClearLine(y + 1);
				end else begin
					newValue := value + InputDeltaX;
					if (value <> newValue) and (newValue >= 0) and (newValue <= 8) then begin
						value := newValue;
						SidebarClearLine(y + 1);
					end;
				end;
			end;
		until (InputKeyPressed = KEY_ENTER) or (InputKeyPressed = KEY_ESCAPE) or not editable or InputShiftPressed;

		VideoWriteText(x + value + 1, y + 1, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), #31);
	end;

procedure PromptString(x, y, arrowColor, color, width: integer; mode: byte; var buffer: TString50);
	var
		i: integer;
		oldBuffer: string;
		firstKeyPress: boolean;
	begin
		oldBuffer := buffer;
		firstKeyPress := true;

		repeat
			for i := 0 to (width - 1) do begin
				VideoWriteText(x + i, y, color, ' ');
				VideoWriteText(x + i, y - 1, arrowColor, ' ');
			end;
			VideoWriteText(x + width, y - 1, arrowColor, ' ');
			VideoWriteText(x + Length(buffer), y - 1, AsColor(ParamList[THEME_START + 1],arrowColor div $10), #31);
			VideoWriteText(x, y, color, buffer);

			InputReadWaitKey;

			if (Length(buffer) < width) and (InputKeyPressed >= #32) and (InputKeyPressed < #128) then begin
				if firstKeyPress then
					buffer := '';
				case mode of
					PROMPT_NUMERIC: begin
						if (InputKeyPressed in ['0' .. '9']) then begin
							buffer := buffer + InputKeyPressed;
						end;
					end;
					PROMPT_ANY: begin
						buffer := buffer + InputKeyPressed;
					end;
					PROMPT_ALPHANUM: begin
						if (UpCase(InputKeyPressed) in ['A' .. 'Z'])
							or (InputKeyPressed in ['0' .. '9'])
							or (InputKeyPressed = '-') then
						begin
							buffer := buffer + UpCase(InputKeyPressed);
						end;
					end;
				end;
			end else if (InputKeyPressed = KEY_LEFT) or (InputKeyPressed = KEY_BACKSPACE) then begin
				buffer := Copy(buffer, 1, Length(buffer) - 1);
			end;

			firstKeyPress := false;
		until (InputKeyPressed = KEY_ENTER) or (InputKeyPressed = KEY_ESCAPE);
		if InputKeyPressed = KEY_ESCAPE then begin
			buffer := oldBuffer;
		end;
	end;

function SidebarPromptYesNo(message: string; defaultReturn: boolean): boolean;
	begin
		SidebarClearLine(5);
		VideoWriteText(63, 5, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), message);
		VideoWriteText(63 + Length(message), 5, AsColor(ParamList[THEME_START + 2],8 + ParamList[THEME_START]), '_');

		repeat
			InputReadWaitKey;
		until UpCase(InputKeyPressed) in [KEY_ESCAPE, 'N', 'Y'];
		if UpCase(InputKeyPressed) = 'Y' then
			defaultReturn := true
		else
			defaultReturn := false;

		SidebarClearLine(5);
		GameDrawCustomSidebar;
		SidebarPromptYesNo := defaultReturn;
	end;

procedure SidebarPromptString(prompt: string; extension: TString50; var filename: string; promptMode: byte);
	begin
		SidebarClearLine(3);
		SidebarClearLine(4);
		SidebarClearLine(5);
		VideoWriteText(75 - Length(prompt), 3, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), prompt);
		VideoWriteText(63, 5, AsColor(ParamList[THEME_START + 1],0), '        ' + extension);

		PromptString(63, 5, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]),
			AsColor(ParamList[THEME_START + 1],0), 8, promptMode, filename);

		SidebarClearLine(3);
		SidebarClearLine(4);
		SidebarClearLine(5);
		GameDrawCustomSidebar;
	end;

procedure PauseOnError;
	begin
		SoundQueue(1, SoundParse('s004x114x9'));
		Delay(2000);
	end;

function DisplayIOError(filename: TString50): boolean;
	begin
		if IOResult = 0 then
			DisplayIOError := false
		else
			DisplayIOError := true;
	end;

procedure WorldUnload;
	var
		i: integer;
	begin
		BoardClose;
		for i := 0 to World.BoardCount do
			ExtMemFree(World.BoardData[i], World.BoardLen[i]);
	end;

function WorldLoad(filename, extension: TString50): boolean;
	var
		f: file;
		ptr: pointer;
		boardId: integer;
	label OnError;
	begin
		WorldLoad := false;
		if not FileExists(filename + extension) then begin
			exit;
		end;
		SidebarClearLine(4);
		SidebarClearLine(5);
		VideoWriteText(62, 5, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), 'Loading.....');

		Assign(f, filename + extension);
		Reset(f, 1);

		if not DisplayIOError(filename + extension) then begin
			WorldUnload;
			BlockRead(f, IoTmpBuf^, WORLD_FILE_HEADER_SIZE);

			if not DisplayIOError(filename + extension) then begin
				ptr := IoTmpBuf;
				Move(ptr^, World.BoardCount, SizeOf(World.BoardCount));
				AdvancePointer(ptr, SizeOf(World.BoardCount));

				if World.BoardCount < 0 then begin
					if World.BoardCount <> -1 then begin
						VideoWriteText(63, 5, $1E, 'You need a newer');
						VideoWriteText(63, 6, $1E, ' version of ZZT!');
						goto OnError;
					end else begin
						Move(ptr^, World.BoardCount, SizeOf(World.BoardCount));
						AdvancePointer(ptr, SizeOf(World.BoardCount));
					end;
				end;

				if (World.BoardCount > MAX_BOARD) or (World.BoardCount < 0) then begin
					VideoWriteText(62, 5, $1E, 'Too many boards!');
					World.BoardCount := 0;
					exit;
				end;

				Move(ptr^, World.Info, SizeOf(World.Info));
				AdvancePointer(ptr, SizeOf(World.Info));

				for boardId := 0 to World.BoardCount do begin
					BlockRead(f, World.BoardLen[boardId], 2);

					if ExtMemGet(World.BoardData[boardId], World.BoardLen[boardId]) then begin
						case EnsureIoTmpBufSize(World.BoardLen[boardId]) of
							0, 1: begin end;
							2: RunError(203);
						end;

						BlockRead(f, IoTmpBuf^, World.BoardLen[boardId]);
						Move(IoTmpBuf^, BoardNames[boardId], SizeOf(TString50));
						ExtMemWrite(World.BoardData[boardId], IoTmpBuf^, World.BoardLen[boardId]);
					end else RunError(203);
				end;

				ParamsLoad;
				InitPalette;
				InitElementsGame;
				BoardOpen(World.Info.CurrentBoard);
				LoadedGameFileName := filename;
				WorldLoad := true;

				HighScoresLoad;
				ConfigStringsLoad;
				CustomFlagsLoad;
				CustomOOPLoad;
				CustomKeyLoad;

				SidebarClearLine(5);

			end;
		end;
	OnError:
		Close(f);
	end;

procedure WorldSave(filename, extension: TString50);
	var
		f: file;
		i: integer;
		unk1: integer;
		ptr: pointer;
		version: integer;
	label OnError;
	begin
		BoardClose;
		VideoWriteText(63, 5, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), 'Saving...');

		Assign(f, filename + extension);
		Rewrite(f, 1);

		if not DisplayIOError(filename + extension) then begin
			ptr := IoTmpBuf;
			FillChar(IoTmpBuf^, WORLD_FILE_HEADER_SIZE, 0);
			version := -1;
			Move(version, ptr^, SizeOf(version));
			AdvancePointer(ptr, SizeOf(version));

			Move(World.BoardCount, ptr^, SizeOf(World.BoardCount));
			AdvancePointer(ptr, SizeOf(World.BoardCount));

			Move(World.Info, ptr^, SizeOf(World.Info));
			AdvancePointer(ptr, SizeOf(World.Info));

			BlockWrite(f, IoTmpBuf^, WORLD_FILE_HEADER_SIZE);
			if DisplayIOError(filename + extension) then goto OnError;

			for i := 0 to World.BoardCount do begin
				BlockWrite(f, World.BoardLen[i], 2);
				if DisplayIOError(filename + extension) then goto OnError;

				ExtMemRead(World.BoardData[i], IoTmpBuf^, World.BoardLen[i]);
				BlockWrite(f, IoTmpBuf^, World.BoardLen[i]);
				if DisplayIOError(filename + extension) then goto OnError;
			end;
			Close(f);
		end;

		BoardOpen(World.Info.CurrentBoard);
		SidebarClearLine(5);
		GameDrawCustomSidebar;
		exit;

	OnError:
		Close(f);
		Erase(f);
		BoardOpen(World.Info.CurrentBoard);
		SidebarClearLine(5);
		GameDrawCustomSidebar;
	end;

procedure GameWorldSave(prompt: TString50; var filename: TString50; extension: TString50);
	var
		newFilename: TString50;
	begin
		newFilename := filename;
		SidebarPromptString(prompt, extension, newFilename, PROMPT_ALPHANUM);
		if (InputKeyPressed <> KEY_ESCAPE) and (Length(newFilename) <> 0) then begin
			filename := newFilename;
			if extension = '.ZZT' then
				World.Info.Name := filename
			else
				CurrentSave := filename;
			WorldSave(filename, extension);
		end;
	end;

function GameWorldLoad(extension: TString50): boolean;
	var
		entryName: string;
	begin
		{ As directory listings can take up a lot of memory, }
		{ free IoTmpBuf for the duration - the data will be }
		{ unloaded later anyway. - asie }
		FreeMem(IoTmpBuf, IoTmpBufSize);

		GameWorldLoad := false;
		if extension = '.ZZT' then
			entryName := FileSelect('ZZT Worlds', extension, FileWorldCachedLinePos)
		else
			entryName := FileSelect('Saved Games', extension, FileSaveCachedLinePos);

		GetMem(IoTmpBuf, IoTmpBufSize);

		if Length(entryName) > 0 then begin
			if WorldLoad(entryName, extension) then
				GameWorldLoad := true
			else begin
				WorldCreate;
				PauseOnError;
			end;
			TransitionDrawToFill(#219, $44);
		end;
	end;

procedure AddStat(tx, ty: integer; txelement, txcolor: byte; tcycle: integer; template: TStat);
	var
		i: integer;
	begin
		if Board.StatCount < ParamList[115] then begin {Max Stats}
			Inc(Board.StatCount);
			Board.Stats[Board.StatCount] := template;
			with Board.Stats[Board.StatCount] do begin
				X := tx;
				Y := ty;
				Cycle := tcycle;
				if template.Cycle = 255 then begin
					if txelement = E_PASSAGE then
						P3 := ElementDefs[txelement].Param1
					else
						P1 := ElementDefs[txelement].Param1;
					P2 := ElementDefs[txelement].Param2;
				end else begin
					P1 := template.P1;
					P2 := template.P2;
					P3 := template.P3;
					for i := 1 to 4 do
						ObjLocal[i] := template.ObjLocal[i];
				end;
				Under := Board.Tiles[tx][ty];
				DataPos := 0;
			end;

			if (template.Data <> nil) and (template.DataLen > 0) then begin
				GetMem(Board.Stats[Board.StatCount].Data, template.DataLen);
				Move(template.Data^, Board.Stats[Board.StatCount].Data^, template.DataLen);
			end;

			Board.Tiles[tx][ty].Color := txcolor;
			Board.Tiles[tx][ty].Element := txelement;

			if ty > 0 then
				BoardDrawTile(tx, ty);
		end;
	end;

Procedure FreeStatDataMem(statId: integer);
	var
		i: integer;
	begin
		with Board.Stats[statId] do begin
			if DataLen <> 0 then begin
				for i := 1 to Board.StatCount do begin
					if (Board.Stats[i].Data = Data) and (i <> statId) then
						exit;
				end;
				FreeMem(Data, DataLen);
			end;
		end;
	end;

function FileLoadStatData(s: TString8; statId: integer): boolean;
	var
		TmpString: string;
		f: text;
		i, j, k: integer;
		NumRead: word;
		TmpPtr: pointer;
	begin
		FileLoadStatData := true;
		Assign(f, s + '.OBJ');
		Reset(f);
		if IOResult = 0 then begin
			with Board.Stats[statId] do begin
				FreeStatDataMem(statId);
				NumRead := 0;
				k := 0;
				TmpPtr := ObjTmpBuf;

				for i := 1 to 1024 do begin
					ReadLn(f, TmpString);
					if NumRead < (LOAD_OBJ_LENGTH - 255) then begin
						if TmpString <> '' then begin
							k := 0;
							TmpString := TmpString + KEY_ENTER;
							NumRead := NumRead + Length(TmpString);						
							for j := 1 to Length(TmpString) do begin
								Char(TmpPtr^) := TmpString[j];
								AdvancePointer(TmpPtr, 1);
							end;
						end else begin
							Inc(NumRead);
							Inc(k);
							Char(TmpPtr^) := KEY_ENTER;
							AdvancePointer(TmpPtr, 1);
						end;
					end;
				end;

				GetMem(Data, NumRead - k);
				Move(ObjTmpBuf^, Data^, NumRead - k);
				DataLen := NumRead - k;
				DataPos := 0;
			end;
		end else
			FileLoadStatData := false;
		Close(f);
	end;

procedure RemoveStat(statId: integer);
	var
		i: integer;
	begin
		with Board.Stats[statId] do begin
			FreeStatDataMem(statId);

			if statId < CurrentStatTicked then
				CurrentStatTicked := CurrentStatTicked - 1;

			Board.Tiles[X][Y] := Under;
			if Y > 0 then
				BoardDrawTile(X, Y);

			for i := 1 to Board.StatCount do begin
				if (Board.Tiles[Board.Stats[i].X,Board.Stats[i].Y].Element = E_CENTIPEDE_HEAD)
					or (Board.Tiles[Board.Stats[i].X,Board.Stats[i].Y].Element = E_CENTIPEDE_SEGMENT)
					then begin
					if Board.Stats[i].Follower >= statId then begin
						if Board.Stats[i].Follower = statId then
							Board.Stats[i].Follower := -1
						else
							Board.Stats[i].Follower := Board.Stats[i].Follower - 1;
					end;

					if Board.Stats[i].Leader >= statId then begin
						if Board.Stats[i].Leader = statId then
							Board.Stats[i].Leader := -1
						else
							Board.Stats[i].Leader := Board.Stats[i].Leader - 1;
					end;
				end;
			end;

			for i := (statId + 1) to Board.StatCount do
				Board.Stats[i - 1] := Board.Stats[i];
			Board.StatCount := Board.StatCount - 1;
		end;
	end;

function GetStatIdAt(x, y: integer): integer;
	var
		i: integer;
	begin
		i := -1;
		repeat
			i := i + 1;
		until ((Board.Stats[i].X = x) and (Board.Stats[i].Y = y)) or (i > Board.StatCount);

		if i > Board.StatCount then
			GetStatIdAt := -1
		else
			GetStatIdAt := i;
	end;

function BoardPrepareTileForPlacement(x, y: integer): boolean;
	var
		statId: integer;
		result: boolean;
	begin
		statId := GetStatIdAt(x, y);
		if statId > 0 then begin
			RemoveStat(statId);
			result := true;
		end else if statId < 0 then begin
			if not ElementDefs[Board.Tiles[x][y].Element].PlaceableOnTop then
				Board.Tiles[x][y].Element := E_EMPTY;
			result := true;
		end else result := false;
		BoardDrawTile(x, y);
		BoardPrepareTileForPlacement := result;
	end;

procedure MoveStat(statId: integer; newX, newY: integer);
	var
		iUnder: TTile;
		ix, iy: integer;
		oldX, oldY: integer;
		oldBgColor: integer;
	begin
		if statId = 0 then begin
			if (newX < 0) or (newX > (BOARD_WIDTH + 1)) then exit;
			if (newY < 0) or (newY > (BOARD_HEIGHT + 1)) then exit;
		end else begin
			if (newX < 1) or (newX > BOARD_WIDTH) then exit;
			if (newY < 1) or (newY > BOARD_HEIGHT) then exit;
		end;
		with Board.Stats[statId] do begin
			oldBgColor := Board.Tiles[newX][newY].Color and $F0;

			iUnder := Under;
			Under := Board.Tiles[newX][newY];

			with Board.Tiles[X][Y] do begin
				if (Element = E_PLAYER) or ((ElementDefs[Element].Color and $F0) > 0) then
					Board.Tiles[newX][newY].Color := Color
				else if Board.Tiles[newX][newY].Element = E_EMPTY then
					Board.Tiles[newX][newY].Color := Color and $0F
				else
					Board.Tiles[newX][newY].Color := (Color and $0F) + (Board.Tiles[newX][newY].Color and $F0);

				Board.Tiles[newX][newY].Element := Element;
			end;
			Board.Tiles[X][Y] := iUnder;

			oldX := X;
			oldY := Y;
			X := newX;
			Y := newY;

			BoardDrawTile(X, Y);
			BoardDrawTile(oldX, oldY);

			if (statId = 0)
				and (Board.Info.IsDark > 0)
				and (World.Info.TorchTicks <> 0)
			then begin
				if (Sqr(oldX-X) + Sqr(oldY-Y)) = 1 then begin
					for ix := (X - ParamList[109] - 3) to (X + ParamList[109] + 3) do
						if (ix >= 1) and (ix <= BOARD_WIDTH) then
							for iy := (Y - ParamList[110] - 3) to (Y + ParamList[110] + 3) do
								if (iy >= 1) and (iy <= BOARD_HEIGHT) then
									if (((Sqr(ix-oldX))+(Sqr(iy-oldY)*2)) < ParamList[111]) xor
										(((Sqr(ix-newX))+(Sqr(iy-newY)*2)) < ParamList[111]) then {Torch Radius}
										BoardDrawTile(ix, iy);
				end else begin
					DrawPlayerSurroundings(oldX, oldY);
					DrawPlayerSurroundings(X, Y);
				end;
			end;

		end;
	end;

procedure PopupPromptString(question: string; var buffer: TString50);
	var
		x, y: integer;
	begin
		VideoWriteText(3, 18, $4F, TextWindowStrTop);
		VideoWriteText(3, 19, $4F, TextWindowStrText);
		VideoWriteText(3, 20, $4F, TextWindowStrSep);
		VideoWriteText(3, 21, $4F, TextWindowStrText);
		VideoWriteText(3, 22, $4F, TextWindowStrText);
		VideoWriteText(3, 23, $4F, TextWindowStrBottom);
		VideoWriteText(4 + (TextWindowWidth - Length(question)) div 2, 19, $4F, question);
		buffer := '';
		PromptString(10, 22, $4F, $4E, TextWindowWidth - 16, PROMPT_ANY, buffer);
		for y := 18 to 23 do
			for x := 3 to (TextWindowWidth + 3) do
				BoardDrawTile(x + 1, y + 1);
	end;

function Signum(val: integer): integer;
	begin
		if val > 0 then
			Signum := 1
		else if val < 0 then
			Signum := -1
		else
			Signum := 0;
	end;

function Difference(a, b: integer): integer;
	begin
		if (a - b) >= 0 then
			Difference := a - b
		else
			Difference := b - a;
	end;

procedure GameUpdateSidebar;
	var
		keyChar: char;
		numStr: TString8;
		i: integer;
	begin
		if GameStateElement = E_PLAYER then begin
			if ConfigList[69] <> '' then {Time Sidebar}
				if Board.Info.TimeLimitSec > 0 then begin
					VideoWriteText(64, 6, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[69]);
					Str(Board.Info.TimeLimitSec - World.Info.BoardTimeSec, numStr);
					VideoWriteText(72, 6, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + ' ');
				end else SidebarClearLine(6);

			if World.Info.Health < 0 then
				World.Info.Health := 0;

			Str(World.Info.Health, numStr);
			if ConfigList[63] <> '' then {Health Sidebar}
				VideoWriteText(72, 7, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + ' ');		
			Str(World.Info.Ammo, numStr);
			if ConfigList[64] <> '' then {Ammo Sidebar}
				VideoWriteText(72, 8, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + '  ');
			Str(World.Info.Gems, numStr);
			if ConfigList[66] <> '' then {Gems Sidebar}
				VideoWriteText(72, 10, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + ' ');
			Str(World.Info.Score, numStr);
			if ConfigList[67] <> '' then {Score Sidebar}
				VideoWriteText(72, 11, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + ' ');

			if ConfigList[65] <> '' then begin {Torches Sidebar}
				Str(World.Info.Torches, numStr);
				VideoWriteText(72, 9, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + ' ');
				if World.Info.TorchTicks <= 0 then
					VideoWriteText(75, 9, AsColor(ParamList[8],ParamList[THEME_START]), '    ')
				else begin
					for i := 2 to 5 do begin
						if i <= ((World.Info.TorchTicks * 5) div ParamList[12]) then
							VideoWriteText(73 + i, 9, AsColor(ParamList[8],ParamList[THEME_START]), #177)
						else
							VideoWriteText(73 + i, 9, AsColor(ParamList[8],ParamList[THEME_START]), #176);
					end;
				end;
			end;

			if ConfigList[68] <> '' then {Keys Sidebar}
				for i := 1 to 7 do begin
					if Diffkeys then
						keyChar := Chr(139 + i)
					else
						keyChar := Chr(ParamList[17]);
					if World.Info.Keys[i] > 0 then begin
						if World.Info.Keys[i] = 1 then
							VideoWriteText(71 + i, 12, AsColor(8 + i,ParamList[THEME_START]), keyChar)
						else if World.Info.Keys[i] < 10 then
							VideoWriteText(71 + i, 12, AsColor(8 + i,ParamList[THEME_START]), Chr(World.Info.Keys[i] + 48))
						else 
							VideoWriteText(71 + i, 12, AsColor(8 + i,ParamList[THEME_START]), '*')
					end else
						VideoWriteText(71 + i, 12, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ');
				end;

			if ConfigList[72] <> '' then begin {Sound toggle sidebar}
				if SoundEnabled then
					VideoWriteText(65, 15, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[73])
				else
					VideoWriteText(65, 15, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[74]);
			end;

			if DebugEnabled then begin
				Str(MemAvail, numStr);
				VideoWriteText(62, 0, $1E, 'm' + numStr + ' ');
				if ExtMemEmsActive then begin
					Str(ExtMemEmsAvailPages, numstr);
					VideoWriteText(62, 1, $1E, 'e' + numStr + 'p ');
				end;
				if ExtMemXmsActive then begin
					Str(ExtMemXmsAvail, numStr);
					VideoWriteText(62, 2, $1E, 'x' + numStr + ' ');
				end;
			end;
		end;
	end;

procedure DisplayMessage(time: integer; message: string);
	var
		statId: integer;
	begin
		if Length(message) <> 0 then begin
			if message = '$' then begin
				Board.Stats[0].P3 := 0;
				BoardDrawRow(BOARD_HEIGHT);
			end else begin
				if Length(Board.Info.Message) > Length(message) then
					BoardDrawRow(BOARD_HEIGHT);
				Board.Stats[0].P3 := time div (TickTimeDuration + 1);
				Board.Info.Message := message;
				VideoWriteText((60 - Length(Board.Info.Message)) div 2, 24, 9 + (Board.Stats[0].P3 mod 7), ' '+Board.Info.Message+' ');
			end;
		end;
	end;

procedure DamageStat(attackerStatId: integer);
	var
		oldX, oldY: integer;
	begin
		with Board.Stats[attackerStatId] do begin
			if attackerStatId = 0 then begin
				if World.Info.Health > 0 then begin
					World.Info.Health := World.Info.Health - ParamList[101]; {Damage}

					GameUpdateSidebar;
					DisplayMessage(100, ConfigList[48]); {"Ouch!"}

					if Board.Tiles[X][Y].Element = E_PLAYER then
						Board.Tiles[X][Y].Color := $70 + (ElementDefs[E_PLAYER].Color and $0F);

					if World.Info.Health > 0 then begin
						World.Info.BoardTimeSec := 0;
						if Board.Info.ReenterWhenZapped then begin

							{ Move player to start }
							Board.Tiles[X][Y].Element := E_EMPTY;
							BoardDrawTile(X, Y);
							oldX := X;
							oldY := Y;
							X := Board.Info.StartPlayerX;
							Y := Board.Info.StartPlayerY;
							DrawPlayerSurroundings(oldX, oldY);
							DrawPlayerSurroundings(X, Y);

							GamePaused := true;
						end;
						SoundQueue(4, SoundParse(ConfigList[49])); {Ouch sound}
					end;
				end;
			end else begin
				case Board.Tiles[X][Y].Element of
					E_BULLET: SoundQueue(3, SoundParse(ConfigList[56])); {Breakwall sound}
					E_OBJECT: begin end;
				else
					SoundQueue(3, SoundParse(ConfigList[47])) {Enemy die sound}
				end;
				RemoveStat(attackerStatId);
			end;
		end;
	end;

procedure BoardDamageTile(x, y: integer);
	var
		statId: integer;
	begin
		statId := GetStatIdAt(x, y);
		if statId <> -1 then begin
			DamageStat(statId);
		end else if (ElementDefs[Board.Tiles[x][y].Element].PlaceableOnTop = false) then begin
			Board.Tiles[x][y].Element := E_EMPTY;
			BoardDrawTile(x, y);
		end;
	end;

procedure BoardAttack(attackerStatId: integer; x, y: integer);
	begin
		if (attackerStatId = 0) and (World.Info.EnergizerTicks > 0) then begin
			World.Info.Score := ElementDefs[Board.Tiles[x][y].Element].ScoreValue + World.Info.Score;
			GameUpdateSidebar;
		end else begin
			DamageStat(attackerStatId);
		end;

		if (attackerStatId > 0) and (attackerStatId <= CurrentStatTicked) then
			CurrentStatTicked := CurrentStatTicked - 1;

		if (Board.Tiles[x][y].Element = E_PLAYER) and (World.Info.EnergizerTicks > 0) then begin
			World.Info.Score := ElementDefs[Board.Tiles[Board.Stats[attackerStatId].X][Board.Stats[attackerStatId].Y].Element]
				.ScoreValue + World.Info.Score;
			GameUpdateSidebar;
		end else begin
			BoardDamageTile(x, y);
		end;
	end;

function TileSetColor(toptile, bottomtile: TTile): byte;
	var
		fg, bg: byte;
	begin
		if toptile.Color and $F0 > 0 then
			bg := toptile.Color div 16
		else if ElementDefs[toptile.Element].Color and $F0 > 0 then
			bg := ElementDefs[toptile.Element].Color div 16
		else if ((toptile.Element = E_PASSAGE) or (toptile.Element = E_DOOR)) then
			if toptile.Color and $0F <> 0 then
				bg := toptile.Color and $07
			else
				bg := (bottomtile.Color div 16) and $07
		else bg := bottomtile.Color div 16;

		if toptile.Color > 0 then
			fg := toptile.Color and $0F
		else if ElementDefs[toptile.Element].Color > 0 then
			fg := ElementDefs[toptile.Element].Color and $0F
		else fg := bottomtile.Color and $0F;

		if fg + bg = 0 then
			fg := 15;
		TileSetColor := AsColor(fg,bg);
	end;

procedure OopForceTile(x, y: integer; tile: TTile);
	begin
		with Board.Tiles[x][y] do begin
			if (Element <> E_PLAYER) then begin
				if Element = tile.Element then
					Color := tile.Color
				else begin
					BoardDamageTile(x, y);
					if ElementDefs[tile.Element].Cycle >= 0 then
						AddStat(x, y, tile.Element, tile.Color,
							ElementDefs[tile.Element].Cycle, StatTemplateDefault)
					else begin
						Element := tile.Element;
						Color := tile.Color;
					end;
				end;
				BoardDrawTile(x, y);					
			end;
		end;
	end;

procedure OopPlaceTile(x, y: integer; var tile: TTile);
	var
		txcolor: byte;
	begin
		with Board.Tiles[x][y] do begin
			if Element <> E_PLAYER then begin
				txcolor := TileSetColor(tile, Board.Tiles[x][y]);
				if Element = tile.Element then
					Color := txcolor
				else begin
					BoardDamageTile(x, y);
					if ElementDefs[tile.Element].Cycle >= 0 then
						AddStat(x, y, tile.Element, txcolor,
							ElementDefs[tile.Element].Cycle, StatTemplateDefault)
					else begin
						Element := tile.Element;
						Color := txcolor;
					end;
				end;
				BoardDrawTile(x, y);
			end;
		end;
	end;

function BoardShoot(txelement: byte; tx, ty, deltaX, deltaY: integer; source: integer): boolean;
	var
		tile: TTile;
	begin
		with Board.Tiles[tx + deltaX][ty + deltaY] do begin
			if ElementDefs[Element].PlaceableOnTop then begin
				tile.Element := txelement;
				tile.Color := ElementDefs[txelement].Color;
				OopPlaceTile(tx + deltaX, ty + deltaY, tile);
				with Board.Stats[Board.StatCount] do begin
					P1 := source;
					StepX := deltaX;
					StepY := deltaY;
					P2 := ParamList[120]; {Projectile Health}
				end;
				BoardShoot := true;
			end else if (
					(Element = E_BREAKABLE)
					or ((Element >= E_TEXT_MIN)
					and (ElementDefs[Element].Destructible))
				) or (
					ElementDefs[Element].Destructible
					and ((Element = E_PLAYER) = Boolean(source))
					and (World.Info.EnergizerTicks <= 0)
				) then
			begin
				BoardDamageTile(tx + deltaX, ty + deltaY);
				BoardShoot := true;
			end else begin
				BoardShoot := false;
			end;
		end;
	end;

procedure CalcDirectionRnd(var deltaX, deltaY: integer);
	begin
		deltaX := Random(3) - 1;

		if deltaX = 0 then
			deltaY := Random(2) * 2 - 1
		else
			deltaY := 0;
	end;

procedure CalcDirectionToward(x, y: integer; var deltaX, deltaY: integer);
	var
		ix, iy: integer;
	begin
		ix := deltaX;
		iy := deltaY;
		deltaX := 0;
		deltaY := 0;
		if (Random(2) < 1) or (iy = y) then
			deltaX := Signum(ix - x);

		if deltaX = 0 then
			deltaY := Signum(iy - y);

	end;

procedure CalcDirectionSeek(x, y: integer; var deltaX, deltaY: integer);
	begin
		deltaX := 0;
		deltaY := 0;

		if (Random(2) < 1) or (Board.Stats[0].Y = y) then
			deltaX := Signum(Board.Stats[0].X - x);

		if deltaX = 0 then
			deltaY := Signum(Board.Stats[0].Y - y);

		if World.Info.EnergizerTicks > 0 then begin
			deltaX := -deltaX;
			deltaY := -deltaY;
		end;
	end;

procedure TransitionDrawBoardChange;
	begin
		TransitionDrawToFill(#219, $05);
		TransitionDrawToBoard;
	end;

procedure BoardEnter;
	begin
		Board.Info.StartPlayerX := Board.Stats[0].X;
		Board.Info.StartPlayerY := Board.Stats[0].Y;

		if (Board.Info.IsDark > 0) and MessageHintTorchNotShown then begin
			DisplayMessage(200, ConfigList[46]); {"Board is dark - you need to light a torch!"}
			MessageHintTorchNotShown := false;
		end;

		World.Info.BoardTimeSec := 0;
		GameUpdateSidebar;
	end;

procedure BoardPassageTeleport(x, y: integer);
	var
		oldBoard: integer;
		col: byte;
		ix, iy: integer;
		newX, newY: integer;
	begin
		col := Board.Tiles[x][y].Color;

		oldBoard := World.Info.CurrentBoard;
		BoardChange(Board.Stats[GetStatIdAt(x, y)].P3);

		newX := 0;
		for ix := 1 to BOARD_WIDTH do
			for iy := 1 to BOARD_HEIGHT do
				if (Board.Tiles[ix][iy].Element = E_PASSAGE) and (Board.Tiles[ix][iy].Color = col) then begin
					newX := ix;
					newY := iy;
				end;

		with Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y] do begin
			if Element = E_PLAYER then begin
				Element := Board.Stats[0].Under.Element;
				Color := Board.Stats[0].Under.Color;
			end;
		end;
		if newX <> 0 then begin
			Board.Stats[0].X := newX;
			Board.Stats[0].Y := newY;
		end;

		GamePaused := true;
		SoundQueue(4, SoundParse(ConfigList[61])); {Passage Sound}
		TransitionDrawBoardChange;
		BoardEnter;
	end;

procedure GameDebugPrompt;
	var
		input: TString50;
		i: integer;
		toggle: boolean;
		textWindow: TTextWindowState;
		s: string;
	begin
		input := '';
		SidebarClearLine(4);
		SidebarClearLine(5);

		PromptString(63, 5, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]),
			AsColor(ParamList[THEME_START + 1],0), 11, PROMPT_ANY, input);
		for i := 1 to Length(input) do
			input[i] := UpCase(input[i]);

		toggle := true;
		if (input[1] = '+') or (input[1] = '-') then begin
			if input[1] = '-' then
				toggle := false;
			input := Copy(input, 2, Length(input) - 1);

			if toggle = true then
				WorldSetFlag(input)
			else
				WorldClearFlag(input);
		end;

		DebugEnabled := WorldGetFlagPosition('DEBUG') >= 0;

		if input = 'HEALTH' then
			World.Info.Health := World.Info.Health + 50
		else if input = 'AMMO' then
			World.Info.Ammo := World.Info.Ammo + 5
		else if input = 'KEYS' then
			for i := 1 to 7 do Inc(World.Info.Keys[i])
		else if input = 'TORCHES' then
			World.Info.Torches := World.Info.Torches + 3
		else if input = 'TIME' then
			World.Info.BoardTimeSec := World.Info.BoardTimeSec - 30
		else if input = 'GEMS' then
			World.Info.Gems := World.Info.Gems + 5
		else if (input = 'NODMG') or (input = 'IDDQD') then
			ParamList[101] := 0
		else if input = 'INSPECT' then
			InspectNext := true
		else if input = 'STATS' then
			GetBoardStats
		else if input = 'FREE' then
			Board.Stats[0].P2 := 0
		else if input = 'NOZAP' then
			Board.Info.ReenterWhenZapped := false
		else if (input = 'NOCLIP') or (input = 'CLIP') then begin
			GamePaused := true;
			NoClip := not NoClip;
		end else if input = 'SPEED' then begin
			SidebarPromptSlider(true, 64, 4, 'Game speed:;FS', TickSpeed);
			TickTimeDuration := TickSpeed * 2;
			SidebarClearLine(6);
		end else if input = 'FLAGS' then begin
			TextWindowInitState(textWindow);
			textWindow.Selectable := false;
			textWindow.Title := 'List of Flags';
			TextWindowAppend(textWindow, '$** Flags **');
			for i := 1 to MAX_FLAG do
				if World.Info.Flags[i] <> '' then
					TextWindowAppend(textWindow, World.Info.Flags[i]);
			TextWindowAppend(textWindow, '$** Keys **');
			for i := 1 to 7 do
				if World.Info.Keys[i] > 0 then begin
					if World.Info.Keys[i] > 1 then begin
						Str(World.Info.Keys[i],s);
						TextWindowAppend(textWindow, OOPList[i + 19] + ': ' + s);
					end else
						TextWindowAppend(textWindow, OOPList[i + 19]);
				end;
			TextWindowAppend(textWindow, '$** Custom World Parameters **');
			for i := 1 to CUSTOM_FLAG_COUNT do
				if World.Info.CustomFlags[i] <> 0 then begin
					if World.Info.CustomFlags[i] = 1 then
						TextWindowAppend(textWindow, CustomFlagList[i + 5])
					else begin
						Str(World.Info.CustomFlags[i],s);
						TextWindowAppend(textWindow, CustomFlagList[i + 5] + ': ' + s);
					end;
				end;
			TextWindowDrawOpen(textWindow);
			TextWindowSelect(textWindow, TWS_IGNORE_HYPERLINKS);
			TextWindowDrawClose(textWindow);
			TextWindowFree(textWindow);
		end else if input = 'BOARD' then begin
			TextWindowInitState(textWindow);
			textWindow.Selectable := true;
			textWindow.Title := 'Warp To Board';
			for i := 0 to World.BoardCount do
				TextWindowAppend(textWindow, BoardNames[i]);
			TextWindowAppend(textWindow, 'Cancel');
			TextWindowDrawOpen(textWindow);
			TextWindowSelect(textWindow, TWS_IGNORE_HYPERLINKS);
			TextWindowDrawClose(textWindow);
			if ((textWindow.LinePos <> textWindow.LineCount) 
				and (TextWindowRejected = false))
				and (textWindow.LinePos <> (World.Info.CurrentBoard + 1))
			then begin
				BoardChange(textWindow.LinePos - 1);
				TransitionDrawToBoard;
				BoardEnter;
			end;
			TextWindowFree(textWindow);
		end else if input = 'DARK' then begin
			Board.Info.IsDark := 1 - Board.Info.IsDark;
			TransitionDrawToBoard;
		end else if input = 'ZAP' then begin
			for i := 0 to 3 do begin
				BoardDamageTile(Board.Stats[0].X + NeighborDeltaX[i], Board.Stats[0].Y + NeighborDeltaY[i]);
				Board.Tiles[Board.Stats[0].X + NeighborDeltaX[i]][Board.Stats[0].Y + NeighborDeltaY[i]].Element := E_EMPTY;
				BoardDrawTile(Board.Stats[0].X + NeighborDeltaX[i], Board.Stats[0].Y + NeighborDeltaY[i]);
			end;
		end;

		SoundQueue(10, SoundParse(ConfigList[59])); {Cheat sound}
		SidebarClearLine(4);
		SidebarClearLine(5);
		GameUpdateSidebar;
		GameDrawCustomSidebar;
	end;

procedure GameDrawCustomSidebar;
	var
		i, y, code: integer;
	begin
		i := 0;
		while i < KeyLimit do begin
			Val(KeyList[(i * 3) + 2],y,code);
			if (y > 2) and (y < 25) then begin
				if ((y mod 2) = 1) then
					VideoWriteText(62, y,
						AsColor(ParamList[THEME_START + 3],
						ParamList[THEME_START + 4]),
						' ' + UpCase(KeyList[i * 3][1]) + ' ')
				else
					VideoWriteText(62, y,
						AsColor(ParamList[THEME_START + 3],
						ParamList[THEME_START + 5]),
						' ' + UpCase(KeyList[i * 3][1]) + ' ');
				VideoWriteText(65, y,
					AsColor(ParamList[THEME_START + 1],
					ParamList[THEME_START]), ' '+ KeyList[(i * 3) + 1]);
			end;
			Inc(i);
		end;
	end;

procedure GamePlayLoop(boardChanged: boolean);
	var
		f: file;
		exitLoop: boolean;
		pauseBlink: boolean;
	procedure GameDrawSidebar;
		begin
			SidebarClear;
			SidebarClearLine(0);
			SidebarClearLine(1);
			SidebarClearLine(2);
			VideoWriteText(61, 0, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), '    - - - - -      ');
			VideoWriteText(62, 1, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), '      ZZT      ');
			VideoWriteText(62, 1, AsColor(ParamList[THEME_START + 5],ParamList[THEME_START + 4]), ' Weave');
			VideoWriteText(61, 2, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), '    - - - - -      ');
			if GameStateElement = E_PLAYER then begin
				VideoWriteText(64, 7, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[63]); {Health Sidebar}
				VideoWriteText(64, 8, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[64]); {Ammo Sidebar}
				VideoWriteText(64, 9, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[65]); {Torches Sidebar}
				VideoWriteText(64, 10, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[66]); {Gems Sidebar}
				VideoWriteText(64, 11, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[67]); {Score Sidebar}
				VideoWriteText(64, 12, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[68]); {Keys Sidebar}
				if ConfigList[63] <> '' then  {Sidebar player}
					VideoWriteText(62, 7, ElementDefs[E_PLAYER].Color, ElementDefs[E_PLAYER].Character);
				if ConfigList[64] <> '' then  {Sidebar ammo}
					VideoWriteText(62, 8, AsColor(ParamList[4],ParamList[THEME_START]), ElementDefs[E_AMMO].Character);
				if ConfigList[65] <> '' then  {Sidebar Torch}
					VideoWriteText(62, 9, AsColor(ParamList[8],ParamList[THEME_START]), ElementDefs[E_TORCH].Character);
				if ConfigList[66] <> '' then  {Sidebar Gem}
					VideoWriteText(62, 10, AsColor(ParamList[THEME_START + 6],ParamList[THEME_START]), ElementDefs[E_GEM].Character);
				if ConfigList[68] <> '' then  {Sidebar key}
				VideoWriteText(62, 12, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), Chr(ParamList[17]));
				if ConfigList[70] <> '' then begin  {'T' Torch hotkey}
					VideoWriteText(62, 14, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' ' + ConfigList[70] + ' ');
					VideoWriteText(65, 14, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[71]);
				end;
				if ConfigList[72] <> '' then  {'B' Toggle Sounds hotkey}
					VideoWriteText(62, 15, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' ' + ConfigList[72] + ' ');
				if ConfigList[75] <> '' then begin {'H' Help hotkey}
					VideoWriteText(62, 16, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' ' + ConfigList[75] + ' ');
					VideoWriteText(65, 16, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[76]);
				end;
				VideoWriteText(67, 18, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' '#24#25#26#27' ');
				VideoWriteText(72, 18, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' Move');
				VideoWriteText(61, 19, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' Shift '#24#25#26#27' ');
				VideoWriteText(72, 19, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' Shoot');
				if ConfigList[77] <> '' then begin {'S' Save gave hotkey}
					VideoWriteText(62, 21, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' ' + ConfigList[77] + ' ');
					VideoWriteText(65, 21, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[78]);
				end;
				if NeuromotorAssist then begin
					VideoWriteText(62, 22, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' P ');
					VideoWriteText(65, 22, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' Proceed')
				end else if ConfigList[79] <> '' then begin {'P' Pause game hotkey}
					VideoWriteText(62, 22, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' ' + ConfigList[79] + ' ');
					VideoWriteText(65, 22, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[80]);
				end;
				VideoWriteText(62, 23, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' Q ');
				VideoWriteText(65, 23, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' Quit');
				GameDrawCustomSidebar;
			end else if GameStateElement = E_MONITOR then begin
				SidebarPromptSlider(false, 66, 21, 'Game speed:;FS', TickSpeed);
				VideoWriteText(62, 21, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' S ');
				VideoWriteText(62, 7, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' W ');
				VideoWriteText(65, 7, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ' World:');

				if Length(World.Info.Name) <> 0 then
					VideoWriteText(69, 8, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), World.Info.Name)
				else
					VideoWriteText(69, 8, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), 'Untitled');

				VideoWriteText(62, 11, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' P ');
				VideoWriteText(65, 11, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' Play');
				VideoWriteText(62, 12, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' R ');
				VideoWriteText(65, 12, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ' Restore game');
				VideoWriteText(62, 13, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' Q ');
				VideoWriteText(65, 13, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ' Quit');
				VideoWriteText(62, 16, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' A ');
				VideoWriteText(65, 16, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' License Info');
				VideoWriteText(62, 17, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' H ');
				VideoWriteText(65, 17, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ' High Scores');

			end;
		end;
	begin
		GameDrawSidebar;
		GameUpdateSidebar;

		if JustStarted then begin
			if Length(StartupWorldFileName) <> 0 then begin
				if (FileExists(StartupWorldFileName + '.ZZT')
					and WorldLoad(StartupWorldFileName, '.ZZT'))
					or (FileExists(StartupWorldFileName)
					and WorldLoad(StartupWorldFileName,''))
				then begin
					GameDrawSidebar;
					GameUpdateSidebar;
					VideoWriteText(69, 8, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), World.Info.Name);
				end else begin
					WorldCreate;
				end;
			end;
			if ParamStr(1) = '' then
				GameAboutScreen;
			ReturnBoardId := World.Info.CurrentBoard;
			BoardChange(0);
			JustStarted := false;
		end;

		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := GameStateElement;
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := ElementDefs[GameStateElement].Color;

		if GameStateElement = E_MONITOR then begin
			DisplayMessage(0, '');
			VideoWriteText(62, 5, AsColor(ParamList[THEME_START + 6],ParamList[THEME_START]), ConfigList[82]); {"Pick a command:"}
		end;

		if boardChanged then
			TransitionDrawBoardChange;

		TickTimeDuration := TickSpeed * 2;
		GamePlayExitRequested := false;
		exitLoop := false;

		CurrentTick := Board.Info.BoardTicks;
		CurrentStatTicked := Board.StatCount + 1;

		repeat
			if GamePaused then begin
				if SoundHasTimeElapsed(TickTimeCounter, 25) then
					pauseBlink := not pauseBlink;

				if pauseBlink then begin
					if (World.Info.PlayerColor = 0) and (World.Info.PlayerChar = #0) then
						VideoWriteText(Board.Stats[0].X - 1, Board.Stats[0].Y - 1,
							ElementDefs[E_PLAYER].Color,ElementDefs[E_PLAYER].Character)
					else
						VideoWriteText(Board.Stats[0].X - 1, Board.Stats[0].Y - 1,
							World.Info.PlayerColor, World.Info.PlayerChar);
				end else begin
					if Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element = E_PLAYER then
						VideoWriteText(Board.Stats[0].X - 1, Board.Stats[0].Y - 1, $0F, ' ')
					else
						BoardDrawTile(Board.Stats[0].X, Board.Stats[0].Y);
				end;

				VideoWriteText(64, 5, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ConfigList[81]); {"Pausing..."}
				InputUpdate;


				if InputKeyPressed = KEY_ESCAPE then
					GamePromptEndPlay;

				if UpCase(InputKeyPressed) = UpCase(ConfigList[83][1]) then begin {Cheat hotkey}
					GameDebugPrompt;
					InputKeyPressed := #0;
				end;

				if NoClip then begin
					if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
						with Board.Stats[0] do begin
							if Board.Tiles[X][Y].Element = E_PLAYER then
								Board.Tiles[X][Y] := Under;
							if (X + InputDeltaX > 0) and (X + InputDeltaX <= BOARD_WIDTH) then
								X := X + InputDeltaX;
							if (Y + InputDeltaY > 0) and (Y + InputDeltaY <= BOARD_HEIGHT) then
								Y := Y + InputDeltaY;
							BoardDrawTile(X, Y);
							BoardDrawTile(X - InputDeltaX, Y - InputDeltaY);
						end;
					end;						
				end else begin
					if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
						ElementDefs[Board.Tiles[Board.Stats[0].X + InputDeltaX][Board.Stats[0].Y + InputDeltaY].Element].TouchProc(
							Board.Stats[0].X + InputDeltaX, Board.Stats[0].Y + InputDeltaY, 0, InputDeltaX, InputDeltaY);
					end;

					if ((InputDeltaX <> 0) or (InputDeltaY <> 0))
						and ElementDefs[Board.Tiles[Board.Stats[0].X + InputDeltaX][Board.Stats[0].Y + InputDeltaY].Element].Walkable
					then begin
						{ Move player }
						if Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element = E_PLAYER then
							MoveStat(0, Board.Stats[0].X + InputDeltaX, Board.Stats[0].Y + InputDeltaY)
						else begin
							BoardDrawTile(Board.Stats[0].X, Board.Stats[0].Y);
							Inc(Board.Stats[0].X, InputDeltaX);
							Inc(Board.Stats[0].Y, InputDeltaY);
							with Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y] do begin
								Board.Stats[0].Under.Element := Element;
								Board.Stats[0].Under.Color := Color;
								Element := E_PLAYER;
								if (World.Info.PlayerColor = 0) and (World.Info.PlayerChar = #0) then
									Color := ElementDefs[E_PLAYER].Color
								else
									Color := World.Info.PlayerColor;
							end;
							BoardDrawTile(Board.Stats[0].X, Board.Stats[0].Y);
							DrawPlayerSurroundings(Board.Stats[0].X, Board.Stats[0].Y);
							DrawPlayerSurroundings(Board.Stats[0].X - InputDeltaX, Board.Stats[0].Y - InputDeltaY);
						end;

						{ Unpause }
						GamePaused := false;
						SidebarClearLine(5);
						GameDrawCustomSidebar;
						CurrentTick := Board.Info.BoardTicks;
						CurrentStatTicked := Board.StatCount + 1;
						World.Info.IsSave := true;
					end;
				end;

			end else begin { not GamePaused }
				if CurrentStatTicked <= Board.StatCount then begin
					with Board.Stats[CurrentStatTicked] do begin
						if (Cycle <> 0) and ((CurrentTick mod Cycle) = (CurrentStatTicked mod Cycle)) then
							ElementDefs[Board.Tiles[X][Y].Element].TickProc(CurrentStatTicked);

						CurrentStatTicked := CurrentStatTicked + 1;
					end;
				end;
			end;

			if (CurrentStatTicked > Board.StatCount) and not GamePlayExitRequested then begin
				{ all stats ticked }
				if SoundHasTimeElapsed(TickTimeCounter, TickTimeDuration) then begin
					{ next cycle }
					CurrentTick := Board.Info.BoardTicks;
					if CurrentTick > 420 then
						CurrentTick := 1;
					CurrentStatTicked := 0;

					InputUpdate;
				end;
			end;
		until (exitLoop or GamePlayExitRequested) and GamePlayExitRequested;

		SoundClearQueue;

		if GameStateElement = E_PLAYER then begin
			if (World.Info.Health <= 0) then begin
				HighScoresAdd(World.Info.Score);
			end;
		end else if GameStateElement = E_MONITOR then begin
			SidebarClearLine(5);
		end;

		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := E_PLAYER;
		if (World.Info.PlayerColor = 0) and (World.Info.PlayerChar = #0) then
			Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := ElementDefs[E_PLAYER].Color
		else
			Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := World.Info.PlayerColor;

		SoundBlockQueueing := false;
	end;

procedure GameTitleLoop;
	var
		boardChanged: boolean;
		startPlay: boolean;
	begin
		GameTitleExitRequested := false;
		JustStarted := true;
		ReturnBoardId := 0;
		boardChanged := true;
		repeat
			BoardChange(0);
			repeat
				GameStateElement := E_MONITOR;
				startPlay := false;
				GamePaused := false;
				GamePlayLoop(boardChanged);
				boardChanged := false;

				case UpCase(InputKeyPressed) of
					'W': begin
						if GameWorldLoad('.ZZT') then begin
							ReturnBoardId := World.Info.CurrentBoard;
							boardChanged := true;
						end;
					end;
					'P': begin
						if World.Info.IsSave and not DebugEnabled then begin
							startPlay := WorldLoad(World.Info.Name, '.ZZT');
							ReturnBoardId := World.Info.CurrentBoard;
						end else begin
							startPlay := true;
						end;
						if startPlay then begin
							BoardChange(ReturnBoardId);
							BoardEnter;
						end;
						KeyRepeat;
					end;
					'A': GameAboutScreen;
					'S': begin
						SidebarPromptSlider(true, 66, 21, 'Game speed:;FS', TickSpeed);
						InputKeyPressed := #0;
					end;
					'R': begin
						if GameWorldLoad('.SAV') then begin
							ReturnBoardId := World.Info.CurrentBoard;
							BoardChange(ReturnBoardId);
							startPlay := true;
						end;
						KeyRepeat;
					end;
					'H': begin
						HighScoresLoad;
						HighScoresDisplay(1);
					end;
					'|': GameDebugPrompt;
					KEY_ESCAPE, 'Q': GameTitleExitRequested := SidebarPromptYesNo('Quit ZZT? ', true);
				end;

				if startPlay then begin
					GameStateElement := E_PLAYER;
					GamePaused := true;
					GamePlayLoop(true);
					boardChanged := true;
				end;
			until boardChanged or GameTitleExitRequested;
		until GameTitleExitRequested;
	end;

procedure ResetCachedLinePos;
	begin
		FileWorldCachedLinePos := 1;
		FileSaveCachedLinePos := 1;
	end;

begin
end.
