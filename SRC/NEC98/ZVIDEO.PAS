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
{$DEFINE PC98VBUF}
unit ZVideo;

interface
	type
		TVideoLine = string[80];
		TVideoWriteTextProc = procedure(x, y, color: byte; text: TVideoLine);
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
		VideoForceSafe: boolean;
		VideoForceNoSnow: boolean;
		VideoMonochrome: boolean;
		VideoBlink: boolean;
		VideoBlinkMask: byte;
		VideoCurrentMode: integer;
		VideoPc98DrawingMode: integer;
		VideoPc98MaxDrawingMode: integer;
	procedure VideoWriteText(x, y, color: byte; text: TVideoLine);
	procedure VideoWriteTextWide(x, y, color: byte; text: TVideoLine);
	function VideoInstall(mode: integer; charsetData: PTCharsetData; charsetHeight: integer;
		borderColor: integer): boolean;
	procedure VideoUninstall;
	procedure VideoShowCursor;
	procedure VideoHideCursor;
	procedure VideoSetBorderColor(value: integer);
	procedure VideoSetBlink(value: boolean);
	function VideoSetCharset(data: PTCharsetData; height: integer): boolean;
	function VideoSetPaletteColor(idx, r, g, b: byte): boolean;
	procedure VideoRedraw;
	procedure VideoPc98Clear(bgColor: integer);
	procedure VideoClear(bgColor: integer);
	procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	procedure VideoInvert(x1, y1, x2, y2: integer);
	procedure VideoScroll(x, y, width, height, dx, dy: integer);

implementation
uses Dos, PC98, TimerSys;

type
	TVideoBackingBuffer = array[0 .. 3999] of word;
const
{$I VIDCONST.INC}
	MEM_GRCG_SEGMENT = $A800;
	GRCG_CONTROL_OFF = $00;
	GRCG_CONTROL_TDW = $80;
	GRCG_CONTROL_RMW = $C0;
	GRCG_CONTROL_DISABLE_I = $08;
	GRCG_CONTROL_DISABLE_G = $04;
	GRCG_CONTROL_DISABLE_R = $02;
	GRCG_CONTROL_DISABLE_B = $01;
	PORT_GDC2_MODE2 = $6A;
	PORT_GRCG_CONTROL = $7C;
	PORT_GRCG_TILE = $7E;
	PORT_GDC2_STATUS = $A0;
	PORT_GDC2_DATA = $A2;
	PORT_GDC2_PAGE = $A4;
	PORT_GDC2_PAGE_ACCESS = $A6;
	PORT_GDC2_PALETTE_INDEX = $A8;
	PORT_GDC2_PALETTE_GREEN = $AA;
	PORT_GDC2_PALETTE_RED = $AC;
	PORT_GDC2_PALETTE_BLUE = $AE;
	GDC2_STATUS_VSYNC = $20;
	GDC2_MODE2_8COL = $00;
	GDC2_MODE2_16COL = $01;
	TILE_ARRAY: array[0 .. 15] of byte = (
		$00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF, $00, $FF);
	{ TODO: ?????? }
	PALETTE_GREEN_ARRAY: array[0 .. 15] of byte = (
		$00, $00, $00, $00, $28, $28, $14, $28, $14, $14, $14, $14, $3C, $3C, $3C, $3C
	);
	PALETTE_RED_ARRAY: array[0 .. 15] of byte = (
		$00, $00, $28, $28, $00, $00, $28, $28, $14, $14, $3C, $3C, $14, $14, $3C, $3C
	);
	PALETTE_BLUE_ARRAY: array[0 .. 15] of byte = (
		$00, $28, $00, $28, $00, $28, $00, $28, $14, $3C, $14, $3C, $14, $3C, $14, $3C
	);
{$IFDEF PC98VBUF}
var
	VideoBackingBuffer: ^TVideoBackingBuffer;
	VideoBackingBufferPresent: boolean;

