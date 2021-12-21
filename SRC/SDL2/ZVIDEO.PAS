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
		TSDLScalingMode = (SMNone, SMInteger, SMOrigAspect, SM43Aspect, SMIgnoreAspect);
		TVideoLine = string[80];
		TScreenCopyLine = string[160];
	var
		VideoMonochrome: boolean;
		VideoColumns: integer;
		VideoBorderColor: integer;
		VideoTextSegment: word;
		VideoTextPointer: pointer;
		VideoCursorVisible: boolean;
		VideoEGAInstalled: boolean;
		VideoMDAInstalled: boolean;
		VideoForceNoSnow: boolean;
	function VideoGetSDLScalingMode: TSDLScalingMode;
	procedure VideoSetSDLScalingMode(value: TSDLScalingMode);
	procedure VideoWriteText(x, y, color: byte; text: TVideoLine);
	function VideoConfigure: boolean;
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
uses F_ASCII, FileSys, SysUtils, Sounds, TimerSys, SDL2;
type
	TByteArray = array of byte;
	TCharsetTexture = record
		valid: boolean;
		charWidth: Uint32;
		charHeight: Uint32;
		charsetPitch: Uint32;
		texture: PSDL_Texture;
	end;
const
	EGA_PALETTE: array[0 .. 15] of Uint32 = (
		$000000,
		$0000AA,
		$00AA00,
		$00AAAA,
		$AA0000,
		$AA00AA,
		$AA5500,
		$AAAAAA,
		$555555,
		$5555FF,
		$55FF55,
		$55FFFF,
		$FF5555,
		$FF55FF,
		$FFFF55,
		$FFFFFF
	);
	TEXT_BLINK_RATE = 534;
var
	window: PSDL_Window;
	renderer: PSDL_Renderer;
	playfieldMutex: PSDL_Mutex;
	playfieldTexture: PSDL_Texture;
	charsetTexture: TCharsetTexture;
	renderThread: PSDL_Thread;
	renderThreadRunning: boolean;
	screenBuffer: array[0 .. 3999] of byte;
	screenBufferChange: array[0 .. 3999] of boolean; { we only use the even ones }
	blinkActive: boolean;
	VideoSDLScalingMode: TSDLScalingMode;

{ Window handling }

procedure CalcRenderArea(rect: PSDL_Rect; w, h: Int32);
	var
		origw, origh, iw, ih, scale: Int32;
	begin
		iw := 80 * charsetTexture.charWidth;
		ih := 25 * charsetTexture.charHeight;
		origw := w;
		origh := h;

		scale := 1;
		while (((scale+1)*iw <= w) and ((scale+1)*ih <= h)) do Inc(scale);

		if rect <> Nil then begin
			case VideoSDLScalingMode of
				SMNone: begin
					w := iw;
					h := ih;
				end;
				SMInteger: begin
					w := iw * scale;
					h := ih * scale;
				end;
				SMOrigAspect: begin
					if (w < iw) then w := iw;
					if (h < ih) then h := ih;

					if ((w * ih div iw) > h) then
						w := h * iw div ih
					else
						h := w * ih div iw;
				end;
				SM43Aspect: begin
					if (w < iw) then w := iw;
					if (h < (iw * 3 div 4)) then h := (iw * 3 div 4);

					if (w > 640) and ((w * 3 div 4) > h) then
						w := h * 4 div 3
					else
						h := w * 3 div 4;
				end;
				SMIgnoreAspect: begin
					{ Leave w/h as-is. }
				end;
			end;

			rect^.w := w;
			rect^.h := h;
			rect^.x := (origw - w) div 2;
			rect^.y := (origh - h) div 2;
		end;
	end;

procedure SDLResizeWindow(delta: Int32; onlyIfTooSmall: boolean);
	var
		iw, ih, w, h, scale: Int32;
		destRect: TSDL_Rect;
	begin
		if window = Nil then exit;
		if VideoSDLScalingMode = SMIgnoreAspect then
			SDL_SetWindowMinimumSize(window, 80, 25)
		else begin
			iw := 80 * charsetTexture.charWidth;
			ih := 25 * charsetTexture.charHeight;
			if VideoSDLScalingMode = SM43Aspect then
				ih := iw * 3 div 4;

			SDL_SetWindowMinimumSize(window, iw, ih);
		end;

		SDL_GetWindowSize(window, @w, @h);
		CalcRenderArea(@destRect, w, h);
		Inc(scale, delta);
		if scale < 1 then scale := 1;

		iw := destRect.w;
		ih := destRect.h;

		{ TODO: if windowed }
		if (not onlyIfTooSmall) or ((iw > w) or (ih > h)) then
			SDL_SetWindowSize(window, iw, ih);
	end;

