{
	Copyright (c) 2020 Adrian Siekierka

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

{ Zeta support extensions for OpenZoo. }
{ Deliberately written in a way which avoids touching the data segment. }

unit ZetaSupp;

interface
	procedure ZetaSetIdleHacks(value: boolean);
	procedure ZetaSleepPit;
	procedure ZetaSleepFrame;
	function ZetaDelay(ms: word): boolean;

implementation
uses Crt, Dos;
type
	TCmpCStringArgOne = string[7];
	TCmpCStringArgTwo = ^string;

{ TODO: Rewrite in ASM }
function ZetaCmpCString(pstr: TCmpCStringArgOne; cstr: TCmpCStringArgTwo): boolean;
	var
		i: integer;
	begin
		for i := 1 to Length(pstr) do begin
			if pstr[i] <> cstr^[i] then begin
				ZetaCmpCString := false;
				exit;
			end;
		end;
		ZetaCmpCString := true;
	end;

function ZetaDetect: boolean;
	begin
		ZetaDetect := ZetaCmpCString('ZetaEmu', Ptr($F000, $FFF4));
	end;

procedure ZetaSetIdleHacks(value: boolean);
	var
		regs: Registers;
	begin
		if not ZetaDetect then exit;
		regs.AH := $02;
		regs.AL := Byte(value);
		regs.CX := $1515;
		Intr($A5, regs);
	end;

procedure ZetaSleepFrame;
	var
		regs: Registers;
	begin
		if not ZetaDetect then exit;
		regs.AX := $0200;
		regs.CX := $1515;
		Intr($A5, regs);
	end;

procedure ZetaSleepPit;
	var
		regs: Registers;
	begin
		if not ZetaDetect then exit;
		regs.AX := $0201;
		regs.CX := $1515;
		Intr($A5, regs);
	end;

function ZetaDelay(ms: word): boolean;
	var
		regs: Registers;
	begin
		if not ZetaDetect then begin
			ZetaDelay := false;
			exit;
		end;
		regs.AH := $03;
		regs.CX := $1515;
		regs.DX := ms;
		Intr($A5, regs);
		ZetaDelay := true;
	end;

begin
end.
