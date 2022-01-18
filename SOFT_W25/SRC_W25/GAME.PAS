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
	function ColorNumber(s: string): integer;
	procedure SidebarClearLine(y: integer);
	procedure SidebarClear;
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
	function DisplayIOError: boolean;
	procedure WorldUnload;
	function WorldLoad(filename, extension: TString50): boolean;
	procedure WorldSave(filename, extension: TString50);
	procedure GameWorldSave(prompt: TString50; var filename: TString50; extension: TString50);
	function GameWorldLoad(extension: TString50): boolean;
	procedure CopyStatDataToTextWindow(statId: integer; var state: TTextWindowState);
	procedure AddStat(tx, ty: integer; element: byte; color, tcycle: integer; template: TStat);
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
	function BoardShoot(element: byte; tx, ty, deltaX, deltaY: integer; source: integer): boolean;
	procedure CalcDirectionRnd(var deltaX, deltaY: integer);
	procedure CalcDirectionSeek(x, y: integer; var deltaX, deltaY: integer);
	procedure TransitionDrawBoardChange;
	procedure GameUpdateSidebar;
	procedure GameAboutScreen;
	procedure GamePlayLoop(boardChanged: boolean);
	procedure DisplayMessage(time: integer; message: string);
	procedure BoardEnter;
	procedure BoardPassageTeleport(x, y: integer);
	procedure GameDebugPrompt;
	procedure GameTitleLoop;
	procedure ResetCachedLinePos;

const
	ColorNames: array[0 .. 7] of TString8 =
		('Black', 'Blue', 'Green', 'Cyan', 'Red', 'Purple', 'Yellow', 'White');

	ColorList: array[0..15] of byte = (
		0,1,2,3,4,5,20,7,56,57,58,59,60,61,62,63
	);
	NeighborArrowList: array[0..3] of char = (
		#30, #31, #17, #16
	);
	LFSR11_START = 42;
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

function ColorNumber(s: string): integer;
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

function DefaultParamList(i: integer): integer;
	begin
		case i of
			1,3,6,12,13: DefaultParamList := 1;
			2: DefaultParamList := 10;
			4,7: DefaultParamList := 2;
			5,8: DefaultParamList := 50;
			9: DefaultParamList := 150;
			10: DefaultParamList := 33;
			11,16,20,22,23,24,25,26,28,30,31,35,36,38,42: DefaultParamList := 0;
			14: DefaultParamList := 15;
			15: DefaultParamList := 14;
			17: DefaultParamList := 7;
			18: DefaultParamList := 3;
			19: DefaultParamList := 12;
			21: DefaultParamList := -1;
			27,29,32,33,34,37,39,40,43,44,45: DefaultParamList := 42;
			41,46,47,48,49,50,52,54,55,59,60,62,66: DefaultParamList := 21;
			51,53,56,57,58,61,63,64,65,67,68,69: DefaultParamList := 63;
		else DefaultParamList := -128 end;
	end;

procedure ParamsLoad;
	var
		f: text;
		i: integer;
		s: TString8;
		code: integer;
	begin
		for i := 1 to PARAM_FILE_COUNT do
			ParamList[i] := DefaultParamList(i);
		InitElementsGame;
		ConfigStringsLoad;
		if ParamList[THEME_START + 7] = 0 then
			SetBlink(true)
		else
			SetBlink(false);
		if (ParamList[THEME_START + 8] <> -1) and (World.Info.IsSave = false) then
			World.Info.CurrentBoard := ParamList[THEME_START + 8];
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
		if DisplayIOError then begin
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

function LFSR11UpdateSeed(var seed: word; var tx, ty: byte): boolean;
	begin
		seed := (seed shr 1) xor ((-(seed and 1)) and $740);
		tx := (seed - 1) and $3F;
		ty := ((seed - 1) shr 6) and $3F;
		LFSR11UpdateSeed := seed = LFSR11_START;
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
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := E_PLAYER;
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := ElementDefs[E_PLAYER].Color;
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
		Board.Info.IsDark := false;
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
	end;

