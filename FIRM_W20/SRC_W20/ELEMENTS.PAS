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
	function AsColor(fg, bg: integer): byte;
	procedure ElementMove(oldX, oldY, newX, newY: integer);
	procedure ElementPushablePush(x, y: integer; deltaX, deltaY: integer);
	function ElementDuplicate(srcX, srcY, dstX, dstY, statId: integer): boolean;
	procedure DrawPlayerSurroundings(x, y: integer);
	procedure DrawBombSurroundings(x, y: integer; bombPhase: integer);
	procedure GamePromptEndPlay;
	procedure ResetMessageNotShownFlags;
	procedure InitElementsGame;

implementation
uses Crt, Video, Sounds, Input, TxtWind, Oop, Game;

const
	TransporterNSChars: string = '^~^-v_v-';
	TransporterEWChars: string = '(<('#179')>)'#179;
	StarAnimChars: string = #179'/'#196'\';

function AsColor(fg, bg: integer): byte;
	begin
		AsColor := ((bg * 16) + fg) + $00;
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

procedure ElementDamagingTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		BoardAttack(sourceStatId, x, y);
	end;

procedure ElementLionTick(statId: integer);
	var
		deltaX, deltaY: integer;
	begin
		with Board.Stats[statId] do begin
			if P1 < Random(10) then
				CalcDirectionRnd(deltaX, deltaY)
			else
				CalcDirectionSeek(X, Y, deltaX, deltaY);

			if ElementDefs[Board.Tiles[X + deltaX][Y + deltaY].Element].Walkable then begin
				MoveStat(statId, X + deltaX, Y + deltaY);
			end else if Board.Tiles[X + deltaX][Y + deltaY].Element = E_PLAYER then begin
				BoardAttack(statId, X + deltaX, Y + deltaY)
			end;
		end;
	end;

procedure ElementTigerTick(statId: integer);
	var
		shot: boolean;
		element: byte;
	begin
		with Board.Stats[statId] do begin
			element := E_BULLET;
			if P2 >= $80 then
				element := E_STAR;

			if (Random(10) * 3) <= (P2 mod $80) then begin
				if Difference(X, Board.Stats[0].X) <= 2 then begin
					shot := BoardShoot(element, X, Y, 0, Signum(Board.Stats[0].Y - Y), SHOT_SOURCE_ENEMY);
				end else begin
					shot := false;
				end;

				if not shot then begin
					if Difference(Y, Board.Stats[0].Y) <= 2 then begin
						shot := BoardShoot(element, X, Y, Signum(Board.Stats[0].X - X), 0, SHOT_SOURCE_ENEMY);
					end;
				end;
			end;

			ElementLionTick(statId);
		end;
	end;

procedure ElementRuffianTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			if (StepX = 0) and (StepY = 0) then begin
				if (P2 + 8) <= Random(17) then begin
					if P1 >= Random(9) then
						CalcDirectionSeek(X, Y, StepX, StepY)
					else
						CalcDirectionRnd(StepX, StepY);
				end;
			end else begin
				if ((Y = Board.Stats[0].Y) or (X = Board.Stats[0].X)) and (Random(9) <= P1) then begin
					CalcDirectionSeek(X, Y, StepX, StepY);
				end;

				with Board.Tiles[X + StepX][Y + StepY] do begin
					if Element = E_PLAYER then begin
						BoardAttack(statId, X + StepX, Y + StepY)
					end else if ElementDefs[Element].Walkable then begin
						MoveStat(statId, X + StepX, Y + StepY);
						if (P2 + 8) <= Random(17) then begin
							StepX := 0;
							StepY := 0;
						end;
					end else begin
						StepX := 0;
						StepY := 0;
					end;
				end;

			end;
		end;
	end;

procedure ElementBearTick(statId: integer);
	var
		deltaX, deltaY: integer;
	label Movement;
	begin
		with Board.Stats[statId] do begin
			if X <> Board.Stats[0].X then
				if Difference(Y, Board.Stats[0].Y) <= (8 - P1) then begin
					deltaX := Signum(Board.Stats[0].X - X);
					deltaY := 0;
					goto Movement;
				end;

			if Difference(X, Board.Stats[0].X) <= (8 - P1) then begin
				deltaY := Signum(Board.Stats[0].Y - Y);
				deltaX := 0;
			end else begin
				deltaX := 0;
				deltaY := 0;
			end;

		Movement:
			with Board.Tiles[X + deltaX][Y + deltaY] do begin
				if ElementDefs[Element].Walkable then begin
					MoveStat(statId, X + deltaX, Y + deltaY);
				end else if (Element = E_PLAYER) or (Element = E_BREAKABLE) then begin
					BoardAttack(statId, X + deltaX, Y + deltaY)
				end;
			end;

		end;
	end;

procedure ElementCentipedeHeadTick(statId: integer);
	var
		ix, iy: integer;
		tx, ty: integer;
		tmp: integer;
	begin
		with Board.Stats[statId] do begin
			if (X = Board.Stats[0].X) and (Random(10) < P1) then begin
				StepY := Signum(Board.Stats[0].Y - Y);
				StepX := 0;
			end else if (Y = Board.Stats[0].Y) and (Random(10) < P1) then begin
				StepX := Signum(Board.Stats[0].X - X);
				StepY := 0;
			end else if ((Random(10) * 4) < P2) or ((StepX = 0) and (StepY = 0)) then begin
				CalcDirectionRnd(StepX, StepY);
			end;

			if not ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable
				and (Board.Tiles[X + StepX][Y + StepY].Element <> E_PLAYER) then
			begin
				ix := StepX;
				iy := StepY;
				tmp := ((Random(2) * 2) - 1) * StepY;
				StepY := ((Random(2) * 2) - 1) * StepX;
				StepX := tmp;
				if not ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable
					and (Board.Tiles[X + StepX][Y + StepY].Element <> E_PLAYER) then
				begin
					StepX := -StepX;
					StepY := -StepY;
					if not ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable
						and (Board.Tiles[X + StepX][Y + StepY].Element <> E_PLAYER) then
					begin
						if ElementDefs[Board.Tiles[X - ix][Y - iy].Element].Walkable
							or (Board.Tiles[X - ix][Y - iy].Element = E_PLAYER) then
						begin
							StepX := -ix;
							StepY := -iy;
						end else begin
							StepX := 0;
							StepY := 0;
						end;
					end;
				end;
			end;

			if (StepX = 0) and (StepY = 0) then begin
				Board.Tiles[X][Y].Element := E_CENTIPEDE_SEGMENT;
				Leader := -1;
				while Board.Stats[statId].Follower > 0 do begin
					tmp := Board.Stats[statId].Follower;
					Board.Stats[statId].Follower := Board.Stats[statId].Leader;
					Board.Stats[statId].Leader := tmp;
					statId := tmp;
				end;
				Board.Stats[statId].Follower := Board.Stats[statId].Leader;
				Board.Tiles[Board.Stats[statId].X][Board.Stats[statId].Y].Element := E_CENTIPEDE_HEAD;
			end else if Board.Tiles[X + StepX][Y + StepY].Element = E_PLAYER then begin
				if Follower <> -1 then begin
					Board.Tiles[Board.Stats[Follower].X][Board.Stats[Follower].Y].Element := E_CENTIPEDE_HEAD;
					Board.Stats[Follower].StepX := StepX;
					Board.Stats[Follower].StepY := StepY;
					BoardDrawTile(Board.Stats[Follower].X, Board.Stats[Follower].Y);
				end;
				BoardAttack(statId, X + StepX, Y + StepY);
			end else begin
				MoveStat(statId, X + StepX, Y + StepY);
				tx := X - StepX;
				ty := Y - StepY;
				ix := StepX;
				iy := StepY;

				repeat
					with Board.Stats[statId] do begin
						tx := X - StepX;
						ty := Y - StepY;
						ix := StepX;
						iy := StepY;
						if Follower < 0 then begin
							if (Board.Tiles[tx - ix][ty - iy].Element = E_CENTIPEDE_SEGMENT)
								and (Board.Stats[GetStatIdAt(tx - ix, ty - iy)].Leader < 0) then
							begin
								Follower := GetStatIdAt(tx - ix, ty - iy)
							end else if (Board.Tiles[tx - iy][ty - ix].Element = E_CENTIPEDE_SEGMENT)
								and (Board.Stats[GetStatIdAt(tx - iy, ty - ix)].Leader < 0) then
							begin
								Follower := GetStatIdAt(tx - iy, ty - ix);
							end else if (Board.Tiles[tx + iy][ty + ix].Element = E_CENTIPEDE_SEGMENT)
								and (Board.Stats[GetStatIdAt(tx + iy, ty + ix)].Leader < 0) then
							begin
								Follower := GetStatIdAt(tx + iy, ty + ix);
							end;
						end;

						if Follower > 0 then begin
							Board.Stats[Follower].Leader := statId;
							Board.Stats[Follower].P1 := P1;
							Board.Stats[Follower].P2 := P2;
							Board.Stats[Follower].StepX := tx - Board.Stats[Follower].X;
							Board.Stats[Follower].StepY := ty - Board.Stats[Follower].Y;
							MoveStat(Follower, tx, ty);
						end;
						statId := Follower;
					end;
				until statId = -1;
			end;
		end;
	end;

procedure ElementCentipedeSegmentTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			if Leader < 0 then begin
				if Leader < -1 then
					Board.Tiles[X][Y].Element := E_CENTIPEDE_HEAD
				else
					Leader := Leader - 1;
			end;
		end;
	end;

procedure ElementBulletTick(statId: integer);
	var
		ix, iy: integer;
		iStat: integer;
		iElem: byte;
		firstTry: boolean;
	label TryMove;
	label BulletExpire;
	begin
		with Board.Stats[statId] do begin
			if P2 < ParamList[122] then
				goto BulletExpire
			else
				P2 := P2 - ParamList[122];
			firstTry := true;

		TryMove:
			ix := X + StepX;
			iy := Y + StepY;
			iElem := Board.Tiles[ix][iy].Element;

			if ElementDefs[iElem].Walkable or (iElem = E_WATER) then begin
				MoveStat(statId, ix, iy);
				exit;
			end;

			if (iElem = E_RICOCHET) and firstTry then begin
				StepX := -StepX;
				StepY := -StepY;
				SoundQueue(1, SoundParse(ConfigList[53]));
				firstTry := false;
				goto TryMove;
				exit;
			end;

			if (iElem = E_BREAKABLE)
				or (ElementDefs[iElem].Destructible and ((iElem = E_PLAYER) or (P1 = 0))) then
			begin
				if ElementDefs[iElem].ScoreValue <> 0 then begin
					World.Info.Score := World.Info.Score + ElementDefs[iElem].ScoreValue;
					GameUpdateSidebar;
				end;
				BoardAttack(statId, ix, iy);
				exit;
			end;

			if (Board.Tiles[X + StepY][Y + StepX].Element = E_RICOCHET) and firstTry then begin
				ix := StepX;
				StepX := -StepY;
				StepY := -ix;
				SoundQueue(1, SoundParse(ConfigList[53]));
				firstTry := false;
				goto TryMove;
				exit;
			end;

			if (Board.Tiles[X - StepY][Y - StepX].Element = E_RICOCHET) and firstTry then begin
				ix := StepX;
				StepX := StepY;
				StepY := ix;
				SoundQueue(1, SoundParse(ConfigList[53]));
				firstTry := false;
				goto TryMove;
				exit;
			end;

		BulletExpire:
			if (iElem = E_OBJECT) or (iElem = E_SCROLL) then begin
				if (P1 = ParamList[119]) or (P1 = SHOT_SOURCE_PLAYER) then begin
					iStat := GetStatIdAt(ix, iy);
					if OopSend(-iStat, 'SHOT', false) then begin end;
				end;
			end;
			RemoveStat(statId);
			CurrentStatTicked := CurrentStatTicked - 1;
		end;
	end;

procedure ElementSpinningGunDraw(x, y: integer; var ch: byte);
	begin
		case CurrentTick mod 8 of
			0, 1: ch := 24;
			2, 3: ch := 26;
			4, 5: ch := 25;
		else ch := 27 end;
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

procedure ElementSpinningGunTick(statId: integer);
	var
		shot: boolean;
		deltaX, deltaY: integer;
		element: byte;
	begin
		with Board.Stats[statId] do begin
			BoardDrawTile(X, Y);

			element := E_BULLET;
			if P2 >= $80 then
				element := E_STAR;

			if Random(9) < (P2 mod $80) then begin
				if Random(9) <= P1 then begin
					if Difference(X, Board.Stats[0].X) <= 2 then begin
						shot := BoardShoot(element, X, Y, 0, Signum(Board.Stats[0].Y - Y), SHOT_SOURCE_ENEMY);
					end else begin
						shot := false;
					end;

					if not shot then begin
						if Difference(Y, Board.Stats[0].Y) <= 2 then begin
							shot := BoardShoot(element, X, Y, Signum(Board.Stats[0].X - X), 0, SHOT_SOURCE_ENEMY);
						end;
					end;
				end else begin
					CalcDirectionRnd(deltaX, deltaY);
					shot := BoardShoot(element, X, Y, deltaX, deltaY, SHOT_SOURCE_ENEMY);
				end;
			end;
		end;
	end;

procedure ElementConveyorTick(x, y: integer; direction: integer);
	var
		i: integer;
		iStat: integer;
		ix, iy: integer;
		canMove: boolean;
		tiles: array[0..7] of TTile;
		iMin, iMax: integer;
		tmpTile: TTile;
	begin
		if direction = 1 then begin
			iMin := 0;
			iMax := 8;
		end else begin
			iMin := 7;
			iMax := -1;
		end;

		canMove := true;
		i := iMin;
		repeat
			tiles[i] := Board.Tiles[x + DiagonalDeltaX[i]][y + DiagonalDeltaY[i]];
			with tiles[i] do begin
				if Element = E_EMPTY then
					canMove := true
				else if not ElementDefs[Element].Pushable then
					canMove := false;
			end;
			i := i + direction;
		until i = iMax;

		i := iMin;
		repeat
			with tiles[i] do begin
				if canMove then begin
					if ElementDefs[Element].Pushable then begin
						ix := x + DiagonalDeltaX[(i - direction + 8) mod 8];
						iy := y + DiagonalDeltaY[(i - direction + 8) mod 8];
						if ElementDefs[Element].Cycle > -1 then begin
							tmpTile := Board.Tiles[x + DiagonalDeltaX[i]][y + DiagonalDeltaY[i]];
							iStat := GetStatIdAt(x + DiagonalDeltaX[i], y + DiagonalDeltaY[i]);
							Board.Tiles[x + DiagonalDeltaX[i]][y + DiagonalDeltaY[i]] := tiles[i];
							Board.Tiles[ix][iy].Element := E_EMPTY;
							MoveStat(iStat, ix, iy);
							Board.Tiles[x + DiagonalDeltaX[i]][y + DiagonalDeltaY[i]] := tmpTile;
						end else begin
							Board.Tiles[ix][iy] := tiles[i];
							BoardDrawTile(ix, iy);
						end;
						if not ElementDefs[tiles[(i + direction + 8) mod 8].Element].Pushable then begin
							Board.Tiles[x + DiagonalDeltaX[i]][y + DiagonalDeltaY[i]].Element := E_EMPTY;
							BoardDrawTile(x + DiagonalDeltaX[i], y + DiagonalDeltaY[i]);
						end;
					end else begin
						canMove := false;
					end;
				end else if Element = E_EMPTY then
					canMove := true
				else if not ElementDefs[Element].Pushable then
					canMove := false;
			end;
			i := i + direction;
		until i = iMax;
	end;

procedure ElementConveyorCWDraw(x, y: integer; var ch: byte);
	begin
		case (CurrentTick div ElementDefs[E_CONVEYOR_CW].Cycle) mod 4 of
			0: ch := 179;
			1: ch := 47;
			2: ch := 196;
		else ch := 92 end;
	end;

procedure ElementConveyorCWTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			BoardDrawTile(X, Y);
			ElementConveyorTick(X, Y, 1);
		end;
	end;

procedure ElementConveyorCCWDraw(x, y: integer; var ch: byte);
	begin
		case (CurrentTick div ElementDefs[E_CONVEYOR_CCW].Cycle) mod 4 of
			3: ch := 179;
			2: ch := 47;
			1: ch := 196;
		else ch := 92 end;
	end;

procedure ElementConveyorCCWTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			BoardDrawTile(X, Y);
			ElementConveyorTick(X, Y, -1);
		end;
	end;

procedure ElementBombDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do
			if P1 <= 1 then
				ch := 11
			else
				ch := 48 + P1;
	end;

