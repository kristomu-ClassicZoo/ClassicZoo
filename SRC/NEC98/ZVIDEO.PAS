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
unit ZVideo;

interface
	type
		TVideoLine = string[80];
		TScreenCopyLine = string[200];
		TCharsetData = array[0 .. 31999] of byte;
		PTCharsetData = ^TCharsetData;
	const
		VideoSidebarX = 60;
		VideoColumns = 80;
		VideoRows = 25;
		VIDEO_MODE_40X25 = 0;
		VIDEO_MODE_80X25 = 1;
		VIDEO_MODE_80X43 = 2;
		VIDEO_MODE_80X50 = 3;
		VIDEO_CHARSET_UNCHANGED = -1;
	var
		VideoEightColor: boolean;
		VideoForceSafe: boolean;
		VideoForceNoSnow: boolean;
		VideoMonochrome: boolean;
		VideoBlinkMask: byte;
		VideoCurrentMode: integer;
	procedure VideoWriteText(x, y, color: byte; text: TVideoLine);
	procedure VideoWriteTextSJIS(x, y, color: byte; text: TVideoLine);
	function VideoInstall(mode: integer; charsetData: PTCharsetData; charsetHeight: integer;
		borderColor: integer): boolean;
	procedure VideoUninstall;
	procedure VideoShowCursor;
	procedure VideoHideCursor;
	procedure VideoSetBorderColor(value: integer);
	procedure VideoSetBlink(value: boolean);
	function VideoBlink: boolean;
	function VideoSetCharset(data: PTCharsetData; height: integer): boolean;
	function VideoSetPaletteColor(idx, r, g, b: byte): boolean;
	procedure VideoClear(bgColor: integer);
	procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	procedure VideoInvert(x1, y1, x2, y2: integer);
	procedure VideoScroll(x, y, width, height, dx, dy: integer);

implementation
uses Dos, PC98, TimerSys;

{$I VIDCONST.INC}

procedure VideoWriteText(x, y, color: byte; text: TVideoLine);
	var
		attr: word;
		i, offset: integer;
	begin
		offset := (y * VideoColumns + x) * 2;
		if ((color and $70) shr 4) = (color and $0F) then begin
			{ Same color. }
			attr := ATTR_MAP[color and $70];
			for i := 1 to Length(text) do begin
				MemW[$A000:offset] := $0020;
				MemW[$A200:offset] := attr;
				Inc(offset, 2);
			end;
		end else begin
			attr := ATTR_MAP[color and $7F] or (((color and $80) shr 6) and VideoBlinkMask);
			for i := 1 to Length(text) do begin
				MemW[$A000:offset] := CP437_MAP[Ord(text[i])];
				MemW[$A200:offset] := attr;
				Inc(offset, 2);
			end;
		end;
	end;

procedure VideoWriteTextSJIS(x, y, color: byte; text: TVideoLine);
	var
		attr: word;
		doubleByte: boolean;
		i, offset: integer;
		s1, s2: byte; { FetchPC98Word }
	function FetchPC98Word: word;
		label DepackS2;
		begin
			if doubleByte then begin
				FetchPC98Word := (s2 shl 8) or s1;
				doubleByte := false;
				exit;
			end;

			s1 := Byte(text[i]);
			Inc(i);
			if (s1 >= $81) and (s1 <= $9F) then begin
				{ s1 := ((s1 - $70) shl 1); }
				s1 := ((s1 - $80) shl 1);
				s2 := Byte(text[i]);
				Inc(i);
				goto DepackS2;
			end else if ((s1 and $F0) = $E0) then begin
				{ s1 := ((s1 - $B0) shl 1); }
				s1 := ((s1 - $C0) shl 1);
				s2 := Byte(text[i]);
				Inc(i);
	DepackS2:
				if s2 >= 159 then begin
					s2 := s2 - 126;
				end else begin
					Dec(s1);
					if s2 >= 128 then
						s2 := s2 - 32
					else
						s2 := s2 - 31;
				end;
				doubleByte := true;
				FetchPC98Word := (s2 shl 8) or s1;
			end else FetchPC98Word := s1;
		end;
	begin
		i := 1;
		doubleByte := false;
		offset := (y * VideoColumns + x) * 2;
		if ((color and $70) shr 4) = (color and $0F) then begin
			{ Same color. }
			attr := ATTR_MAP[color and $70];
			while i <= Length(text) do begin
				MemW[$A000:offset] := FetchPC98Word;
				MemW[$A200:offset] := attr;
				Inc(offset, 2);
			end;
		end else begin
			attr := ATTR_MAP[color and $7F] or (((color and $80) shr 6) and VideoBlinkMask);
			while i <= Length(text) do begin
				MemW[$A000:offset] := FetchPC98Word;
				MemW[$A200:offset] := attr;
				Inc(offset, 2);
			end;
		end;
	end;