procedure TransitionDrawToFill(chr: char; color: integer);
	var
		seed: word;
		tx, ty: byte;
	begin
		seed := LFSR11_START;
		repeat
			if (tx < 60) and (ty < 25) then
				VideoWriteText(tx, ty, color, chr);
		until LFSR11UpdateSeed(seed, tx, ty);

		if (tx < 60) and (ty < 25) then
			VideoWriteText(tx, ty, color, chr);
	end;

procedure BoardDrawTile(x, y: integer);
	var
		ch: byte;
	begin
		with Board.Tiles[x][y] do begin
			if ((Board.Info.IsDark = false) or (ElementDefs[Board.Tiles[x][y].Element].VisibleInDark = true))
				or (
					(World.Info.TorchTicks <> 0)
					and (
						(Sqr(Board.Stats[0].X-x)*ParamList[3])
						+ (Sqr(Board.Stats[0].Y-y)*ParamList[4])
						< ParamList[5]
					)
				) {Torch Radius}
			then begin
				if Element = E_EMPTY then
					VideoWriteText(x - 1, y - 1, $0F, ' ')
				else if ElementDefs[Element].HasDrawProc then begin
					ElementDefs[Element].DrawProc(x, y, ch);
					VideoWriteText(x - 1, y - 1, Color, Chr(ch));
				end else if Element < E_TEXT_MIN then
					VideoWriteText(x - 1, y - 1, Color, ElementDefs[Element].Character)
				else begin
					{ Text drawing }
					if Element = E_TEXT_WHITE then
						VideoWriteText(x - 1, y - 1, $0F, Chr(Board.Tiles[x][y].Color))
					else if VideoMonochrome then
						VideoWriteText(x - 1, y - 1, ((Element - E_TEXT_MIN) + 1) * 16, Chr(Board.Tiles[x][y].Color))
					else
						VideoWriteText(x - 1, y - 1, (((Element - E_TEXT_MIN) + 1) * 16) + $F, Chr(Board.Tiles[x][y].Color));
				end
			end else begin
				{ Darkness }
				VideoWriteText(x - 1, y - 1, ElementDefs[E_DARKNESS].Color, ElementDefs[E_DARKNESS].Character); {Darkness}
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
		seed: word;
		tx, ty: byte;
	begin
		BoardDrawBorder;

		seed := LFSR11_START;
		repeat
			if (tx < 60) and (ty < 25) then
				BoardDrawTile(tx+1, ty+1);
		until LFSR11UpdateSeed(seed, tx, ty);


		if (tx < 60) and (ty < 25) then
			BoardDrawTile(tx+1, ty+1);
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
		VideoWriteText(x, y, Integer(editable) + AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), prompt);
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
		SidebarClearLine(3);
		SidebarClearLine(4);
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
	end;

procedure PauseOnError;
	begin
		SoundQueue(1, SoundParse('s004x114x9'));
		Delay(2000);
	end;

function DisplayIOError: boolean;
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
		SidebarClearLine(4);
		SidebarClearLine(5);
		VideoWriteText(62, 5, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), 'Loading.....');

		Assign(f, filename + extension);
		Reset(f, 1);

		if not DisplayIOError then begin
			WorldUnload;
			BlockRead(f, IoTmpBuf^, WORLD_FILE_HEADER_SIZE);

			if not DisplayIOError then begin
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
						ExtMemWrite(World.BoardData[boardId], IoTmpBuf^, World.BoardLen[boardId]);
					end else RunError(203);
				end;

				ParamsLoad;
				InitElementsGame;
				BoardOpen(World.Info.CurrentBoard);
				LoadedGameFileName := filename;
				WorldLoad := true;

				HighScoresLoad;

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

		if not DisplayIOError then begin
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
			if DisplayIOError then goto OnError;

			for i := 0 to World.BoardCount do begin
				BlockWrite(f, World.BoardLen[i], 2);
				if DisplayIOError then goto OnError;

				ExtMemRead(World.BoardData[i], IoTmpBuf^, World.BoardLen[i]);
				BlockWrite(f, IoTmpBuf^, World.BoardLen[i]);
				if DisplayIOError then goto OnError;
			end;
			Close(f);
		end;

		BoardOpen(World.Info.CurrentBoard);
		SidebarClearLine(5);
		exit;

	OnError:
		Close(f);
		Erase(f);
		BoardOpen(World.Info.CurrentBoard);
		SidebarClearLine(5);
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
				World.Info.Name := filename;
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