function VideoGetSDLScalingMode: TSDLScalingMode;
	begin
		VideoGetSDLScalingMode := VideoSDLScalingMode;
	end;

procedure VideoSetSDLScalingMode(value: TSDLScalingMode);
	begin
		VideoSDLScalingMode := value;
		SDLResizeWindow(0, true);
	end;

{ Charset management }

procedure FreeCharsetTexture(var tex: TCharsetTexture);
	begin
		if tex.valid then begin
			SDL_DestroyTexture(tex.texture);
			tex.valid := false;
		end;
	end;

procedure LoadCharsetFromBMP(var tex: TCharsetTexture; path: string);
	var
		surfaceOld, surface: PSDL_Surface;
		texWidth, texHeight: Int32;
		aspectRatio: Single;
	begin
		tex.valid := false;

		path := ExpandFileName(path);
		surface := SDL_LoadBMP(@path[1]);
		if surface = nil then exit;

		{ Ensure 32-bit color format for color key }
		surfaceOld := surface;
		surface := SDL_ConvertSurfaceFormat(surfaceOld, SDL_PIXELFORMAT_ARGB8888, 0);
		SDL_FreeSurface(surfaceOld);
		if surface = nil then exit;

		SDL_SetColorKey(surface, 1, PUint32(surface^.pixels)^ and $00FFFFFF);
		texWidth := surface^.w;
		texHeight := surface^.h;

		tex.texture := SDL_CreateTextureFromSurface(renderer, surface);
		SDL_FreeSurface(surface);
		if tex.texture = nil then exit;

		if (texWidth * texHeight) < 256 then begin
			FreeCharsetTexture(tex);
			exit;
		end;

		tex.valid := true;

		{ Try to figure out character width and height }
		tex.charsetPitch := 1;
		while tex.charsetPitch <= 256 do begin
			if ((texWidth mod tex.charsetPitch) = 0) and ((texHeight mod (256 div tex.charsetPitch)) = 0) then begin
				{ Proper divisors, 256 tiles }
				{ say, 8x16 will lead to 16x8 in the next iteration }
				{ so, clamping between 1:1 and 1:2 aspect ratios should work }
				tex.charWidth := (texWidth div tex.charsetPitch);
				tex.charHeight := (texHeight div (256 div tex.charsetPitch));

				{ We go from highest to lowest aspect ratio, so just pick the first one which works. }
				{ aspectRatio := Single(LongInt(tex.charWidth)) / Single(LongInt(tex.charHeight)); }
				if tex.charWidth <= tex.charHeight then begin
					exit;
				end;
			end;
			tex.charsetPitch := tex.charsetPitch shl 1;
		end;

		FreeCharsetTexture(tex);
	end;

procedure LoadCharsetFromByteArray(var tex: TCharsetTexture; chByteArray: array of byte; chSizeBytes: longint);
	var
		surface: PSDL_Surface;
		palette: array[0 .. 1] of TSDL_Color;
		colors: array[0 .. 256*128-1] of byte;
		i, ix, iy: Int32;
		iyo: Uint32;
		ib: byte;
	begin
		tex.charWidth := 8;
		tex.charHeight := chSizeBytes shr 8;
		tex.charsetPitch := 32;
		tex.valid := false;
		if (tex.charHeight < 8) or (tex.charHeight > 16) then exit;

		for i := 0 to 255 do
			for iy := 0 to (tex.charHeight - 1) do begin
				ib := chByteArray[i * tex.charHeight + iy];
				iyo := (((i shr 5) * tex.charHeight + iy) shl 8) + ((i and 31) shl 3);
				for ix := 0 to 7 do begin
					colors[iyo + ix] := (ib shr (7 - ix)) and 1;
				end;
			end;

		surface := SDL_CreateRGBSurfaceFrom(
			@colors, 256, tex.charHeight * 8, 8, 256,
			0, 0, 0, 0
		);

		if surface = nil then exit;

		palette[0].r := 0;
		palette[0].g := 0;
		palette[0].b := 0;
		palette[0].a := 0;
		palette[1].r := 255;
		palette[1].g := 255;
		palette[1].b := 255;
		palette[1].a := 255;
		SDL_SetPaletteColors(surface^.format^.palette, @palette, 0, 2);
		SDL_SetColorKey(surface, 1, 0);

		tex.texture := SDL_CreateTextureFromSurface(renderer, surface);
		SDL_FreeSurface(surface);
		if tex.texture = nil then exit;

		tex.valid := true;
	end;

