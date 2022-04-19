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

{ Game Variables - Serialize }

unit GameVSer;

interface
	uses GameVars;
	procedure CopyBoardInfoFromLocal(var ptr: pointer);
	procedure CopyBoardInfoToLocal(var ptr: pointer);
	procedure CopyWorldInfoFromLocal(var ptr: pointer);
	procedure CopyWorldInfoToLocal(var ptr: pointer);
	procedure CopyStatFromLocal(var ptr: pointer; var stat: TStat);
	procedure CopyStatToLocal(var ptr: pointer; var stat: TStat);

implementation
uses GameSh;

type
	TStatPacked = packed record
		X, Y: byte;
		StepX, StepY: integer;
		Cycle: integer;
		P1, P2, P3: byte;
		Follower: integer;
		Leader: integer;
		Under: TTile;
		UnusedData: longint;
		DataPos: integer;
		DataLen: integer;
	end;
	TBoardInfoPacked = packed record
		MaxShots: byte;
		NeighborBoards: array[0 .. 3] of byte;
		ReenterWhenZapped: boolean;
		StartPlayerX: byte;
		StartPlayerY: byte;
		DrawXOffset: integer;
		DrawYOffset: integer;
		TimeLimitSec: integer;
		unk1: array[14 .. 27] of byte;
	end;
	TWorldInfoPacked = packed record
		Ammo: integer;
		Gems: integer;
		Keys: array [1..7] of boolean;
		Health: integer;
		CurrentBoard: integer;
		unk1: integer;
		EnergizerTicks: integer;
		unk2: integer;
		Score: integer;
		Name: string[20];
		Flags: array[1 .. MAX_FLAG] of string[20];
		BoardTimeSec: integer;
		BoardTimeHsec: integer;
		IsSave: boolean;
		StonesOfPower: integer;
		unk3: array[387 .. 398] of byte;
	end;

procedure CopyBoardInfoFromLocal(var ptr: pointer);
	var
		i: integer;
		s: TBoardInfoPacked;
	begin
		s.MaxShots := Board.Info.MaxShots;
		for i := 0 to 3 do
			s.NeighborBoards[i] := Board.Info.NeighborBoards[i];
		s.ReenterWhenZapped := Board.Info.ReenterWhenZapped;
		s.StartPlayerX := Board.Info.StartPlayerX;
		s.StartPlayerY := Board.Info.StartPlayerY;
		s.DrawXOffset := NtoLE(Board.Info.DrawXOffset);
		s.DrawYOffset := NtoLE(Board.Info.DrawYOffset);
		s.TimeLimitSec := NtoLE(Board.Info.TimeLimitSec);
{$IFDEF SDL2}
		for i := Low(Board.Info.unk1) to High(Board.Info.unk1) do
			s.unk1[i] := Board.Info.unk1[i];
{$ELSE}
		FillChar(s.unk1, SizeOf(s.unk1), 0);
{$ENDIF}

		Move(s, ptr^, SizeOf(s));
		AdvancePointer(ptr, SizeOf(s));
	end;

procedure CopyBoardInfoToLocal(var ptr: pointer);
	var
		i: integer;
		s: TBoardInfoPacked;
	begin
		Move(ptr^, s, SizeOf(s));
		AdvancePointer(ptr, SizeOf(s));

		Board.Info.MaxShots := s.MaxShots;
		for i := 0 to 3 do
			Board.Info.NeighborBoards[i] := s.NeighborBoards[i];
		Board.Info.ReenterWhenZapped := s.ReenterWhenZapped;
		Board.Info.StartPlayerX := s.StartPlayerX;
		Board.Info.StartPlayerY := s.StartPlayerY;
		Board.Info.DrawXOffset := LEtoN(s.DrawXOffset);
		Board.Info.DrawYOffset := LEtoN(s.DrawYOffset);
		Board.Info.TimeLimitSec := LEtoN(s.TimeLimitSec);
{$IFDEF SDL2}
		for i := Low(Board.Info.unk1) to High(Board.Info.unk1) do
			Board.Info.unk1[i] := s.unk1[i];
{$ENDIF}
	end;