procedure CopyStatDataToTextWindow(statId: integer; var state: TTextWindowState);
	var
		dataStr: string;
		dataPtr: pointer;
		dataChr: char;
		i: integer;
	begin
		with Board.Stats[statId] do begin
			TextWindowInitState(state);
			dataStr := '';
			dataPtr := Data;

			for i := 0 to DataLen do begin
				Move(dataPtr^, dataChr, 1);
				if dataChr = KEY_ENTER then begin
					TextWindowAppend(state, dataStr);
					dataStr := '';
				end else begin
					dataStr := dataStr + dataChr;
				end;
				AdvancePointer(dataPtr, 1);
			end;
		end;
	end;

procedure AddStat(tx, ty: integer; element: byte; color, tcycle: integer; template: TStat);
	begin
		if Board.StatCount < ParamList[9] then begin
			Board.StatCount := Board.StatCount + 1;
			Board.Stats[Board.StatCount] := template;
			with Board.Stats[Board.StatCount] do begin
				X := tx;
				Y := ty;
				Cycle := tcycle;
				if template.Cycle = 255 then begin
					if element = E_PASSAGE then
						P3 := ElementDefs[element].Param1
					else
						P1 := ElementDefs[element].Param1;
					P2 := ElementDefs[element].Param2;
				end else begin
					P1 := template.P1;
					P2 := template.P2;
					P3 := template.P3;
				end;
				Under := Board.Tiles[tx][ty];
				DataPos := 0;
			end;

			if template.Data <> nil then begin
				GetMem(Board.Stats[Board.StatCount].Data, template.DataLen);
				Move(template.Data^, Board.Stats[Board.StatCount].Data^, template.DataLen);
			end;

			if ElementDefs[Board.Tiles[tx][ty].Element].PlaceableOnTop then
				if (((ElementDefs[element].Color and $F0) > 0)
					and (ElementDefs[element].Color < COLOR_SPECIAL_MIN)) then
					Board.Tiles[tx][ty].Color := ElementDefs[element].Color
				else
					Board.Tiles[tx][ty].Color := (color and $0F) +
						(Board.Tiles[tx][ty].Color and $F0)
			else
				Board.Tiles[tx][ty].Color := color;
			Board.Tiles[tx][ty].Element := element;

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