{ Video drawing }

procedure VideoDrawCharBg(x, y: integer);
	var
		offset: integer;
		chr, col: byte;
		bgCol: Uint32;
		outRect: TSDL_Rect;
	begin
		offset := (y * VideoColumns + x) shl 1;
		chr := screenBuffer[offset];
		col := screenBuffer[offset + 1];

		if (col < $80) and (not screenBufferChange[offset]) then exit;

		col := col and $7F;

		bgCol := EGA_PALETTE[col shr 4];

		outRect.x := x * charsetTexture.charWidth;
		outRect.y := y * charsetTexture.charHeight;
		outRect.w := charsetTexture.charWidth;
		outRect.h := charsetTexture.charHeight;

		SDL_SetRenderDrawColor(renderer, (bgCol shr 16), (bgCol shr 8), (bgCol shr 0), SDL_ALPHA_OPAQUE);
		SDL_RenderFillRect(renderer, @outRect);
	end;

procedure VideoDrawCharFg(x, y: integer; blink: boolean);
	var
		offset: integer;
		chr, col: byte;
		fgCol: Uint32;
		inRect, outRect: TSDL_Rect;
	begin
		offset := (y * VideoColumns + x) shl 1;
		chr := screenBuffer[offset];
		col := screenBuffer[offset + 1];

		if (chr = 0) or (chr = 32) then exit;
		if (col < $80) and (not screenBufferChange[offset]) then exit;

		if blinkActive then begin
			blink := blink and (col >= $80);
			col := col and $7F;
			if blink or ((col shr 4) = (col and $0F)) then exit;
		end;

		fgCol := EGA_PALETTE[col and 15];

		inRect.x := (chr mod charsetTexture.charsetPitch) * charsetTexture.charWidth;
		inRect.y := (chr div charsetTexture.charsetPitch) * charsetTexture.charHeight;
		inRect.w := charsetTexture.charWidth;
		inRect.h := charsetTexture.charHeight;

		outRect.x := x * charsetTexture.charWidth;
		outRect.y := y * charsetTexture.charHeight;
		outRect.w := charsetTexture.charWidth;
		outRect.h := charsetTexture.charHeight;

		SDL_SetTextureColorMod(charsetTexture.texture, (fgCol shr 16), (fgCol shr 8), (fgCol shr 0));
		SDL_RenderCopy(renderer, charsetTexture.texture, @inRect, @outRect);
	end;

function VideoRenderThread(data: pointer): LongInt; cdecl;
	var
		ix, iy: integer;
		w, h: Int32;
		blink: boolean;
		destRect: TSDL_Rect;
	begin
		while renderThreadRunning do begin
			SDL_GetRendererOutputSize(renderer, @w, @h);
			CalcRenderArea(@destRect, w, h);

			SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
			SDL_RenderClear(renderer);

			SDL_SetRenderTarget(renderer, playfieldTexture);

			SDL_LockMutex(playfieldMutex);

			blink := (SDL_GetTicks mod TEXT_BLINK_RATE) >= (TEXT_BLINK_RATE div 2);

			for iy := 0 to 24 do
				for ix := 0 to (VideoColumns - 1) do
					VideoDrawCharBg(ix, iy);

			for iy := 0 to 24 do
				for ix := 0 to (VideoColumns - 1) do
					VideoDrawCharFg(ix, iy, blink);

			FillChar(screenBufferChange, 4000, false);
			SDL_UnlockMutex(playfieldMutex);

			SDL_SetRenderTarget(renderer, nil);
			SDL_RenderCopy(renderer, playfieldTexture, nil, @destRect);

			SDL_RenderPresent(renderer);
			TimerSysWake(IMUntilFrame);
			SDL_Delay(1);
		end;
		VideoRenderThread := 0;
	end;

procedure VideoWriteText(x, y, color: byte; text: TVideoLine);
	var
		i, offset: integer;
	begin
		offset := (y * VideoColumns + x) shl 1;
		SDL_LockMutex(playfieldMutex);
		for i := 1 to Length(text) do begin
			screenBuffer[offset] := Byte(text[i]);
			screenBufferChange[offset] := true;
			Inc(offset);
			screenBuffer[offset] := color;
			Inc(offset);
		end;
		SDL_UnlockMutex(playfieldMutex);
	end;

