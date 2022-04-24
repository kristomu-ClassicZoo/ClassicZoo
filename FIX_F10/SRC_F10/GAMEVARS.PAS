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

unit GameVars;

interface
	uses ExtMem;
	const
		MAX_STAT = 254;
		MAX_ELEMENT = 53;
		MAX_BOARD = 250;
		MAX_FLAG = 10;
		BOARD_WIDTH = 60;
		BOARD_HEIGHT = 25;
		WORLD_FILE_HEADER_SIZE = 512;
		HIGH_SCORE_COUNT = 30;
		OOP_TOKEN_LENGTH = 20;
		IO_BUFFER_DEFAULT_SIZE = 20000;
		IO_BUFFER_MAXIMUM_SIZE = 65500;
		IO_BUFFER_SIZE_INCREMENT = 500;
		{.OBJ FILES}
		LOAD_OBJ_LENGTH = 40960;
		{.CFG FILE}
		CONFIG_FILE_COUNT = 88;
		THEME_START = 13;
		PALETTE_START = 22;
		PARAM_FILE_COUNT = 69;
		{.INI FILE}
		CUSTOM_OOP_COUNT = 38;
		CUSTOM_KEY_COUNT = 24;
		CUSTOM_LOCAL_OFFSET = CUSTOM_OOP_COUNT + CUSTOM_KEY_COUNT + 1;
		CUSTOM_OBJ_OFFSET = CUSTOM_LOCAL_OFFSET + 5;
		CUSTOM_COUNTER_OFFSET = CUSTOM_OBJ_OFFSET + 3;
		CUSTOM_FLAG_COUNT = 64;
	type
		TString50 = string[50];
		TString20 = string[20];
		TString8 = string[8];
		TFilenameString = string[128];
		TCoord = record
			X: integer;
			Y: integer;
		end;
		TTile = record
			Element: byte;
			Color: byte;
		end;
		TMatchTile = record
			Element: byte;
			Color: byte;
			SetFG: boolean;
			SetBG: boolean;
		end;
		TPalette = array[0..47] of byte;
		TElementDrawProc = procedure(x, y: integer; var ch: byte);
		TElementTickProc = procedure(statId: integer);
		TElementTouchProc = procedure(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
		TElementDef = record
			Character: char;
			Color: byte;
			Destructible: boolean;
			Pushable: boolean;
			VisibleInDark: boolean;
			PlaceableOnTop: boolean;
			Walkable: boolean;
			HasDrawProc: boolean;
			DrawProc: TElementDrawProc;
			Cycle: integer;
			TickProc: TElementTickProc;
			TouchProc: TElementTouchProc;
			Name: string[20];
			Param1: byte;
			Param2: byte;
			Param3: byte;
			ScoreValue: integer;
		end;
		TStat = record
			X, Y: byte;
			StepX, StepY: integer;
			Cycle: integer;
			P1, P2, P3: byte;
			Follower: integer;
			Leader: integer;
			Under: TTile;
			Data: ^string;
			DataPos: integer;
			DataLen: integer;
			ObjLocal: array[1 .. 3] of integer;
			elseCheck: boolean;
			unk: boolean;
		end;
		TRleTile = record
			Count: byte;
			Tile: TTile;
		end;
		TBoardInfo = record
			MaxShots: byte;
			IsDark: shortint;
			NeighborBoards: array[0 .. 3] of byte;
			ReenterWhenZapped: boolean;
			Message: string[57];
			boardFixed: byte;
			StartPlayerX: byte;
			StartPlayerY: byte;
			TimeLimitSec: integer;
			BoardTicks: integer;
			Local: array[1 .. 6] of integer;
			unk1: integer;
		end;
		TWorldInfo = record
			Ammo: integer;
			Gems: integer;
			Keys: array [1..7] of shortint;
			Health: integer;
			CurrentBoard: integer;
			Torches: integer;
			TorchTicks: integer;
			EnergizerTicks: integer;
			GracePeriod: integer;
			Score: integer;
			Name: string[20];
			Flags: array[1 .. MAX_FLAG] of string[20];
			BoardTimeSec: integer;
			BoardTimeHsec: integer;
			IsSave: boolean;
			CustomFlags: array[1 .. CUSTOM_FLAG_COUNT] of integer;
			PlayerColor: byte;
			PlayerChar: char;
			CustomPalette: TPalette;
			KeySpeed: shortint;
		end;
		TBoard = record
			Name: TString50;
			Tiles: array[0 .. BOARD_WIDTH + 1] of array[0 .. BOARD_HEIGHT + 1] of TTile;
			StatCount: integer;
			Stats: array[0 .. MAX_STAT + 1] of TStat;
			Info: TBoardInfo;      
		end;
		TWorld = record
			BoardCount: integer;
			BoardData: array[0 .. MAX_BOARD] of TExtMemBlock;
			BoardLen: array[0 .. MAX_BOARD] of word;
			Info: TWorldInfo;
		end;
		THighScoreEntry = record
			Name: TString50;
			Score: integer;
		end;
		THighScoreList = array[1 .. HIGH_SCORE_COUNT] of THighScoreEntry;
		TConfigList = array[1 .. CONFIG_FILE_COUNT] of string[80];
		TCustomFlagList = array[1 .. CUSTOM_FLAG_COUNT] of TString20;
		TCustomBoardList = array[1 .. 6] of TString20;
		TCustomObjList = array[1 .. 3] of TString20;
		TParamList = array[1 .. PARAM_FILE_COUNT] of integer;
		TCustomOOPList = array[1 .. CUSTOM_OOP_COUNT] of TString20;
		TCustomKeyList = array[0 .. CUSTOM_KEY_COUNT - 1] of TString20;
		TSearchArea = array[-7 .. 7] of array[-7 .. 7] of shortint;
	var
		PlayerDirX: integer;
		PlayerDirY: integer;
		PMouseX, PMouseY, PPosX, PPosY, OPosX, OPosY: shortint;

		LoadedGameFileName: TString50;
		SavedGameFileName: TString50;
		SavedBoardFileName: TString50;
		StartupWorldFileName: TString50;
		Board: TBoard;
		World: TWorld;
		MessageAmmoNotShown: boolean;
		MessageOutOfAmmoNotShown: boolean;
		MessageNoShootingNotShown: boolean;
		MessageTorchNotShown: boolean;
		MessageOutOfTorchesNotShown: boolean;
		MessageRoomNotDarkNotShown: boolean;
		MessageHintTorchNotShown: boolean;
		MessageForestNotShown: boolean;
		MessageFakeNotShown: boolean;
		MessageGemNotShown: boolean;
		MessageEnergizerNotShown: boolean;
		NeuromotorAssist: boolean;
		HearingImpaired: boolean;
		Diffkeys: boolean;
		SkipToTitle: boolean;
		GameMove: boolean;
		IoTmpBufSize: word;
		FileWorldCachedLinePos: integer; 
		FileSaveCachedLinePos: integer;

		InspectNext: boolean;
		NoClip: boolean;

		GameTitleExitRequested: boolean;
		GamePlayExitRequested: boolean;
		GameStateElement: integer;
		ReturnBoardId: integer;

		TickSpeed: byte;

		IoTmpBuf: pointer;
		ObjTmpBuf: pointer;
		PathTmpBuf: ^string;

		ElementDefs: array[0 .. MAX_ELEMENT] of TElementDef;

		TickTimeDuration: integer;
		CurrentTick: integer;
		CurrentStatTicked: integer;
		GamePaused: boolean;
		TickTimeCounter: integer;
		KeyLimit: integer;

		InitialTextAttr: byte;

		OopChar: char;
		OopWord: string[20];
		OopValue: integer;
		CurrentSave: string[8];
		InputTerminal: string[20];

		DebugEnabled: boolean;

		CustomFlagList: TCustomFlagList;
		CustomBoardList: TCustomBoardList;
		CustomObjList: TCustomObjList;
		ConfigList: TConfigList;
		ParamList: TParamList;
		OOPList: TCustomOOPList;
		KeyList: TCustomKeyList;
		SearchArea: TSearchArea;
		HighScoreList: THighScoreList;
		JustStarted: boolean;
		ConfigWorldFile: TString50;
		Accessibility: array[1..4] of TString50;		


		BoardNames: array[0 .. MAX_BOARD] of TString50;
	const
		E_EMPTY = 0;
		E_BOARD_EDGE = 1;
		E_DARKNESS = 2;
		E_MONITOR = 3; { State - Title screen }
		E_PLAYER = 4; { State - Playing }
		E_AMMO = 5;
		E_TORCH = 6;
		E_GEM = 7;
		E_KEY = 8;
		E_DOOR = 9;
		E_SCROLL = 10;
		E_PASSAGE = 11;
		E_DUPLICATOR = 12;
		E_BOMB = 13;
		E_ENERGIZER = 14;
		E_STAR = 15;
		E_CONVEYOR_CW = 16;
		E_CONVEYOR_CCW = 17;
		E_BULLET = 18;
		E_WATER = 19;
		E_FOREST = 20;
		E_SOLID = 21;
		E_NORMAL = 22;
		E_BREAKABLE = 23;
		E_BOULDER = 24;
		E_SLIDER_NS = 25;
		E_SLIDER_EW = 26;
		E_FAKE = 27;
		E_INVISIBLE = 28;
		E_BLINK_WALL = 29;
		E_TRANSPORTER = 30;
		E_LINE = 31;
		E_RICOCHET = 32;
		E_BLINK_RAY_EW = 33;
		E_BEAR = 34;
		E_RUFFIAN = 35;
		E_OBJECT = 36;
		E_SLIME = 37;
		E_SHARK = 38;
		E_SPINNING_GUN = 39;
		E_PUSHER = 40;
		E_LION = 41;
		E_TIGER = 42;
		E_BLINK_RAY_NS = 43;
		E_CENTIPEDE_HEAD = 44;
		E_CENTIPEDE_SEGMENT = 45;
		E_TEXT_BLUE = 47;
		E_TEXT_GREEN = 48;
		E_TEXT_CYAN = 49;
		E_TEXT_RED = 50;
		E_TEXT_PURPLE = 51;
		E_TEXT_YELLOW = 52;
		E_TEXT_WHITE = 53;
		{}
		E_TEXT_MIN = 46;
		{}
		CATEGORY_ITEM = 1;
		CATEGORY_CREATURE = 2;
		CATEGORY_TERRAIN = 3;
		{}
		SHOT_SOURCE_PLAYER = 0;
		SHOT_SOURCE_ENEMY = 1;

implementation

begin
end.