procedure VideoDrawFromBackingBuffer(x, y: byte; textLength: integer);
	var
		i: word;
		regs: Registers;
		glyphData: array[0 .. 33] of byte;
		glyphCode, newGlyphCode, attr: word;
		doubleWideGlyph, startNewGlyph: boolean;
		initTmOffset, initGmOffset, tmOffset, gmOffset: word;
		iy, color: byte;
	label NextGlyph;
	begin
		initTmOffset := (y * VideoColumns + x) * 2;
		initGmOffset := (Word(y) * 1280) + Word(x);

		if VideoPc98DrawingMode > 0 then begin
			{ Draw background (graphics mode). }
			tmOffset := initTmOffset + 1;
			gmOffset := initGmOffset;
			Port[PORT_GRCG_CONTROL] := GRCG_CONTROL_TDW;
			for i := 1 to textLength do begin
				color := VideoBackingBuffer^[tmOffset] shr 4;
				if (VideoPc98DrawingMode = 1) and ((color and $0F) = 0) then
					color := 0;

				Inc(tmOffset, 2);

				Port[PORT_GRCG_TILE] := TILE_ARRAY[color];
				Port[PORT_GRCG_TILE] := TILE_ARRAY[color shr 2];
				Port[PORT_GRCG_TILE] := TILE_ARRAY[color shr 1];
				if not VideoBlink then begin
					Port[PORT_GRCG_TILE] := TILE_ARRAY[color shr 3];
				end else begin
					Port[PORT_GRCG_TILE] := 0;
				end;

				for iy := 0 to 14 do begin
					Mem[MEM_GRCG_SEGMENT:gmOffset] := $FF;
					Inc(gmOffset, 80);
				end;
				Mem[MEM_GRCG_SEGMENT:gmOffset] := $FF;
				Dec(gmOffset, (80 * 15) - 1);
			end;
		end;

		if VideoPc98DrawingMode > 1 then begin
			{ Draw foreground (graphics mode). }
			tmOffset := initTmOffset;
			gmOffset := initGmOffset;
			Port[PORT_GRCG_CONTROL] := GRCG_CONTROL_RMW;
			for i := 1 to textLength do begin
				newGlyphCode := VideoBackingBuffer^[tmOffset];
				if (newGlyphCode = $20) then begin
					Inc(tmOffset, 2);
					Inc(gmOffset, 1);
					goto NextGlyph;
				end;
				Inc(tmOffset);
				color := VideoBackingBuffer^[tmOffset] and $0F;
				Inc(tmOffset);

				Port[PORT_GRCG_TILE] := TILE_ARRAY[color];
				Port[PORT_GRCG_TILE] := TILE_ARRAY[color shr 2];
				Port[PORT_GRCG_TILE] := TILE_ARRAY[color shr 1];
				Port[PORT_GRCG_TILE] := TILE_ARRAY[color shr 3];

				doubleWideGlyph := true;
				if (newGlyphCode < $100) then begin
					newGlyphCode := (newGlyphCode or $8000);
					doubleWideGlyph := false;
				end else if ((newGlyphCode and $8056) = $56) then begin
					newGlyphCode := $7600 or ((newGlyphCode and 1) shl 8) or (newGlyphCode shr 8);
				end else if ((newGlyphCode and $F0) = $00) then begin
					doubleWideGlyph := not ((newGlyphCode and $FC) = $08);
					newGlyphCode := (newGlyphCode shl 8) or (newGlyphCode shr 8) or $2000;
				end;

				if (i = 1) or (glyphCode <> newGlyphCode) then begin
					startNewGlyph := true;
					glyphCode := newGlyphCode;
					regs.AH := $14;
					regs.BX := Seg(glyphData);
					regs.CX := Ofs(glyphData);
					regs.DX := newGlyphCode;
					Intr($18, regs);
				end;

				if not doubleWideGlyph then begin
					for iy := 2 to 16 do begin
						Mem[MEM_GRCG_SEGMENT:gmOffset] := glyphData[iy];
						Inc(gmOffset, 80);
					end;
					Mem[MEM_GRCG_SEGMENT:gmOffset] := glyphData[15 + 2];
				end else if not startNewGlyph then begin
					for iy := 1 to 15 do begin
						Mem[MEM_GRCG_SEGMENT:gmOffset] := glyphData[(iy shl 1) + 1];
						Inc(gmOffset, 80);
					end;
					Mem[MEM_GRCG_SEGMENT:gmOffset] := glyphData[30 + 2 + 1];
				end else begin
					for iy := 1 to 15 do begin
						Mem[MEM_GRCG_SEGMENT:gmOffset] := glyphData[iy shl 1];
						Inc(gmOffset, 80);
					end;
					Mem[MEM_GRCG_SEGMENT:gmOffset] := glyphData[30 + 2];
				end;
				Dec(gmOffset, (80 * 15) - 1);
				startNewGlyph := not startNewGlyph;
