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
	var
		VideoMonochrome: boolean;
		VideoColumns: integer;
		VideoBorderColor: integer;
		VideoTextSegment: word;
		VideoTextPointer: pointer;
		VideoCursorVisible: boolean;
		VideoEGAInstalled: boolean;
		VideoMDAInstalled: boolean;
	procedure VideoWriteText(x, y, color: byte; text: TVideoLine);
	function VideoConfigure: boolean;
	procedure VideoInstall(columns, borderColor: integer);
	procedure VideoUninstall;
	procedure VideoShowCursor;
	procedure VideoHideCursor;
	procedure VideoSetBorderColor(value: integer);
	procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);

implementation
uses Sounds, TimerSys, SDL2;
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
var
	window: PSDL_Window;
	renderer: PSDL_Renderer;
	playfieldMutex: PSDL_Mutex;
	playfieldTexture: PSDL_Texture;
	charsetTexture: PSDL_Texture;
	renderThread: PSDL_Thread;
	renderThreadRunning: boolean;
	screenBuffer: array[0 .. 3999] of byte;
	screenBufferChange: array[0 .. 3999] of boolean; { we only use the even ones }

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

		outRect.x := x * 8;
		outRect.y := y * 14;
		outRect.w := 8;
		outRect.h := 14;

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

		blink := blink and (col >= $80);
		col := col and $7F;
		if blink or ((col shr 4) = (col and $0F)) then exit;

		fgCol := EGA_PALETTE[col and 15];

		inRect.x := (chr and 31) * 8;
		inRect.y := (chr shr 5) * 14;
		inRect.w := 8;
		inRect.h := 14;

		outRect.x := x * 8;
		outRect.y := y * 14;
		outRect.w := 8;
		outRect.h := 14;

		SDL_SetTextureColorMod(charsetTexture, (fgCol shr 16), (fgCol shr 8), (fgCol shr 0));
		SDL_RenderCopy(renderer, charsetTexture, @inRect, @outRect);
	end;

function VideoRenderThread(data: pointer): LongInt; cdecl;
	var
		ix, iy: integer;
		blink: boolean;
	begin
		while renderThreadRunning do begin
			SDL_RenderClear(renderer);
			SDL_SetRenderTarget(renderer, playfieldTexture);

			SDL_LockMutex(playfieldMutex);

			blink := (SDL_GetTicks mod 534) >= 267;

			for iy := 0 to 24 do
				for ix := 0 to (VideoColumns - 1) do
					VideoDrawCharBg(ix, iy);

			for iy := 0 to 24 do
				for ix := 0 to (VideoColumns - 1) do
					VideoDrawCharFg(ix, iy, blink);

			FillChar(screenBufferChange, 4000, false);
			SDL_UnlockMutex(playfieldMutex);

			SDL_SetRenderTarget(renderer, nil);
			SDL_RenderCopy(renderer, playfieldTexture, nil, nil);

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

procedure VideoInstall(columns, borderColor: integer);
	var
		charsetSurface: PSDL_Surface;
	begin
		VideoColumns := columns;
		window := SDL_CreateWindow('Zeta2',
			SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
			640, 350, 0);

		renderer := SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED or SDL_RENDERER_PRESENTVSYNC);
		SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, '0');

		charsetSurface := SDL_LoadBMP('charset.bmp');
		SDL_SetColorKey(charsetSurface, 1, 0);
		charsetTexture := SDL_CreateTextureFromSurface(renderer, charsetSurface);
		SDL_FreeSurface(charsetSurface);
		{ charsetTexture := SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_STATIC, 256, 112); }
		playfieldTexture := SDL_CreateTexture(renderer, SDL_PIXELFORMAT_RGBA8888, SDL_TEXTUREACCESS_TARGET, 640, 350);

		playfieldMutex := SDL_CreateMutex;

		SDL_RenderClear(renderer);
		SDL_RenderPresent(renderer);

		renderThreadRunning := true;
		renderThread := SDL_CreateThread(VideoRenderThread, 'Render thread', nil);
	end;

procedure VideoUninstall;
	begin
		renderThreadRunning := false;
		SDL_WaitThread(renderThread, nil);

		SDL_DestroyMutex(playfieldMutex);
		SDL_DestroyTexture(playfieldTexture);
		SDL_DestroyTexture(charsetTexture);
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

begin
	FillChar(screenBuffer, 4000, 0);
	FillChar(screenBufferChange, 4000, true);
	VideoBorderColor := 0;
	VideoColumns := 80;
	VideoCursorVisible := true;
end.
