{
	Copyright (c) 2022 Adrian Siekierka

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
unit ZWideChr;

interface
	const
		WIDE_STRING_MAX = 32767;
{$IFDEF SHIFTJIS}
		WIDE_CHAR_MAX_LENGTH = 2;
{$ENDIF}
{$IFDEF UTF8}
		WIDE_CHAR_MAX_LENGTH = 4;
{$ENDIF}
	{ Returns true if a byte is the first byte of a multi-byte char. }
	function WideIsFirstByte(s1: byte): boolean;
	{ The following assume the position is on the first byte of a wide character. }
	function WideGetCharWidth(var s: string; pos: integer): integer;
	function WideGetCharLength(var s: string; pos: integer): integer;
	function WideGetStringLength(var s: string; pos, maxWidth: integer): integer;
	{ Note: this one is O(n). }
	procedure WideAdjustCursor(var s: string; var pos: integer; direction: integer);

implementation

{$IFDEF UTF8}
function WideIsFirstByte(s1: byte): boolean;
	begin
		WideIsFirstByte := (s1 >= $C0);
	end;

function WideGetCharWidth(var s: string; pos: integer): integer;
	begin
		WideGetCharWidth := 1;
	end;

function WideGetCharLength(var s: string; pos: integer): integer;
	begin
		if Byte(s[pos]) >= $F0 then
			WideGetCharLength := 4
		else if Byte(s[pos]) >= $E0 then
			WideGetCharLength := 3
		else if Byte(s[pos]) >= $C0 then
			WideGetCharLength := 2
		else
			WideGetCharLength := 1;
	end;
{$ENDIF}

{$IFDEF SHIFTJIS}
function WideIsFirstByte(s1: byte): boolean;
	begin
		WideIsFirstByte := ((s1 >= $81) and (s1 <= $9F)) or ((s1 and $F0) = $E0);
	end;

function WideGetCharWidth(var s: string; pos: integer): integer;
	var
		w: word;
	begin
		if WideIsFirstByte(Byte(s[pos])) then begin
			w := (Byte(s[pos]) shl 8) or Byte(s[pos + 1]);
			if (w >= $8540) and (w <= $869D) then { JIS X 0208 rows 9, 10, 11 on PC-9801 }
				WideGetCharWidth := 1
			else
				WideGetCharWidth := 2;
		end else
			WideGetCharWidth := 1;
	end;

function WideGetCharLength(var s: string; pos: integer): integer;
	begin
		if WideIsFirstByte(Byte(s[pos])) then
			WideGetCharLength := 2
		else
			WideGetCharLength := 1;
	end;
{$ENDIF}

function WideGetStringLength(var s: string; pos, maxWidth: integer): integer;
	var
		i, iw, t: integer;
	label WGSLFinished;
	begin
		i := pos;
		iw := 0;
		while i <= Length(s) do begin
			t := WideGetCharWidth(s, i);
			if (iw + t) > maxWidth then goto WGSLFinished;
			Inc(iw, t);
			Inc(i, WideGetCharLength(s, i));
		end;
WGSLFinished:
		WideGetStringLength := i - pos;
	end;

procedure WideAdjustCursor(var s: string; var pos: integer; direction: integer);
	var
		i: integer;
	begin
		if pos > Length(s) then exit;
		i := 1;
		while i < pos do
			Inc(i, WideGetCharLength(s, i));
		{ If we skipped the character at pos, that means it's the second byte. }
		if i = (pos + 1) then begin
			Inc(pos, direction);
		end;
	end;

end.
