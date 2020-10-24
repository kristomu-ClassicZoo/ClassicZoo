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

unit Input;

interface
	const
		KEY_BACKSPACE = #8;
		KEY_TAB = #9;
		KEY_ENTER = #13;
		KEY_ESCAPE = #27;
		KEY_F1 = #187;
		KEY_F2 = #188;
		KEY_F3 = #189;
		KEY_F4 = #190;
		KEY_F5 = #191;
		KEY_F6 = #192;
		KEY_F7 = #193;
		KEY_F8 = #194;
		KEY_F9 = #195;
		KEY_F10 = #196;
		KEY_UP = #200;
		KEY_PAGE_UP = #201;
		KEY_LEFT = #203;
		KEY_RIGHT = #205;
		KEY_DOWN = #208;
		KEY_PAGE_DOWN = #209;
		KEY_INSERT = #210;
		KEY_DELETE = #211;
		KEY_HOME = #199;
		KEY_END = #207;
		{ Maximum emulated scancode: 128 + 83 = 211 }
		KEY_CTRL_Y = #212;
		KEY_ALT_P = #213;
	var
		InputDeltaX, InputDeltaY: integer;
		InputShiftPressed: boolean;
		InputShiftAccepted: boolean;
		InputJoystickEnabled: boolean;
		InputMouseEnabled: boolean;
		InputKeyPressed: char;
		InputMouseX, InputMouseY: integer;
		InputMouseActivationX, InputMouseActivationY: integer;
		InputMouseButtonX, InputMouseButtonY: integer;
		InputJoystickMoved: boolean;
		JoystickXInitial, JoystickYInitial: integer;
		InputLastDeltaX, InputLastDeltaY: integer;
	procedure InputUpdate;
	procedure InputInitDevices;
	procedure InputReadWaitKey;
	function InputConfigure: boolean;

implementation
uses Keys, Sounds, TimerSys, SDL2;

const
	PCScancodeMap: array[0 .. 83] of Byte = (
{  0 } 0,
{  1 } 0, 0, 0,
{  4 } $1E, $30, $2E, $20, $12, $21, $22, $23, $17, { A-I }
{ 13 } $24, $25, $26, $32, $31, $18, $19, $10, $13, { J-R }
{ 22 } $1F, $14, $16, $2F, $11, $2D, $15, $2C,       { S-Z }
{ 30 } 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, { 1-0  }
{ 40 } $1C, $01, $0E, $0F, $39,
{ 45 } $0C, $0D, $1A, $1B, $2B,
{ 50 } $2B, $27, $28, $29,
{ 54 } $33, $34, $35, $3A,
        $3B, $3C, $3D, $3E, $3F, $40, $41, $42, $43, $44, $57, $58,
        $37, $46, 0, $52, $47, $49, $53, $4F, $51,
        $4D, $4B, $50, $48, $45
	);

var
	InputKeyBuffer: string;

procedure InputUpdateKeymod(kmod: Uint16);
	begin
		KeysLeftShiftHeld := (kmod and KMOD_LSHIFT) <> 0;
		KeysRightShiftHeld := (kmod and KMOD_RSHIFT) <> 0;
		KeysShiftHeld := (kmod and KMOD_SHIFT) <> 0;
		KeysCtrlHeld := (kmod and KMOD_CTRL) <> 0;
		KeysAltHeld := (kmod and KMOD_ALT) <> 0;
		KeysNumLockHeld := (kmod and KMOD_NUM) <> 0;
	end;

procedure InputUpdate;
	var
		event: TSDL_Event;
		scode, kcode: Uint32;
		k: char;
	begin
		InputDeltaX := 0;
		InputDeltaY := 0;
		InputShiftPressed := false;
		InputJoystickMoved := false;

		while SDL_PollEvent(@event) <> 0 do begin
			case event.type_ of
				SDL_TEXTINPUT: begin
					k := event.text.text[0];
					if (Byte(k) >= 32) and (Byte(k) < 127) then
						InputKeyBuffer := InputKeyBuffer + k;
				end;
				SDL_KEYDOWN: begin
					InputUpdateKeymod(event.key.keysym._mod);
					scode := Uint32(event.key.keysym.scancode);
					kcode := Uint32(event.key.keysym.sym);
					if KeysAltHeld and (Char(kcode) = 'p') then begin
						k := KEY_ALT_P;
					end else if KeysCtrlHeld and (Char(kcode) = 'y') then begin
						k := KEY_CTRL_Y;
					end else if (kcode > 0) and (kcode < 127) then begin
						k := Char(kcode);
					end else if scode <= 83 then begin
						k := Char(Integer(PCScancodeMap[scode]) + 128);
					end else k := #0;
					if ((Byte(k) and $7F) <> 0) and not ((Byte(k) >= 32) and (Byte(k) < 127)) then
						InputKeyBuffer := InputKeyBuffer + k;
				end;
				SDL_KEYUP: begin
					InputUpdateKeymod(event.key.keysym._mod);
				end;
			end;
		end;

		if Length(InputKeyBuffer) <> 0 then begin
			InputKeyPressed := InputKeyBuffer[1];
			if Length(InputKeyBuffer) = 1 then
				InputKeyBuffer := ''
			else
				InputKeyBuffer := Copy(InputKeyBuffer, Length(InputKeyBuffer) - 1, 1);

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
			InputKeyPressed := #0;
		end;

		if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
			{ keyboard movement }
			InputShiftPressed := KeysShiftHeld;
		end;
	end;

procedure InputInitDevices;
	begin
		InputJoystickEnabled := false; 
		InputMouseEnabled := false;
	end;

function InputConfigure: boolean;
	begin
		{ stub }
		InputConfigure := true;
	end;

procedure InputReadWaitKey;
	begin
		repeat
			SoundIdle(IMUntilFrame);
			InputUpdate;
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
	InputKeyBuffer := '';
end.