procedure ElementBombTick(statId: integer);
	var
		oldX, oldY: integer;
	begin
		with Board.Stats[statId] do begin
			if P1 > 0 then begin
				P1 := P1 - 1;
				BoardDrawTile(X, Y);

				if P1 = 1 then begin
					SoundQueue(1, SoundParse(ConfigList[5]));
					DrawBombSurroundings(X, Y, 1);
				end else if P1 = 0 then begin
					oldX := X;
					oldY := Y;
					RemoveStat(statId);
					DrawBombSurroundings(oldX, oldY, 2);
				end else begin
					if (P1 mod 2) = 0 then
						SoundQueue(1, SoundParse(ConfigList[4]))
					else
						SoundQueue(1, SoundParse(ConfigList[3]));
				end;
			end;
		end;
	end;

procedure ElementBombTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do begin
			if P1 = 0 then begin
				P1 := 9;
				BoardDrawTile(X, Y);
				DisplayMessage(200, ConfigList[1]);
				SoundQueue(4, SoundParse(ConfigList[2]));
			end else begin
				ElementPushablePush(X, Y, deltaX, deltaY);
			end;
		end;
	end;

procedure ElementTransporterMove(x, y, deltaX, deltaY: integer);
	var
		ix, iy: integer;
		newX, newY: integer;
		iStat: integer;
		finishSearch: boolean;
		isValidDest: boolean;
	begin
		with Board.Stats[GetStatIdAt(x + deltaX, y + deltaY)] do begin
			if (deltaX = StepX) and (deltaY = StepY) then begin
				ix := X;
				iy := Y;
				newX := -1;
				finishSearch := false;
				isValidDest := true;
				repeat
					ix := ix + deltaX;
					iy := iy + deltaY;
					with Board.Tiles[ix][iy] do begin
						if Element = E_BOARD_EDGE then
							finishSearch := true
						else if isValidDest then begin
							isValidDest := false;

							if not ElementDefs[Element].Walkable then
								ElementPushablePush(ix, iy, deltaX, deltaY);

							if ElementDefs[Element].Walkable then begin
								finishSearch := true;
								newX := ix;
								newY := iy;
							end else begin
								newX := -1
							end;
						end;
						if Element = E_TRANSPORTER then begin
							iStat := GetStatIdAt(ix, iy);
							if (Board.Stats[iStat].StepX = -deltaX) and (Board.Stats[iStat].StepY = -deltaY) then
								isValidDest := true;
						end;
					end;
				until finishSearch;
				if newX <> -1 then begin
					ElementMove(X - deltaX, Y - deltaY, newX, newY);
					SoundQueue(3, SoundParse(ConfigList[62]));
				end;
			end;
		end;
	end;

procedure ElementTransporterTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		ElementTransporterMove(x - deltaX, y - deltaY, deltaX, deltaY);
		deltaX := 0;
		deltaY := 0;
	end;

procedure ElementTransporterTick(statId: integer);
	begin
		with Board.Stats[statId] do
			BoardDrawTile(X, Y);
	end;

procedure ElementTransporterDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do begin
			if StepX = 0 then
				ch := Ord(TransporterNSChars[StepY * 2 + 3 + (CurrentTick div Cycle) mod 4])
			else
				ch := Ord(TransporterEWChars[StepX * 2 + 3 + (CurrentTick div Cycle) mod 4]);
		end;
	end;

procedure ElementStarDraw(x, y: integer; var ch: byte);
	begin
		ch := Ord(StarAnimChars[(CurrentTick mod 4) + 1]);
		Board.Tiles[x][y].Color := Board.Tiles[x][y].Color + 1;
		if Board.Tiles[x][y].Color > 15 then
			Board.Tiles[x][y].Color := 9;
	end;

procedure ElementStarTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			if P2 < ParamList[121] then
				RemoveStat(statId)
			else begin
				P2 := P2 - ParamList[121];
				if (P2 mod 2) = 0 then begin
					CalcDirectionSeek(X, Y, StepX, StepY);
					with Board.Tiles[X + StepX][Y + StepY] do begin
						if (Element = E_PLAYER) or (Element = E_BREAKABLE) then begin
							BoardAttack(statId, X + StepX, Y + StepY);
						end else begin
							if not ElementDefs[Element].Walkable then
								ElementPushablePush(X + StepX, Y + StepY, StepX, StepY);

							if ElementDefs[Element].Walkable or (Element = E_WATER) then
								MoveStat(statId, X + StepX, Y + StepY);
						end;
					end;
				end;
			end;
			BoardDrawTile(X, Y);
		end;
	end;

procedure ElementEnergizerTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		SoundQueue(9, SoundParse(ConfigList[7])
			+ SoundParse(ConfigList[8])
			+ SoundParse(ConfigList[9])
			+ SoundParse(ConfigList[10]));

		Board.Tiles[x][y].Element := E_EMPTY;
		BoardDrawTile(x, y);

		World.Info.EnergizerTicks := ParamList[25];
		GameUpdateSidebar;

		if MessageEnergizerNotShown then begin
			DisplayMessage(200, ConfigList[6]);
			MessageEnergizerNotShown := false;
		end;

		if OopSend(0, 'ALL:ENERGIZE', false) then begin end;
	end;

procedure ElementSlimeTick(statId: integer);
	var
		dir, changedTiles: integer;
		startX, startY: integer;
		color: byte;
	begin
		with Board.Stats[statId] do begin
			if P1 < P2 then
				P1 := P1 + 1
			else begin
				color := Board.Tiles[X][Y].Color;
				P1 := 0;
				startX := X;
				startY := Y;
				changedTiles := 0;

				for dir := 0 to 3 do begin
					if ElementDefs[Board.Tiles[startX + NeighborDeltaX[dir]][startY + NeighborDeltaY[dir]].Element].Walkable then begin
						if changedTiles = 0 then begin
							MoveStat(statId, startX + NeighborDeltaX[dir], startY + NeighborDeltaY[dir]);
							Board.Tiles[startX][startY].Color := color;
							Board.Tiles[startX][startY].Element := E_BREAKABLE;
							BoardDrawTile(startX, startY);
						end else begin
							AddStat(startX + NeighborDeltaX[dir], startY + NeighborDeltaY[dir], E_SLIME, color,
								ElementDefs[E_SLIME].Cycle, StatTemplateDefault);
							Board.Stats[Board.StatCount].P2 := P2;
						end;

						changedTiles := changedTiles + 1;
					end;
				end;

				if changedTiles = 0 then begin
					RemoveStat(statId);
					Board.Tiles[startX][startY].Element := E_BREAKABLE;
					Board.Tiles[startX][startY].Color := color;
					BoardDrawTile(startX, startY);
				end;
			end;
		end;
	end;

procedure ElementSlimeTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		color: integer;
	begin
		color := Board.Tiles[x][y].Color;
		DamageStat(GetStatIdAt(x, y));
		Board.Tiles[x][y].Element := E_BREAKABLE;
		Board.Tiles[x][y].Color := color;
		BoardDrawTile(x, y);
	end;

procedure ElementSharkTick(statId: integer);
	var
		deltaX, deltaY: integer;
	begin
		with Board.Stats[statId] do begin
			if P1 < Random(10) then
				CalcDirectionRnd(deltaX, deltaY)
			else
				CalcDirectionSeek(X, Y, deltaX, deltaY);

			if Board.Tiles[X + deltaX][Y + deltaY].Element = E_WATER then
				MoveStat(statId, X + deltaX, Y + deltaY)
			else if Board.Tiles[X + deltaX][Y + deltaY].Element = E_PLAYER then
				BoardAttack(statId, X + deltaX, Y + deltaY);
		end;
	end;

procedure ElementBlinkWallDraw(x, y: integer; var ch: byte);
	begin
		ch := ParamList[44];
	end;

