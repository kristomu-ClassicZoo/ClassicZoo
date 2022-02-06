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
	procedure DrawBombSurroundings(x, y: integer; bombPhase: integer);
	procedure GamePromptEndPlay;
	procedure ResetMessageNotShownFlags;
	procedure InitElementsGame;
	procedure ConfigStringsLoad;

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
			if P2 < ElementDefs[E_BULLET].Param1 then
				goto BulletExpire
			else
				Dec(P2, ElementDefs[E_BULLET].Param1);
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
				SoundQueue(1, SoundParse(ConfigList[53])); {Ricochet sound}
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
				SoundQueue(1, SoundParse(ConfigList[53])); {Ricochet sound}
				firstTry := false;
				goto TryMove;
				exit;
			end;

			if (Board.Tiles[X - StepY][Y - StepX].Element = E_RICOCHET) and firstTry then begin
				ix := StepX;
				StepX := StepY;
				StepY := ix;
				SoundQueue(1, SoundParse(ConfigList[53])); {Ricochet sound}
				firstTry := false;
				goto TryMove;
				exit;
			end;

		BulletExpire:
			if (iElem = E_OBJECT) or (iElem = E_SCROLL) then begin
				if (P1 = ParamList[12]) or (P1 = SHOT_SOURCE_PLAYER) then begin {Friendly Fire}
					iStat := GetStatIdAt(ix, iy);
					if OopSend(-iStat, 'SHOT', false) then begin end;
				end;
			end;
			RemoveStat(statId);
			{ Dec(CurrentStatTicked); }
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

procedure ElementDoorDraw(x, y: integer; var ch: byte);
	var
		key: integer;
	begin
		key := (Board.Tiles[x][y].Color div 16) mod 8;
		if Diffkeys then
			ch := 132 + key
		else
			ch := Ord(ElementDefs[E_DOOR].Character);
	end;

procedure ElementKeyDraw(x, y: integer; var ch: byte);
	var
		key: integer;
	begin
		key := Board.Tiles[x][y].Color mod 8;
		if Diffkeys then
			ch := 139 + key
		else
			ch := Ord(ElementDefs[E_KEY].Character);
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

procedure ElementConveyorTick(x, y, direction: integer);
	var
		i, j: integer;
		ix, iy, tx, ty: integer;
		canMove: boolean;
		tiles: array[0..7] of TTile;
		statIds: array[0..7] of integer;
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

		BoardDrawTile(x, y);

		canMove := true;
		i := iMin;
		repeat
			tx := x + DiagonalDeltaX[i];
			ty := y + DiagonalDeltaY[i];
			tiles[i] := Board.Tiles[tx][ty];
			with tiles[i] do begin
				if Element = E_EMPTY then
					canMove := true
				else if not ElementDefs[Element].Pushable then
					canMove := false;
				if ElementDefs[Element].Cycle > -1 then
					statIds[i] := GetStatIdAt(tx, ty);
			end;
			Inc(i, direction);
		until i = iMax;

		i := iMin;
		repeat
			with tiles[i] do begin
				if canMove then begin
					if (ElementDefs[Element].Pushable) or (Element = E_EMPTY) then begin
						j := (i - direction) and 7;
						ix := x + DiagonalDeltaX[j];
						iy := y + DiagonalDeltaY[j];
						tx := x + DiagonalDeltaX[i];
						ty := y + DiagonalDeltaY[i];

						if ElementDefs[Element].Cycle > -1 then begin
							tmpTile := Board.Tiles[tx][ty];
							Board.Tiles[tx][ty] := tiles[i];
							Board.Tiles[ix][iy].Element := E_EMPTY;
							MoveStat(statIds[i], ix, iy);
							Board.Tiles[tx][ty] := tmpTile;
							BoardDrawTile(tx, ty);
						end else begin
							Board.Tiles[ix][iy] := tiles[i];
							BoardDrawTile(ix, iy);
						end;
						if not ElementDefs[tiles[j].Element].Pushable and (tiles[j].Element <> E_EMPTY)	then begin
							Board.Tiles[tx][ty].Element := E_EMPTY;
							BoardDrawTile(tx, ty);
						end;
					end else begin
						canMove := false;
					end;
				end else if Element = E_EMPTY then
					canMove := true
				else if not ElementDefs[Element].Pushable then
					canMove := false;
			end;
			Inc(i, direction);
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
			ElementConveyorTick(X, Y, -1);
		end;
	end;

procedure ElementBombDraw(x, y: integer; var ch: byte);
	begin
		with Board.Stats[GetStatIdAt(x, y)] do
			if P1 <= 1 then
				ch := Ord(ElementDefs[E_BOMB].Character)
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
					SoundQueue(1, SoundParse(ConfigList[5])); {Bomb explode sound}
					DrawBombSurroundings(X, Y, 1);
				end else if P1 = 0 then begin
					oldX := X;
					oldY := Y;
					RemoveStat(statId);
					DrawBombSurroundings(oldX, oldY, 2);
				end else begin
					if (P1 mod 2) = 0 then
						SoundQueue(1, SoundParse(ConfigList[4])) {Bomb tock}
					else
						SoundQueue(1, SoundParse(ConfigList[3])); {Bomb tick}
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
				DisplayMessage(200, ConfigList[1]); {"Bomb Activated!"}
				SoundQueue(4, SoundParse(ConfigList[2])); {Bomb activate sound}
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
					SoundQueue(3, SoundParse(ConfigList[62])); {Transporter sound}
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