procedure CopyWorldInfoFromLocal(var ptr: pointer);
	var
		i: integer;
		s: TWorldInfoPacked;
	begin
		s.Ammo := NtoLE(World.Info.Ammo);
		s.Gems := NtoLE(World.Info.Gems);
		for i := 1 to 7 do
			s.Keys[i] := World.Info.Keys[i];
		s.Health := NtoLE(World.Info.Health);
		s.CurrentBoard := NtoLE(World.Info.CurrentBoard);
		s.EnergizerTicks := NtoLE(World.Info.EnergizerTicks);
		s.Score := NtoLE(World.Info.Score);
		s.Name := World.Info.Name;
		for i := 1 to 10 do
			s.Flags[i] := World.Info.Flags[i];
		s.BoardTimeSec := NtoLE(World.Info.BoardTimeSec);
		s.BoardTimeHsec := NtoLE(World.Info.BoardTimeHsec);
		s.IsSave := World.Info.IsSave;
		s.StonesOfPower := NtoLE(World.Info.StonesOfPower);
{$IFDEF SDL2}
		s.unk1 := NtoLE(World.Info.unk1);
		s.unk2 := NtoLE(World.Info.unk2);
		for i := Low(World.Info.unk3) to High(World.Info.unk3) do
			s.unk3[i] := World.Info.unk3[i];
{$ELSE}
		s.unk1 := 0;
		s.unk2 := 0;
		FillChar(s.unk3, SizeOf(s.unk3), 0);
{$ENDIF}

		Move(s, ptr^, SizeOf(s));
		AdvancePointer(ptr, SizeOf(s));
	end;

procedure CopyWorldInfoToLocal(var ptr: pointer);
	var
		i: integer;
		s: TWorldInfoPacked;
	begin
		Move(ptr^, s, SizeOf(s));
		AdvancePointer(ptr, SizeOf(s));

		World.Info.Ammo := LEtoN(s.Ammo);
		World.Info.Gems := LEtoN(s.Gems);
		for i := 1 to 7 do
			World.Info.Keys[i] := s.Keys[i];
		World.Info.Health := LEtoN(s.Health);
		World.Info.CurrentBoard := LEtoN(s.CurrentBoard);
		World.Info.EnergizerTicks := LEtoN(s.EnergizerTicks);
		World.Info.Score := LEtoN(s.Score);
		World.Info.Name := s.Name;
		for i := 1 to 10 do
			World.Info.Flags[i] := s.Flags[i];
		if MAX_FLAG > 10 then begin
			for i := 11 to MAX_FLAG do
				World.Info.Flags[i] := '';
		end;
		World.Info.BoardTimeSec := LEtoN(s.BoardTimeSec);
		World.Info.BoardTimeHsec := LEtoN(s.BoardTimeHsec);
		World.Info.IsSave := s.IsSave;
		World.Info.StonesOfPower := LEtoN(s.StonesOfPower);
{$IFDEF SDL2}
		World.Info.unk1 := LEtoN(s.unk1);
		World.Info.unk2 := LEtoN(s.unk2);
		for i := Low(World.Info.unk3) to High(World.Info.unk3) do
			World.Info.unk3[i] := s.unk3[i];
{$ENDIF}
	end;

procedure CopyStatFromLocal(var ptr: pointer; var stat: TStat);
	var
		i: integer;
		s: TStatPacked;
	begin
		s.X := stat.X;
		s.Y := stat.Y;
		s.StepX := NtoLE(stat.StepX);
		s.StepY := NtoLE(stat.StepY);
		s.Cycle := NtoLE(stat.Cycle);
		s.P1 := stat.P1;
		s.P2 := stat.P2;
		s.P3 := stat.P3;
		s.Follower := NtoLE(stat.Follower);
		s.Leader := NtoLE(stat.Leader);
		s.Under := stat.Under;
		s.DataPos := NtoLE(stat.DataPos);
		s.DataLen := NtoLE(stat.DataLen);
{$IFDEF SDL2}
		s.UnusedData := NtoLE(stat.UnusedData);
{$ELSE}
		s.UnusedData := 0;
{$ENDIF}

		Move(s, ptr^, SizeOf(s));
		AdvancePointer(ptr, SizeOf(s));
	end;

procedure CopyStatToLocal(var ptr: pointer; var stat: TStat);
	var
		i: integer;
		s: TStatPacked;
	begin
		Move(ptr^, s, SizeOf(s));
		AdvancePointer(ptr, SizeOf(s));

		stat.X := s.X;
		stat.Y := s.Y;
		stat.StepX := LEtoN(s.StepX);
		stat.StepY := LEtoN(s.StepY);
		stat.Cycle := LEtoN(s.Cycle);
		stat.P1 := s.P1;
		stat.P2 := s.P2;
		stat.P3 := s.P3;
		stat.Follower := LEtoN(s.Follower);
		stat.Leader := LEtoN(s.Leader);
		stat.Under := s.Under;
		stat.Data := nil;
		stat.DataPos := LEtoN(s.DataPos);
		stat.DataLen := LEtoN(s.DataLen);
{$IFDEF SDL2}
		stat.UnusedData := LEtoN(s.UnusedData);
{$ENDIF}
	end;

end.