procedure ElementBlinkWallTick(statId: integer);
	var
		ix, iy: integer;
		hitBoundary: boolean;
		playerStatId: integer;
		el: integer;
	begin
		with Board.Stats[statId] do begin
			if P3 = 0 then
				P3 := P1 + 1;
			if P3 = 1 then begin
				ix := X + StepX;
				iy := Y + StepY;

				if StepX <> 0 then
					el := E_BLINK_RAY_EW
				else
					el := E_BLINK_RAY_NS;

				while (Board.Tiles[ix][iy].Element = el)
					and (Board.Tiles[ix][iy].Color = Board.Tiles[X][Y].Color) do
				begin
					Board.Tiles[ix][iy].Element := E_EMPTY;
					BoardDrawTile(ix, iy);
					ix := ix + StepX;
					iy := iy + StepY;
					P3 := (P2) * 2 + 1;
				end;

				if ((X + StepX) = ix) and ((Y + StepY) = iy) then begin
					hitBoundary := false;
					repeat
						if (Board.Tiles[ix][iy].Element <> E_EMPTY) and (ElementDefs[Board.Tiles[ix][iy].Element].Destructible) then
							BoardDamageTile(ix, iy);

						if Board.Tiles[ix][iy].Element = E_PLAYER then begin
							playerStatId := GetStatIdAt(ix, iy);
							if StepX <> 0 then begin
								if Board.Tiles[ix][iy - 1].Element = E_EMPTY then
									MoveStat(playerStatId, ix, iy - 1)
								else if Board.Tiles[ix][iy + 1].Element = E_EMPTY then
									MoveStat(playerStatId, ix, iy + 1);
							end else begin
								if Board.Tiles[ix + 1][iy].Element = E_EMPTY then
									MoveStat(playerStatId, ix + 1, iy)
								else if Board.Tiles[ix - 1][iy].Element = E_EMPTY then
									MoveStat(playerStatId, ix + 1, iy);
							end;

							if Board.Tiles[ix][iy].Element = E_PLAYER then begin
								while World.Info.Health > 0 do
									DamageStat(playerStatId);
								hitBoundary := true;
							end;
						end;

						if Board.Tiles[ix][iy].Element = E_EMPTY then begin
							Board.Tiles[ix][iy].Element := el;
							Board.Tiles[ix][iy].Color := Board.Tiles[X][Y].Color;
							BoardDrawTile(ix, iy);
						end else begin
							hitBoundary := true;
						end;

						ix := ix + StepX;
						iy := iy + StepY;
					until hitBoundary;

					P3 := (P2 * 2) + 1;
				end;
			end else begin
				P3 := P3 - 1;
			end;
		end;
	end;

procedure ElementMove(oldX, oldY, newX, newY: integer);
	var
		statId: integer;
	begin
		if (newX < 0) or (newX > (BOARD_WIDTH + 1)) then exit;
		if (newY < 0) or (newY > (BOARD_HEIGHT + 1)) then exit;

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
	begin
		if ((x + deltaX) < 0) or ((x + deltaX) > (BOARD_WIDTH + 1)) then exit;
		if ((y + deltaY) < 0) or ((y + deltaY) > (BOARD_HEIGHT + 1)) then exit;
		if (deltaX <> 0) or (deltaY <> 0) then begin
			with Board.Tiles[x][y] do begin
				if ((Element = E_SLIDER_NS) and (deltaX = 0)) or ((Element = E_SLIDER_EW) and (deltaY = 0))
					or ElementDefs[Element].Pushable then
				begin
					if Board.Tiles[x + deltaX][y + deltaY].Element = E_TRANSPORTER then
						ElementTransporterMove(x, y, deltaX, deltaY)
					else if Board.Tiles[x + deltaX][y + deltaY].Element <> E_EMPTY then
						ElementPushablePush(x + deltaX, y + deltaY, deltaX, deltaY);

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
	end;

procedure ElementDuplicatorDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do
			case P1 of
				1: ch := 250;
				2: ch := 249;
				3: ch := 248;
				4: ch := 111;
				5: ch := 79;
			else ch := 250 end;
	end;

procedure ElementObjectTick(statId: integer);
	var
		retVal: boolean;
	begin
		with Board.Stats[statId] do begin
			if DataPos >= 0 then
				retVal := OopExecute(statId, DataPos, 'Interaction')
			else
				retVal := true;

			if retVal then begin
				if ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable then
					MoveStat(statId, X + StepX, Y + StepY)
				else if (StepX <> 0) or (StepY <> 0) then
					retVal := OopSend(-statId, 'THUD', false);
			end;
		end;
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
		statId := GetStatIdAt(x, y);
		if InspectNext then begin
			InspectObjectCode(statid);
			InspectNext := false;
		end else
			retVal := OopSend(-statId, 'TOUCH', false);
	end;

function ElementDuplicate(srcX, srcY, dstX, dstY, statId: integer): boolean;
	var
		sourceStatId: integer;
	begin
		ElementDuplicate := false;
		if (srcX = dstX) and (srcY = dstY) then
			exit;
		with Board.Stats[statId] do begin
			with Board.Tiles[X + dstX][Y + dstY] do begin
				if Element = E_PLAYER then begin
					ElementDefs[Board.Tiles[X + srcX][Y + srcY].Element]
						.TouchProc(X + srcX, Y + srcY, 0, InputDeltaX, InputDeltaY);
					BoardDrawTile(X + srcX, Y + srcY);
				end else begin
					if Element <> E_EMPTY then
						ElementPushablePush(X + dstX, Y + dstY, dstX, dstY);

					if Element = E_EMPTY then begin
						sourceStatId := GetStatIdAt(X + srcX, Y + srcY);
						if sourceStatId > 0 then begin
							ElementDuplicate := true;
							AddStat(X + dstX, Y + dstY,
								Board.Tiles[X + srcX][Y + srcY].Element,
								Board.Tiles[X + srcX][Y + srcY].Color,
								Board.Stats[sourceStatId].Cycle,
								Board.Stats[sourceStatId]);
						end else if sourceStatId <> 0 then begin
							ElementDuplicate := true;
							Board.Tiles[X + dstX][Y + dstY]
								:= Board.Tiles[X + srcX][Y + srcY];
						end;
					end;
				end;
			end;
		end;
	end;

procedure ElementDuplicatorTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			Cycle := (9 - P2) * 3;
			if P1 <= 4 then
				Inc(P1)
			else begin
				P1 := 0;
				if ElementDuplicate(StepX,StepY,-StepX,-StepY,statId) then begin
					SoundQueue(3, SoundParse(ConfigList[50]));
					BoardDrawTile(X - StepX, Y - StepY);
				end else
					SoundQueue(3, SoundParse(ConfigList[51]));
			end;
			BoardDrawTile(X, Y);
		end;
	end;

procedure ElementScrollTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			Board.Tiles[X][Y].Color := Board.Tiles[X][Y].Color + 1;
			if Board.Tiles[X][Y].Color > $0F then
				Board.Tiles[X][Y].Color := $09;

			BoardDrawTile(X, Y);
		end;
	end;

procedure ElementScrollTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		textWindow: TTextWindowState;
		statId: integer;
		unk1: integer;
	begin
		statId := GetStatIdAt(x, y);

		with Board.Stats[statId] do begin
			textWindow.Selectable := false;
			textWindow.LinePos := 1;

			SoundQueue(2, SoundParse(ConfigList[60]));

			DataPos := 0;
			if OopExecute(statId, DataPos, 'Scroll') then begin end;
		end;

		RemoveStat(GetStatIdAt(x, y));
	end;

procedure ElementKeyTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		key: integer;
	begin
		key := Board.Tiles[x][y].Color and $07;

		if World.Info.Keys[key] >= ParamList[117] then begin
			DisplayMessage(200, ConfigList[15]+ColorNames[key]+ConfigList[16]);
			SoundQueue(2, SoundParse(ConfigList[17]));
		end else begin
			Inc(World.Info.Keys[key]);
			Board.Tiles[x][y].Element := E_EMPTY;
			GameUpdateSidebar;
			DisplayMessage(200, ConfigList[12]+ColorNames[key]+ConfigList[13]);
			SoundQueue(2, SoundParse(ConfigList[14]));
		end;
	end;

procedure ElementAmmoTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		World.Info.Ammo := World.Info.Ammo + ParamList[7];

		Board.Tiles[x][y].Element := E_EMPTY;
		GameUpdateSidebar;
		SoundQueue(2, SoundParse(ConfigList[25]));

		if MessageAmmoNotShown then begin
			MessageAmmoNotShown := false;
			DisplayMessage(200, ConfigList[24]);
		end;
	end;

procedure ElementGemTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		World.Info.Gems := World.Info.Gems + ParamList[14];
		World.Info.Health := World.Info.Health + ParamList[16];
		World.Info.Score := World.Info.Score + ParamList[15];

		Board.Tiles[x][y].Element := E_EMPTY;
		GameUpdateSidebar;
		SoundQueue(2, SoundParse(ConfigList[27]));

		if MessageGemNotShown then begin
			MessageGemNotShown := false;
			DisplayMessage(200, ConfigList[26]);
		end;
	end;

procedure ElementPassageTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		BoardPassageTeleport(x, y);
		deltaX := 0;
		deltaY := 0;
		if OopSend(0, 'ALL:' + OOPList[28], false) then begin end;
	end;

procedure ElementDoorTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		key: integer;
	begin
		key := (Board.Tiles[x][y].Color div 16) and $07;

		if World.Info.Keys[key] > 0 then begin
			Board.Tiles[x][y].Element := E_EMPTY;
			BoardDrawTile(x, y);

			Dec(World.Info.Keys[key]);
			GameUpdateSidebar;

			DisplayMessage(200, ConfigList[18]+ColorNames[key]+ConfigList[19]);
			SoundQueue(3, SoundParse(ConfigList[20]));
		end else begin
			DisplayMessage(200, ConfigList[21]+ColorNames[key]+ConfigList[22]);
			SoundQueue(3, SoundParse(ConfigList[23]));
		end;
	end;

