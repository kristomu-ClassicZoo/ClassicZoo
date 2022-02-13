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

unit ZInput;

interface
	type
		TInputMode = (IMKeyboard, IMJoystick, IMMouse);
	const
		InputJoystickPresent = false;
		KEY_BACKSPACE = #8;
		KEY_TAB = #9;
		KEY_ENTER = #13;
		KEY_ESCAPE = #27;
		KEY_F1 = #226; 
		KEY_F2 = #227;
		KEY_F3 = #228;
		KEY_F4 = #229;
		KEY_F5 = #230;
		KEY_F6 = #231;
		KEY_F7 = #232;
		KEY_F8 = #233;
		KEY_F9 = #234;
		KEY_F10 = #235;
		KEY_UP = #186;
		KEY_PAGE_UP = #182;
		KEY_LEFT = #187;
		KEY_RIGHT = #188;
		KEY_DOWN = #189;
		KEY_PAGE_DOWN = #183;
		KEY_INSERT = #184;
		KEY_DELETE = #185;
		KEY_HOME = #190;
		KEY_END = #191;
		KEY_CTRL_Z = #26;
		KEY_CTRL_C = #3;
		KEY_CTRL_O = #15;
		KEY_CTRL_S = #19;
		KEY_CTRL_T = #20;
		KEY_CTRL_X = #24;
		KEY_CTRL_V = #22;
		KEY_CTRL_Y = #25;
		{}
		KEY_SJIS = #254;
		KEY_ALT_P = #255;
	var
		InputKeyBuffering: boolean;
		InputDeltaX, InputDeltaY: integer;
		InputShiftPressed: boolean;
		InputShiftAccepted: boolean;
		InputKeyPressedJis: word;
		InputKeyPressed: char;
		InputMouseX, InputMouseY: integer;
		InputMouseActivationX, InputMouseActivationY: integer;
		InputMouseButtonX, InputMouseButtonY: integer;
		InputJoystickMoved: boolean;
		InputLastDeltaX, InputLastDeltaY: integer;
		InputMode: TInputMode;
		InputMousePresent: boolean;
	procedure InputUpdate;
	procedure InputInitDevices;
	procedure InputReadWaitKey;

implementation
uses Dos, Keys, TimerSys;

const
	INPUT_KEY_BUFFER_MAX_LEN = 64;
var
	InputKeyBuffer: array[1 .. INPUT_KEY_BUFFER_MAX_LEN] of word;
	InputKeyBufferLen: byte;

function KeyPressed: boolean;
	var
		regs: Registers;
	begin
		regs.AH := $01;
		Intr($18, regs);
{		KeyPressed := (regs.Flags and $02) <> 0; }
		KeyPressed := regs.BH <> 0;
	end;

function ReadKey: word;
	var
		regs: Registers;
		k: byte;
	begin
		regs.AH := $00;
		Intr($18, regs);
		if ((regs.AL >= $81) and (regs.AL <= $9F)) or ((regs.AL and $F0) = $E0) then begin 
			k := regs.AL;
			regs.AH := $00;
			Intr($18, regs);
			ReadKey := (k shl 8) or regs.AL;			
		end else if (regs.AL = $00) then
			ReadKey := regs.AH or $FF00
		else
			ReadKey := regs.AL;
	end;

function KeySjisToZzt(k: word): char;
	begin
		if (k >= $FF00) then
			KeySjisToZzt := Chr(k or $80)
		else if ((k >= $8100) and (k <= $9FFF)) or ((k and $F000) = $E000) then
			KeySjisToZzt := KEY_SJIS
		else if (k < $80) then
			KeySjisToZzt := Chr(k)
		else
			KeySjisToZzt := Chr(0);
	end;

