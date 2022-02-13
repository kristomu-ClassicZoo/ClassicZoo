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
unit ShiftJis;

interface
	function SjisIsFirstByte(s1: byte): boolean;
	{ Assumes the position is on the first byte of a double-byte character. }
	function SjisGetCharLength(var s: string; pos: integer): integer;
	{ Note: this one is O(n). }
	procedure SjisAdjustCursor(var s: string; var pos: integer; direction: integer);

implementation

function SjisIsFirstByte(s1: byte): boolean;
	begin
		SjisIsFirstByte := ((s1 >= $81) and (s1 <= $9F)) or ((s1 and $F0) = $E0);
	end;

{ Assumes the position is on the first byte of a double-byte character. }
function SjisGetCharLength(var s: string; pos: integer): integer;
	begin
		if SjisIsFirstByte(Byte(s[pos])) then
			SjisGetCharLength := 2
		else
			SjisGetCharLength := 1;
	end;

procedure SjisAdjustCursor(var s: string; var pos: integer; direction: integer);
	var
		i: integer;
	begin
		if pos > Length(s) then exit;
		i := 1;
		while i < pos do begin
			if SjisIsFirstByte(Byte(s[i])) then	
				Inc(i, 2)
			else
				Inc(i, 1);
		end;
		{ If we skipped the character at pos, that means it's the second byte. }
		if i = (pos + 1) then begin
			Inc(pos, direction);
		end;
	end;

end.