procedure ElementPushableTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		ElementPushablePush(x, y, deltaX, deltaY);
		SoundQueue(2, SoundParse(ConfigList[52]));
	end;

procedure ElementPusherDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do begin
			if StepX = 1 then
				ch := 16
			else if StepX = -1 then
				ch := 17
			else if StepY = -1 then
				ch := 30
			else
				ch := 31;
		end;
	end;

procedure ElementPusherTick(statId: integer);
	var
		i, startX, startY: integer;
	begin
		with Board.Stats[statId] do begin
			startX := X;
			startY := Y;

			if not ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable then begin
				ElementPushablePush(X + StepX, Y + StepY, StepX, StepY);
			end;
		end;

		statId := GetStatIdAt(startX, startY);
		with Board.Stats[statId] do begin
			if ElementDefs[Board.Tiles[X + StepX][Y + StepY].Element].Walkable then begin
				MoveStat(statId, X + StepX, Y + StepY);
				SoundQueue(2, SoundParse(ConfigList[52]));

				if Board.Tiles[X - (StepX * 2)][Y - (StepY * 2)].Element = E_PUSHER then begin
					i := GetStatIdAt(X - (StepX * 2), Y - (StepY * 2));
					if (Board.Stats[i].StepX = StepX) and (Board.Stats[i].StepY = StepY) then
						ElementDefs[E_PUSHER].TickProc(i);
				end;
			end;
		end;
	end;

procedure ElementTorchTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		World.Info.Torches := World.Info.Torches + ParamList[11];
		Board.Tiles[x][y].Element := E_EMPTY;

		BoardDrawTile(x, y);
		GameUpdateSidebar;

		if MessageTorchNotShown then begin
			DisplayMessage(200, ConfigList[28]);
		end;
		MessageTorchNotShown := false;

		SoundQueue(3, SoundParse(ConfigList[29]));
	end;

procedure ElementInvisibleTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		with Board.Tiles[x][y] do begin
			Element := ParamList[43];
			BoardDrawTile(x, y);

			SoundQueue(3, SoundParse(ConfigList[32]));
			DisplayMessage(100, ConfigList[31]);
		end;
	end;

procedure ElementForestTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		Board.Tiles[x][y].Element := E_EMPTY;
		BoardDrawTile(x, y);

		SoundQueue(3, SoundParse(ConfigList[34]));

		if MessageForestNotShown then begin
			DisplayMessage(200, ConfigList[33]);
		end;
		MessageForestNotShown := false;
	end;

procedure ElementFakeTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		if MessageFakeNotShown then begin
			DisplayMessage(150, ConfigList[35]);
		end;
		MessageFakeNotShown := false;
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
				if OopSend(0, 'ALL:' + OOPList[28], false) then begin end;
			end else begin
				BoardChange(boardId);
			end;
		end;
	end;

procedure ElementWaterTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		SoundQueue(3, SoundParse(ConfigList[37]));
		DisplayMessage(100, ConfigList[36]);
	end;

procedure DrawPlayerSurroundings(x, y: integer);
	var
		ix, iy: integer;
	begin
		for ix := ((x - ParamList[109]) - 1) to ((x + ParamList[109]) + 1) do
			if (ix >= 1) and (ix <= BOARD_WIDTH) then
				for iy := ((y - ParamList[110]) - 1) to ((y + ParamList[110]) + 1) do
					if (iy >= 1) and (iy <= BOARD_HEIGHT) then
						with Board.Tiles[ix][iy] do begin
							BoardDrawTile(ix, iy);
						end;
	end;

procedure DrawBombSurroundings(x, y: integer; bombPhase: integer);
	var
		ix, iy: integer;
		istat: integer;
		result: boolean;
	begin
		for ix := ((x - ParamList[112]) - 1) to ((x + ParamList[112]) + 1) do
			if (ix >= 1) and (ix <= BOARD_WIDTH) then
				for iy := ((y - ParamList[113]) - 1) to ((y + ParamList[113]) + 1) do
					if (iy >= 1) and (iy <= BOARD_HEIGHT) then
						with Board.Tiles[ix][iy] do begin
							if (Sqr(ix-x) + Sqr(iy-y)*2) < ParamList[114] then begin
								if bombPhase = 1 then begin
									if Element = E_OBJECT then begin
										istat := GetStatIdAt(ix, iy);
										if istat > 0 then
											result := OopSend(-istat, 'BOMBED', false);
									end;

									if ElementDefs[Element].Destructible or (Element = E_STAR) then
										BoardDamageTile(ix, iy);

									if (Element = E_EMPTY) or (Element = E_BREAKABLE) then begin
										Element := E_BREAKABLE;
										Color := $09 + Random(7);
										BoardDrawTile(ix, iy);
									end;
								end else begin
									if Element = E_BREAKABLE then
										Element := E_EMPTY;
								end;
							end;
							BoardDrawTile(ix, iy);
						end;
	end;

procedure GamePromptEndPlay;
	begin
		if (World.Info.Health <= 0) and (World.Info.GracePeriod >= ParamList[118]) then begin
			GamePlayExitRequested := true;
			BoardDrawBorder;
		end else begin
			GamePlayExitRequested := SidebarPromptYesNo('End this game? ', true);
			if InputKeyPressed = #27 then
				GamePlayExitRequested := false;
		end;
		InputKeyPressed := #0;
	end;