procedure InputUpdate;
	var
		i: integer;
		regs: Registers;
	begin
		KeysUpdateModifiers;

		InputDeltaX := 0;
		InputDeltaY := 0;
		InputShiftPressed := false;
		InputJoystickMoved := false;
		while KeyPressed do begin
			InputKeyPressedJis := ReadKey;
			if InputKeyBufferLen < INPUT_KEY_BUFFER_MAX_LEN then
				Inc(InputKeyBufferLen);
			InputKeyBuffer[InputKeyBufferLen] := InputKeyPressedJis;
		end;
		if InputKeyBufferLen > 0 then begin
			InputKeyPressedJis := InputKeyBuffer[1];
			if InputKeyBufferLen = 1 then
				InputKeyBufferLen := 0
			else if InputKeyBuffering then begin
				for i := 2 to InputKeyBufferLen do
					InputKeyBuffer[i - 1] := InputKeyBuffer[i];
				Dec(InputKeyBufferLen);
			end else begin
				InputKeyBuffer[1] := InputKeyBuffer[InputKeyBufferLen];
				InputKeyBufferLen := 1;
			end;

			InputKeyPressed := KeySjisToZzt(InputKeyPressedJis);
			if (UpCase(InputKeyPressed) = 'P') and KeysAltHeld then
				InputKeyPressed := KEY_ALT_P;

			case InputKeyPressed of
				KEY_UP, '8': begin
					InputDeltaX := 0;
					InputDeltaY := -1;
				end;
				KEY_LEFT, '4': begin
					InputDeltaX := -1;
					InputDeltaY := 0;
				end;
				KEY_RIGHT, '6': begin
					InputDeltaX := 1;
					InputDeltaY := 0;
				end;
				KEY_DOWN, '2': begin
					InputDeltaX := 0;
					InputDeltaY := 1;
				end;
			end;
		end else begin
			InputKeyPressedJis := 0;
			InputKeyPressed := #0;
		end;

		if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
			InputShiftPressed := KeysShiftHeld;
		end;

		{ TODO: Joystick? }

		if InputMode = IMMouse then begin
			regs.AX := $0B;
			Intr($33, regs);
			Inc(InputMouseX, Integer(regs.CX));
			Inc(InputMouseY, Integer(regs.DX));

			if Abs(InputMouseX) > Abs(InputMouseY) then begin
				if Abs(InputMouseX) > InputMouseActivationX then begin
					if InputMouseX > 0 then
						InputDeltaX := 1
					else
						InputDeltaX := -1;
					InputMouseX := 0;
				end;
			end else if Abs(InputMouseY) > Abs(InputMouseX) then begin
				if Abs(InputMouseY) > InputMouseActivationY then begin
					if InputMouseY > 0 then
						InputDeltaY := 1
					else
						InputDeltaY := -1;
					InputMouseY := 0;
				end;
			end;

			regs.AX := $03;
			Intr($33, regs);

			{ left mouse button }
			if (regs.BX and 1) <> 0 then begin
				if not InputShiftAccepted then
					InputShiftPressed := true;
			end else begin
				InputShiftAccepted := false;
			end;

			{ right/middle mouse button }
			if (regs.BX and 6) <> 0 then begin
				if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
					InputMouseButtonX := InputDeltaX;
					InputMouseButtonY := InputDeltaY;
				end else begin
					InputDeltaX := InputMouseButtonX;
					InputDeltaY := InputMouseButtonY;
				end;
			end else begin
				InputMouseButtonX := 0;
				InputMouseButtonY := 0;
			end;
		end;

		if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
			InputLastDeltaX := InputDeltaX;
			InputLastDeltaY := InputDeltaY;
		end;
	end;

function InputInitMouse: boolean;
	var
		vec: pointer;
		regs: Registers;
	begin
		InputInitMouse := false;
		GetIntVec($33, vec);
		if Seg(vec) <> $0000 then begin
			regs.AX := 0;
			Intr($33, regs);
			InputInitMouse := (regs.AX <> 0);
		end;
	end;

procedure InputInitDevices;
	begin
		InputMousePresent := InputInitMouse;
	end;

procedure InputReadWaitKey;
	begin
		repeat
			InputUpdate
		until InputKeyPressed <> #0;
	end;

begin
	InputLastDeltaX := 0;
	InputLastDeltaY := 0;
	InputDeltaX := 0;
	InputDeltaY := 0;
	InputShiftPressed := false;
	InputShiftAccepted := false;
	InputMouseX := 0;
	InputMouseY := 0;
	InputMouseActivationX := 60;
	InputMouseActivationY := 60;
	InputMouseButtonX := 0;
	InputMouseButtonY := 0;
	InputKeyBufferLen := 0;
	InputKeyBuffering := false;
	InputMode := IMKeyboard;
end.
