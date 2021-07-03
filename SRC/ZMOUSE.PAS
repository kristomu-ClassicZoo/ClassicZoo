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

unit ZMouse;

interface
	var
		MouseX, MouseY: integer;
		MousePresent, MouseMoved: boolean;
		MouseLeftPressed: boolean;
		MouseRightPressed: boolean;
		MouseWheelY: shortint;
	procedure MouseUpdate;

implementation
uses Dos, Crt;

var
	MouseWheelPresent: boolean;

procedure MouseUpdate;
	var
		regs: Registers;
	begin
		MouseMoved := false;
		MouseWheelY := 0;
		if MousePresent then begin
			regs.AX := $0003;
			Intr($33, regs);
			MouseLeftPressed := (regs.BX and 1) <> 0;
			MouseRightPressed := (regs.BX and 6) <> 0;
			MouseMoved := (MouseX <> regs.CX)
				or (MouseY <> regs.DX);
			MouseX := regs.CX;
			MouseY := regs.DX;
			if MouseWheelPresent then begin
				MouseWheelY := regs.BH;
			end;
		end;
	end;

procedure MouseCheckPresent;
	var
		vec: pointer;
		regs: Registers;
	begin
		MousePresent := false;
		MouseWheelPresent := false;
		GetIntVec($33, vec);
		if Seg(vec) <> $0000 then begin
			regs.AX := 0;
			Intr($33, regs);
			MousePresent := (regs.AX <> 0);
			if MousePresent then begin	
				{ Check for CuteMouse wheel API }
				regs.AX := $0011;
				Intr($33, regs);
				MouseWheelPresent := (regs.AX = $574D) and ((regs.CX and 1) = 1);
			end;
		end;
	end;

begin
	MouseCheckPresent;
	MouseX := -1;
	MouseY := -1;
	MouseLeftPressed := false;
	MouseRightPressed := false;	
	MouseWheelY := 0;
end.