procedure ElementPlayerTick(statId: integer);
	var
		i: integer;
		bulletCount: integer;
		inputC: char;
	begin
		with Board.Stats[statId] do begin
			if P3 = 1 then begin
				Dec(P3);
				BoardDrawBorder;
				Board.Info.Message := '';
			end else if P3 > 1 then begin
				VideoWriteText((60 - Length(Board.Info.Message)) div 2, 24, 9 + ((P3 - 1) mod 7), ' '+Board.Info.Message+' ');
				Dec(P3);
			end;

			if (World.Info.PlayerColor = 0) and (World.Info.PlayerChar = #0) then begin
				World.Info.PlayerChar := Chr(ParamList[3]);
				World.Info.PlayerColor := AsColor(ParamList[1],ParamList[2]);
				ElementDefs[E_PLAYER].Character := World.Info.PlayerChar;
				ElementDefs[E_PLAYER].Color := World.Info.PlayerColor;
			end;

			if World.Info.EnergizerTicks > 0 then begin
				if ElementDefs[E_PLAYER].Character = World.Info.PlayerChar then
					ElementDefs[E_PLAYER].Character := Chr(ParamList[100])
				else
					ElementDefs[E_PLAYER].Character := World.Info.PlayerChar;

				if (CurrentTick mod 2) <> 0 then
					Board.Tiles[X][Y].Color := (World.Info.PlayerColor and $0F)
				else
					Board.Tiles[X][Y].Color := AsColor(World.Info.PlayerColor and $0F,(CurrentTick mod 7) + 1);

				BoardDrawTile(X, Y);
			end else if (Board.Tiles[X][Y].Color <> World.Info.PlayerColor)
				or (ElementDefs[E_PLAYER].Character <> World.Info.PlayerChar) then begin
					Board.Tiles[X][Y].Color := World.Info.PlayerColor;
					ElementDefs[E_PLAYER].Character := World.Info.PlayerChar;
					BoardDrawTile(X, Y);
			end;

			if P2 = 1 then begin
				InputDeltaX := 0;
				InputDeltaY := 0;
				InputShiftPressed := false;
			end;

			if (World.Info.Health <= 0) then begin
				if World.Info.GracePeriod < ParamList[118] then begin
					Inc(World.Info.GracePeriod);
					if World.Info.GracePeriod = ParamList[118] - 1 then begin
						InputDeltaX := 0;
						InputDeltaY := 0;
						InputShiftPressed := false;
					end;
				end else begin
					if World.Info.GracePeriod = ParamList[118] then begin
						Inc(World.Info.GracePeriod);
						SoundQueue(5, SoundParse(ConfigList[39]));
						SoundBlockQueueing := true;
					end;
					InputDeltaX := 0;
					InputDeltaY := 0;
					InputShiftPressed := false;
					if P3 = 0 then
						DisplayMessage(250, ConfigList[38]);
					TickTimeDuration := 0;					
				end;
			end else
				World.Info.GracePeriod := 0;
			if InputShiftPressed or (InputKeyPressed = ' ') then begin
				if InputShiftPressed and ((InputDeltaX <> 0) or (InputDeltaY <> 0)) then begin
					PlayerDirX := InputDeltaX;
					PlayerDirY := InputDeltaY;
				end;

				if (PlayerDirX <> 0) or (PlayerDirY <> 0) then begin
					if Board.Info.MaxShots = 0 then begin
						if MessageNoShootingNotShown then
							DisplayMessage(200, ConfigList[40]);
						MessageNoShootingNotShown := false;
					end else if World.Info.Ammo = 0 then begin
						if MessageOutOfAmmoNotShown then
							DisplayMessage(200, ConfigList[41]);
						MessageOutOfAmmoNotShown := false;
					end else begin
						bulletCount := 0;
						for i := 0 to Board.StatCount do
							if (Board.Tiles[Board.Stats[i].X][Board.Stats[i].Y].Element = E_BULLET)
								and (Board.Stats[i].P1 = SHOT_SOURCE_PLAYER)
							then
								bulletCount := bulletCount + 1;

						if bulletCount < Board.Info.MaxShots then begin
							if BoardShoot(E_BULLET, X, Y, PlayerDirX, PlayerDirY, SHOT_SOURCE_PLAYER) then begin
								World.Info.Ammo := World.Info.Ammo - 1;
								GameUpdateSidebar;

								SoundQueue(2, SoundParse(ConfigList[42]));

								InputDeltaX := 0;
								InputDeltaY := 0;
							end;
						end;
					end;
				end;
			end else if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
				PlayerDirX := InputDeltaX;
				PlayerDirY := InputDeltaY;

				ElementDefs[Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element].TouchProc(
					X + InputDeltaX, Y + InputDeltaY, 0, InputDeltaX, InputDeltaY);
				if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
					if SoundEnabled and not SoundIsPlaying then
						Sound(110);
					if ElementDefs[Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element].Walkable then begin
						if SoundEnabled and not SoundIsPlaying then
							NoSound;

						MoveStat(0, X + InputDeltaX, Y + InputDeltaY);
					end else if SoundEnabled and not SoundIsPlaying then begin
						NoSound;
					end;
				end;
			end;

			inputC := UpCase(InputKeyPressed);
			if ((P2 = 1) and (inputC <> #27))
				and ((inputC <> UpCase(ConfigList[83][1]))
				and (inputC <> UpCase(ConfigList[77][1])))
			then
				inputC := #0;
			if inputC =	UpCase(ConfigList[70][1]) then begin
				if World.Info.TorchTicks = 0 then begin
					if World.Info.Torches > 0 then begin
						if Board.Info.IsDark > 0 then begin
							World.Info.Torches := World.Info.Torches - 1;
							World.Info.TorchTicks := ParamList[12];

							DrawPlayerSurroundings(X, Y);
							GameUpdateSidebar;
						end else begin
							if MessageRoomNotDarkNotShown then begin
								DisplayMessage(200, ConfigList[44]);
								MessageRoomNotDarkNotShown := false;
							end;
						end;
					end else begin
						if MessageOutOfTorchesNotShown then begin
							DisplayMessage(200, ConfigList[45]);
							MessageOutOfTorchesNotShown := false;
						end;
					end;
				end;
			end else if ((inputC = #27) or (inputC = 'Q')) then begin
				GamePromptEndPlay;
			end else if inputC = UpCase(ConfigList[77][1]) then begin
				GameWorldSave(ConfigList[78] + ':', SavedGameFileName, '.SAV');
			end else if inputC = UpCase(ConfigList[79][1]) then begin
				if World.Info.Health > 0 then
					GamePaused := true;
			end else if inputC = UpCase(ConfigList[72][1]) then begin
				SoundEnabled := not SoundEnabled;
				SoundClearQueue;
				GameUpdateSidebar;
				InputKeyPressed := ' ';
			end else if inputC = UpCase(ConfigList[75][1]) then begin
				TextWindowDisplayFile(World.Info.Name + '.HLP', 'Help for '+ World.Info.Name);
			end else if inputC = UpCase(ConfigList[83][1]) then begin
				GameDebugPrompt;
				InputKeyPressed := #0;
			end else begin
				i := 0;
				while i < KeyLimit do begin
					if inputC = UpCase(KeyList[i * 3][1]) then
						if OopSend(0, 'ALL:' + UpCaseString(KeyList[(i * 3) + 1]), false) then begin end;
					Inc(i);
				end;
			end;

			if World.Info.TorchTicks > 0 then begin
				Dec(World.Info.TorchTicks);
				if World.Info.TorchTicks = 0 then begin
					DrawPlayerSurroundings(X, Y);
					SoundQueue(3, SoundParse(ConfigList[30]));
				end;
				if ParamList[12] > 10 then
					if (World.Info.TorchTicks mod (ParamList[12] div 5)) = 0 then
						GameUpdateSidebar;
			end;

			if World.Info.EnergizerTicks > 0 then begin
				World.Info.EnergizerTicks := World.Info.EnergizerTicks - 1;

				if World.Info.EnergizerTicks = 10 then
					SoundQueue(9, SoundParse(ConfigList[11]))
				else if World.Info.EnergizerTicks <= 0 then begin
					Board.Tiles[X][Y].Color := World.Info.PlayerColor;
					BoardDrawTile(X, Y);
				end;
			end;

			if (Board.Info.TimeLimitSec > 0) and (World.Info.Health > 0) then
				if SoundHasTimeElapsed(World.Info.BoardTimeHsec, 100) then begin
					World.Info.BoardTimeSec := World.Info.BoardTimeSec + 1;

					if (Board.Info.TimeLimitSec - 10) = World.Info.BoardTimeSec then begin
						DisplayMessage(200, ConfigList[54]);
						SoundQueue(3, SoundParse(ConfigList[55]));
					end else if World.Info.BoardTimeSec > Board.Info.TimeLimitSec then begin
						DamageStat(0);
					end;

					GameUpdateSidebar;
				end;

		end;
	end;

procedure ElementMonitorTick(statId: integer);
	begin
		if UpCase(InputKeyPressed) in [#27, 'A', 'H', 'N', 'P', 'Q', 'R', 'S', 'W', '|'] then
			GamePlayExitRequested := true;
	end;

procedure ResetMessageNotShownFlags;
	begin
		MessageAmmoNotShown := true;
		MessageOutOfAmmoNotShown := true;
		MessageNoShootingNotShown := true;
		MessageTorchNotShown := true;
		MessageOutOfTorchesNotShown := true;
		MessageRoomNotDarkNotShown := true;
		MessageHintTorchNotShown := true;
		MessageForestNotShown := true;
		MessageFakeNotShown := true;
		MessageGemNotShown := true;
		MessageEnergizerNotShown := true;
		InspectNext := false;
		NoClip := false;
	end;

procedure InitElementDefs;
	var
		i, code: integer;
	begin
		for i := 0 to MAX_ELEMENT do
			with ElementDefs[i] do begin
				Character := ' ';
				Color := $00;
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
				Param1 := 0;
				Param2 := 0;
				ScoreValue := 0;
			end;

		ElementDefs[0].Character := ' ';
		ElementDefs[0].Color := AsColor(ParamList[95],ParamList[96]);
		ElementDefs[0].Pushable := true;
		ElementDefs[0].Walkable := true;
		ElementDefs[0].PlaceableOnTop := true;
		ElementDefs[0].Name := 'Empty';

		ElementDefs[3].Character := ' ';
		ElementDefs[3].Color := AsColor(ParamList[97],ParamList[98]);
		ElementDefs[3].Cycle := 1;
		ElementDefs[3].TickProc := ElementMonitorTick;
		ElementDefs[3].Name := 'Monitor';

		ElementDefs[19].Character := Chr(ParamList[31]);
		ElementDefs[19].PlaceableOnTop := true;
		ElementDefs[19].TouchProc := ElementWaterTouch;
		ElementDefs[19].Name := 'Water';

		ElementDefs[20].Character := Chr(ParamList[34]);
		ElementDefs[20].Color := AsColor(ParamList[32],ParamList[33]);
		ElementDefs[20].Walkable := false;
		ElementDefs[20].TouchProc := ElementForestTouch;
		ElementDefs[20].Name := 'Forest';

		ElementDefs[4].Character := Chr(ParamList[3]);
		ElementDefs[4].Color := AsColor(ParamList[1],ParamList[2]);
		ElementDefs[4].Destructible := true;
		ElementDefs[4].Pushable := true;
		ElementDefs[4].VisibleInDark := true;
		ElementDefs[4].Cycle := 1;
		ElementDefs[4].TickProc := ElementPlayerTick;
		ElementDefs[4].Name := 'Player';

		ElementDefs[41].Color := AsColor(ParamList[74],ParamList[75]);
		ElementDefs[41].Character := Chr(ParamList[76]);
		ElementDefs[41].Cycle := ParamList[77];
		ElementDefs[41].ScoreValue := ParamList[78];
		ElementDefs[41].Destructible := true;
		ElementDefs[41].Pushable := true;
		ElementDefs[41].TickProc := ElementLionTick;
		ElementDefs[41].TouchProc := ElementDamagingTouch;
		ElementDefs[41].Name := 'Lion';
		ElementDefs[41].Param1 := ParamList[79];

		ElementDefs[42].Color := AsColor(ParamList[80],ParamList[81]);
		ElementDefs[42].Character := Chr(ParamList[82]);
		ElementDefs[42].Cycle := ParamList[83];
		ElementDefs[42].ScoreValue := ParamList[84];
		ElementDefs[42].Destructible := true;
		ElementDefs[42].Pushable := true;
		ElementDefs[42].TickProc := ElementTigerTick;
		ElementDefs[42].TouchProc := ElementDamagingTouch;
		ElementDefs[42].Name := 'Tiger';
		ElementDefs[42].Param1 := ParamList[85];
		ElementDefs[42].Param2 := ParamList[86];

		ElementDefs[44].Character := Chr(ParamList[87]);
		ElementDefs[44].Cycle := ParamList[88];
		ElementDefs[44].ScoreValue := ParamList[89];
		ElementDefs[44].Destructible := true;
		ElementDefs[44].TickProc := ElementCentipedeHeadTick;
		ElementDefs[44].TouchProc := ElementDamagingTouch;
		ElementDefs[44].Name := 'Head';
		ElementDefs[44].Param1 := ParamList[90];
		ElementDefs[44].Param2 := ParamList[91];

		ElementDefs[45].Character := Chr(ParamList[92]);
		ElementDefs[45].Cycle := ParamList[93];
		ElementDefs[45].ScoreValue := ParamList[94];
		ElementDefs[45].Destructible := true;
		ElementDefs[45].TickProc := ElementCentipedeSegmentTick;
		ElementDefs[45].TouchProc := ElementDamagingTouch;
		ElementDefs[45].Name := 'Segment';

		ElementDefs[18].Character := Chr(ParamList[29]);
		ElementDefs[18].Color := AsColor(ParamList[27],ParamList[28]);
		ElementDefs[18].Destructible := true;
		ElementDefs[18].Cycle := ParamList[30];
		ElementDefs[18].TickProc := ElementBulletTick;
		ElementDefs[18].TouchProc := ElementDamagingTouch;
		ElementDefs[18].Name := 'Bullet';

		ElementDefs[15].Character := 'S';
		ElementDefs[15].Color := $0F;
		ElementDefs[15].Destructible := false;
		ElementDefs[15].Cycle := ParamList[26];
		ElementDefs[15].TickProc := ElementStarTick;
		ElementDefs[15].TouchProc := ElementDamagingTouch;
		ElementDefs[15].HasDrawProc := true;
		ElementDefs[15].DrawProc := ElementStarDraw;
		ElementDefs[15].Name := 'Star';

		ElementDefs[8].Character := Chr(ParamList[17]);
		ElementDefs[8].Pushable := true;
		ElementDefs[8].TouchProc := ElementKeyTouch;
		ElementDefs[8].Name := 'Key';

		ElementDefs[5].Character := Chr(ParamList[6]);
		ElementDefs[5].Color := AsColor(ParamList[4],ParamList[5]);
		ElementDefs[5].Pushable := true;
		ElementDefs[5].TouchProc := ElementAmmoTouch;
		ElementDefs[5].Name := 'Ammo';

		ElementDefs[7].Character := Chr(ParamList[13]);
		ElementDefs[7].Pushable := true;
		ElementDefs[7].TouchProc := ElementGemTouch;
		ElementDefs[7].Destructible := true;
		ElementDefs[7].Name := 'Gem';

		ElementDefs[11].Character := Chr(ParamList[19]);
		ElementDefs[11].Color := $0F;
		ElementDefs[11].Cycle := 0;
		ElementDefs[11].VisibleInDark := true;
		ElementDefs[11].TouchProc := ElementPassageTouch;
		ElementDefs[11].Name := 'Passage';
		ElementDefs[11].Param1 := ParamList[102];

		ElementDefs[9].Character := Chr(ParamList[18]);
		ElementDefs[9].Color := $0F;
		ElementDefs[9].TouchProc := ElementDoorTouch;
		ElementDefs[9].Name := 'Door';

		ElementDefs[10].Character := Chr(ParamList[99]);
		ElementDefs[10].Color := $0F;
		ElementDefs[10].TouchProc := ElementScrollTouch;
		ElementDefs[10].TickProc := ElementScrollTick;
		ElementDefs[10].Pushable := true;
		ElementDefs[10].Cycle := 1;
		ElementDefs[10].Name := 'Scroll';

		ElementDefs[12].Character := #250;
		ElementDefs[12].Color := $0F;
		ElementDefs[12].Cycle := 2;
		ElementDefs[12].TickProc := ElementDuplicatorTick;
		ElementDefs[12].HasDrawProc := true;
		ElementDefs[12].DrawProc := ElementDuplicatorDraw;
		ElementDefs[12].Name := 'Duplicator';
		ElementDefs[12].Param1 := ParamList[108];
		ElementDefs[12].Param2 := ParamList[107];

		ElementDefs[6].Character := Chr(ParamList[10]);
		ElementDefs[6].Color := AsColor(ParamList[8],ParamList[9]);
		ElementDefs[6].VisibleInDark := true;
		ElementDefs[6].TouchProc := ElementTorchTouch;
		ElementDefs[6].Name := 'Torch';

		ElementDefs[39].Character := #24;
		ElementDefs[39].Cycle := ParamList[71];
		ElementDefs[39].TickProc := ElementSpinningGunTick;
		ElementDefs[39].HasDrawProc := true;
		ElementDefs[39].DrawProc := ElementSpinningGunDraw;
		ElementDefs[39].Name := 'Spinning gun';
		ElementDefs[39].Param1 := ParamList[72];
		ElementDefs[39].Param2 := ParamList[73];

		ElementDefs[35].Color := AsColor(ParamList[56],ParamList[57]);
		ElementDefs[35].Character := Chr(ParamList[58]);
		ElementDefs[35].Cycle := ParamList[59];
		ElementDefs[35].ScoreValue := ParamList[60];
		ElementDefs[35].Destructible := true;
		ElementDefs[35].Pushable := true;
		ElementDefs[35].TickProc := ElementRuffianTick;
		ElementDefs[35].TouchProc := ElementDamagingTouch;
		ElementDefs[35].Name := 'Ruffian';
		ElementDefs[35].Param1 := ParamList[61];
		ElementDefs[35].Param2 := ParamList[62];

		ElementDefs[34].Color := AsColor(ParamList[50],ParamList[51]);
		ElementDefs[34].Character := Chr(ParamList[52]);
		ElementDefs[34].Cycle := ParamList[53];
		ElementDefs[34].ScoreValue := ParamList[54];
		ElementDefs[34].Destructible := true;
		ElementDefs[34].Pushable := true;
		ElementDefs[34].TickProc := ElementBearTick;
		ElementDefs[34].TouchProc := ElementDamagingTouch;
		ElementDefs[34].Name := 'Bear';
		ElementDefs[34].Param1 := ParamList[55];

		ElementDefs[37].Character := Chr(ParamList[63]);
		ElementDefs[37].Cycle := ParamList[64];
		ElementDefs[37].Destructible := false;
		ElementDefs[37].TickProc := ElementSlimeTick;
		ElementDefs[37].TouchProc := ElementSlimeTouch;
		ElementDefs[37].Name := 'Slime';
		ElementDefs[37].Param2 := ParamList[65];

		ElementDefs[38].Color := AsColor(ParamList[66],ParamList[67]);
		ElementDefs[38].Character := Chr(ParamList[68]);
		ElementDefs[38].Cycle := ParamList[69];
		ElementDefs[38].Destructible := false;
		ElementDefs[38].TickProc := ElementSharkTick;
		ElementDefs[38].Name := 'Shark';
		ElementDefs[38].Param1 := ParamList[70];

		ElementDefs[16].Character := '/';
		ElementDefs[16].Cycle := 3;
		ElementDefs[16].HasDrawProc := true;
		ElementDefs[16].TickProc := ElementConveyorCWTick;
		ElementDefs[16].DrawProc := ElementConveyorCWDraw;
		ElementDefs[16].Name := 'Clockwise';

		ElementDefs[17].Character := '\';
		ElementDefs[17].Cycle := 2;
		ElementDefs[17].HasDrawProc := true;
		ElementDefs[17].DrawProc := ElementConveyorCCWDraw;
		ElementDefs[17].TickProc := ElementConveyorCCWTick;
		ElementDefs[17].Name := 'Counter';

		ElementDefs[21].Character := Chr(ParamList[35]);
		ElementDefs[21].Name := 'Solid';

		ElementDefs[22].Character := Chr(ParamList[36]);
		ElementDefs[22].Name := 'Normal';

		ElementDefs[31].Character := #206;
		ElementDefs[31].HasDrawProc := true;
		ElementDefs[31].DrawProc := ElementLineDraw;
		ElementDefs[31].Name := 'Line';

		ElementDefs[43].Character := Chr(ParamList[45]);
		ElementDefs[43].Name := 'BlinkNS';

		ElementDefs[33].Character := Chr(ParamList[46]);
		ElementDefs[33].Name := 'BlinkEW';

		ElementDefs[32].Character := Chr(ParamList[49]);
		ElementDefs[32].Color := AsColor(ParamList[47],ParamList[48]);
		ElementDefs[32].Name := 'Ricochet';

		ElementDefs[23].Character := Chr(ParamList[37]);
		ElementDefs[23].Destructible := false;
		ElementDefs[23].Name := 'Breakable';

		ElementDefs[24].Character := Chr(ParamList[38]);
		ElementDefs[24].Pushable := true;
		ElementDefs[24].TouchProc := ElementPushableTouch;
		ElementDefs[24].Name := 'Boulder';

		ElementDefs[25].Character := Chr(ParamList[39]);
		ElementDefs[25].TouchProc := ElementPushableTouch;
		ElementDefs[25].Name := 'Slider (NS)';

		ElementDefs[26].Character := Chr(ParamList[40]);
		ElementDefs[26].TouchProc := ElementPushableTouch;
		ElementDefs[26].Name := 'Slider (EW)';

		ElementDefs[30].Character := #197;
		ElementDefs[30].TouchProc := ElementTransporterTouch;
		ElementDefs[30].HasDrawProc := true;
		ElementDefs[30].DrawProc := ElementTransporterDraw;
		ElementDefs[30].Cycle := 2;
		ElementDefs[30].TickProc := ElementTransporterTick;
		ElementDefs[30].Name := 'Transporter';

		ElementDefs[40].Character := #16;
		ElementDefs[40].HasDrawProc := true;
		ElementDefs[40].DrawProc := ElementPusherDraw;
		ElementDefs[40].Cycle := 4;
		ElementDefs[40].TickProc := ElementPusherTick;
		ElementDefs[40].Name := 'Pusher';

		ElementDefs[13].Character := Chr(ParamList[20]);
		ElementDefs[13].HasDrawProc := true;
		ElementDefs[13].DrawProc := ElementBombDraw;
		ElementDefs[13].Pushable := true;
		ElementDefs[13].Cycle := ParamList[21];
		ElementDefs[13].TickProc := ElementBombTick;
		ElementDefs[13].TouchProc := ElementBombTouch;
		ElementDefs[13].Name := 'Bomb';

		ElementDefs[14].Character := Chr(ParamList[24]);
		ElementDefs[14].Color := AsColor(ParamList[22],ParamList[23]);
		ElementDefs[14].TouchProc := ElementEnergizerTouch;
		ElementDefs[14].Name := 'Energizer';

		ElementDefs[29].Character := Chr(ParamList[44]);
		ElementDefs[29].Cycle := 1;
		ElementDefs[29].TickProc := ElementBlinkWallTick;
		ElementDefs[29].HasDrawProc := true;
		ElementDefs[29].DrawProc := ElementBlinkWallDraw;
		ElementDefs[29].Name := 'Blink wall';

		ElementDefs[27].Character := Chr(ParamList[41]);
		ElementDefs[27].PlaceableOnTop := true;
		ElementDefs[27].Walkable := true;
		ElementDefs[27].TouchProc := ElementFakeTouch;
		ElementDefs[27].Name := 'Fake';

		ElementDefs[28].Character := Chr(ParamList[42]);
		ElementDefs[28].Character := ' ';
		ElementDefs[28].TouchProc := ElementInvisibleTouch;
		ElementDefs[28].Name := 'Invisible';

		ElementDefs[36].Character := #2;
		ElementDefs[36].Cycle := 1;
		ElementDefs[36].HasDrawProc := true;
		ElementDefs[36].DrawProc := ElementObjectDraw;
		ElementDefs[36].TickProc := ElementObjectTick;
		ElementDefs[36].TouchProc := ElementObjectTouch;
		ElementDefs[36].Name := 'Object';

		ElementDefs[1].Character := Chr(ParamList[106]);
		ElementDefs[1].TouchProc := ElementBoardEdgeTouch;
		ElementDefs[1].Name := 'Edge';

		ElementDefs[47].Color := AsColor(ParamList[TEXT_DEF_START + 1],
			ParamList[TEXT_DEF_START + 2]);
		ElementDefs[47].Destructible := ParamList[TEXT_DEF_START + 3] <> 0;
		ElementDefs[47].PlaceableOnTop := ParamList[TEXT_DEF_START + 4] <> 0;
		ElementDefs[47].Walkable := ParamList[TEXT_DEF_START + 5] <> 0;
		ElementDefs[47].Name := 'Bluetext';

		ElementDefs[48].Color := AsColor(ParamList[TEXT_DEF_START + 6],
			ParamList[TEXT_DEF_START + 7]);
		ElementDefs[48].Destructible := ParamList[TEXT_DEF_START + 8] <> 0;
		ElementDefs[48].PlaceableOnTop := ParamList[TEXT_DEF_START + 9] <> 0;
		ElementDefs[48].Walkable := ParamList[TEXT_DEF_START + 10] <> 0;
		ElementDefs[48].Name := 'Greentext';

		ElementDefs[49].Color := AsColor(ParamList[TEXT_DEF_START + 11],
			ParamList[TEXT_DEF_START + 12]);
		ElementDefs[49].Destructible := ParamList[TEXT_DEF_START + 13] <> 0;
		ElementDefs[49].PlaceableOnTop := ParamList[TEXT_DEF_START + 14] <> 0;
		ElementDefs[49].Walkable := ParamList[TEXT_DEF_START + 15] <> 0;
		ElementDefs[49].Name := 'Cyantext';

		ElementDefs[50].Color := AsColor(ParamList[TEXT_DEF_START + 16],
			ParamList[TEXT_DEF_START + 17]);
		ElementDefs[50].Destructible := ParamList[TEXT_DEF_START + 18] <> 0;
		ElementDefs[50].PlaceableOnTop := ParamList[TEXT_DEF_START + 19] <> 0;
		ElementDefs[50].Walkable := ParamList[TEXT_DEF_START + 20] <> 0;
		ElementDefs[50].Name := 'Redtext';

		ElementDefs[51].Color := AsColor(ParamList[TEXT_DEF_START + 21],
			ParamList[TEXT_DEF_START + 22]);
		ElementDefs[51].Destructible := ParamList[TEXT_DEF_START + 23] <> 0;
		ElementDefs[51].PlaceableOnTop := ParamList[TEXT_DEF_START + 24] <> 0;
		ElementDefs[51].Walkable := ParamList[TEXT_DEF_START + 25] <> 0;
		ElementDefs[51].Name := 'Purpletext';

		ElementDefs[52].Color := AsColor(ParamList[TEXT_DEF_START + 26],
			ParamList[TEXT_DEF_START + 27]);
		ElementDefs[52].Destructible := ParamList[TEXT_DEF_START + 28] <> 0;
		ElementDefs[52].PlaceableOnTop := ParamList[TEXT_DEF_START + 29] <> 0;
		ElementDefs[52].Walkable := ParamList[TEXT_DEF_START + 30] <> 0;
		ElementDefs[52].Name := 'Yellowtext';

		ElementDefs[53].Color := AsColor(ParamList[TEXT_DEF_START + 31],
			ParamList[TEXT_DEF_START + 32]);
		ElementDefs[53].Destructible := ParamList[TEXT_DEF_START + 33] <> 0;
		ElementDefs[53].PlaceableOnTop := ParamList[TEXT_DEF_START + 34] <> 0;
		ElementDefs[53].Walkable := ParamList[TEXT_DEF_START + 35] <> 0;
		ElementDefs[53].Name := 'Whitetext';

	end;

procedure InitElementsGame;
	begin
		InitElementDefs;
		ForceDarknessOff := false;
	end;

begin
end.
