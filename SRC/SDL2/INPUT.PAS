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
		KEY_CTRL_C = #212;
		KEY_CTRL_O = #213;
		KEY_CTRL_S = #214;
		KEY_CTRL_V = #215;
		KEY_CTRL_X = #216;
		KEY_CTRL_Y = #217;
		KEY_ALT_P = #218;
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

{DEFINE DEBUG_INPUT_FLAGS}

implementation
uses Keys, Sounds, TimerSys, SDL2;

type
	TKeyPress = record
		Value: char;
		Hsecs: word;
		Flags: byte;
	end;

const
	MAX_KEYS_PRESSED = 16;
	KP_PRESSED = $01;
	KP_HELD = $02;
	KP_REPEATED = $04;
	JOY_REPEAT_HSECS_DELAY = 25;
	JOY_REPEAT_HSECS_DELAY_NEXT = 4;
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
	KeysPressed: array[1 .. MAX_KEYS_PRESSED] of TKeyPress;
	KeysPressedPos: integer;

procedure InputSetKeyPressed(key: char; oneTime: boolean; isRepeat: boolean);
	var
		i, kid, kid2: integer;
		anyPressed: boolean;
		newHsecs: word;
	begin
		{ if isPressed and (key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]) then begin
			InputSetKeyPressed(KEY_UP, false, false, false);
			InputSetKeyPressed(KEY_DOWN, false, false, false);
			InputSetKeyPressed(KEY_LEFT, false, false, false);
			InputSetKeyPressed(KEY_RIGHT, false, false, false);
		end; }

		anyPressed := false;

		kid := 0;
		for i := 1 to MAX_KEYS_PRESSED do with KeysPressed[i] do begin
			anyPressed := anyPressed or ((Flags and (KP_PRESSED or KP_HELD)) <> 0);
			if (Value = key) and ((Flags and (KP_PRESSED or KP_HELD)) <> 0) then begin
				if (isRepeat or ((Flags and KP_HELD) <> 0)) then begin
					kid := i;
					break;
				end;
			end;
		end;

		if not anyPressed then begin
			KeysPressedPos := 0;
		end;

		if (kid = 0) then begin
			for i := (KeysPressedPos + 1) to MAX_KEYS_PRESSED do with KeysPressed[i] do begin
				if ((Flags and (KP_PRESSED or KP_HELD)) = 0) then begin
					kid := i;
					break;
				end;
			end;
		end;

		if kid > 0 then begin
			with KeysPressed[kid] do begin
				if isRepeat and ((Flags and KP_HELD) <> 0) then exit;
				Value := key;
				Hsecs := TimerSysGetHsecs + JOY_REPEAT_HSECS_DELAY;
				Flags := KP_PRESSED;
				if not oneTime then Flags := Flags or KP_HELD;
{$IFDEF DEBUG_INPUT_FLAGS}
				WriteLn('flag changed by press');
				WriteLn(Flags);
{$ENDIF}
				{ Anti-skating }
				if key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT] then begin
					newHsecs := TimerSysGetHsecs + JOY_REPEAT_HSECS_DELAY_NEXT;
					for kid2 := 1 to MAX_KEYS_PRESSED do with KeysPressed[kid2] do begin
						if (Value in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]) then
							if Hsecs < newHsecs then
								Hsecs := newHsecs;
					end;
				end;
			end;
		end;
	end;

procedure InputClearKeyPressed(key: char; forceClear: boolean);
	var
		i: integer;
	begin
		for i := 1 to MAX_KEYS_PRESSED do begin
			with KeysPressed[i] do begin
				if Value = key then begin
					Flags := Flags and (not KP_HELD);
					if forceClear or ((Flags and KP_REPEATED) <> 0) then begin
						Flags := Flags and (not KP_PRESSED) and (not KP_REPEATED);
					end;
{$IFDEF DEBUG_INPUT_FLAGS}
					WriteLn('flag changed by clear');
					WriteLn(Flags);
{$ENDIF}
				end;
			end;
		end;
	end;

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
		i: integer;
		localHsecs, hsecsDiff: word;
	begin
		InputDeltaX := 0;
		InputDeltaY := 0;
		InputShiftPressed := false;
		InputJoystickMoved := false;
		localHsecs := TimerSysGetHsecs;

		while SDL_PollEvent(@event) <> 0 do begin
			case event.type_ of
				SDL_TEXTINPUT: begin
					k := event.text.text[0];
					if (Byte(k) >= 32) and (Byte(k) < 127) then
						InputSetKeyPressed(k, true, false);
				end;
				SDL_KEYDOWN, SDL_KEYUP: begin
					InputUpdateKeymod(event.key.keysym._mod);
					scode := Uint32(event.key.keysym.scancode);
					kcode := Uint32(event.key.keysym.sym);
					if KeysAltHeld and (Char(kcode) = 'p') then begin
						k := KEY_ALT_P;
					end else if KeysCtrlHeld and (Char(kcode) = 'c') then begin
						k := KEY_CTRL_C;
					end else if KeysCtrlHeld and (Char(kcode) = 'o') then begin
						k := KEY_CTRL_O;
					end else if KeysCtrlHeld and (Char(kcode) = 's') then begin
						k := KEY_CTRL_S;
					end else if KeysCtrlHeld and (Char(kcode) = 'v') then begin
						k := KEY_CTRL_V;
					end else if KeysCtrlHeld and (Char(kcode) = 'x') then begin
						k := KEY_CTRL_X;
					end else if KeysCtrlHeld and (Char(kcode) = 'y') then begin
						k := KEY_CTRL_Y;
					end else if (kcode > 0) and (kcode < 127) then begin
						k := Char(kcode);
					end else if scode <= 83 then begin
						k := Char(Integer(PCScancodeMap[scode]) + 128);
					end else k := #0;
					if ((Byte(k) and $7F) <> 0) and not ((Byte(k) >= 32) and (Byte(k) < 127)) then
						if event.type_ = SDL_KEYDOWN then
							InputSetKeyPressed(k, false, event.key._repeat <> 0)
						else
							InputClearKeyPressed(k, false);
				end;
			end;
		end;

		InputKeyPressed := #0;
		for i := 1 to MAX_KEYS_PRESSED do begin
			with KeysPressed[KeysPressedPos + 1] do begin
				if ((Flags and (KP_PRESSED or KP_HELD)) = KP_HELD) then begin
					hsecsDiff := Hsecs - localHsecs;
					if hsecsDiff >= 32768 then begin
						Hsecs := localHsecs + JOY_REPEAT_HSECS_DELAY_NEXT;
						Flags := (Flags or KP_PRESSED) or KP_REPEATED;
{$IFDEF DEBUG_INPUT_FLAGS}
						WriteLn('flag changed by hsecs diff');
						WriteLn(Flags);
{$ENDIF}
					end;
				end;
				if ((Flags and KP_PRESSED) = KP_PRESSED) then begin
					Flags := Flags and (not KP_PRESSED);
{$IFDEF DEBUG_INPUT_FLAGS}
					WriteLn('flag changed by unpress');
					WriteLn(Flags);
{$ENDIF}
					InputKeyPressed := Value;
					KeysPressedPos := (KeysPressedPos + 1) mod MAX_KEYS_PRESSED;
					break;
				end;
			end;

			KeysPressedPos := (KeysPressedPos + 1) mod MAX_KEYS_PRESSED;
		end;

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

	KeysPressedPos := 0;
end.
