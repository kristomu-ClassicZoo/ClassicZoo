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
unit GameSh; { GameShared }

interface
	uses GameVars, TxtWind;
	procedure CalcDirectionRnd(var deltaX, deltaY: integer);
	procedure CalcDirectionSeek(x, y: integer; var deltaX, deltaY: integer);
	function Signum(val: integer): integer;
	function Difference(a, b: integer): integer;
{$IFNDEF FPC}
	procedure AdvancePointer(var address: pointer; count: integer);
		inline(
			$58/$5F/$07/ { POP AX, DI, ES }
			$26/$01/$05 { ADD ES:[DI], AX }
		);
{$ELSE}
	procedure AdvancePointer(var address: pointer; count: integer);
{$ENDIF}
	function GetStatIdAt(tx, ty: integer): integer;
	function TileOutOfBounds(x, y: integer): boolean;
	procedure CopyStatDataToTextWindow(statId: integer; var state: TTextWindowState);
	procedure FreeStatDataMem(statId: integer; showError: boolean);

implementation
uses
{$IFDEF DEBUGWND}
DebugWnd,
{$ENDIF}
ZInput;

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

{$IFDEF FPC}
procedure AdvancePointer(var address: pointer; count: integer);
	begin
		Inc(address, count);
	end;
{$ENDIF}

{$IFDEF CPU8086}
{ GetStatIdAt - hand-rolled ASM version }
{$IFNDEF FPC}
function GetStatIdAt(tx, ty: integer): integer;
	var
		sc: integer;
		st: word;
	begin
		{ Work around TP 5.5 flaw }
		sc := Board.StatCount;
		st := Ofs(Board.Stats);

		inline(
			$8B/$46/<tx/ { MOV AX, tx }
			$0B/$46/<ty/ { OR AX, ty }
			$25/$00/$FF/ { AND AX, 0xFF00 }
			$74/$02/ { JZ func_valid_range }
			$EB/$1E/ { JMP func_notfound }
			{ func_valid_range: }
			$8B/$5E/<ty/ { MOV BX, ty }
			$B1/$08/ { MOV CL, 0x8 }
			$D3/$E3/ { SHL BX, CL }
			$0B/$5E/<tx/ { OR BX, tx }
			$8B/$7E/<st/ { MOV DI, Board.Stats }
			$8B/$4E/<sc/ { MOV CX, [Board.StatCount] }
			$31/$C0/ { XOR AX, AX }
			{ func_loop: }
			$39/$1D/ { CMP [DI], BX }
			$74/$0B/ { JZ func_exit }
			$83/$C7/SizeOf(TStat)/ { ADD DI, SizeOf(TStat) }
			$40/ { INC AX }
			$39/$C8/ { CMP AX, CX }
			$7E/$F4/ { JLE func_loop }
			{ func_notfound: }
			$B8/$FF/$FF/ { MOV AX, 0xFFFF }
			{ func_finish: }
			{ Another TP 5.5 workaround... }
			$89/$46/$FE { MOV [return value], AX }
		);
	end;
{$ELSE}
function GetStatIdAt(tx, ty: integer): integer;
	assembler;
	label func_valid_range;
	label func_loop;
	label func_notfound;
	label func_finish;
	asm
		mov ax, tx
		or ax, ty
		and ax, 0FF00h
		jz func_valid_range
		jmp func_notfound
	func_valid_range:
		mov bx, ty
		mov cl, 8
		shl bx, cl
		or bx, tx
		mov di, offset Board.Stats
		mov cx, [Board.StatCount]
		xor ax, ax
	func_loop:
		cmp [di], bx
		je func_finish
		add di, SizeOf(TStat)
		inc ax
		cmp ax, cx
		jle func_loop
	func_notfound:
		mov ax, 0FFFFh
	func_finish:
	end ['ax', 'bx', 'cx', 'di'];
{$ENDIF}

{$ELSE}
function GetStatIdAt(tx, ty: integer): integer;
	var
		i: integer;
	begin
		i := -1;
		repeat
			Inc(i);
		until ((Board.Stats[i].X = tx) and (Board.Stats[i].Y = ty)) or (i > Board.StatCount);

		if i > Board.StatCount then
			GetStatIdAt := -1
		else
			GetStatIdAt := i;
	end;
{$ENDIF}

function TileOutOfBounds(x, y: integer): boolean;
	begin
		TileOutOfBounds := (x < 0) or (y < 0) or (x > (BOARD_WIDTH + 1)) or (y > (BOARD_HEIGHT + 1));
	end;

procedure CopyStatDataToTextWindow(statId: integer; var state: TTextWindowState);
	var
		dataStr: string;
		dataChr: char;
		i: integer;
		dataStrLen: byte;
	begin
		with Board.Stats[statId] do begin
			TextWindowInitState(state);
			dataStrLen := 0;

			for i := 0 to (DataLen - 1) do begin
				{$IFNDEF FPC}
				{ On Turbo Pascal, the array pointer is actually }
				{ a poiter to a string. }
				dataChr := Data^[i];
				{$ELSE}
				dataChr := Data[i];
				{$ENDIF}
				if dataChr = #13 { Return } then begin
					dataStr[0] := Chr(dataStrLen);
					TextWindowAppendEdit(state, dataStr);
					dataStrLen := 0;
				end else begin
					Inc(dataStrLen);
					dataStr[dataStrLen] := dataChr;
				end;
			end;

			if dataStrLen > 0 then begin
				dataStr[0] := Chr(dataStrLen);
				TextWindowAppendEdit(state, dataStr);
			end;
		end;
	end;

procedure FreeStatDataMem(statId: integer; showError: boolean);
	var
		i: integer;
	begin
		with Board.Stats[statId] do begin
			if DataLen <> 0 then begin
				for i := 1 to Board.StatCount do begin
					if (Board.Stats[i].Data = Data) and (i <> statId) then begin
{$IFDEF DEBUGWND}
						if (showError) and (DebugCompatEnabled) then
							DebugShowElementMessage('Illegal double free', x, y);
{$ENDIF}
						exit;
					end;
				end;
				FreeMem(Data, DataLen);
			end;
		end;
	end;

end.
