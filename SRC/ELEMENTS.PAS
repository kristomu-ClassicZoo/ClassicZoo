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

{$F+}
{$I-}
unit Elements;

interface
	uses GameVars;
	procedure ElementMove(oldX, oldY, newX, newY: integer);
	procedure ElementPushablePush(x, y: integer; deltaX, deltaY: integer);
	procedure ElementWeave(x, y: integer; deltaX, deltaY: integer);
	procedure DrawPlayerSurroundings(x, y: integer);
	procedure GamePromptEndPlay;
	procedure InitElementsGame;
	procedure SetExpr(bank, expr: integer);

implementation
uses Crt, Video, Sounds, Input, TxtWind, Oop, Game, Dos;

const
	EXPRESSIONS: array[1..2] of array[0..6] of array[1..14] of char = (
		((#$00, #$00, #$7E, #$FF, #$DB, #$FF, #$FF, #$C3, #$E7, #$FF, #$7E, #$00, #$00, #$00),
		(#$00, #$00, #$7E, #$81, #$93, #$FF, #$FF, #$DF, #$C7, #$FF, #$7E, #$00, #$00, #$00),
		(#$00, #$00, #$7E, #$FF, #$DB, #$FF, #$FF, #$E7, #$C3, #$FF, #$7E, #$00, #$00, #$00),
		(#$00, #$00, #$7E, #$DB, #$E7, #$DB, #$FF, #$FF, #$E3, #$C7, #$7E, #$00, #$00, #$00),
		(#$00, #$00, #$7E, #$81, #$93, #$FF, #$FF, #$DF, #$C7, #$FF, #$7E, #$00, #$00, #$00),
		(#$00, #$00, #$7E, #$FF, #$DB, #$FF, #$FF, #$FF, #$E7, #$DF, #$7E, #$00, #$00, #$00),
		(#$1C, #$08, #$3E, #$7F, #$1C, #$6B, #$77, #$00, #$49, #$7F, #$7F, #$63, #$3E, #$3E)),

	 	((#$00, #$00, #$1C, #$76, #$FB, #$AE, #$AE, #$FB, #$E8, #$C8, #$70, #$00, #$00, #$00),
		(#$00, #$00, #$1C, #$76, #$FB, #$AE, #$FE, #$DB, #$F8, #$F8, #$70, #$00, #$00, #$00),
    	(#$00, #$00, #$1C, #$76, #$AB, #$AE, #$AE, #$FB, #$88, #$88, #$70, #$00, #$00, #$00),
		(#$00, #$00, #$1C, #$76, #$AB, #$DE, #$AE, #$FB, #$D8, #$D8, #$70, #$00, #$00, #$00),
		(#$00, #$00, #$1C, #$76, #$FB, #$06, #$4E, #$FB, #$E8, #$C8, #$70, #$00, #$00, #$00),
		(#$00, #$00, #$1C, #$76, #$FB, #$AE, #$FE, #$FB, #$88, #$F8, #$70, #$00, #$00, #$00),
		(#$1C, #$08, #$3E, #$7F, #$1C, #$6B, #$77, #$00, #$49, #$7F, #$7F, #$63, #$3E, #$3E))
	);
var
	WoahThere: integer;


procedure SetExpr(bank, expr: integer);
	var
		regs: Registers;
	begin
		regs.ax := $1110;
		regs.bh := $0E;                           (* bytes per character *)
		regs.bl := 0;                             (* load to block 0 *)
		regs.cx := 1;                             (* 1 characters *)
		regs.dx := 255;                           (* start with character 255 *)
		regs.es := Seg(EXPRESSIONS[bank][expr]);  (* segment of table *)
		regs.bp := Ofs(EXPRESSIONS[bank][expr]);  (* offset of the table *)
		intr($10, regs);
	end;

procedure ElementDefaultTick(statId: integer);
	begin
	end;

procedure ElementDefaultTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
	end;

procedure ElementDefaultDraw(x, y: integer; var ch: byte);
	begin
		ch := Ord('?');
	end;

procedure ElementMessageTimerTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			case X of
				0: begin
					VideoWriteText((60 - Length(Board.Info.Message)) div 2, 24, 10 + (P2 mod 6), ' '+Board.Info.Message+' ');
					Dec(P2);
					if P2 <= 0 then begin
						RemoveStat(statId);
						Dec(CurrentStatTicked);
						BoardDrawBorder;
						Board.Info.Message := '';
					end;
				end;
			end;
		end;
	end;

{ ## GLOBAL OBJECT }
procedure ElementGlobalTick(statId: integer);
	begin
		if World.Info.CurrentBoard <> 0 then
			with Board.Stats[statId] do
				if DataPos >= 0 then begin
					GlobalRead := true;
					OopExecute(statId, DataPos, 'Global');
					GlobalRead := false;
				end;
	end;
{ ## END GLOBAL OBJECT }

procedure ElementDamagingTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		BoardAttack(sourceStatId, x, y);
	end;

procedure ElementLineDraw(x, y: integer; var ch: byte);
	var
		i, v, shift: integer;
	begin
		v := 1;
		shift := 1;
		for i := 0 to 3 do begin
			case Board.Tiles[x + NeighborDeltaX[i]][y + NeighborDeltaY[i]].Element of
				E_LINE, E_BOARD_EDGE: v := v + shift;
			end;
			shift := shift shl 1;
		end;
		ch := Ord(LineChars[v]);
	end;

procedure ElementVineDraw(x, y: integer; var ch: byte);
	var
		v, shift: integer;
	begin
		v := 0;
		shift := 7;
		if (Board.Tiles[x + 1][y].Element = E_FOREST) or (Board.Tiles[x + 1][y].Element = E_PLAYER) then begin
			Inc(v);
			shift := 1;
		end;
		if (Board.Tiles[x - 1][y].Element = E_FOREST) or (Board.Tiles[x - 1][y].Element = E_PLAYER) then begin
			Inc(v);
			shift := 2;
		end;
		if (Board.Tiles[x][y + 1].Element = E_FOREST) or (Board.Tiles[x][y + 1].Element = E_PLAYER) then begin
			Inc(v);
			shift := 3;
		end;
		if (Board.Tiles[x][y - 1].Element = E_FOREST) or (Board.Tiles[x][y - 1].Element = E_PLAYER) then begin
			Inc(v);
			shift := 4;
		end;
		if v > 2 then begin
			if x mod 2 = 0 then
				shift := 5
			else
				shift := 6;
		end;
		ch := Ord(VineChars[shift]);
	end;

procedure ElementBigDoorDraw(x, y: integer; var ch: byte);
	var
		v, k: integer;
	begin
		v := 0;
		k := Board.Tiles[x][y+1].Element;
		if (k = E_BIG_DOOR) or (k > E_TEXT_MAX) then
			v := v + 2;
		k := Board.Tiles[x+1][y].Element;
		if (k = E_BIG_DOOR) or (k > E_TEXT_MAX) then
			v := v + 1;
		ch := 228 + v;
	end;

procedure ElementBigDoorSwingDraw(x, y: integer; var ch: byte);
	begin
		if (Board.Tiles[x+1][y].Element = E_BIG_DOOR) or (Board.Tiles[x+1][y].Element > E_TEXT_MAX) then
			ch := 221
		else
			ch := 222;
	end;

procedure ElementBigDoorTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		v, k: integer;
	begin
		v := 0;
		k := Board.Tiles[x][y+1].Element;
		if (k = E_BIG_DOOR) or (k > E_TEXT_MAX) then begin
			v := 1;
			Board.Tiles[x][y+1].Element := 54;
			BoardDrawTile(x,y+1);
		end else begin
			k := Board.Tiles[x][y-1].Element;
			if (k = E_BIG_DOOR) or (k > E_TEXT_MAX) then begin
				Board.Tiles[x][y-1].Element := 54;
				BoardDrawTile(x,y-1);
			end;
		end;
		k := Board.Tiles[x+1][y].Element;
		if (k = E_BIG_DOOR) or (k > E_TEXT_MAX) then begin
			if v = 1 then begin
				Board.Tiles[x+1][y+1].Element := 54;
				BoardDrawTile(x+1,y+1);
			end else begin
				k := Board.Tiles[x+1][y-1].Element;
				if (k = E_BIG_DOOR) or (k > E_TEXT_MAX) then begin
					Board.Tiles[x+1][y-1].Element := 54;
					BoardDrawTile(x+1,y-1);
				end;
			end;
			Board.Tiles[x+1][y].Element := 54;
			BoardDrawTile(x+1,y);
		end else begin
			if v = 1 then begin
				k := Board.Tiles[x-1][y+1].Element;
				if (k = E_BIG_DOOR) or (k > E_TEXT_MAX) then begin
					Board.Tiles[x-1][y+1].Element := 54;
					BoardDrawTile(x-1,y+1);
				end;
			end else begin
				k := Board.Tiles[x-1][y-1].Element;
				if (k = E_BIG_DOOR) or (k > E_TEXT_MAX) then begin
					Board.Tiles[x-1][y-1].Element := 54;
					BoardDrawTile(x-1,y-1);
				end;
			end;
			k := Board.Tiles[x-1][y].Element;
			if (k = E_BIG_DOOR) or (k > E_TEXT_MAX) then begin
				Board.Tiles[x-1][y].Element := 54;
				BoardDrawTile(x-1,y);
			end;
		end;
		Board.Tiles[x][y].Element := 54;
		BoardDrawTile(x,y);		
	end;


procedure ElementMove(oldX, oldY, newX, newY: integer);
	var
		statId: integer;
	begin
		statId := GetStatIdAt(oldX, oldY);

		if statId >= 0 then begin
			MoveStat(statId, newX, newY);
		end else begin
			Board.Tiles[newX][newY] := Board.Tiles[oldX][oldY];
			BoardDrawTile(newX, newY);
			Board.Tiles[oldX][oldY].Element := E_EMPTY;
			BoardDrawTile(oldX, oldY);
		end;
	end;

procedure ElementPushablePush(x, y: integer; deltaX, deltaY: integer);
	var
		unk1: integer;
	begin
		with Board.Tiles[x][y] do begin
			if ((Element = E_SLIDER_NS) and (deltaX = 0)) or ((Element = E_SLIDER_EW) and (deltaY = 0))
				or ElementDefs[Element].Pushable then
			begin
				if Board.Tiles[x + deltaX][y + deltaY].Element <> E_EMPTY then begin
					if (deltaX <> 0) or (deltaY <> 0) then begin
						ElementPushablePush(x + deltaX, y + deltaY, deltaX, deltaY);
					end;
				end;

				if not ElementDefs[Board.Tiles[x + deltaX][y + deltaY].Element].Walkable
					and ElementDefs[Board.Tiles[x + deltaX][y + deltaY].Element].Destructible
					and (Board.Tiles[x + deltaX][y + deltaY].Element <> E_PLAYER) then
				begin
					BoardDamageTile(x + deltaX, y + deltaY);
				end;

				if ElementDefs[Board.Tiles[x + deltaX][y + deltaY].Element].Walkable then
					ElementMove(x, y, x + deltaX, y + deltaY);
			end;
		end;
	end;

procedure ElementWeave(x, y: integer; deltaX, deltaY: integer);
	var
		statDestroy: boolean;
		statId: integer;
	begin
		statDestroy := false;
		with Board.Tiles[x][y] do begin
			if Board.Tiles[x + deltaX][y + deltaY].Element = E_PLAYER then begin
				if Board.Tiles[x + ( deltaX * 2 )][y + ( deltaY * 2 )].Element = E_BOARD_EDGE then
					statDestroy := true;
				if Board.Tiles[x + ( deltaX * 2 )][y + ( deltaY * 2 )].Element = E_SOLID then
					statDestroy := true;
				if Board.Tiles[x + ( deltaX * 2 )][y + ( deltaY * 2 )].Element = E_OBJECT then
					statDestroy := true;
			end;
			if Board.Tiles[x + deltaX][y + deltaY].Element = E_BOARD_EDGE then
				statDestroy := true;
			if Board.Tiles[x + deltaX][y + deltaY].Element = E_SOLID then
				statDestroy := true;
			if Board.Tiles[x + deltaX][y + deltaY].Element = E_OBJECT then
				statDestroy := true;
			statId := GetStatIdAt(x, y);
			if statDestroy = true then begin
				if statId > 0 then
					RemoveStat(statId);
			end else begin
				ElementWeave(x + deltaX, y + deltaY, deltaX, deltaY);
				statId := GetStatIdAt(x, y);
				Board.Tiles[x + deltaX][y + deltaY] := Board.Tiles[x][y];
				Board.Tiles[x][y].Element := E_EMPTY;
				Board.Tiles[x][y].Color := $0F;
				if statId >= 0 then begin
					Board.Stats[statId].X := x + deltaX;
					Board.Stats[statId].Y := y + deltaY;
				end;
				BoardDrawTile(x, y);
				BoardDrawTile(x + deltaX, y + deltaY);
			end;
		end;
	end;

procedure ElementObjectTick(statId: integer);
	var
		retVal: boolean;
	begin
		with Board.Stats[statId] do begin
			if DataPos >= 0 then
				OopExecute(statId, DataPos, 'Interaction');

			if (StepX <> 0) or (StepY <> 0) then begin
				if ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable then
					MoveStat(statId, X + StepX, Y + StepY)
				else
					retVal := OopSend(-statId, 'THUD', false);
			end;
		end;
	end;

procedure ElementShedSpaceDraw(x, y: integer; var ch: byte);
	var
		a, i, j, k: integer;
	begin
		a := (Sqr(x - 30) + Sqr(y - 12)) + CurrentTick;
		k := (x + CurrentTick) mod 420;
		j := (26 - y + CurrentTick) mod 420;
		i := (k mod 6) div 3;
		i := i + random(2);
		case j mod 15 of
			1,2,3,9,10,11: Inc(i);
			4,5,6,7,8: i := i + 2;
		end;
		case k mod 21 of
			6,7,8,9,14,15,16,17: Inc(i);
			10,11,12,13: i := i + 2;
		end;
		case (a div 7) mod 35 of
			8,9,10,11,28: Inc(i);
			12,13,14,15,16,27: i := i + 2;
			17,18,19,20,21,22,23,26: i := i + 3;
			24,25: i := i + 4;
		end;
		case i of
			{1: ch := 198;}
			2,8: ch := 176;
			3,7: ch := 177;
			4,6: ch := 178;
			5: ch := 219;
		else ch := 32 end;
	end;

procedure ElementObjectDraw(x, y: integer; var ch: byte);
	begin
		ch := Board.Stats[GetStatIdAt(x, y)].P1;
	end;

procedure ElementObjectTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		statId: integer;
		retVal: boolean;
	begin
		if WoahThere > 0 then
			Dec(WoahThere)
		else begin
			statId := GetStatIdAt(x, y);
			retVal := OopSend(-statId, 'TOUCH', false);
			WoahThere := 4;
		end;
	end;

procedure ElementPushableTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		ElementPushablePush(x, y, deltaX, deltaY);
		SoundQueue(2, SoundParse('0'));
	end;

procedure ElementInvisibleTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		with Board.Tiles[x][y] do begin
			Element := E_NORMAL;
			BoardDrawTile(x, y);

			SoundQueue(2, SoundParse('654'));
			DisplayMessage(100, 'You are blocked by an invisible wall.');
		end;
	end;

procedure ElementBoardEdgeTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		neighborId: integer;
		boardId: integer;
		entryX, entryY: integer;
	begin
		entryX := Board.Stats[0].X;
		entryY := Board.Stats[0].Y;
		if deltaY = -1 then begin
			neighborId := 0;
			entryY := BOARD_HEIGHT;
		end else if deltaY = 1 then begin
			neighborId := 1;
			entryY := 1;
		end else if deltaX = -1 then begin
			neighborId := 2;
			entryX := BOARD_WIDTH;
		end else begin
			neighborId := 3;
			entryX := 1;
		end;

		if Board.Info.NeighborBoards[neighborId] <> 0 then begin
			boardId := World.Info.CurrentBoard;
			BoardChange(Board.Info.NeighborBoards[neighborId]);
			if Board.Tiles[entryX][entryY].Element <> E_PLAYER then begin
				ElementDefs[Board.Tiles[entryX][entryY].Element].TouchProc(
					entryX, entryY, sourceStatId, InputDeltaX, InputDeltaY);
			end;

			if ElementDefs[Board.Tiles[entryX][entryY].Element].Walkable
				or (Board.Tiles[entryX][entryY].Element = E_PLAYER) then
			begin
				if Board.Tiles[entryX][entryY].Element <> E_PLAYER then
					MoveStat(0, entryX, entryY);

				TransitionDrawBoardChange;
				deltaX := 0;
				deltaY := 0;
				BoardEnter;
			end else begin
				BoardChange(boardId);
			end;
		end;
	end;

procedure DrawPlayerSurroundings(x, y: integer);
	var
		ix, iy: integer;
		istat: integer;
		result: boolean;
	begin
		for ix := ((x - TORCH_DX) - 1) to ((x + TORCH_DX) + 1) do
			if (ix >= 1) and (ix <= BOARD_WIDTH) then
				for iy := ((y - TORCH_DY) - 1) to ((y + TORCH_DY) + 1) do
					if (iy >= 1) and (iy <= BOARD_HEIGHT) then
							BoardDrawTile(ix, iy);
	end;

procedure GamePromptEndPlay;
	begin
		JustEntered := true;
		if World.Info.Health <= 0 then begin
			GamePlayExitRequested := true;
			BoardDrawBorder;
		end else GamePlayExitRequested := SidebarPromptYesNo('End this game? ', true);
	end;

procedure HintFlash(var flash: integer);
	var
		i: integer;
	begin
		Dec(Flash);
		for i := 1 to Board.StatCount do
			if Board.Stats[i].P3 = 1 then
				if (flash < 2) or (flash mod 2 = 1) then
					BoardDrawTile(Board.Stats[i].X, Board.Stats[i].Y)
				else
					VideoWriteText(Board.Stats[i].X - 1, Board.Stats[i].Y - 1, $4C, 'H');
	end;

procedure ElementPlayerTick(statId: integer);
	var
		i: integer;
		OnEdge: boolean;
		bx: string;
	begin
		if FlashInv > 0 then begin
			Dec(FlashInv);
			GameUpdateSidebar;
		end;
		if Board.Stats[0].P3 = 0 then
			Dec(BigTimer);
		if BigTimer < 0 then begin
			BigTimer := BigTimer + 9;
			if World.Info.Register[8] < 32409 then
				Inc(World.Info.Register[8]);
			if DisplayClock > 0 then
				GameUpdateSidebar;
		end;
		if FlashHint > 0 then
			HintFlash(FlashHint);
		if WoahThere > 0 then
			Dec(WoahThere);
		if World.Info.Torches > 0 then begin
			Dec(World.Info.Torches);
			GameUpdateSidebar;
		end;
		if World.Info.Ammo > 0 then begin
			Dec(World.Info.Ammo);
			if Sqr(InputDeltaX) + Sqr(InputDeltaY) <> 0 then
				Dec(World.Info.Ammo);
			GameUpdateSidebar;
		end;
		if JustEntered then begin
			GameUpdateSidebar;
			JustEntered := false;
		end;

{ ## GLOBAL OBJECT }
		if GlobalLen > 0 then begin
			if GetStatIdAt(BOARD_WIDTH+1, 0) < 0 then begin
				AddStat(BOARD_WIDTH+1, 0, E_GLOBAL, 0, 1, StatTemplateDefault);
				FreeMem(Board.Stats[Board.StatCount].Data, Board.Stats[Board.StatCount].DataLen);
				Board.Stats[Board.StatCount].Data := @GlobalData;
				Board.Stats[Board.StatCount].DataLen := GlobalLen;
				Board.Stats[Board.StatCount].DataPos := 0;
				GetMem(Board.Stats[Board.StatCount].Data, GlobalLen);
				Move(GlobalData^, Board.Stats[Board.StatCount].Data^, GlobalLen);
			end;
			if Board.Tiles[BOARD_WIDTH+1][0].Element <> E_GLOBAL then
				Board.Tiles[BOARD_WIDTH+1][0].Element := E_GLOBAL;
		end;
{ ## END GLOBAL OBJECT }
		if World.Info.PlayerColor = $00 then begin
			if ConfigPaper then begin
				World.Info.PlayerColor := $09;
			end else begin
				World.Info.PlayerColor := $1F;
			end;
		end;
		with Board.Stats[statId] do begin
			Board.Tiles[X][Y].Color := World.Info.PlayerColor;
			ElementDefs[E_PLAYER].Character := #255;
			BoardDrawTile(X, Y);

			if World.Info.Health <= 0 then begin
				InputDeltaX := 0;
				InputDeltaY := 0;

				if GetStatIdAt(0,0) = -1 then
					DisplayMessage(32000, ' Game over  -  Press ESCAPE');

				TickTimeDuration := 0;
				SoundBlockQueueing := true;
			end;

			{MOVEMENT DEBUG}
			{Str(P1, bx);
			VideoWriteText(62, 4, $1D, 'P1: ' + bx + ' ');
			Str(InputDeltaX, bx);
			VideoWriteText(62, 5, $1D, 'DX: ' + bx + ' ');
			Str(InputDeltaY, bx);
			VideoWriteText(62, 6, $1D, 'DY: ' + bx + ' ');}

			if P1 > 0 then begin
				{ Jumping & Gravity }
				if P1 = 1 then begin
					if ElementDefs[Board.Tiles[X][Y + 1].Element].Walkable then begin
						if ((InputDeltaY < 0) and (InputDeltaX <> 0)) and ((ElementDefs[Board.Tiles[X + InputDeltaX][Y - 1].Element].Walkable)
							and not ElementDefs[Board.Tiles[X + InputDeltaX][Y].Element].Walkable) then
							InputDeltaY := -1
						else begin
							InputDeltaY := 1;
							if not ElementDefs[Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element].Walkable then
								InputDeltaX := 0;
						end;
					end else begin
						if InputDeltaY < 0 then begin
							P1 := 4;
						end else begin
							InputDeltaY := 0;
						end;
					end;

					{BONK}

					{ SLOPES }
					if (InputDeltaX <> 0) and (InputDeltaY = 0) then
						if ElementDefs[Board.Tiles[X + InputDeltaX][Y].Element].PlaceableOnTop then
							if not ElementDefs[Board.Tiles[X + InputDeltaX][Y].Element].Walkable then
								if ElementDefs[Board.Tiles[X + InputDeltaX][Y - 1].Element].Walkable then
									if not ElementDefs[Board.Tiles[X][Y + 1].Element].Walkable then
										InputDeltaY := -1;
				end else begin
					Dec(P1);
					InputDeltaY := -1;
				end;

			end else if P2 < 1 then begin
				{SMART MOVEMENT}

				if (InputDeltaX <> 0) and (InputDeltaY <> 0) then begin
					if (X = 1) or (X = BOARD_WIDTH) then begin
						InputDeltaY := 0;
						OnEdge := true;
					end;
					if (Y = 1) or (Y = BOARD_HEIGHT) then begin
						InputDeltaX := 0;
						OnEdge := true;
					end;

					if not OnEdge then begin
						if not ElementDefs[Board.Tiles[X][Y + InputDeltaY].Element].Walkable then begin
							if not ElementDefs[Board.Tiles[X + InputDeltaX][Y].Element].Walkable then begin
								InputDeltaY := 0;
								InputDeltaX := 0;
							end;
						end;
					end;

					if not OnEdge then begin
						if not ElementDefs[Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element].Walkable then begin
							if ElementDefs[Board.Tiles[X + InputDeltaX][Y].Element].Walkable then begin
								if ElementDefs[Board.Tiles[X][Y + InputDeltaY].Element].Walkable and (Random(2) = 0) then begin
									InputDeltaX := 0;
								end else begin
									InputDeltaY := 0;
								end;
							end else begin
								if ElementDefs[Board.Tiles[X][Y + InputDeltaY].Element].Walkable then InputDeltaX := 0;
							end;
						end;
					end;

				end;

				if (InputDeltaX <> 0) and (InputDeltaY = 0) then begin
					if ElementDefs[Board.Tiles[X + InputDeltaX][Y].Element].PlaceableOnTop then begin
						if not ElementDefs[Board.Tiles[X + InputDeltaX][Y].Element].Walkable then begin
							if ElementDefs[Board.Tiles[X + InputDeltaX][Y + 1].Element].Walkable then begin
								if ElementDefs[Board.Tiles[X + InputDeltaX][Y - 1].Element].Walkable then begin
									InputDeltaY := (Random(2) * 2) - 1;
								end else begin
									InputDeltaY := 1;
								end;
							end else begin
								if ElementDefs[Board.Tiles[X + InputDeltaX][Y - 1].Element].Walkable then InputDeltaY := -1;
							end;
						end;
					end;
				end;

				if (InputDeltaX = 0) and (InputDeltaY <> 0) then begin
					if ElementDefs[Board.Tiles[X][Y + InputDeltaY].Element].PlaceableOnTop then begin
						if not ElementDefs[Board.Tiles[X][Y + InputDeltaY].Element].Walkable then begin
							if ElementDefs[Board.Tiles[X + 1][Y + InputDeltaY].Element].Walkable then begin
								if ElementDefs[Board.Tiles[X - 1][Y + InputDeltaY].Element].Walkable then begin
									InputDeltaX := (Random(2) * 2) - 1;
								end else begin
									InputDeltaX := 1;
								end;
							end else begin
								if ElementDefs[Board.Tiles[X - 1][Y + InputDeltaY].Element].Walkable then InputDeltaX := -1;
							end;
						end;
					end;
				end;
			end;

			if (P1 > 0) or (P2 < 1) then
				{ MOVEMENT }
				if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
					ElementDefs[Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element].TouchProc(
						X + InputDeltaX, Y + InputDeltaY, 0, InputDeltaX, InputDeltaY);
					if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
						if SoundEnabled and not SoundIsPlaying then
							Sound(110);
						if ElementDefs[Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element].Walkable then begin
							if SoundEnabled and not SoundIsPlaying then
								NoSound;
							MoveStat(0, X + InputDeltaX, Y + InputDeltaY);
						end else if SoundEnabled and not SoundIsPlaying then
							NoSound;
					end;
				end;

			{MOVEMENT DEBUG}
			{Str(InputDeltaX, bx);
			VideoWriteText(70, 5, $1D, bx + ' ');
			Str(InputDeltaY, bx);
			VideoWriteText(70, 6, $1D, bx + ' ');}

			if InputCheck(#27) or InputCheck('q') then begin
				WorldSave(99);
				GameFadeIn(2);
				GamePromptEndPlay;
				GameFadeIn(Board.Info.IsDark);
			end;
			if InputCheck('p') and (World.Info.Health > 0) then GamePaused := true;
			if InputCheck('b') then begin
				SoundEnabled := not SoundEnabled;
				SoundClearQueue;
				GameUpdateSidebar;
			end;
			if (InputCheck('?') and (P3 > 0)) then GameDebugPrompt;
			if InputCheck('i') and (Board.Stats[0].P2 = 0) then GameInventoryPrompt;
			if InputCheck('c') then begin
				DisplayClock := 1 - DisplayClock;
				GameUpdateSidebar;
			end;
			if InputCheck('h') and (WoahThere = 0) then begin
				if Board.Stats[0].P2 = 0 then begin
					WoahThere := 12;
					FlashHint := 12;
				end;
			end;
			
			if InputCheck('t') then begin
				if (Board.Info.IsDark = 1) and (World.Info.TorchTicks < 50) then begin
					if WorldGetFlagPosition('CANDLE') >= 0 then
						World.Info.TorchTicks := 220;
					if WorldGetFlagPosition('SCONCE') >= 0 then
						World.Info.TorchTicks := 440;
					if WorldGetFlagPosition('LANTERN') >= 0 then
						World.Info.TorchTicks := 880;			
					GameUpdateSidebar;			
				end;
			end;
			if InputCheck('d') then begin
				if (WorldGetFlagPosition('AMETHISP') < 0) or (World.Info.Register[1] > 0) then
						World.Info.Register[1] := 0
					else
						World.Info.Register[1] := 1;
				GameUpdateSidebar;
			end;

			if World.Info.TorchTicks > 0 then begin
				Dec(World.Info.TorchTicks);
				if World.Info.TorchTicks <= 161 then begin
					if WorldGetFlagPosition('SCONCE') >= 0 then
						World.Info.TorchTicks := World.Info.TorchTicks - 2;
					if WorldGetFlagPosition('LANTERN') >= 0 then
						World.Info.TorchTicks := World.Info.TorchTicks - 4;
				end;
				if World.Info.TorchTicks <= 0 then begin
					World.Info.TorchTicks := 0;
					SoundQueue(3, SoundParse('000x0xx0'));
				end;
				DrawPlayerSurroundings(X, Y);
				GameUpdateSidebar;
			end;
		end;
	end;

procedure ElementMonitorTick(statId: integer);
	begin
		if World.Info.PlayerColor = $00 then begin
			if ConfigPaper then begin
				World.Info.PlayerColor := $09;
			end else begin
				World.Info.PlayerColor := $1F;
			end;
		end;
		if UpCase(InputKeyPressed) in [#27, 'A', 'E', 'H', 'N', 'P', 'Q', 'R', 'S', 'W', '|'] then
			GamePlayExitRequested := true
		else
			SlowInput;
	end;

procedure InitElementDefs;
	var
		i: integer;
	begin
		for i := 0 to MAX_ELEMENT do
			with ElementDefs[i] do begin
				Character := ' ';
				Color := COLOR_CHOICE_ON_BLACK;
				Destructible := false;
				Pushable := false;
				VisibleInDark := false;
				PlaceableOnTop := false;
				Walkable := false;
				HasDrawProc := false;
				Cycle := -1;
				TickProc := ElementDefaultTick;
				DrawProc := ElementDefaultDraw;
				TouchProc := ElementDefaultTouch;
				Name := '';
				CategoryName := '';
				Param1Name := '';
				ParamTextName := '';
			end;

		ElementDefs[0].Character := ' ';
		ElementDefs[0].Color := $70;
		ElementDefs[0].Pushable := true;
		ElementDefs[0].Walkable := true;
		ElementDefs[0].Name := 'Empty';

		ElementDefs[3].Character := ' ';
		ElementDefs[3].Color := $07;
		ElementDefs[3].Cycle := 1;
		ElementDefs[3].TickProc := ElementMonitorTick;
		ElementDefs[3].Name := 'Monitor';

		ElementDefs[19].Character := #176;
		ElementDefs[19].PlaceableOnTop := true;
		ElementDefs[19].Walkable := true;
		ElementDefs[19].Name := 'Floor';
		ElementDefs[19].CategoryName := 'Terrains:';

		ElementDefs[20].Character := #176;
		ElementDefs[20].PlaceableOnTop := true;
		ElementDefs[20].Walkable := true;
		ElementDefs[20].HasDrawProc := true;
		ElementDefs[20].DrawProc := ElementVineDraw;
		ElementDefs[20].Name := 'Forest';

		ElementDefs[4].Character := #255;
		ElementDefs[4].Destructible := true;
		ElementDefs[4].Pushable := true;
		ElementDefs[4].VisibleInDark := true;
		ElementDefs[4].Cycle := 1;
		ElementDefs[4].TickProc := ElementPlayerTick;
		ElementDefs[4].Name := 'Player';
		ElementDefs[4].CategoryName := 'Items:';

		ElementDefs[41].Character := #234;
		ElementDefs[41].PlaceableOnTop := true;
		ElementDefs[41].Name := 'Lion';

		ElementDefs[42].Character := #227;
		ElementDefs[42].PlaceableOnTop := true;
		ElementDefs[42].Name := 'Tiger';

		ElementDefs[44].Character := #233;
		ElementDefs[44].PlaceableOnTop := true;
		ElementDefs[44].Name := 'Head';

		ElementDefs[45].Character := #228;
		ElementDefs[45].Name := 'bigdoor';
		ElementDefs[45].HasDrawProc := true;
		ElementDefs[45].DrawProc := ElementBigDoorDraw;
		ElementDefs[45].TouchProc := ElementBigDoorTouch;

		ElementDefs[54].Character := #222;
		ElementDefs[54].Name := 'bdopen';
		ElementDefs[54].HasDrawProc := true;
		ElementDefs[54].DrawProc := ElementBigDoorSwingDraw;

		ElementDefs[55].Character := #222;
		ElementDefs[55].Name := 'bdclose';
		ElementDefs[55].HasDrawProc := true;
		ElementDefs[55].DrawProc := ElementBigDoorSwingDraw;

		ElementDefs[56].Character := ' ';
		ElementDefs[56].Walkable := true;
		ElementDefs[56].Name := 'bdunder';

		ElementDefs[18].Character := #248;
		ElementDefs[18].PlaceableOnTop := true;
		ElementDefs[18].Name := 'Bullet';

		ElementDefs[15].Character := #253;
		ElementDefs[15].PlaceableOnTop := true;
		ElementDefs[15].Walkable := true;
		ElementDefs[15].Name := 'Star';

		ElementDefs[8].Character := #12;
		ElementDefs[8].PlaceableOnTop := true;
		ElementDefs[8].Name := 'Key';

		ElementDefs[5].Character := #132;
		ElementDefs[5].PlaceableOnTop := true;
		ElementDefs[5].Name := 'Ammo';

		ElementDefs[7].Character := #4;
		ElementDefs[7].PlaceableOnTop := true;
		ElementDefs[7].Name := 'Gem';

		ElementDefs[11].Character := #240;
		ElementDefs[11].PlaceableOnTop := true;
		ElementDefs[11].Name := 'Passage';

		ElementDefs[9].Character := #10;
		ElementDefs[9].PlaceableOnTop := true;
		ElementDefs[9].Name := 'Door';

		ElementDefs[10].Character := #232;
		ElementDefs[10].PlaceableOnTop := true;
		ElementDefs[10].Name := 'Scroll';

		ElementDefs[12].Character := #250;
		ElementDefs[12].PlaceableOnTop := true;
		ElementDefs[12].Name := 'Duplicator';

		ElementDefs[6].Character := #157;
		ElementDefs[6].PlaceableOnTop := true;
		ElementDefs[6].Name := 'Torch';

		ElementDefs[39].Character := #24;
		ElementDefs[39].PlaceableOnTop := true;
		ElementDefs[39].Name := 'Spinning gun';

		ElementDefs[35].Character := #5;
		ElementDefs[35].PlaceableOnTop := true;
		ElementDefs[35].Name := 'Ruffian';

		ElementDefs[34].Character := #153;
		ElementDefs[34].PlaceableOnTop := true;
		ElementDefs[34].Name := 'Bear';

		ElementDefs[37].Character := #211;
		ElementDefs[37].Name := 'Slime';
		ElementDefs[37].PlaceableOnTop := true;

		ElementDefs[38].Character := '^';
		ElementDefs[38].PlaceableOnTop := true;
		ElementDefs[38].Name := 'Shark';

		ElementDefs[16].Character := #220;
		ElementDefs[16].Name := 'Clockwise';
		ElementDefs[16].PlaceableOnTop := true;

		ElementDefs[17].Character := #221;
		ElementDefs[17].Name := 'Counter';
		ElementDefs[17].PlaceableOnTop := true;

		ElementDefs[21].Character := #219;
		ElementDefs[21].Name := 'Solid';
		ElementDefs[21].PlaceableOnTop := true;

		ElementDefs[22].Character := #178;
		ElementDefs[22].Name := 'Normal';
		ElementDefs[22].PlaceableOnTop := true;

		ElementDefs[31].Character := #206;
		ElementDefs[31].HasDrawProc := true;
		ElementDefs[31].DrawProc := ElementLineDraw;
		ElementDefs[31].Name := 'Line';
		ElementDefs[31].PlaceableOnTop := true;

		ElementDefs[43].Character := #147;
		ElementDefs[43].PlaceableOnTop := true;

		ElementDefs[33].Character := #146;
		ElementDefs[33].PlaceableOnTop := true;

		ElementDefs[32].Character := '*';
		ElementDefs[32].Name := 'Ricochet';
		ElementDefs[32].PlaceableOnTop := true;

		ElementDefs[23].Character := #177;
		ElementDefs[23].PlaceableOnTop := true;
		ElementDefs[23].Walkable := true;
		ElementDefs[23].Name := 'Breakable';

		ElementDefs[24].Character := #254;
		ElementDefs[24].Pushable := true;
		ElementDefs[24].Name := 'Egg';

		ElementDefs[25].Character := #18;
		ElementDefs[25].PlaceableOnTop := true;
		ElementDefs[25].Name := 'Slider (NS)';

		ElementDefs[26].Character := #29;
		ElementDefs[26].PlaceableOnTop := true;
		ElementDefs[26].Name := 'Slider (EW)';

		ElementDefs[30].Character := #243;
		ElementDefs[30].Walkable := true;
		ElementDefs[30].PlaceableOnTop := true;
		ElementDefs[30].Name := 'Shedspace';
		ElementDefs[30].HasDrawProc := true;
		ElementDefs[30].DrawProc := ElementShedSpaceDraw;

		ElementDefs[40].Character := #31;
		ElementDefs[40].PlaceableOnTop := true;
		ElementDefs[40].Name := 'Pusher';

		ElementDefs[13].Character := #11;
		ElementDefs[13].PlaceableOnTop := true;
		ElementDefs[13].Name := 'Bomb';

		ElementDefs[14].Character := #127;
		ElementDefs[14].PlaceableOnTop := true;
		ElementDefs[14].Name := 'Energizer';

		ElementDefs[29].Character := #176;
		ElementDefs[29].PlaceableOnTop := true;
		ElementDefs[29].Walkable := true;
		ElementDefs[29].Name := 'Overlay';

		ElementDefs[27].Character := #178;
		ElementDefs[27].PlaceableOnTop := true;
		ElementDefs[27].Walkable := true;
		ElementDefs[27].Name := 'Fake';

		ElementDefs[28].Character := ' ';
		ElementDefs[28].TouchProc := ElementInvisibleTouch;
		ElementDefs[28].Name := 'Invisible';

		ElementDefs[36].Character := #2;
		ElementDefs[36].Cycle := 3;
		ElementDefs[36].HasDrawProc := true;
		ElementDefs[36].DrawProc := ElementObjectDraw;
		ElementDefs[36].TickProc := ElementObjectTick;
		ElementDefs[36].TouchProc := ElementObjectTouch;
		ElementDefs[36].Name := 'Object';
		ElementDefs[36].Param1Name := 'Character?';
		ElementDefs[36].ParamTextName := 'Edit Program';

		ElementDefs[2].TickProc := ElementMessageTimerTick;
{ ## GLOBAL OBJECT }
		ElementDefs[46].TickProc := ElementGlobalTick;
{ ## END GLOBAL OBJECT }
		ElementDefs[1].TouchProc := ElementBoardEdgeTouch;

		ElementDefs[47].PlaceableOnTop := true;
		ElementDefs[47].Walkable := true;
		ElementDefs[47].Name := 'Bluetext';
		ElementDefs[48].PlaceableOnTop := true;
		ElementDefs[48].Walkable := true;
		ElementDefs[48].Name := 'Greentext';
		ElementDefs[49].PlaceableOnTop := true;
		ElementDefs[49].Walkable := true;
		ElementDefs[49].Name := 'Cyantext';
		ElementDefs[50].PlaceableOnTop := true;
		ElementDefs[50].Walkable := true;
		ElementDefs[50].Name := 'Redtext';
		ElementDefs[51].PlaceableOnTop := true;
		ElementDefs[51].Walkable := true;
		ElementDefs[51].Name := 'Graytext';
		ElementDefs[52].PlaceableOnTop := true;
		ElementDefs[52].Walkable := true;
		ElementDefs[52].Name := 'Browntext';
		ElementDefs[53].PlaceableOnTop := true;
		ElementDefs[53].Walkable := true;
		ElementDefs[53].Name := 'Whitetext';

	end;

procedure InitElementsGame;
	begin
		InitElementDefs;
		ForceDarknessOff := false;
	end;

begin
end.