function VideoInstall(mode: integer; charsetData: PTCharsetData; charsetHeight: integer;
	borderColor: integer): boolean;
	var
		regs: Registers;
	begin
		VideoInstall := false;
		if mode <> VIDEO_MODE_80X25 then exit;

		{ TODO }
		ClrScr;
		VideoHideCursor;
		VideoInstall := true;
	end;

procedure VideoUninstall;
	var
		regs: Registers;
	begin
		{ TODO }
		ClrScr;
		VideoShowCursor;
	end;

procedure VideoShowCursor;
	var
		regs: Registers;
	begin
		regs.AH := $11;
		Intr($18, regs);
	end;

procedure VideoHideCursor;
	var
		regs: Registers;
	begin
		regs.AH := $12;
		Intr($18, regs);
	end;

procedure VideoSetBorderColor(value: integer);
	begin
		{ TODO }
	end;

{ TODO: This doesn't update existing characters. }
procedure VideoSetBlink(value: boolean);
	begin
		if value then
			VideoBlinkMask := $FF
		else
			VideoBlinkMask := $00;
	end;

function VideoBlink: boolean;
	begin
		VideoBlink := (VideoBlinkMask <> 0);
	end;

function VideoSetCharset(data: PTCharsetData; height: integer): boolean;
	begin
		VideoSetCharset := false;
	end;

function VideoSetPaletteColor(idx, r, g, b: byte): boolean;
	begin
		VideoSetPaletteColor := false;
	end;

procedure VideoClear(bgColor: integer);
	begin
		{ stub }
		ClrScr;
	end;

procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	var
		offset: integer;
	begin
		offset := (y * VideoColumns + x) * 2;
		if toVideo then begin
			Move(data^, Ptr($A000, offset)^, chars * 2);
			Move(Ptr(Seg(data^), Ofs(data^) + (chars * 2))^, Ptr($A200, offset)^, chars * 2);
		end else begin
			Move(Ptr($A000, offset)^, data^, chars * 2);
			Move(Ptr($A200, offset)^, Ptr(Seg(data^), Ofs(data^) + (chars * 2))^, chars * 2);
		end
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
			offset := ((iy * VideoColumns) + x1) shl 1;
				for ix := x1 to x2 do begin
				MemW[$A200:offset] := MemW[$A200:offset] xor $04;
				Inc(offset, 2);
			end;
		end;
	end;

procedure VideoScroll(x, y, width, height, dx, dy: integer);
	var
		iy: integer;
		srcOfs, destOfs: integer;
	begin
		if dy = 0 then begin
			if dx >= 0 then begin
				{ move right }
				srcOfs := (y * VideoColumns + x) * 2;
				destOfs := srcOfs + (dx * 2);
				for iy := 1 to height do begin
					Move(Ptr($A000, srcOfs)^, Ptr($A000, destOfs)^, (width - dx) * 2);
					Move(Ptr($A200, srcOfs)^, Ptr($A200, destOfs)^, (width - dx) * 2);
					srcOfs := srcOfs + (VideoColumns * 2);
					destOfs := destOfs + (VideoColumns * 2);
				end;
			end else begin
				{ move left }
				destOfs := (y * VideoColumns + x) * 2;
				srcOfs := destOfs - (dx * 2);
				for iy := 1 to height do begin
					Move(Ptr($A000, srcOfs)^, Ptr($A000, destOfs)^, (width + dx) * 2);
					Move(Ptr($A200, srcOfs)^, Ptr($A200, destOfs)^, (width + dx) * 2);
					srcOfs := srcOfs + (VideoColumns * 2);
					destOfs := destOfs + (VideoColumns * 2);
				end;
			end;
		end else begin
			if dy > 0 then begin
				{ move down }
				srcOfs := ((y + height - 2) * VideoColumns + x) * 2;
				destOfs := VideoColumns * 2 + srcOfs;
				for iy := 1 to (height - 1) do begin
					Move(Ptr($A000, srcOfs)^, Ptr($A000, destOfs)^, width * 2);
					Move(Ptr($A200, srcOfs)^, Ptr($A200, destOfs)^, width * 2);
					srcOfs := srcOfs - (VideoColumns * 2);
					destOfs := destOfs - (VideoColumns * 2);
				end;
			end else begin
				{ move up }
				destOfs := (y * VideoColumns + x) * 2;
				srcOfs := VideoColumns * 2 + destOfs;
				for iy := 1 to (height - 1) do begin
					Move(Ptr($A000, srcOfs)^, Ptr($A000, destOfs)^, width * 2);
					Move(Ptr($A200, srcOfs)^, Ptr($A200, destOfs)^, width * 2);
					srcOfs := srcOfs + (VideoColumns * 2);
					destOfs := destOfs + (VideoColumns * 2);
				end;
			end;
		end;
	end;

begin
	VideoEightColor := true;
	VideoMonochrome := false;
	VideoBlinkMask := $FF;
	VideoCurrentMode := VIDEO_MODE_80X25;

	SetCBreak(false);
end.