NextGlyph:
			end;
		end else begin
			{ Draw foreground (text mode). }
			tmOffset := initTmOffset;

			for i := 1 to textLength do begin
				color := VideoBackingBuffer^[tmOffset + 1];
				if (VideoPc98DrawingMode = 1) and ((color and $0F) <> 0) then begin
					attr := ATTR_NEC98_MAP[color and $0F];
				end else if ((color and $70) shr 4) = (color and $0F) then begin
					attr := ATTR_NEC98_MAP[color and $70];
				end else begin
					attr := ATTR_NEC98_MAP[color];
				end;
				MemW[$A000:tmOffset] := VideoBackingBuffer^[tmOffset];
				MemW[$A200:tmOffset] := attr;
				Inc(tmOffset, 2);
			end;
		end;

		Port[PORT_GRCG_CONTROL] := GRCG_CONTROL_OFF;
	end;
{$ENDIF}

procedure VideoWriteText(x, y, color: byte; text: TVideoLine);
	var
		attr: word;
		i, offset: integer;
	begin
		offset := (y * VideoColumns + x) * 2;
{$IFDEF PC98VBUF}
		if VideoBackingBufferPresent then begin
			for i := 1 to Length(text) do begin
				VideoBackingBuffer^[offset] := CP437_NEC98_MAP[Ord(text[i])];
				Inc(offset);
				VideoBackingBuffer^[offset] := color;
				Inc(offset);
			end;

			VideoDrawFromBackingBuffer(x, y, Length(text));
			exit;
		end;
{$ENDIF}

		if ((color and $70) shr 4) = (color and $0F) then begin
			{ Same color. }
			attr := ATTR_NEC98_MAP[color and $70];
			for i := 1 to Length(text) do begin
				MemW[$A000:offset] := $0020;
				MemW[$A200:offset] := attr;
				Inc(offset, 2);
			end;
		end else begin
			attr := ATTR_NEC98_MAP[color and $7F] or (((color and $80) shr 6) and VideoBlinkMask);
			for i := 1 to Length(text) do begin
				MemW[$A000:offset] := CP437_NEC98_MAP[Ord(text[i])];
				MemW[$A200:offset] := attr;
				Inc(offset, 2);
			end;
		end;
	end;

procedure VideoWriteTextWide(x, y, color: byte; text: TVideoLine);
	var
		attr: word;
		i, offset: integer;
		doubleByte: boolean; { FetchPC98Word }
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
{$IFDEF PC98VBUF}
		if VideoBackingBufferPresent then begin
			while i <= Length(text) do begin
				VideoBackingBuffer^[offset] := FetchPC98Word;
				Inc(offset);
				VideoBackingBuffer^[offset] := color;
				Inc(offset);
			end;

			VideoDrawFromBackingBuffer(x, y, Length(text));
			exit;
		end;
{$ENDIF}

		if ((color and $70) shr 4) = (color and $0F) then begin
			{ Same color. }
			attr := ATTR_NEC98_MAP[color and $70];
			while i <= Length(text) do begin
				MemW[$A000:offset] := FetchPC98Word;
				MemW[$A200:offset] := attr;
				Inc(offset, 2);
			end;
		end else begin
			attr := ATTR_NEC98_MAP[color and $7F] or (((color and $80) shr 6) and VideoBlinkMask);
			while i <= Length(text) do begin
				MemW[$A000:offset] := FetchPC98Word;
				MemW[$A200:offset] := attr;
				Inc(offset, 2);
			end;
		end;
	end;

procedure VideoPc98Sync;
	begin
		while (Port[PORT_GDC2_STATUS] and GDC2_STATUS_VSYNC) <> 0 do begin end;
		while (Port[PORT_GDC2_STATUS] and GDC2_STATUS_VSYNC) = 0 do begin end;
	end;

procedure VideoReinit(force: boolean);
	var
		i: integer;
	begin
		if VideoPc98DrawingMode < 2 then
			Port[PORT_GDC2_MODE2] := GDC2_MODE2_8COL
		else
			Port[PORT_GDC2_MODE2] := GDC2_MODE2_16COL;
		VideoPc98Sync;

		if VideoPc98DrawingMode < 2 then begin
			Port[$A8] := $37;
			Port[$AA] := $15;
			Port[$AC] := $26;
			Port[$AE] := $04;
		end else if force then begin
			for i := 0 to 15 do begin
				if VideoSetPaletteColor(i, PALETTE_RED_ARRAY[i], PALETTE_GREEN_ARRAY[i], PALETTE_BLUE_ARRAY[i]) then
					begin end;
			end;
		end;
	end;

procedure VideoRedraw;
	var
		i: integer;
	begin
{$IFDEF PC98VBUF}
		if VideoBackingBufferPresent then begin
			VideoReinit(false);
			VideoPc98Clear(0);

			for i := 0 to (VideoRows-1) do begin
				VideoDrawFromBackingBuffer(0, i, VideoColumns);
			end;
		end;
{$ENDIF}
	end;