procedure RemoveStat(statId: integer);
	var
		i: integer;
	begin
		with Board.Stats[statId] do begin
			FreeStatDataMem(statId);

			if statId <= CurrentStatTicked then
				Dec(CurrentStatTicked);

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
							Dec(Board.Stats[i].Follower);
					end;

					if Board.Stats[i].Leader >= statId then begin
						if Board.Stats[i].Leader = statId then
							Board.Stats[i].Leader := -1
						else
							Dec(Board.Stats[i].Leader);
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
		end else begin { statId = 0 (player) cannot be modified }
			result := false;
		end;
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
				if ((ElementDefs[Element].Color and $F0) > 0) or (Element = E_PLAYER) then
					Board.Tiles[newX][newY].Color := Color
				else if Board.Tiles[newX][newY].Element = E_EMPTY then
					Board.Tiles[newX][newY].Color := Color and $0F
				else
					Board.Tiles[newX][newY].Color := (Color and $0F) +
						(Board.Tiles[newX][newY].Color and $70);

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
				and (Board.Info.IsDark = true)
				and (World.Info.TorchTicks <> 0)
			then
				TransitionDrawToBoard;

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
			if ConfigList[69] <> '' then
				if Board.Info.TimeLimitSec > 0 then begin
					VideoWriteText(64, 6, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[69]);
					Str(Board.Info.TimeLimitSec - World.Info.BoardTimeSec, numStr);
					VideoWriteText(72, 6, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + ' ');
				end else SidebarClearLine(6);

			if World.Info.Health < 0 then
				World.Info.Health := 0;

			Str(World.Info.Health, numStr);
			if ConfigList[63] <> '' then
				VideoWriteText(72, 7, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + ' ');		
			Str(World.Info.Ammo, numStr);
			if ConfigList[64] <> '' then
				VideoWriteText(72, 8, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + '  ');
			Str(World.Info.Gems, numStr);
			if ConfigList[66] <> '' then
				VideoWriteText(72, 10, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + ' ');
			Str(World.Info.Score, numStr);
			if ConfigList[67] <> '' then
				VideoWriteText(72, 11, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + ' ');

			if ConfigList[65] <> '' then begin {Torches Sidebar}
				Str(World.Info.Torches, numStr);
				VideoWriteText(72, 9, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), numStr + ' ');
				if World.Info.TorchTicks <= 0 then
					VideoWriteText(75, 9, AsColor(ElementDefs[E_TORCH].Color and $0F,ParamList[THEME_START]), '    ')
				else begin
					for i := 2 to 5 do begin
						if i <= ((World.Info.TorchTicks * 5) div ElementDefs[E_TORCH].Param2) then
							VideoWriteText(73 + i, 9, AsColor(ElementDefs[E_TORCH].Color and $0F,ParamList[THEME_START]), #177)
						else
							VideoWriteText(73 + i, 9, AsColor(ElementDefs[E_TORCH].Color and $0F,ParamList[THEME_START]), #176);
					end;
				end;
			end;

			if ConfigList[68] <> '' then {Keys Sidebar}
				for i := 1 to 7 do begin
					if Diffkeys then
						keyChar := Chr(139 + i)
					else
						keyChar := ElementDefs[E_KEY].Character;
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

			if ConfigList[72] <> '' then begin
				if SoundEnabled then
					VideoWriteText(65, 15, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[73])
				else
					VideoWriteText(65, 15, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[74]);
			end;

			if DebugEnabled then begin
				Str(MemAvail, numStr);
				VideoWriteText(0, 0, $1E, 'm' + numStr + ' ');
				if ExtMemEmsActive then begin
					Str(ExtMemEmsAvailPages, numstr);
					VideoWriteText(0, 1, $1E, 'e' + numStr + 'p ');
				end;
				if ExtMemXmsActive then begin
					Str(ExtMemXmsAvail, numStr);
					VideoWriteText(0, 2, $1E, 'x' + numStr + ' ');
				end;
			end;
		end;
	end;

procedure DisplayMessage(time: integer; message: string);
	var
		statId: integer;
	begin
		if Length(message) <> 0 then begin
			if Length(Board.Info.Message) > Length(message) then
				BoardDrawRow(BOARD_HEIGHT);
			Board.Stats[0].P3 := time div (TickTimeDuration + 1);
			Board.Info.Message := message;
			VideoWriteText((60 - Length(Board.Info.Message)) div 2, 24, 9 + (Board.Stats[0].P3 mod 7), ' '+Board.Info.Message+' ');
		end;
	end;


procedure DamageStat(attackerStatId: integer);
	var
		oldX, oldY: integer;
	begin
		with Board.Stats[attackerStatId] do begin
			if attackerStatId = 0 then begin
				if World.Info.Health > 0 then begin
					World.Info.Health := World.Info.Health - ParamList[2];

					GameUpdateSidebar;
					DisplayMessage(100, ConfigList[48]);

					if Board.Tiles[X][Y].Element = E_PLAYER then
						VideoWriteText(X-1,Y-1,$70 + ElementDefs[E_PLAYER].Color and $0F, ElementDefs[E_PLAYER].Character);

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
							TransitionDrawToBoard;

							GamePaused := true;
						end;
						SoundQueue(4, SoundParse(ConfigList[49]));
					end;
				end;
			end else begin
				case Board.Tiles[X][Y].Element of
					E_BULLET: SoundQueue(3, SoundParse(ConfigList[56]));
					E_OBJECT: begin end;
				else
					SoundQueue(3, SoundParse(ConfigList[47]))
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
		end else begin
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
			Dec(CurrentStatTicked);

		if (Board.Tiles[x][y].Element = E_PLAYER) and (World.Info.EnergizerTicks > 0) then begin
			World.Info.Score := ElementDefs[Board.Tiles[Board.Stats[attackerStatId].X][Board.Stats[attackerStatId].Y].Element]
				.ScoreValue + World.Info.Score;
			GameUpdateSidebar;
		end else begin
			BoardDamageTile(x, y);
		end;
	end;

function BoardShoot(element: byte; tx, ty, deltaX, deltaY: integer; source: integer): boolean;
	begin
		if ElementDefs[Board.Tiles[tx + deltaX][ty + deltaY].Element].Walkable
			or (Board.Tiles[tx + deltaX][ty + deltaY].Element = E_WATER) then
		begin
			AddStat(tx + deltaX, ty + deltaY, element, ElementDefs[element].Color, 1, StatTemplateDefault);
			with Board.Stats[Board.StatCount] do begin
				P1 := source;
				StepX := deltaX;
				StepY := deltaY;
				P2 := ElementDefs[element].Param2;
			end;
			BoardShoot := true;
		end else if (Board.Tiles[tx + deltaX][ty + deltaY].Element = E_BREAKABLE)
			or (
				ElementDefs[Board.Tiles[tx + deltaX][ty + deltaY].Element].Destructible
				and ((Board.Tiles[tx + deltaX][ty + deltaY].Element = E_PLAYER) = Boolean(source))
				and (World.Info.EnergizerTicks <= 0)
			) then
		begin
			BoardDamageTile(tx + deltaX, ty + deltaY);
			BoardShoot := true;
		end else begin
			BoardShoot := false;
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

		if Board.Info.IsDark and MessageHintTorchNotShown then begin
			DisplayMessage(200, ConfigList[46]);
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

		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := E_EMPTY;
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := 0;
		if newX <> 0 then begin
			Board.Stats[0].X := newX;
			Board.Stats[0].Y := newY;
		end;

		GamePaused := true;
		SoundQueue(4, SoundParse(ConfigList[61]));
		TransitionDrawBoardChange;
		BoardEnter;
	end;

procedure GameDebugPrompt;
	var
		input: TString50;
		i: integer;
		toggle: boolean;
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
		else if input = 'DARK' then begin
			Board.Info.IsDark := toggle;
			TransitionDrawToBoard;
		end else if input = 'ZAP' then begin
			for i := 0 to 3 do begin
				BoardDamageTile(Board.Stats[0].X + NeighborDeltaX[i], Board.Stats[0].Y + NeighborDeltaY[i]);
				Board.Tiles[Board.Stats[0].X + NeighborDeltaX[i]][Board.Stats[0].Y + NeighborDeltaY[i]].Element := E_EMPTY;
				BoardDrawTile(Board.Stats[0].X + NeighborDeltaX[i], Board.Stats[0].Y + NeighborDeltaY[i]);
			end;
		end;

		SoundQueue(10, SoundParse(ConfigList[59]));
		SidebarClearLine(4);
		SidebarClearLine(5);
		GameUpdateSidebar;
	end;

procedure GameAboutScreen;
	begin
		TextWindowDisplayFile('ABOUT.HLP', 'About ZZT...');
	end;

procedure GamePlayLoop(boardChanged: boolean);
	var
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
				VideoWriteText(64, 7, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[63]);
				VideoWriteText(64, 8, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[64]);
				VideoWriteText(64, 9, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[65]);
				VideoWriteText(64, 10, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[66]);
				VideoWriteText(64, 11, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[67]);
				VideoWriteText(64, 12, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ConfigList[68]);
				if ConfigList[63] <> '' then  {Sidebar player}
					VideoWriteText(62, 7, ElementDefs[E_PLAYER].Color, ElementDefs[E_PLAYER].Character);
				if ConfigList[64] <> '' then  {Sidebar ammo}
					VideoWriteText(62, 8, AsColor(ElementDefs[E_AMMO].Color and $0F,ParamList[THEME_START]), ElementDefs[E_AMMO].Character);
				if ConfigList[65] <> '' then  {Sidebar Torch}
					VideoWriteText(62, 9, AsColor(ElementDefs[E_TORCH].Color and $0F,ParamList[THEME_START]), ElementDefs[E_TORCH].Character);
				if ConfigList[66] <> '' then  {Sidebar Gem}
					VideoWriteText(62, 10, AsColor(ParamList[THEME_START + 6],ParamList[THEME_START]), ElementDefs[E_GEM].Character);
				if ConfigList[68] <> '' then  {Sidebar key}
					VideoWriteText(62, 12, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ElementDefs[E_KEY].Character);
				if ConfigList[70] <> '' then begin
					VideoWriteText(62, 14, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' ' + ConfigList[70] + ' ');
					VideoWriteText(65, 14, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[71]);
				end;
				if ConfigList[72] <> '' then
					VideoWriteText(62, 15, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' ' + ConfigList[72] + ' ');
				if ConfigList[75] <> '' then begin
					VideoWriteText(62, 16, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' ' + ConfigList[75] + ' ');
					VideoWriteText(65, 16, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[76]);
				end;
				VideoWriteText(67, 18, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' '#24#25#26#27' ');
				VideoWriteText(72, 18, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' Move');
				VideoWriteText(61, 19, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' Shift '#24#25#26#27' ');
				VideoWriteText(72, 19, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' Shoot');
				if ConfigList[77] <> '' then begin
					VideoWriteText(62, 21, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' ' + ConfigList[77] + ' ');
					VideoWriteText(65, 21, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[78]);
				end;
				if NeuromotorAssist then begin
					VideoWriteText(62, 22, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' P ');
					VideoWriteText(65, 22, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' Proceed')
				end else if ConfigList[79] <> '' then begin
					VideoWriteText(62, 22, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 5]), ' ' + ConfigList[79] + ' ');
					VideoWriteText(65, 22, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' ' + ConfigList[80]);
				end;
				VideoWriteText(62, 23, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' Q ');
				VideoWriteText(65, 23, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' Quit');
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
				VideoWriteText(65, 16, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ' About ZZT!');
				VideoWriteText(62, 17, AsColor(ParamList[THEME_START + 3],ParamList[THEME_START + 4]), ' H ');
				VideoWriteText(65, 17, AsColor(ParamList[THEME_START + 2],ParamList[THEME_START]), ' High Scores');

			end;
		end;
	begin
		GameDrawSidebar;
		GameUpdateSidebar;

		if JustStarted then begin
			GameAboutScreen;
			if Length(StartupWorldFileName) <> 0 then begin
				if (FileExists(StartupWorldFileName + '.ZZT')
					and WorldLoad(StartupWorldFileName, '.ZZT'))
					or (FileExists(StartupWorldFileName)
					and WorldLoad(StartupWorldFileName,''))					
				then begin
					GameDrawSidebar;
					GameUpdateSidebar;
					GameAboutScreen;
					VideoWriteText(69, 8, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), World.Info.Name);
				end else begin
					WorldCreate;
				end;
			end;
			ReturnBoardId := World.Info.CurrentBoard;
			BoardChange(0);
			JustStarted := false;
		end;

		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := GameStateElement;
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := ElementDefs[GameStateElement].Color;

		if GameStateElement = E_MONITOR then begin
			DisplayMessage(0, '');
			VideoWriteText(62, 5, AsColor(ParamList[THEME_START + 6],ParamList[THEME_START]), ConfigList[82]);
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
					VideoWriteText(Board.Stats[0].X - 1, Board.Stats[0].Y - 1,
						ElementDefs[E_PLAYER].Color, ElementDefs[E_PLAYER].Character);
				end else begin
					if Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element = E_PLAYER then
						VideoWriteText(Board.Stats[0].X - 1, Board.Stats[0].Y - 1, $0F, ' ')
					else
						BoardDrawTile(Board.Stats[0].X, Board.Stats[0].Y);
				end;

				VideoWriteText(64, 5, AsColor(ParamList[THEME_START + 1],ParamList[THEME_START]), ConfigList[81]);
				InputUpdate;

				if InputKeyPressed = KEY_ESCAPE then
					GamePromptEndPlay;

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
						Inc(Board.Stats[0].X, InputDeltaX);
						Inc(Board.Stats[0].Y, InputDeltaY);
						Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := E_PLAYER;
						Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := ElementDefs[E_PLAYER].Color;
						TransitionDrawToBoard;
					end;

					{ Unpause }
					GamePaused := false;
					SidebarClearLine(5);
					CurrentTick := Board.Info.BoardTicks;
					CurrentStatTicked := Board.StatCount + 1;
					World.Info.IsSave := true;
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
			if World.Info.Health <= 0 then begin
				HighScoresAdd(World.Info.Score);
			end;
		end else if GameStateElement = E_MONITOR then begin
			SidebarClearLine(5);
		end;

		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Element := E_PLAYER;
		Board.Tiles[Board.Stats[0].X][Board.Stats[0].Y].Color := ElementDefs[E_PLAYER].Color;

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
