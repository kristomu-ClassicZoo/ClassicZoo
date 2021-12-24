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
	const
		KEY_BACKSPACE = #8;
		KEY_TAB = #9;
		KEY_ENTER = #13;
		KEY_CTRL_C = #3;
		KEY_CTRL_O = #15;
		KEY_CTRL_S = #19;
		KEY_CTRL_V = #22;
		KEY_CTRL_X = #24;
		KEY_CTRL_Y = #25;
		KEY_ESCAPE = #27;
		KEY_ALT_P = #153;
{$IFDEF HASAMIGA}
		KEY_F1 = #$81;
		KEY_F2 = #$82;
		KEY_F3 = #$83;
		KEY_F4 = #$84;
		KEY_F5 = #$85;
		KEY_F6 = #$86;
		KEY_F7 = #$87;
		KEY_F8 = #$88;
		KEY_F9 = #$89;
		KEY_F10 = #$8A;
		KEY_UP = #$A1;
		KEY_LEFT = #$A3;
		KEY_RIGHT = #$A5;
		KEY_DOWN = #$A7;
		KEY_DELETE = #$AA;
{$ELSE}
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
		KEY_LEFT = #203;
		KEY_RIGHT = #205;
		KEY_DOWN = #208;
		KEY_DELETE = #211;
{$ENDIF}
		KEY_PAGE_UP = #201;
		KEY_PAGE_DOWN = #209;
		KEY_INSERT = #210;
		KEY_HOME = #212;
		KEY_END = #213;
	var
		InputDeltaX, InputDeltaY: integer;
		InputShiftPressed: boolean;
		InputShiftAccepted: boolean;
		InputKeyPressed: char;
		InputJoystickPresent: boolean;
		InputMousePresent: boolean;
		InputMouseX, InputMouseY: integer;
		InputMouseActivationX, InputMouseActivationY: integer;
		InputMouseButtonX, InputMouseButtonY: integer;
		InputJoystickMoved: boolean;
		JoystickXMin, JoystickXCenter, JoystickXMax: integer;
		JoystickYMin, JoystickYCenter, JoystickYMax: integer;
	procedure InputUpdate;
	procedure InputInitDevices;
	procedure InputReadWaitKey;

implementation
uses Dos, Keys, Keyboard, TimerSys;

var
	InputKeyBuffer: string;

procedure InputUpdate;
	var
		ev: TKeyEvent;
	begin
		InputDeltaX := 0;
		InputDeltaY := 0;
		InputShiftPressed := false;
		InputJoystickMoved := false;
		while PollKeyEvent <> 0 do begin
			ev := TranslateKeyEvent(GetKeyEvent);
			InputKeyPressed := GetKeyEventChar(ev);
{$IFDEF MSDOS}
			if (GetKeyEventCode(ev) shr 8) = $FF then
				InputKeyPressed := Chr(Ord(InputKeyPressed) or $80);
{$ENDIF}
{$IFDEF HASAMIGA}
			if (GetKeyEventCode(ev) shr 8) = $FF then
				InputKeyPressed := Chr((GetKeyEventCode(ev) and $7F) or $80);
{$ENDIF}
{$IFDEF UNIX}
			{ TODO: This is hacky and incomplete! Notably missing: F-keys }
			if (InputKeyPressed = #0) then begin
				ev := TranslateKeyEvent(GetKeyEvent);
				case (GetKeyEventCode(ev) shr 8) of
					$03: InputKeyPressed := KEY_INSERT;
					$04: InputKeyPressed := KEY_DELETE;
					$06: InputKeyPressed := KEY_PAGE_UP;
					$07: InputKeyPressed := KEY_PAGE_DOWN;
					$08: InputKeyPressed := KEY_HOME;
					$09: InputKeyPressed := KEY_END;
					$1E: InputKeyPressed := KEY_UP;
					$30: InputKeyPressed := KEY_DOWN;
					$20: InputKeyPressed := KEY_LEFT;
					$2E: InputKeyPressed := KEY_RIGHT;
				end;
			end;
{$ENDIF}
			if (InputKeyPressed <> #0) then
				InputKeyBuffer := InputKeyBuffer + InputKeyPressed;
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

		KeysUpdateModifiers;
		if (InputDeltaX <> 0) or (InputDeltaY <> 0) then begin
			InputShiftPressed := KeysShiftHeld;
		end;
	end;

procedure InputInitDevices;
	begin
	end;

procedure InputReadWaitKey;
	begin
		repeat
			InputUpdate
		until InputKeyPressed <> #0;
	end;

begin
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
	JoystickXMin := 0;
	JoystickXCenter := 0;
	JoystickXMax := 0;
	JoystickYMin := 0;
	JoystickYCenter := 0;
	JoystickYMax := 0;
end.