function VideoConfigure: boolean;
	begin
		{ stub }
		VideoConfigure := true;
	end;

function VideoSetCharset(data: pointer; height: integer): boolean;
	label FinishSetCharset;
	begin
		VideoSetCharset := false;

		FreeCharsetTexture(charsetTexture);

		if data <> Nil then begin
			LoadCharsetFromByteArray(charsetTexture, TByteArray(data), height shl 8);
			if charsetTexture.valid then begin
				VideoSetCharset := true;
				goto FinishSetCharset;
			end;
		end;

		LoadCharsetFromByteArray(charsetTexture, F_ASCIIData, F_ASCIISize);
		if not charsetTexture.valid then
			RunError(217);

FinishSetCharset:
		SDLResizeWindow(0, true);
	end;

procedure VideoInstall(borderColor: integer);
	var
		charsetSurface: PSDL_Surface;
		resPath: string;
		asciiBmpPath: string;
		f: file;
	begin
		VideoColumns := 80;
		VideoSDLScalingMode := SMInteger;

		window := SDL_CreateWindow('%NAME% %VERSION%',
			SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
			640, 350, SDL_WINDOW_RESIZABLE or SDL_WINDOW_ALLOW_HIGHDPI);
		resPath := IncludeTrailingPathDelimiter(ExtractFileDir(ExpandFileName(ParamStr(0))));

		renderer := SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED or SDL_RENDERER_PRESENTVSYNC);
		SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, '0');

		LoadCharsetFromByteArray(charsetTexture, F_ASCIIData, F_ASCIISize);
		if not charsetTexture.valid then
			RunError(217);

		playfieldTexture := SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET,
			VideoColumns * charsetTexture.charWidth, 25 * charsetTexture.charHeight);
		SDL_SetWindowSize(window, VideoColumns * charsetTexture.charWidth, 25 * charsetTexture.charHeight);

		playfieldMutex := SDL_CreateMutex;

		SDLResizeWindow(0, false);

		SDL_RenderClear(renderer);
		SDL_RenderPresent(renderer);

		renderThreadRunning := true;
		renderThread := SDL_CreateThread(VideoRenderThread, 'Render thread', nil);

		blinkActive := true;
	end;

procedure VideoUninstall;
	begin
		renderThreadRunning := false;
		SDL_WaitThread(renderThread, nil);

		SDL_DestroyMutex(playfieldMutex);
		SDL_DestroyTexture(playfieldTexture);
		FreeCharsetTexture(charsetTexture);
		SDL_DestroyRenderer(renderer);
		SDL_DestroyWindow(window);
	end;

procedure VideoSetCursorShape(value: integer);
	begin
		{ stub }
	end;

procedure VideoShowCursor;
	begin
		{ stub }
		VideoCursorVisible := true;
	end;

procedure VideoHideCursor;
	begin
		{ stub }
		VideoCursorVisible := false;
	end;

procedure VideoSetBorderColor(value: integer);
	begin
		{ stub }
	end;

procedure VideoSetBlink(value: boolean);
	begin
		blinkActive := value;
	end;

procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	var
		i, offset: integer;
	begin
		offset := (y * VideoColumns + x) shl 1;
		if toVideo then begin
			SDL_LockMutex(playfieldMutex);
			Move(data^, screenBuffer[offset], chars shl 1);
			for i := 0 to chars - 1 do
				screenBufferChange[offset + (i shl 1)] := true;
			SDL_UnlockMutex(playfieldMutex);
		end else begin
			Move(screenBuffer[offset], data^, chars shl 1);
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
		SDL_LockMutex(playfieldMutex);
		for iy := y1 to y2 do begin
			offset := (((iy * VideoColumns) + x1) shl 1);
			for ix := x1 to x2 do begin
				screenBuffer[offset + 1] := screenBuffer[offset + 1] xor $7F;
				screenBufferChange[offset] := true;
				Inc(offset, 2);
			end;
		end;
		SDL_UnlockMutex(playfieldMutex);
	end;

begin
	FillChar(screenBuffer, 4000, 0);
	FillChar(screenBufferChange, 4000, true);
	VideoBorderColor := 0;
	VideoColumns := 80;
	VideoCursorVisible := true;
end.
