{
	Copyright (c) 2024 Adrian Siekierka

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
unit Counter;

interface
	type
		TCounter = record
			CType: (TCReadOnly, TCByte, TCShortInt, TCInteger, TCTickSpeed);
			UpdateBoard: boolean;
			UpdateTheme: boolean;
			Value: integer;
			Pointer: pointer;
		end;
		cInteger = ^integer;
		cShortint = ^shortint;
		cByte = ^byte;
	{ Parses the counter name s. Returns true if valid counter }
	function CounterFromWord(var c: TCounter; statId: integer; s: string): boolean;
	{ Reads value to c.Value }
	procedure CounterReadValue(var c: TCounter);
	{ Writes value from c.Value }
	function CounterWriteValue(var c: TCounter): boolean;

implementation
uses GameVars, Game;

function CounterFromWord(var c: TCounter; statId: integer; s: string): boolean;
	var
		i: integer;
	begin
		CounterFromWord := true;
		c.UpdateBoard := false;
		c.UpdateTheme := false;

		if s = 'ISDARK' then begin
			c.CType := TCShortInt;
			c.Pointer := @Board.Info.IsDark;
			c.UpdateBoard := true;
		end else if s = 'BLUEKEY' then begin
			c.CType := TCShortInt;
			c.Pointer := @World.Info.Keys[1];
		end else if s = 'GREENKEY' then begin
			c.CType := TCShortInt;
			c.Pointer := @World.Info.Keys[2];
		end else if s = 'CYANKEY' then begin
			c.CType := TCShortInt;
			c.Pointer := @World.Info.Keys[3];
		end else if s = 'REDKEY' then begin
			c.CType := TCShortInt;
			c.Pointer := @World.Info.Keys[4];
		end else if s = 'PURPLEKEY' then begin
			c.CType := TCShortInt;
			c.Pointer := @World.Info.Keys[5];
		end else if s = 'YELLOWKEY' then begin
			c.CType := TCShortInt;
			c.Pointer := @World.Info.Keys[6];
		end else if s = 'WHITEKEY' then begin
			c.CType := TCShortInt;
			c.Pointer := @World.Info.Keys[7];
		end else if s = 'TICKSPEED' then begin
			c.CType := TCTickSpeed;
		end else if s = 'MAXBULLETS' then begin
			c.CType := TCShortInt;
			c.Pointer := @Board.Info.MaxShots;
		end else if s = 'PLAYERX' then begin
			c.CType := TCReadOnly;
			c.Value := Board.Stats[0].X;
		end else if s = 'PLAYERY' then begin
			c.CType := TCReadOnly;
			c.Value := Board.Stats[0].Y;
		end else if s = 'THISX' then begin
			c.CType := TCReadOnly;
			c.Value := Board.Stats[statId].X;
		end else if s = 'THISY' then begin
			c.CType := TCReadOnly;
			c.Value := Board.Stats[statId].Y;
		end else if s = 'BOARDID' then begin
			c.CType := TCReadOnly;
			c.Value := World.Info.CurrentBoard;
		end else if s = 'ARG' then begin
			c.CType := TCReadOnly;
			c.Value := GlobalArg;
		end else if s = 'MOUSEX' then begin
			c.CType := TCReadOnly;
			c.Value := PMouseX;
		end else if s = 'MOUSEY' then begin
			c.CType := TCReadOnly;
			c.Value := PMouseY;
		end else if s = 'EDGEN' then begin
			c.CType := TCReadOnly;
			c.Value := Board.Info.NeighborBoards[0];
		end else if s = 'EDGES' then begin
			c.CType := TCReadOnly;
			c.Value := Board.Info.NeighborBoards[1];
		end else if s = 'EDGEW' then begin
			c.CType := TCReadOnly;
			c.Value := Board.Info.NeighborBoards[2];
		end else if s = 'EDGEE' then begin
			c.CType := TCReadOnly;
			c.Value := Board.Info.NeighborBoards[3];
		end else if s = 'HEALTH' then begin
			c.CType := TCInteger;
			c.Pointer := @World.Info.Health;
		end else if s = 'AMMO' then begin
			c.CType := TCInteger;
			c.Pointer := @World.Info.Ammo;
		end else if s = 'GEMS' then begin
			c.CType := TCInteger;
			c.Pointer := @World.Info.Gems;
		end else if s = 'TORCHES' then begin
			c.CType := TCInteger;
			c.Pointer := @World.Info.Torches;
		end else if s = 'SCORE' then begin
			c.CType := TCInteger;
			c.Pointer := @World.Info.Score;
		end else if s = 'TIME' then begin
			c.CType := TCInteger;
			c.Pointer := @World.Info.BoardTimeSec;
		end else if s = 'ENERGIZED' then begin
			c.CType := TCInteger;
			c.Pointer := @World.Info.EnergizerTicks;
		end else if s = 'WICK' then begin
			c.CType := TCInteger;
			c.Pointer := @World.Info.TorchTicks;
			c.UpdateBoard := true;
		end else if s = 'TIMELIMIT' then begin
			c.CType := TCInteger;
			c.Pointer := @Board.Info.TimeLimitSec;
		end else begin
			c.CType := TCInteger;
			for i := 1 to 7 do
				if s = CustomBoardList[i] then begin
					c.Pointer := @Board.Info.Local[i];
					exit;
				end;
			for i := 1 to 4 do
				if s = CustomObjList[i] then begin
					c.Pointer := @Board.Stats[statId].ObjLocal[i];
					exit;
				end;
			if s = CustomObjList[5] then begin
				c.Pointer := @Board.Stats[statId].Leader;
				exit;
			end;
			if s = CustomObjList[6] then begin
				c.Pointer := @Board.Stats[statId].Follower;
				exit;
			end;
			if s = 'ARRAY' then begin
				c.Pointer := @Board.Stats[statId].ObjArray;
				exit;
			end;
			for i := 1 to CUSTOM_COUNTER_COUNT do
				if s = CustomCounterList[i] then begin
					c.Pointer := @World.Info.CustomCounters[i];
					exit;
				end;
			for i := 1 to (PALETTE_START - 1) do
				if s = ParamConfigs(i) then begin
					c.Pointer := @ExtendedData.Params[i];
					c.UpdateBoard := true;
					if s[1] = 'T' then c.UpdateTheme := true;
					exit;
				end;
			if s = ParamConfigs(71) then begin
				c.Pointer := @ExtendedData.Params[71];
				exit;				
			end;

			{ No match }
			CounterFromWord := false;
		end;		
	end;

procedure CounterReadValue(var c: TCounter);
	begin
		if c.CType = TCByte then
			c.Value := cByte(c.Pointer)^
		else if c.CType = TCShortInt then
			c.Value := cShortInt(c.Pointer)^
		else if c.CType = TCInteger then
			c.Value := cInteger(c.Pointer)^
		else if c.CType = TCTickSpeed then
			c.Value := TickSpeed + 1;
	end;

function CounterWriteValue(var c: TCounter): boolean;
	begin
		CounterWriteValue := true;

		if c.CType = TCByte then
			cByte(c.Pointer)^ := c.Value
		else if c.CType = TCShortInt then
			cShortInt(c.Pointer)^ := c.Value
		else if c.CType = TCInteger then
			cInteger(c.Pointer)^ := c.Value
		else if c.CType = TCTickSpeed then begin
			if c.Value <= 0 then
				TickSpeed := 0
			else
				TickSpeed := c.Value - 1;
			TickTimeDuration := TickSpeed * 2;
		end else
			CounterWriteValue := false;

		if c.UpdateTheme then begin
			GameDrawTheme;
			GameUpdateSidebar;
		end;
		if c.UpdateBoard then
			TransitionDrawToBoard;
	end;

end.