procedure ElementPlayerDraw(x, y: integer; var ch: byte);
	begin
		if (World.Info.PlayerColor = 0) and (World.Info.PlayerChar = #0) then begin
			World.Info.PlayerChar := ElementDefs[E_PLAYER].Character;
			World.Info.PlayerColor := ElementDefs[E_PLAYER].Color;
		end;

		ch := Ord(World.Info.PlayerChar);

		if (x = Board.Stats[0].X) and (y = Board.Stats[0].Y) then begin
			Board.Tiles[x][y].Color := World.Info.PlayerColor;
			if World.Info.EnergizerTicks > 0 then begin
				Board.Tiles[x][y].Color := AsColor(World.Info.PlayerColor and $0F,(CurrentTick mod 7) + 1);
				if (CurrentTick mod 2) <> 0 then
					ch := ParamList[1];
			end;
		end;
	end;


procedure ElementStarTick(statId: integer);
	begin
		with Board.Stats[statId] do begin
			if P2 < ElementDefs[E_STAR].Param1 then {Star Health Drain}
				RemoveStat(statId)
			else begin
				Dec(P2, ElementDefs[E_STAR].Param1);
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
		SoundQueue(9, SoundParse(ConfigList[7]) {Energizer Song}
			+ SoundParse(ConfigList[8])
			+ SoundParse(ConfigList[9])
			+ SoundParse(ConfigList[10]));

		Board.Tiles[x][y].Element := E_EMPTY;
		BoardDrawTile(x, y);

		World.Info.EnergizerTicks := ElementDefs[E_ENERGIZER].Param1; 
		GameUpdateSidebar;

		if MessageEnergizerNotShown then begin
			DisplayMessage(200, ConfigList[6]); {"Energizer - You are Invincible!"}
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
		ch := Ord(ElementDefs[E_BLINK_WALL].Character);
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
		if (newX < 1) or (newX > BOARD_WIDTH) then exit;
		if (newY < 1) or (newY > BOARD_HEIGHT) then exit;

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
		if ((x + deltaX) < 1) or ((x + deltaX) > BOARD_WIDTH) then exit;
		if ((y + deltaY) < 1) or ((y + deltaY) > BOARD_HEIGHT) then exit;
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
			OPosX := X;
			OPosY := Y;
			if DataPos >= 0 then
				retVal := OopExecute(statId, DataPos, ConfigList[84])
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
			InspectObjectCode(statId, Board.Stats[statId].DataPos, '');
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
					SoundQueue(3, SoundParse(ConfigList[50])); {Duplicator success}
					BoardDrawTile(X - StepX, Y - StepY);
				end else
					SoundQueue(3, SoundParse(ConfigList[51])); {Duplicator blocked}
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
	begin
		statId := GetStatIdAt(x, y);

		with Board.Stats[statId] do begin
			textWindow.Selectable := false;
			textWindow.LinePos := 1;

			SoundQueue(2, SoundParse(ConfigList[60])); {Scroll Touch}

			DataPos := 0;
			if OopExecute(statId, DataPos, ConfigList[85]) then begin end; {'Scroll'}
		end;

		statId := GetStatIdAt(x, y);
		if statId <> -1 then
			RemoveStat(statId);
	end;

procedure ElementKeyTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	var
		key: integer;
	begin
		key := Board.Tiles[x][y].Color and $07;

		if World.Info.Keys[key] >= ElementDefs[E_KEY].Param1 then begin {Key Limit}
			DisplayMessage(200, ConfigList[15]+ColorNames[key]+ConfigList[16]); {Already have key}
			SoundQueue(2, SoundParse(ConfigList[17]));
		end else begin
			Inc(World.Info.Keys[key]);
			Board.Tiles[x][y].Element := E_EMPTY;
			GameUpdateSidebar;
			DisplayMessage(200, ConfigList[12]+ColorNames[key]+ConfigList[13]); {You got the key}
			SoundQueue(2, SoundParse(ConfigList[14]));
		end;
	end;

procedure ElementAmmoTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		Inc(World.Info.Ammo, ElementDefs[E_AMMO].Param1); {Amount per ammo collected}

		Board.Tiles[x][y].Element := E_EMPTY;
		GameUpdateSidebar;
		SoundQueue(2, SoundParse(ConfigList[25])); {Ammo Collect sound}

		if MessageAmmoNotShown then begin
			MessageAmmoNotShown := false;
			DisplayMessage(200, ConfigList[24]); {"Ammunition - 5 shots per container"}
		end;
	end;

procedure ElementGemTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		World.Info.Gems := World.Info.Gems + ElementDefs[E_GEM].Param1;
		World.Info.Health := World.Info.Health + ElementDefs[E_GEM].Param2;
		World.Info.Score := World.Info.Score + ElementDefs[E_GEM].ScoreValue;

		Board.Tiles[x][y].Element := E_EMPTY;
		GameUpdateSidebar;
		SoundQueue(2, SoundParse(ConfigList[27])); {Gem sound}

		if MessageGemNotShown then begin
			MessageGemNotShown := false;
			DisplayMessage(200, ConfigList[26]); {"Gems give you Health!"}
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

			DisplayMessage(200, ConfigList[18]+ColorNames[key]+ConfigList[19]); {You opened the door}
			SoundQueue(3, SoundParse(ConfigList[20]));
		end else begin
			DisplayMessage(200, ConfigList[21]+ColorNames[key]+ConfigList[22]); {The door is locked}
			SoundQueue(3, SoundParse(ConfigList[23]));
		end;
	end;

procedure ElementPushableTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		ElementPushablePush(x, y, deltaX, deltaY);
		SoundQueue(2, SoundParse(ConfigList[52])); {Push boulder sound}
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
				SoundQueue(2, SoundParse(ConfigList[52])); {Pusher push sound}

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
		Inc(World.Info.Torches, ElementDefs[E_TORCH].Param1);
		Board.Tiles[x][y].Element := E_EMPTY;

		BoardDrawTile(x, y);
		GameUpdateSidebar;

		if MessageTorchNotShown then begin
			DisplayMessage(200, ConfigList[28]); {"Torch - Used for lighting in the underground."}
		end;
		MessageTorchNotShown := false;

		SoundQueue(3, SoundParse(ConfigList[29])); {Torch sound}
	end;

procedure ElementInvisibleTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		with Board.Tiles[x][y] do begin
			Element := ElementDefs[E_INVISIBLE].Param1;
			BoardDrawTile(x, y);

			SoundQueue(3, SoundParse(ConfigList[32])); {Invisible wall touch}
			DisplayMessage(100, ConfigList[31]); {"You are blocked by an invisible wall."}
		end;
	end;

procedure ElementForestTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		Board.Tiles[x][y].Element := E_EMPTY;
		BoardDrawTile(x, y);

		SoundQueue(3, SoundParse(ConfigList[34])); {Forest sound}

		if MessageForestNotShown then begin
			DisplayMessage(200, ConfigList[33]); {"A path is cleared through the forest."}
		end;
		MessageForestNotShown := false;
	end;

procedure ElementFakeTouch(x, y: integer; sourceStatId: integer; var deltaX, deltaY: integer);
	begin
		if MessageFakeNotShown then begin
			DisplayMessage(150, ConfigList[35]); {"Fake Wall - Secret Passage}
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
		SoundQueue(3, SoundParse(ConfigList[37])); {Water touch sound}
		DisplayMessage(100, ConfigList[36]); {"Your way is blocked by water."}
	end;

procedure DrawBombSurroundings(x, y: integer; bombPhase: integer);
	var
		ix, iy: integer;
		istat: integer;
		result: boolean;
	begin
		for ix := 1 to BOARD_WIDTH do {Bomb Radius}
			for iy := 1 to BOARD_HEIGHT do
				with Board.Tiles[ix][iy] do begin
					if ((Sqr(ix-x)*ParamList[6]) + (Sqr(iy-y)*ParamList[7])) < ParamList[8] then begin
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
							end;
						end else begin
							if Element = E_BREAKABLE then
								Element := E_EMPTY;
						end;
						BoardDrawTile(ix, iy);
					end;
				end;
	end;

procedure GamePromptEndPlay;
	begin
		if (World.Info.Health <= 0) and (World.Info.GracePeriod >= ParamList[11]) then begin
			GamePlayExitRequested := true;
			BoardDrawBorder;
		end else begin
			GamePlayExitRequested := SidebarPromptYesNo('End this game? ', true);
			if InputKeyPressed = #27 then
				GamePlayExitRequested := false;
		end;
		InputKeyPressed := #0;
	end;

procedure ElementTruePlayerTick;
	var
		i: integer;
		bulletCount: integer;
		inputC: char;
	begin
		if NeuromotorAssist then GameMove := false else GameMove := true;
		with Board.Stats[0] do begin

			if P2 = 1 then begin
				InputDeltaX := 0;
				InputDeltaY := 0;
				InputShiftPressed := false;
			end;

			if (World.Info.Health <= 0) then begin
				if World.Info.GracePeriod < ParamList[11] then begin
					Inc(World.Info.GracePeriod);
					if World.Info.GracePeriod = ParamList[11] - 1 then begin
						InputDeltaX := 0;
						InputDeltaY := 0;
						InputShiftPressed := false;
					end;
				end else begin
					if World.Info.GracePeriod = ParamList[11] then begin
						Inc(World.Info.GracePeriod);
						SoundQueue(5, SoundParse(ConfigList[39])); {Game over song}
						SoundBlockQueueing := true;
					end;
					InputDeltaX := 0;
					InputDeltaY := 0;
					InputShiftPressed := false;
					if P3 = 0 then
						DisplayMessage(250, ConfigList[38]); {"Game Over - Press ESCAPE"}
					TickTimeDuration := 0;
				end;
			end else
				World.Info.GracePeriod := 0;
			if InputShiftPressed or (InputKeyPressed = ' ') then begin
				GameMove := true;
				if InputShiftPressed and ((InputDeltaX <> 0) or (InputDeltaY <> 0)) then begin
					PlayerDirX := InputDeltaX;
					PlayerDirY := InputDeltaY;
				end;

				if (PlayerDirX <> 0) or (PlayerDirY <> 0) then begin
					if InputTerminal <> '_nil' then begin
						if PlayerDirY = -1 then
							if OopSend(0, InputTerminal+':SHIFTUP', false) then begin end;
						if PlayerDirY = 1 then
							if OopSend(0, InputTerminal+':SHIFTDOWN', false) then begin end;
						if PlayerDirX = -1 then
							if OopSend(0, InputTerminal+':SHIFTLEFT', false) then begin end;
						if PlayerDirX = 1 then
							if OopSend(0, InputTerminal+':SHIFTRIGHT', false) then begin end;						
					end;
					if Board.Info.MaxShots = 0 then begin
						if MessageNoShootingNotShown then
							DisplayMessage(200, ConfigList[40]); {"Can't Shoot in this place!"}
						MessageNoShootingNotShown := false;
					end else if World.Info.Ammo = 0 then begin
						if MessageOutOfAmmoNotShown then
							DisplayMessage(200, ConfigList[41]); {"You don't have any ammo!"}
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

								SoundQueue(2, SoundParse(ConfigList[42])); {Player Shoot}

								InputDeltaX := 0;
								InputDeltaY := 0;
							end;
						end;
					end;
				end;
			end else if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
				GameMove := true;
				if InputTerminal <> '_nil' then begin
					if InputDeltaY = -1 then
						if OopSend(0, InputTerminal+':UP', false) then begin end;
					if InputDeltaY = 1 then
						if OopSend(0, InputTerminal+':DOWN', false) then begin end;
					if InputDeltaX = -1 then
						if OopSend(0, InputTerminal+':LEFT', false) then begin end;
					if InputDeltaX = 1 then
						if OopSend(0, InputTerminal+':RIGHT', false) then begin end;						
				end;

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
			if ((P2 = 1) and (inputC <> #27)) {Locked players only save, quit or debug prompt}
				and ((inputC <> UpCase(ConfigList[83][1]))
				and (inputC <> UpCase(ConfigList[77][1])))
			then
				inputC := #0;
			if inputC =	UpCase(ConfigList[70][1]) then begin {'T' Torch hotkey}
				GameMove := true;
				if World.Info.TorchTicks = 0 then begin
					if World.Info.Torches > 0 then begin
						if Board.Info.IsDark > 0 then begin
							World.Info.Torches := World.Info.Torches - 1;
							World.Info.TorchTicks := ElementDefs[E_TORCH].Param2;

							TransitionDrawToBoard;
							GameUpdateSidebar;
						end else begin
							if MessageRoomNotDarkNotShown then begin
								DisplayMessage(200, ConfigList[44]); {"Don't need torch - room is not dark!"}
								MessageRoomNotDarkNotShown := false;
							end;
						end;
					end else begin
						if MessageOutOfTorchesNotShown then begin
							DisplayMessage(200, ConfigList[45]); {"You don't have any torches!"}
							MessageOutOfTorchesNotShown := false;
						end;
					end;
				end;
			end else if ((inputC = #27) or (inputC = 'Q')) then begin
				GamePromptEndPlay;
			end else if inputC = UpCase(ConfigList[77][1]) then begin {'S' Save game hotkey }
				GameWorldSave(ConfigList[78] + ':', SavedGameFileName, '.SAV');
			end else if inputC = UpCase(ConfigList[72][1]) then begin {'B' Sound toggle hotkey}
				SoundEnabled := not SoundEnabled;
				SoundClearQueue;
				GameUpdateSidebar;
				InputKeyPressed := ' ';
			end else if inputC = UpCase(ConfigList[75][1]) then begin {'H' Help file hotkey}
				TextWindowDisplayFile(World.Info.Name + '.HLP', 'Help for '+ World.Info.Name);
			end else if inputC = UpCase(ConfigList[83][1]) then begin {'?' Debug prompt hotkey}
				GameDebugPrompt;
				InputKeyPressed := #0;
			end else if (NeuromotorAssist = true) and (inputC = 'P') then begin
				GameMove := true;
			end else if (NeuromotorAssist = false)
				and ((inputC = UpCase(ConfigList[79][1]))
				and (World.Info.Health > 0))
			then begin
				GamePaused := true;
			end else if InputTerminal <> '_nil' then begin
				i := 0;
				while i < KeyLimit do begin
					if inputC = UpCase(KeyList[i * 3][1]) then begin
						GameMove := true;
						if OopSend(0, InputTerminal + ':' + UpCaseString(KeyList[(i * 3) + 1]), false) then begin end; {.INI keyboard inputs}
					end;
					Inc(i);
				end;
			end;

			if World.Info.TorchTicks > 0 then begin
				if GameMove then
					Dec(World.Info.TorchTicks);
				if World.Info.TorchTicks = 0 then begin
					TransitionDrawToBoard;
					SoundQueue(3, SoundParse(ConfigList[30])); {Torch extinguish sound}
				end;
				if ElementDefs[E_TORCH].Param2 > 10 then {Torch duration}
					if (World.Info.TorchTicks mod (ElementDefs[E_TORCH].Param2 div 5)) = 0 then
						GameUpdateSidebar;
			end;

			if World.Info.EnergizerTicks > 0 then begin
				if GameMove then
					Dec(World.Info.EnergizerTicks);

				if World.Info.EnergizerTicks = 10 then
					SoundQueue(9, SoundParse(ConfigList[11])); {Energizer ending sound}
			end;

			if (Board.Info.TimeLimitSec > 0) and (World.Info.Health > 0) then
				if (GameMove) and (Board.Info.BoardTicks mod 10 = 0) then begin
					World.Info.BoardTimeSec := World.Info.BoardTimeSec + 1;

					if (Board.Info.TimeLimitSec - 10) = World.Info.BoardTimeSec then begin
						DisplayMessage(200, ConfigList[54]); {"Running out of time!"}
						SoundQueue(3, SoundParse(ConfigList[55])); {Time running out sound}
					end else if World.Info.BoardTimeSec > Board.Info.TimeLimitSec then begin
						DamageStat(0);
					end;
					GameUpdateSidebar;
				end;

			if P3 > 0 then begin
				VideoWriteText((60 - Length(Board.Info.Message)) div 2, 24, 9 + ((P3 - 1) mod 7), ' '+Board.Info.Message+' ');
				if GameMove then
					Dec(P3);
			end else if Board.Info.Message <> '' then begin
				BoardDrawRow(BOARD_HEIGHT);
				Board.Info.Message := '';
			end;

			if HearingImpaired then begin
				if TopTimer > 0 then begin
					if TopTimer = 16 then
						BoardDrawRow(1);
					VideoWriteText((60 - Length(TopMsg)) div 2, 0, 9 + (TopTimer mod 7),TopMsg + ' ');
					if GameMove then
						Dec(TopTimer);
				end else if TopMsg <> '' then begin
					BoardDrawRow(1);
					TopMsg := '';
				end;
			end;

			if GameMove then begin
				if not GamePaused then
					Inc(Board.Info.BoardTicks);
				if (Board.Info.BoardTicks > 420) then
					Board.Info.BoardTicks := 1;
			end else begin
				CurrentStatTicked := Board.StatCount + 1;
			end;

			BoardDrawTile(X, Y);
			PPosX := X;
			PPosY := Y;

		end;
	end;

procedure ElementCloneTick(statId: integer);
	var
		i: integer;
		bulletCount: integer;
	begin
		with Board.Stats[statId] do begin
			if InputShiftPressed or (InputKeyPressed = ' ') then begin
				if InputShiftPressed and ((InputDeltaX <> 0) or (InputDeltaY <> 0)) then begin
					PlayerDirX := InputDeltaX;
					PlayerDirY := InputDeltaY;
				end;

				if (PlayerDirX <> 0) or (PlayerDirY <> 0) then begin
					if (Board.Info.MaxShots > 0) and (World.Info.Ammo > 0) then begin
						bulletCount := 0;
						for i := 0 to Board.StatCount do
							if (Board.Tiles[Board.Stats[i].X][Board.Stats[i].Y].Element = E_BULLET)
								and (Board.Stats[i].P1 = SHOT_SOURCE_PLAYER)
							then
								bulletCount := bulletCount + 1;

						if bulletCount < Board.Info.MaxShots then begin
							if BoardShoot(E_BULLET, X, Y, PlayerDirX, PlayerDirY, SHOT_SOURCE_PLAYER) then begin
								Dec(World.Info.Ammo);
								GameUpdateSidebar;

								SoundQueue(2, #64#1#48#1#32#1);

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
					if ElementDefs[Board.Tiles[X + InputDeltaX][Y + InputDeltaY].Element].Walkable then
						MoveStat(0, X + InputDeltaX, Y + InputDeltaY);
				end;
			end;

			if World.Info.TorchTicks > 1 then
				Dec(World.Info.TorchTicks);

			if World.Info.EnergizerTicks > 11 then
				Dec(World.Info.EnergizerTicks);

		end;
	end;

procedure ElementPlayerTick(statId: integer);
	begin
		PMouseX := RMouseX;
		PMouseY := RMouseY;
		if statId = 0 then
			ElementTruePlayerTick
		else
			ElementCloneTick(statId);
	end;

procedure ElementMonitorTick(statId: integer);
	begin
		Inc(Board.Info.BoardTicks);
		if (Board.Info.BoardTicks > 420) then
			Board.Info.BoardTicks := 1;
		if UpCase(InputKeyPressed) in [#27, 'A', 'E', 'H', 'N', 'P', 'Q', 'R', 'S', 'W', '|'] then
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
				Param3 := 0;
				ScoreValue := 0;
			end;

		ElementDefs[0].Character := ' ';
		ElementDefs[0].Color := $70;
		ElementDefs[0].Walkable := true;
		ElementDefs[0].PlaceableOnTop := true;
		ElementDefs[0].Name := 'EMPTY';

		ElementDefs[1].Character := ' ';
		ElementDefs[1].TouchProc := ElementBoardEdgeTouch;
		ElementDefs[1].Name := 'EDGE';

		ElementDefs[2].Character := #176;
		ElementDefs[2].Color := $07;
		ElementDefs[2].Name := 'DARKNESS';

		ElementDefs[3].Character := ' ';
		ElementDefs[3].Color := $07;
		ElementDefs[3].Cycle := 1;
		ElementDefs[3].TickProc := ElementMonitorTick;
		ElementDefs[3].Name := 'MONITOR';

		ElementDefs[4].Character := #2;
		ElementDefs[4].Color := $1F;
		ElementDefs[4].Destructible := true;
		ElementDefs[4].Pushable := true;
		ElementDefs[4].VisibleInDark := true;
		ElementDefs[4].Cycle := 1;
		ElementDefs[4].TickProc := ElementPlayerTick;
		ElementDefs[4].HasDrawProc := true;
		ElementDefs[4].DrawProc := ElementPlayerDraw;
		ElementDefs[4].Name := 'PLAYER';

		ElementDefs[5].Character := #132;
		ElementDefs[5].Color := $03;
		ElementDefs[5].Pushable := true;
		ElementDefs[5].TouchProc := ElementAmmoTouch;
		ElementDefs[5].Name := 'AMMO';
		ElementDefs[5].Param1 := 5;

		ElementDefs[6].Character := #157;
		ElementDefs[6].Color := $06;
		ElementDefs[6].TouchProc := ElementTorchTouch;
		ElementDefs[6].VisibleInDark := true;
		ElementDefs[6].Name := 'TORCH';
		ElementDefs[6].Param1 := 1;
		ElementDefs[6].Param2 := 200;

		ElementDefs[7].Character := #4;
		ElementDefs[7].Pushable := true;
		ElementDefs[7].TouchProc := ElementGemTouch;
		ElementDefs[7].Destructible := true;
		ElementDefs[7].Name := 'GEM';
		ElementDefs[7].Param1 := 1;
		ElementDefs[7].Param2 := 1;
		ElementDefs[7].ScoreValue := 10;

		ElementDefs[8].Character := #12;
		ElementDefs[8].Pushable := true;
		ElementDefs[8].TouchProc := ElementKeyTouch;
		ElementDefs[8].HasDrawProc := true;
		ElementDefs[8].DrawProc := ElementKeyDraw;
		ElementDefs[8].Name := 'KEY';
		ElementDefs[8].Param1 := 1;

		ElementDefs[9].Character := #10;
		ElementDefs[9].Color := $0F;
		ElementDefs[9].TouchProc := ElementDoorTouch;
		ElementDefs[9].HasDrawProc := true;
		ElementDefs[9].DrawProc := ElementDoorDraw;
		ElementDefs[9].Name := 'DOOR';

		ElementDefs[10].Character := #232;
		ElementDefs[10].Color := $0F;
		ElementDefs[10].TouchProc := ElementScrollTouch;
		ElementDefs[10].TickProc := ElementScrollTick;
		ElementDefs[10].Pushable := true;
		ElementDefs[10].Cycle := 1;
		ElementDefs[10].Name := 'SCROLL';

		ElementDefs[11].Character := #240;
		ElementDefs[11].Color := $0F;
		ElementDefs[11].Cycle := 0;
		ElementDefs[11].VisibleInDark := true;
		ElementDefs[11].TouchProc := ElementPassageTouch;
		ElementDefs[11].Name := 'PASSAGE';

		ElementDefs[12].Character := #250;
		ElementDefs[12].Color := $0F;
		ElementDefs[12].Cycle := 2;
		ElementDefs[12].TickProc := ElementDuplicatorTick;
		ElementDefs[12].HasDrawProc := true;
		ElementDefs[12].DrawProc := ElementDuplicatorDraw;
		ElementDefs[12].Name := 'DUPLICATOR';

		ElementDefs[13].Character := #11;
		ElementDefs[13].HasDrawProc := true;
		ElementDefs[13].DrawProc := ElementBombDraw;
		ElementDefs[13].Pushable := true;
		ElementDefs[13].Cycle := 6;
		ElementDefs[13].TickProc := ElementBombTick;
		ElementDefs[13].TouchProc := ElementBombTouch;
		ElementDefs[13].Name := 'BOMB';

		ElementDefs[14].Character := #127;
		ElementDefs[14].Color := $05;
		ElementDefs[14].TouchProc := ElementEnergizerTouch;
		ElementDefs[14].Name := 'ENERGIZER';
		ElementDefs[14].Param1 := 75;

		ElementDefs[15].Character := 'S';
		ElementDefs[15].Color := $0F;
		ElementDefs[15].Destructible := false;
		ElementDefs[15].Cycle := 1;
		ElementDefs[15].TickProc := ElementStarTick;
		ElementDefs[15].TouchProc := ElementDamagingTouch;
		ElementDefs[15].HasDrawProc := true;
		ElementDefs[15].DrawProc := ElementStarDraw;
		ElementDefs[15].Name := 'STAR';
		ElementDefs[15].Param1 := 1;
		ElementDefs[15].Param2 := 100;

		ElementDefs[16].Character := '/';
		ElementDefs[16].Cycle := 3;
		ElementDefs[16].HasDrawProc := true;
		ElementDefs[16].TickProc := ElementConveyorCWTick;
		ElementDefs[16].DrawProc := ElementConveyorCWDraw;
		ElementDefs[16].Name := 'CLOCKWISE';

		ElementDefs[17].Character := '\';
		ElementDefs[17].Cycle := 2;
		ElementDefs[17].HasDrawProc := true;
		ElementDefs[17].DrawProc := ElementConveyorCCWDraw;
		ElementDefs[17].TickProc := ElementConveyorCCWTick;
		ElementDefs[17].Name := 'COUNTER';

		ElementDefs[18].Character := #248;
		ElementDefs[18].Color := $0F;
		ElementDefs[18].Destructible := true;
		ElementDefs[18].Cycle := 1;
		ElementDefs[18].TickProc := ElementBulletTick;
		ElementDefs[18].TouchProc := ElementDamagingTouch;
		ElementDefs[18].Name := 'BULLET';
		ElementDefs[18].Param2 := 100;

		ElementDefs[19].Character := #176;
		ElementDefs[19].PlaceableOnTop := true;
		ElementDefs[19].TouchProc := ElementWaterTouch;
		ElementDefs[19].Name := 'WATER';

		ElementDefs[20].Character := #176;
		ElementDefs[20].Color := $20;
		ElementDefs[20].Walkable := false;
		ElementDefs[20].TouchProc := ElementForestTouch;
		ElementDefs[20].Name := 'FOREST';

		ElementDefs[21].Character := #219;
		ElementDefs[21].Name := 'SOLID';

		ElementDefs[22].Character := #178;
		ElementDefs[22].Name := 'NORMAL';

		ElementDefs[23].Character := #177;
		ElementDefs[23].Destructible := false;
		ElementDefs[23].Name := 'BREAKABLE';

		ElementDefs[24].Character := #254;
		ElementDefs[24].Pushable := true;
		ElementDefs[24].TouchProc := ElementPushableTouch;
		ElementDefs[24].Name := 'BOULDER';

		ElementDefs[25].Character := #18;
		ElementDefs[25].TouchProc := ElementPushableTouch;
		ElementDefs[25].Name := 'SLIDERNS';

		ElementDefs[26].Character := #29;
		ElementDefs[26].TouchProc := ElementPushableTouch;
		ElementDefs[26].Name := 'SLIDEREW';

		ElementDefs[27].Character := #178;
		ElementDefs[27].PlaceableOnTop := true;
		ElementDefs[27].Walkable := true;
		ElementDefs[27].TouchProc := ElementFakeTouch;
		ElementDefs[27].Name := 'FAKE';

		ElementDefs[28].Character := ' ';
		ElementDefs[28].TouchProc := ElementInvisibleTouch;
		ElementDefs[28].Name := 'INVISIBLE';
		ElementDefs[28].Param1 := 22;

		ElementDefs[29].Character := #206;
		ElementDefs[29].Cycle := 1;
		ElementDefs[29].TickProc := ElementBlinkWallTick;
		ElementDefs[29].HasDrawProc := true;
		ElementDefs[29].DrawProc := ElementBlinkWallDraw;
		ElementDefs[29].Name := 'BLINKWALL';

		ElementDefs[30].Character := #197;
		ElementDefs[30].TouchProc := ElementTransporterTouch;
		ElementDefs[30].HasDrawProc := true;
		ElementDefs[30].DrawProc := ElementTransporterDraw;
		ElementDefs[30].Cycle := 2;
		ElementDefs[30].TickProc := ElementTransporterTick;
		ElementDefs[30].Name := 'TRANSPORTER';

		ElementDefs[31].Character := #206;
		ElementDefs[31].HasDrawProc := true;
		ElementDefs[31].DrawProc := ElementLineDraw;
		ElementDefs[31].Name := 'LINE';

		ElementDefs[32].Character := '*';
		ElementDefs[32].Color := $0A;
		ElementDefs[32].Name := 'RICOCHET';

		ElementDefs[33].Character := #205;
		ElementDefs[33].Name := 'BLINKEW';

		ElementDefs[34].Character := #153;
		ElementDefs[34].Color := $06;
		ElementDefs[34].Cycle := 3;
		ElementDefs[34].ScoreValue := 1;
		ElementDefs[34].Destructible := true;
		ElementDefs[34].Pushable := true;
		ElementDefs[34].TickProc := ElementBearTick;
		ElementDefs[34].TouchProc := ElementDamagingTouch;
		ElementDefs[34].Name := 'BEAR';

		ElementDefs[35].Character := #5;
		ElementDefs[35].Color := $0D;
		ElementDefs[35].Cycle := 1;
		ElementDefs[35].ScoreValue := 2;
		ElementDefs[35].Destructible := true;
		ElementDefs[35].Pushable := true;
		ElementDefs[35].TickProc := ElementRuffianTick;
		ElementDefs[35].TouchProc := ElementDamagingTouch;
		ElementDefs[35].Name := 'RUFFIAN';

		ElementDefs[36].Character := #2;
		ElementDefs[36].Cycle := 1;
		ElementDefs[36].HasDrawProc := true;
		ElementDefs[36].DrawProc := ElementObjectDraw;
		ElementDefs[36].TickProc := ElementObjectTick;
		ElementDefs[36].TouchProc := ElementObjectTouch;
		ElementDefs[36].Name := 'OBJECT';

		ElementDefs[37].Character := '*';
		ElementDefs[37].Cycle := 3;
		ElementDefs[37].Destructible := false;
		ElementDefs[37].TickProc := ElementSlimeTick;
		ElementDefs[37].TouchProc := ElementSlimeTouch;
		ElementDefs[37].Name := 'SLIME';

		ElementDefs[38].Character := '^';
		ElementDefs[38].Color := $07;
		ElementDefs[38].Cycle := 3;
		ElementDefs[38].Destructible := false;
		ElementDefs[38].TickProc := ElementSharkTick;
		ElementDefs[38].Name := 'SHARK';

		ElementDefs[39].Character := #24;
		ElementDefs[39].Cycle := 2;
		ElementDefs[39].TickProc := ElementSpinningGunTick;
		ElementDefs[39].HasDrawProc := true;
		ElementDefs[39].DrawProc := ElementSpinningGunDraw;
		ElementDefs[39].Name := 'SPINNINGGUN';

		ElementDefs[40].Character := #16;
		ElementDefs[40].HasDrawProc := true;
		ElementDefs[40].DrawProc := ElementPusherDraw;
		ElementDefs[40].Cycle := 4;
		ElementDefs[40].TickProc := ElementPusherTick;
		ElementDefs[40].Name := 'PUSHER';

		ElementDefs[41].Color := $0C;
		ElementDefs[41].Character := #234;
		ElementDefs[41].Cycle := 2;
		ElementDefs[41].ScoreValue := 1;
		ElementDefs[41].Destructible := true;
		ElementDefs[41].Pushable := true;
		ElementDefs[41].TickProc := ElementLionTick;
		ElementDefs[41].TouchProc := ElementDamagingTouch;
		ElementDefs[41].Name := 'LION';

		ElementDefs[42].Color := $0B;
		ElementDefs[42].Character := #227;
		ElementDefs[42].Cycle := 2;
		ElementDefs[42].ScoreValue := 2;
		ElementDefs[42].Destructible := true;
		ElementDefs[42].Pushable := true;
		ElementDefs[42].TickProc := ElementTigerTick;
		ElementDefs[42].TouchProc := ElementDamagingTouch;
		ElementDefs[42].Name := 'TIGER';

		ElementDefs[43].Character := #186;
		ElementDefs[43].Name := 'BLINKNS';

		ElementDefs[44].Character := #233;
		ElementDefs[44].Cycle := 2;
		ElementDefs[44].ScoreValue := 1;
		ElementDefs[44].Destructible := true;
		ElementDefs[44].TickProc := ElementCentipedeHeadTick;
		ElementDefs[44].TouchProc := ElementDamagingTouch;
		ElementDefs[44].Name := 'HEAD';

		ElementDefs[45].Character := #79;
		ElementDefs[45].Cycle := 2;
		ElementDefs[45].ScoreValue := 3;
		ElementDefs[45].Destructible := true;
		ElementDefs[45].TickProc := ElementCentipedeSegmentTick;
		ElementDefs[45].TouchProc := ElementDamagingTouch;
		ElementDefs[45].Name := 'SEGMENT';

		ElementDefs[46].Name := 'CUSTOMTEXT';

		ElementDefs[47].Color := $1F;
		ElementDefs[47].Name := 'BLUETEXT';

		ElementDefs[48].Color := $2F;
		ElementDefs[48].Name := 'GREENTEXT';

		ElementDefs[49].Color := $3F;
		ElementDefs[49].Name := 'CYANTEXT';

		ElementDefs[50].Color := $4F;
		ElementDefs[50].Name := 'REDTEXT';

		ElementDefs[51].Color := $5F;
		ElementDefs[51].Name := 'PURPLETEXT';

		ElementDefs[52].Color := $6F;
		ElementDefs[52].Name := 'YELLOWTEXT';

		ElementDefs[53].Color := $0F;
		ElementDefs[53].Name := 'WHITETEXT';

	end;

function ParamConfigs(i: integer): string;
	var
		s: string;
		j: integer;
	begin
		case i of
			1: ParamConfigs := 'OTHER.ALTCHAR';
			2: ParamConfigs := 'OTHER.OUCHDAMAGE';
			3: ParamConfigs := 'OTHER.TORCHRATIOX';
			4: ParamConfigs := 'OTHER.TORCHRATIOY';
			5: ParamConfigs := 'OTHER.TORCHSIZE';
			6: ParamConfigs := 'OTHER.BOMBRATIOX';
			7: ParamConfigs := 'OTHER.BOMBRATIOY';
			8: ParamConfigs := 'OTHER.BOMBSIZE';
			9: ParamConfigs := 'OTHER.MAXSTATS';
			10: ParamConfigs := 'OTHER.MAXOOPLINES';
			11: ParamConfigs := 'OTHER.GRACEPERIOD';
			12: ParamConfigs := 'OTHER.FRIENDLYFIRE';
			13: ParamConfigs := 'THEME.BG.SIDEBAR';
			14: ParamConfigs := 'THEME.FG.TEXT1';
			15: ParamConfigs := 'THEME.FG.TEXT2';
			16: ParamConfigs := 'THEME.FG.ALT';
			17: ParamConfigs := 'THEME.BG.ALT1';
			18: ParamConfigs := 'THEME.BG.ALT2';
			19: ParamConfigs := 'THEME.FG.SPECIAL';
			20: ParamConfigs := 'THEME.BLINKING';
			21: ParamConfigs := 'OTHER.STARTBOARD';
		else ParamConfigs := '_nil' end;
	end;

procedure InitElementsGame;
	var
		s: string;
		k, l: string[20];
		c: char;
		f: text;
		i, j, q, v, code: integer;
	begin
		InitElementDefs;
		if World.Info.Name <> '' then begin
			Assign(f, World.Info.Name + '.CFG');
			Reset(f);
			if IOResult = 0 then begin
				j := 0;
				while j <= 64 do begin
					s := '';
					ReadLn(f, s);
					if s = '' then
						Inc(j)
					else if s[1] <> '#' then begin
						k := '';
						l := '';
						i := 1;
						while (s[i] <> '.') and (i <= Length(s)) do begin
							c := UpCase(s[i]);
							if ((c >= 'A') and (c <= 'Z')) then
								k := k + c;
							Inc(i);
						end;
						if k = 'PAL' then begin
							k := '';
							Inc(i);
							while (s[i] <> '=') and (i <= Length(s)) do begin
								c := UpCase(s[i]);
								if ((c >= 'A') and (c <= 'Z'))
									or ((c >= '0') and (c <= '9'))
								then
									k := k + c;
								Inc(i);
							end;
							v := ColorNumber(k, -1);
							if (v <> -128) then begin
								v := (v * 3) + 22;
								for q := 0 to 2 do begin
									while (s[i] <> ',') and (i <= Length(s)) do begin
										if (s[i] >= '0') and (s[i] <= '9') then
											l := l + s[i];
										Inc(i);
									end;
									if l <> '' then
										Val(l, Paramlist[v + q], code);
									l := '';
									Inc(i);
								end;
							end;
						end else if (k = 'OTHER') or (k = 'THEME') then begin
							while (s[i] <> '=') and (i <= Length(s)) do begin
								c := UpCase(s[i]);
								if ((c >= 'A') and (c <= 'Z'))
									or ((c >= '0') and (c <= '9'))
									or (c = '.')
								then
									k := k + c;
								Inc(i);
							end;
							while (i <= Length(s)) do begin
								c := UpCase(s[i]);
								if ((c >= 'A') and (c <= 'Z'))
									or ((c >= '0') and (c <= '9'))
									or (c = '-')
								then
									l := l + c;
								Inc(i);
							end;
							v := ColorNumber(l, -1);
							if (v = -128) then
								Val(l, v, code);
							for i := 1 to PALETTE_START do
								if ParamConfigs(i) = k then
									ParamList[i] := v;
						end else begin
							Inc(i);
							while (s[i] <> '=') and (i <= Length(s)) do begin
								c := UpCase(s[i]);
								if ((c >= 'A') and (c <= 'Z'))
									or ((c >= '0') and (c <= '9'))
								then
									l := l + c;
								Inc(i);
							end;
							q := -1;
							for i := 1 to MAX_ELEMENT do
								if ElementDefs[i].Name = k then
									q := i;
							if (q <> -1) and (l <> '') then begin
								i := 1;
								while (s[i] <> '=') and (i <= Length(s)) do
									Inc(i);
								k := '';
								while i <= Length(s) do begin
									c := UpCase(s[i]);
									if ((c >= 'A') and (c <= 'Z'))
										or ((c >= '0') and (c <= '9'))
									then
										k := k + c;
									Inc(i);
								end;
								if k <> '' then begin
									v := ColorNumber(k, -1);
									if (v = -128) then
										Val(k, v, code);
									if l = 'CHAR' then
										ElementDefs[q].Character := Chr(v)
									else if l = 'FG' then
										ElementDefs[q].Color := AsColor(v, ElementDefs[q].Color div 16)
									else if l = 'BG' then
										ElementDefs[q].Color := AsColor(ElementDefs[q].Color and $0F, v)
									else if l = 'DESTRUCTIBLE' then
										ElementDefs[q].Destructible := k = 'TRUE'
									else if l = 'PUSHABLE' then begin
										ElementDefs[q].Pushable := k = 'TRUE';
										if k = 'TRUE' then
											ElementDefs[q].TouchProc := ElementPushableTouch;
									end else if l = 'VISIBLEINDARK' then
										ElementDefs[q].VisibleInDark := k = 'TRUE'
									else if l = 'PLACEABLEONTOP' then
										ElementDefs[q].PlaceableOnTop := k = 'TRUE'
									else if l = 'WALKABLE' then
										ElementDefs[q].Walkable := k = 'TRUE'
									else if l = 'CYCLE' then
										ElementDefs[q].Cycle := v
									else if l = 'PARAM1' then
										ElementDefs[q].Param1 := v
									else if l = 'PARAM2' then
										ElementDefs[q].Param2 := v
									else if l = 'PARAM3' then
										ElementDefs[q].Param3 := v
									else if l = 'SCOREVALUE' then
										ElementDefs[q].ScoreValue := v;
								end;
							end;
						end;
					end;
				end;
			end;
			Close(f);
			if IOResult <> 0 then begin end;
		end;
		World.Info.PlayerChar := ElementDefs[E_PLAYER].Character;
		World.Info.PlayerColor := ElementDefs[E_PLAYER].Color;
	end;

function StringConfigs(i: integer): string;
	begin
		case i of
			1: StringConfigs := 'BOMB.MSG.TOUCH';
			2: StringConfigs := 'BOMB.SND.TOUCH';
			3: StringConfigs := 'BOMB.SND.TICK';
			4: StringConfigs := 'BOMB.SND.TOCK';
			5: StringConfigs := 'BOMB.SND.EXPLODE';
			6: StringConfigs := 'ENERGIZER.MSG.TOUCH';
			7: StringConfigs := 'ENERGIZER.SND.SONG1';
			8: StringConfigs := 'ENERGIZER.SND.SONG2';
			9: StringConfigs := 'ENERGIZER.SND.SONG3';
			10: StringConfigs := 'ENERGIZER.SND.SONG4';
			11: StringConfigs := 'ENERGIZER.SND.END';
			12: StringConfigs := 'KEY.MSG.TOUCH1';
			13: StringConfigs := 'KEY.MSG.TOUCH2';
			14: StringConfigs := 'KEY.SND.TOUCH';
			15: StringConfigs := 'KEY.MSG.FAIL1';
			16: StringConfigs := 'KEY.MSG.FAIL2';
			17: StringConfigs := 'KEY.SND.FAIL';
			18: StringConfigs := 'DOOR.MSG.TOUCH1';
			19: StringConfigs := 'DOOR.MSG.TOUCH2';
			20: StringConfigs := 'DOOR.SND.TOUCH';
			21: StringConfigs := 'DOOR.MSG.FAIL1';
			22: StringConfigs := 'DOOR.MSG.FAIL2';
			23: StringConfigs := 'DOOR.SND.FAIL';
			24: StringConfigs := 'AMMO.MSG.TOUCH';
			25: StringConfigs := 'AMMO.SND.TOUCH';
			26: StringConfigs := 'GEM.MSG.TOUCH';
			27: StringConfigs := 'GEM.SND.TOUCH';
			28: StringConfigs := 'TORCH.MSG.TOUCH';
			29: StringConfigs := 'TORCH.SND.TOUCH';
			30: StringConfigs := 'TORCH.SND.END';
			31: StringConfigs := 'INVISIBLE.MSG.TOUCH';
			32: StringConfigs := 'INVISIBLE.SND.TOUCH';
			33: StringConfigs := 'FOREST.MSG.TOUCH';
			34: StringConfigs := 'FOREST.SND.TOUCH';
			35: StringConfigs := 'FAKE.MSG.TOUCH';
			36: StringConfigs := 'WATER.MSG.TOUCH';
			37: StringConfigs := 'WATER.SND.TOUCH';
			38: StringConfigs := 'GAMEOVER.MSG';
			39: StringConfigs := 'GAMEOVER.SND';
			40: StringConfigs := 'CANTSHOOT.MSG';
			41: StringConfigs := 'OUTOFAMMO.MSG';
			42: StringConfigs := 'PLAYERSHOOT.SND';
			43: StringConfigs := 'OBJECTSHOOT.SND';
			44: StringConfigs := 'NOTDARK.MSG';
			45: StringConfigs := 'OUTOFTORCHES.MSG';
			46: StringConfigs := 'DARKBOARD.MSG';
			47: StringConfigs := 'STATDEATH.SND';
			48: StringConfigs := 'PLAYERHURT.MSG';
			49: StringConfigs := 'PLAYERHURT.SND';
			50: StringConfigs := 'DUPLICATOR.SND';
			51: StringConfigs := 'DUPEBLOCKED.SND';
			52: StringConfigs := 'PUSH.SND';
			53: StringConfigs := 'RICOCHET.SND';
			54: StringConfigs := 'LOWTIMER.MSG';
			55: StringConfigs := 'LOWTIMER.SND';
			56: StringConfigs := 'BREAKABLE.SND';
			57: StringConfigs := 'ERROR.MSG';
			58: StringConfigs := 'ERROR.SND';
			59: StringConfigs := 'CHEAT.SND';
			60: StringConfigs := 'SCROLL.SND';
			61: StringConfigs := 'PASSAGE.SND';
			62: StringConfigs := 'TRANSPORTER.SND';
			63: StringConfigs := 'COUNTER.HEALTH';
			64: StringConfigs := 'COUNTER.AMMO';
			65: StringConfigs := 'COUNTER.TORCHES';
			66: StringConfigs := 'COUNTER.GEMS';
			67: StringConfigs := 'COUNTER.SCORE';
			68: StringConfigs := 'COUNTER.KEYS';
			69: StringConfigs := 'COUNTER.TIME';
			70: StringConfigs := 'KEYS.TORCH.BIND';
			71: StringConfigs := 'KEYS.TORCH.LABEL';
			72: StringConfigs := 'KEYS.SOUND.BIND';
			73: StringConfigs := 'KEYS.SOUND.LABEL.ON';
			74: StringConfigs := 'KEYS.SOUND.LABEL.OFF';
			75: StringConfigs := 'KEYS.HELP.BIND';
			76: StringConfigs := 'KEYS.HELP.LABEL';
			77: StringConfigs := 'KEYS.SAVE.BIND';
			78: StringConfigs := 'KEYS.SAVE.LABEL';
			79: StringConfigs := 'KEYS.PAUSE.BIND';
			80: StringConfigs := 'KEYS.PAUSE.LABEL';
			81: StringConfigs := 'SIDEBAR.PAUSE.MSG';
			82: StringConfigs := 'SIDEBAR.TITLEPROMPT';
			83: StringConfigs := 'KEYS.CHEAT.BIND';
			84: StringConfigs := 'DEFAULT.OBJECT.NAME';
			85: StringConfigs := 'DEFAULT.SCROLL.NAME';
		else StringConfigs := '_nil' end;
	end;

function DefaultConfigList(i: integer): string;
	begin
		case i of
			1: DefaultConfigList := 'Bomb activated!';
			2: DefaultConfigList := 'tcf+cf+c';
			3: DefaultConfigList := 't5';
			4: DefaultConfigList := 't8';
			5: DefaultConfigList := 't+++c-c-c-c-c-c';
			6: DefaultConfigList := 'Energizer - You are invincible';
			7: DefaultConfigList := 's.-cd#e';
			8: DefaultConfigList := 's.-f+f-fd#c+c-d#ef+f-fd#c+c-d#e';
			9: DefaultConfigList := 's.-f+f-fd#c+c-d#ef+f-fd#c+c-d#e';
			10: DefaultConfigList := 's.-f+f-fd#c+c-d#e';
			11: DefaultConfigList := 's.-c-a#gf#fd#c';
			12: DefaultConfigList := 'You now have the';
			13: DefaultConfigList := ' key.';
			14: DefaultConfigList := 't+cegcegceg+sc';
			15: DefaultConfigList := 'You already have a';
			16: DefaultConfigList := ' key!';
			17: DefaultConfigList := 'sc-c';
			18: DefaultConfigList := 'The';
			19: DefaultConfigList := ' door is now open.';
			20: DefaultConfigList := 'tcgbcgb+ic';
			21: DefaultConfigList := 'The';
			22: DefaultConfigList := ' door is locked!';
			23: DefaultConfigList := 't--gc';
			24: DefaultConfigList := 'Ammunition - 5 shots per container.';
			25: DefaultConfigList := 'tcc#d';
			26: DefaultConfigList := 'Gems give you Health!';
			27: DefaultConfigList := 't+c-gec';
			28: DefaultConfigList := 'Torch - used for lighting in the underground.';
			29: DefaultConfigList := 'tcase';
			30: DefaultConfigList := 'tc-c-c';
			31: DefaultConfigList := 'You are blocked by an invisible wall.';
			32: DefaultConfigList := 't--dc';
			33: DefaultConfigList := 'A path is cleared through the forest.';
			34: DefaultConfigList := 'ta';
			35: DefaultConfigList := 'A fake wall - secret passage!';
			36: DefaultConfigList := 'Your way is blocked by water.';
			37: DefaultConfigList := 't+c+c';
			38: DefaultConfigList := ' Game over  -  Press ESCAPE';
			39: DefaultConfigList := 's.-cd#g+c-ga#+dgfg#+cf---w3c';
			40: DefaultConfigList := 'Can'#39't shoot in this place!';
			41: DefaultConfigList := 'You don'#39't have any ammo!';
			42: DefaultConfigList := 't+c-c-c';
			43: DefaultConfigList := 'tc-f#';
			44: DefaultConfigList := 'Don'#39't need torch - room is not dark!';
			45: DefaultConfigList := 'You don'#39't have any torches!';
			46: DefaultConfigList := 'Room is dark - you need to light a torch!';
			47: DefaultConfigList := 't+c---c++++c--c';
			48: DefaultConfigList := 'Ouch!';
			49: DefaultConfigList := 't--c+c---c+d#';
			50: DefaultConfigList := 'scdefg';
			51: DefaultConfigList := 't--g#f#';
			52: DefaultConfigList := 't--f';
			53: DefaultConfigList := 't9';
			54: DefaultConfigList := 'Running out of time!';
			55: DefaultConfigList := 'i.+cfc-f+cfq.c';
			56: DefaultConfigList := 't-c';
			57: DefaultConfigList := 'ERR:';
			58: DefaultConfigList := '++w3c';
			59: DefaultConfigList := 'i-g';
			60: DefaultConfigList := 'tc-c+d-d+e-e+f-f+g-g';
			61: DefaultConfigList := 'tcegc#fg#df#ad#ga#eg#+c';
			62: DefaultConfigList := 'tc+d-e+f#-g#+a#c+d';
			63: DefaultConfigList := ' Health:';
			64: DefaultConfigList := '   Ammo:';
			65: DefaultConfigList := 'Torches:';
			66: DefaultConfigList := '   Gems:';
			67: DefaultConfigList := '  Score:';
			68: DefaultConfigList := '   Keys:';
			69: DefaultConfigList := '   Time:';
			70: DefaultConfigList := 'T';
			71: DefaultConfigList := 'Torch';
			72: DefaultConfigList := 'B';
			73: DefaultConfigList := 'Be quiet';
			74: DefaultConfigList := 'Be noisy';
			75: DefaultConfigList := 'H';
			76: DefaultConfigList := 'Help';
			77: DefaultConfigList := 'S';
			78: DefaultConfigList := 'Save game';
			79: DefaultConfigList := 'P';
			80: DefaultConfigList := 'Pause';
			81: DefaultConfigList := 'Pausing...';
			82: DefaultConfigList := 'Pick a command:';
			83: DefaultConfigList := '?';
			84: DefaultConfigList := 'Interaction';
			85: DefaultConfigList := 'Scroll';
		else DefaultConfigList := '' end;
	end;

procedure ConfigStringsLoad;
	var
		s: string;
		k: string[20];
		l: string[80];
		c: char;
		f: text;
		i, j: integer;
	begin
		for i := 1 to CONFIG_FILE_COUNT do
			ConfigList[i] := DefaultConfigList(i);
		if World.Info.Name <> '' then begin
			Assign(f, World.Info.Name + '.CFG');
			Reset(f);
			if IOResult = 0 then begin
				j := 0;
				while j <= 64 do begin
					s := '';
					ReadLn(f, s);
					if s = '' then
						Inc(j)
					else if s[1] <> '#' then begin
						k := '';
						l := '';
						i := 1;
						while (s[i] <> '=') and (i <= Length(s)) do begin
							c := UpCase(s[i]);
							if ((c >= 'A') and (c <= 'Z'))
								or ((c >= '0') and (c <= '9'))
								or (c = '.')
							then
								k := k + c;
							Inc(i);
						end;
						while (s[i] <> #34) and (i <= Length(s)) do
							Inc(i);
						Inc(i);
						while (s[i] <> #34) and (i <= Length(s)) do begin
							l := l + s[i];
							Inc(i);
						end;
						for i := 1 to CONFIG_FILE_COUNT do
							if StringConfigs(i) = k then begin
								if l = '' then begin
									ConfigList[i] := #1;
									ConfigList[i] := '';
								end else
									ConfigList[i] := l;
							end;
					end;
				end;
			end;
			Close(f);
			if IOResult <> 0 then begin end;
		end;
	end;

begin
end.