function VideoInstall(mode: integer; charsetData: PTCharsetData; charsetHeight: integer;
	borderColor: integer): boolean;
	var
		i: integer;
		regs: Registers;
	begin
		VideoInstall := false;
		if mode <> VIDEO_MODE_80X25 then exit;

{$IFDEF PC98VBUF}
		if VideoPc98MaxDrawingMode > 0 then begin
			if not VideoBackingBufferPresent then begin
				New(VideoBackingBuffer);
				VideoBackingBufferPresent := true;
			end;
		end;

		if VideoPc98DrawingMode > 0 then begin
			{ disable graphics }
			regs.AH := $41;
			Intr($18, regs);
	
			{ init graphics }
			regs.AH := $42;
			regs.CH := $C0;
			Intr($18, regs);

			VideoReinit(true);
	
			{ enable graphics }
			regs.AH := $40;
			Intr($18, regs);
		end;
{$ENDIF}

		VideoClear(0);
		VideoHideCursor;
		VideoInstall := true;
	end;

procedure VideoUninstall;
	var
		regs: Registers;
	begin
		VideoClear(0);
		VideoShowCursor;

{$IFDEF PC98VBUF}
		if VideoBackingBufferPresent then begin
			Dispose(VideoBackingBuffer);
			VideoBackingBufferPresent := false;
		end;
{$ENDIF}
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
	var
		i: integer;
	begin
		if VideoBlink = value then exit;

		VideoBlink := value;
		if VideoBlink then
			VideoBlinkMask := $FF
		else
			VideoBlinkMask := $00;

		VideoRedraw;
	end;

function VideoSetCharset(data: PTCharsetData; height: integer): boolean;
	begin
		VideoSetCharset := false;
	end;

function VideoSetPaletteColor(idx, r, g, b: byte): boolean;
	begin
		VideoSetPaletteColor := false;
{$IFDEF PC98VBUF}
		if VideoPc98DrawingMode >= 2 then begin
			Port[PORT_GDC2_PALETTE_INDEX] := idx;
			Port[PORT_GDC2_PALETTE_RED] := r shr 2;
			Port[PORT_GDC2_PALETTE_GREEN] := g shr 2;
			Port[PORT_GDC2_PALETTE_BLUE] := b shr 2;
			VideoSetPaletteColor := true;
		end;
{$ENDIF}
	end;

procedure VideoPc98Clear(bgColor: integer);
	var
		regs: Registers;
	begin
		{ Clear text display }
		regs.AH := $16;
		regs.DX := $0020;
		Intr($18, regs);

{$IFDEF PC98VBUF}
		{ Clear graphics display }
		if VideoPc98MaxDrawingMode > 0 then begin
			Port[PORT_GRCG_CONTROL] := GRCG_CONTROL_TDW;
			Port[PORT_GRCG_TILE] := TILE_ARRAY[bgColor];
			Port[PORT_GRCG_TILE] := TILE_ARRAY[bgColor shr 2];
			Port[PORT_GRCG_TILE] := TILE_ARRAY[bgColor shr 1];
			Port[PORT_GRCG_TILE] := TILE_ARRAY[bgColor shr 3];
			FillChar(Ptr(MEM_GRCG_SEGMENT, 0)^, 32000, $FF);
			Port[PORT_GRCG_CONTROL] := GRCG_CONTROL_OFF;
		end;
{$ENDIF}
	end;

procedure VideoClear(bgColor: integer);
	var
		regs: Registers;
	begin
		VideoPc98Clear(bgColor);
{$IFDEF PC98VBUF}
		if VideoBackingBufferPresent then begin
			FillChar(VideoBackingBuffer^, SizeOf(VideoBackingBuffer^), 0);
		end;
{$ENDIF}
	end;

procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	var
		offset: integer;
	begin
		offset := (y * VideoColumns + x) * 2;
{$IFDEF PC98VBUF}
		if VideoBackingBufferPresent then begin
			if toVideo then
				Move(data^, VideoBackingBuffer^[offset], chars * 4)
			else
				Move(VideoBackingBuffer^[offset], data^, chars * 4);
			VideoDrawFromBackingBuffer(x, y, chars);
			exit;
		end;
{$ENDIF}

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
	VideoMonochrome := false;
	VideoBlink := true;
	VideoBlinkMask := $FF;
	VideoCurrentMode := VIDEO_MODE_80X25;
	VideoPc98MaxDrawingMode := 2;
	VideoPc98DrawingMode := 2;
{$IFDEF PC98VBUF}
	VideoBackingBufferPresent := false;
{$ENDIF}

	SetCBreak(false);
end.
