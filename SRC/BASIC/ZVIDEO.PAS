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
{$MODE OBJFPC}
unit ZVideo;

interface
	type
		TVideoLine = string[80];
		{ Was 160 in ZZT 3.2. }
		TScreenCopyLine = string[100];
		TScreenCopyLine16 = array[0 .. 49] of word;
		TVideoWriteTextProc = procedure(x, y, color: byte; text: TVideoLine);
	const
		VideoSidebarX = 60;
		VideoRows = 25;
	var
		VideoWriteText: TVideoWriteTextProc;
		VideoForceSafe: boolean;
		VideoForceNoSnow: boolean;
		VideoMonochrome: boolean;
		VideoColumns: integer;
		VideoTextSegment: word;
		VideoEGAInstalled: boolean;
		VideoVGAInstalled: boolean;
		VideoMDAInstalled: boolean;
		VideoLastMode: word;
	procedure VideoLockScreenUpdate;
	procedure VideoUnlockScreenUpdate(x1, y1, x2, y2: integer);
	function VideoSetCharset(data: pointer; height: integer): boolean;
	procedure VideoInstall(borderColor: integer);
	procedure VideoUninstall;
	procedure VideoShowCursor;
	procedure VideoHideCursor;
	procedure VideoSetBorderColor(value: integer);
	procedure VideoSetBlink(value: boolean);
	procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	procedure VideoInvert(x1, y1, x2, y2: integer);

implementation
uses Dos, Video, Keyboard, Mouse, SysUtils, TimerSys;

var
	VSULocked: boolean;

procedure VideoLockScreenUpdate;
	begin
		if not VSULocked then begin
			VSULocked := true;
			LockScreenUpdate;
		end;
	end;

procedure VideoUnlockScreenUpdate(x1, y1, x2, y2: integer);
	begin
		if VSULocked then begin
			UnlockScreenUpdate;
			UpdateScreenArea(x1, y1, x2, y2, false);
			VSULocked := false;
		end;
	end;

function ColorToBW(color: byte): byte;
	begin
		{ FIX: Special handling of blinking solids }
		if (color and $80) = $80 then
			if ((color shr 4) and $07) = (color and $0F) then
				color := (color and $7F);

		if (color and $09) = $09 then
			color := (color and $F0) or $0F
		else if (color and $07) <> 0 then
			color := (color and $F0) or $07;

		if (color and $0F) = $00 then begin
			if (color and $70) = $00 then
				color := (color and $8F)
			else
				color := (color and $8F) or $70;
		end else if (color and $70) <> $70 then
			color := color and $8F;

		ColorToBW := color;
	end;

{$F+}

procedure VideoWriteTextBuf(x, y, color: byte; text: TVideoLine);
	var
		i: integer;
		attr, offset: word;
	begin
		attr := color shl 8;
		offset := (y * VideoColumns + x);
		for i := 1 to Length(text) do begin
			VideoBuf^[offset] := attr or Ord(text[i]);
			Inc(offset);
		end;
		UpdateScreenArea(x, y, x + Length(text) - 1, y, false);
	end;

procedure VideoWriteTextBufBW(x, y, color: byte; text: TVideoLine);
	begin
		VideoWriteTextBuf(x, y, ColorToBW(color), text);
	end;

{$F-}

function VideoSetCharset(data: pointer; height: integer): boolean;
	begin
		VideoSetCharset := false;
	end;

procedure VideoPreInstall;
	begin
	end;

procedure VideoInstall(borderColor: integer);
	begin
		FillChar(VideoBuf^, 0, VideoColumns * 25);
		VideoHideCursor;
	end;

procedure VideoUninstall;
	begin
		FillChar(VideoBuf^, 0, VideoColumns * 25);
		VideoShowCursor;
	end;

procedure VideoShowCursor;
	begin
		SetCursorType(crUnderLine);
	end;

procedure VideoHideCursor;
	begin
		SetCursorType(crHidden);
	end;

procedure VideoSetBorderColor(value: integer);
	begin
	end;

procedure VideoSetBlink(value: boolean);
	begin
		{ TODO }
	end;

procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	var
		offset: integer;
	begin
		offset := (y * VideoColumns + x);
		if toVideo then begin
			Move(data^, VideoBuf^[offset], chars * 2);
			UpdateScreenArea(x, y, x + chars - 1, y, false);
		end else begin
			Move(VideoBuf^[offset], data^, chars * 2);
		end;
	end;

procedure VideoInvert(x1, y1, x2, y2: integer);
	var
		ix, iy, offset: integer;
	begin
		if x2 < x1 then begin
			ix := x1;
			x1 := x2;
			x2 := ix;
		end;
		if y2 < y1 then begin
			ix := y1;
			y1 := y2;
			y2 := ix;
		end;
		for iy := y1 to y2 do begin
			offset := ((iy * VideoColumns) + x1);
			for ix := x1 to x2 do begin
				VideoBuf^[offset] := VideoBuf^[offset] xor $7F00;
				Inc(offset, 1);
			end;
		end;
		UpdateScreenArea(x1, y1, x2, y2, false);
	end;

initialization
	InitVideo;
{$IFDEF HASAMIGA}
	SetWindowTitle(ExtractFileName(ParamStr(0)), '%NAME% %VERSION%');
{$ENDIF}
	InitMouse;
	InitKeyboard;
	VideoColumns := ScreenWidth;
	VideoWriteText := @VideoWriteTextBuf;
	VideoForceNoSnow := false;
	VideoForceSafe := false;
	VideoMDAInstalled := false;
	VideoVGAInstalled := false;
	VSULocked := false;
finalization
	DoneKeyboard;
	DoneMouse;
	DoneVideo;
end.
