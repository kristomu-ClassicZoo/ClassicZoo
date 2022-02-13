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
{$IFDEF SHIFTJIS}
	const
		WIDE_CHAR_MAX_LENGTH = 2;
{$ENDIF}
	function WideIsFirstByte(s1: byte): boolean;
	{ Assumes the position is on the first byte of a wide character. }
	function WideGetCharWidth(var s: string; pos: integer): integer;
	{ Assumes the position is on the first byte of a wide character. }
	function WideGetCharLength(var s: string; pos: integer): integer;
	{ Note: this one is O(n). }
	procedure WideAdjustCursor(var s: string; var pos: integer; direction: integer);

implementation

{$IFDEF SHIFTJIS}
function WideIsFirstByte(s1: byte): boolean;
	begin
		WideIsFirstByte := ((s1 >= $81) and (s1 <= $9F)) or ((s1 and $F0) = $E0);
	end;

function WideGetCharWidth(var s: string; pos: integer): integer;
	begin
		{ TODO: This is WRONG }
		if WideIsFirstByte(Byte(s[pos])) then
			WideGetCharWidth := 2
		else
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
