{
	Copyright (c) 2020 Adrian Siekierka

	Based on a reconstruction of code from Super ZZT,
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
unit Video;

interface
	type
		TVideoLine = string[80];
		TVideoWriteTextProc = procedure(x, y, color: byte; text: TVideoLine);
		TCharsetData = array[0 .. 31999] of byte;
		PTCharsetData = ^TCharsetData;
	const
		PORT_CGA_MODE = $03D8;
		PORT_CGA_PALETTE = $03D9;
		VIDEO_MODE_40X25 = 0;
		VIDEO_MODE_80X25 = 1;
		VIDEO_MODE_80X43 = 2;
		VIDEO_MODE_80X50 = 3;
	var
		VideoWriteText: TVideoWriteTextProc;
		VideoForceNoSnow: boolean;
		VideoUseCustomFont: boolean;
		VideoMonochrome: boolean;
		VideoColumns: integer;
		VideoRows: integer;
		VideoCurrentMode: integer;
		VideoTextSegment: word;
		VideoTextPointer: pointer;
		VideoCursorVisible: boolean;
		VideoEGAInstalled: boolean;
		VideoVGAInstalled: boolean;
		VideoMDAInstalled: boolean;
	procedure VideoScroll(x, y, width, height, dx, dy: integer);
	function VideoConfigure: boolean;
	function VideoSetCharset(data: PTCharsetData; height: integer): boolean;
	function VideoInstall(mode, borderColor: integer): boolean;
	procedure VideoUninstall;
	procedure VideoShowCursor;
	procedure VideoHideCursor;
	procedure VideoSetBorderColor(value: integer);
	procedure VideoSetBlink(value: boolean);
	procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	procedure VideoClear(bgColor: integer);
	procedure VideoInvert(x1, y1, x2, y2: integer);

implementation
uses Crt, Dos;

{ const
	VideoEGAPalette: array[0 .. 16] of byte = (
		$00, $01, $02, $03, $04, $05, $14, $07,
		$38, $39, $3A, $3B, $3C, $3D, $3E, $3F,
		$00
	); }
var
	VideoMaxMode: integer;

{$F+}

{$IFNDEF FPC}
procedure VideoWriteTextCGA(x, y, color: byte; text: TVideoLine);
	begin
		inline(
			$06/                 { PUSH ES }
			$8B/$06/VideoTextSegment/{ MOV AX, VideoTextSegment }
			$8E/$C0/             { MOV ES, AX }
			$8A/$86/y/           { MOV AL, byte ptr [BP + y] }
			$F6/$26/VideoColumns/{ MUL VideoColumns }
			$31/$C9/             { XOR CX, CX }
			$89/$CE/             { MOV SI, CX }
			$8A/$8E/x/           { MOV CL, byte ptr [BP + x] }
			$01/$C8/             { ADD AX, CX }
			$D1/$E0/             { SHL AX, 1 }
			$8B/$F8/             { MOV DI, AX }
			$8A/$BE/color/       { MOV BH, byte ptr [BP + color] }
			$8A/$8E/text/        { MOV CL, byte ptr [BP + text] }
			$BA/$03DA/           { MOV DX, 0x03DA }
			$22/$C9/             { AND CL, CL }
			$74/$1A/             { JZ finish }
			$FA/                 { CLI }
		{ next_char: }
			$46/                 { INC SI }
			$8A/$9A/text/        { MOV BL, byte ptr [BP + SI + text] }
		{ cga_snow: }
			$EC/                 { IN AL, DX }
			$A8/$08/             { TEST AL, 8 }
			$75/$09/             { JNZ write_char }
			$D0/$E8/             { SHR AL, 1 }
			$72/$F7/             { JC cga_snow }
		{ cga_snow2: }
			$EC/                 { IN AL, DX }
			$D0/$E8/             { SHR AL, 1 }
			$73/$FB/             { JNC cga_snow2 }
		{ write_char: }
			$89/$D8/             { MOV AX, BX }
			$AB/                 { STOSW }
			$E2/$E8/             { LOOP next_char }
			$FB/                 { STI }
		{ finish: }
			$07                  { POP ES }
		);
	end;

procedure VideoWriteTextFast(x, y, color: byte; text: TVideoLine);
	begin
		inline(
			$06/                 { PUSH ES }
			$8B/$06/VideoTextSegment/{ MOV AX, VideoTextSegment }
			$8E/$C0/             { MOV ES, AX }
			$8A/$86/y/           { MOV AL, byte ptr [BP + y] }
			$F6/$26/VideoColumns/{ MUL VideoColumns }
			$31/$C9/             { XOR CX, CX }
			$89/$CE/             { MOV SI, CX }
			$8A/$8E/x/           { MOV CL, byte ptr [BP + x] }
			$01/$C8/             { ADD AX, CX }
			$D1/$E0/             { SHL AX, 1 }
			$8B/$F8/             { MOV DI, AX }
			$8A/$A6/color/       { MOV AH, byte ptr [BP + color] }
			$8A/$8E/text/        { MOV CL, byte ptr [BP + text] }
			$22/$C9/             { AND CL, CL }
			$74/$0A/             { JZ finish }
			$FA/                 { CLI }
		{ next_char: }
			$46/                 { INC SI }
			$8A/$82/text/        { MOV AL, byte ptr [BP + SI + text] }
			$AB/                 { STOSW }
			$E2/$F8/             { LOOP next_char }
			$FB/                 { STI }
		{ finish: }
			$07                  { POP ES }
		);
	end;
{$ELSE}
procedure VideoWriteTextCGA(x, y, color: byte; text: TVideoLine);
	assembler;
	label next_char;
	label cga_snow;
	label cga_snow2;
	label write_char;
	label finish;
	asm
		push es
		mov ax, VideoTextSegment
		mov es, ax
		mov al, y
		mul VideoColumns
		xor cx, cx
		mov cl, x
		add ax, cx
		shl ax, 1
		mov di, ax
		mov bh, color
		mov dx, 03DAh
		push ds
		lds si, [text]
		mov cl, [si]
		and cl, cl
		jz finish
		cli
	next_char:
		inc si
		mov bl, [si]
	cga_snow:
		in al, dx
		test al, 8
		jnz write_char
		shr al, 1
		jc cga_snow
	cga_snow2:
		in al, dx
		shr al, 1
		jnc cga_snow2
	write_char:
		mov ax, bx
		stosw
		loop next_char
		sti
	finish:
		pop ds
		pop es
	end ['ax', 'bx', 'cx', 'dx', 'si', 'di'];

procedure VideoWriteTextFast(x, y, color: byte; text: TVideoLine);
	assembler;
	label next_char;
	label finish;
	asm
		push es
		mov ax, VideoTextSegment
		mov es, ax
		mov al, y
		mul VideoColumns
		xor cx, cx
		mov cl, x
		add ax, cx
		shl ax, 1
		mov di, ax
		mov ah, color
		mov dx, 03DAh
		push ds
		lds si, [text]
		mov cl, [si]
		and cl, cl
		jz finish
		cli
	next_char:
		inc si
		mov al, [si]
		stosw
		loop next_char
		sti
	finish:
		pop ds
		pop es
	end ['ax', 'cx', 'dx', 'si', 'di'];
{$ENDIF}

function ColorToBW(color: byte): byte;
	begin
		if ((color shr 4) and $07) = (color and $0F) then
			color := $FF { Special color for solids }
		else if (color and $08) = $08 then begin
			if (color and $F0) = 0 then
				color := $0F
			else
				color := $7F;
		end else begin
			if (color and $07) <> 0 then
				color := $07
			else
				color := $70;
		end;

		ColorToBW := color;
	end;

procedure VideoWriteTextCGABW(x, y, color: byte; text: TVideoLine);
	begin
		color := ColorToBW(color);
		if (color = $FF) and (Length(text) = 1) then begin
			text[1] := #219;
			color := $07;
		end;

		VideoWriteTextCGA(x, y, ColorToBW(color), text);
	end;

procedure VideoWriteTextFastBW(x, y, color: byte; text: TVideoLine);
	begin
		color := ColorToBW(color);
		if (color = $FF) and (Length(text) = 1) then begin
			text[1] := #219;
			color := $07;
		end;

		VideoWriteTextFast(x, y, color, text);
	end;

{$F-}

procedure VideoScroll(x, y, width, height, dx, dy: integer);
	var
		iy: integer;
		srcOfs, destOfs: integer;
		unk1: string;
	begin
		if dy = 0 then begin
			if dx >= 0 then begin
				{ move right }
				srcOfs := (y * VideoColumns + x) * 2;
				destOfs := srcOfs + (dx * 2);
				for iy := 1 to height do begin
 					{ if (iy mod 2) = 1 then
						VideoWriteTextCO80(0, 0, 0, ''); }
					Move(Ptr(VideoTextSegment, srcOfs)^, Ptr(VideoTextSegment, destOfs)^, (width - dx) * 2);
					srcOfs := srcOfs + (VideoColumns * 2);
					destOfs := destOfs + (VideoColumns * 2);
				end;
			end else begin
				{ move left }
				destOfs := (y * VideoColumns + x) * 2;
				srcOfs := destOfs - (dx * 2);
				for iy := 1 to height do begin
 					{ if (iy mod 2) = 1 then
						VideoWriteTextCO80(0, 0, 0, ''); }
					Move(Ptr(VideoTextSegment, srcOfs)^, Ptr(VideoTextSegment, destOfs)^, (width + dx) * 2);
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
 					{ if (iy mod 2) = 1 then
						VideoWriteTextCO80(0, 0, 0, ''); }
					Move(Ptr(VideoTextSegment, srcOfs)^, Ptr(VideoTextSegment, destOfs)^, width * 2);
					srcOfs := srcOfs - (VideoColumns * 2);
					destOfs := destOfs - (VideoColumns * 2);
				end;
			end else begin
				{ move up }
				destOfs := (y * VideoColumns + x) * 2;
				srcOfs := VideoColumns * 2 + destOfs;
				for iy := 1 to (height - 1) do begin
 					{ if (iy mod 2) = 1 then
						VideoWriteTextCO80(0, 0, 0, ''); }
					Move(Ptr(VideoTextSegment, srcOfs)^, Ptr(VideoTextSegment, destOfs)^, width * 2);
					srcOfs := srcOfs + (VideoColumns * 2);
					destOfs := destOfs + (VideoColumns * 2);
				end;
			end;
		end;
	end;

function VideoSetCharset(data: PTCharsetData; height: integer): boolean;
	var
		regs: Registers;
	begin
		VideoSetCharset := false;
		if not VideoEGAInstalled then exit;
		if (height <> 8) and (height <> 14) then exit;
		if not VideoVGAInstalled then begin
			if (height <> 8) and (VideoRows = 43) then exit;
			if (height <> 14) and (VideoRows = 25) then exit;
		end;

		regs.BX := (height shl 8);
		regs.CX := 256;
		regs.DX := 0;

		regs.AX := $1110;
		regs.ES := Seg(data^);
		regs.BP := Ofs(data^);

		Intr($10, regs);

		VideoHideCursor;
		VideoSetCharset := true;
	end;

function VideoConfigure: boolean;
	var
		charTyped: Char;
	begin
		charTyped := ' ';
		if LastMode = 7 then begin
			VideoWriteText := VideoWriteTextFastBW;
			VideoMonochrome := true;
		end else begin
			Writeln;
			Write('  Video mode:  C)olor,  M)onochrome?  ');
			repeat
				repeat until KeyPressed;
				charTyped := UpCase(ReadKey);
			until charTyped in [#27, 'C', 'M'];
			case charTyped of
				'C': VideoMonochrome := false;
				'M': VideoMonochrome := true;
				#27: VideoMonochrome := (LastMode = 7);
			end;
			WriteLn;
			WriteLn;
			WriteLn;
			WriteLn('  Maximum text resolution:  ');
			WriteLn('    1) 80x25   2) 80x43   3) 80x50?  ');
			repeat
				repeat until KeyPressed;
				charTyped := UpCase(ReadKey);
			until charTyped in [#27, '1', '2', '3'];
			if charTyped <> #27 then
				VideoMaxMode := Ord(charTyped) - Ord('0');
		end;
		VideoConfigure := charTyped <> #27;
	end;

procedure VideoPreInstall;
	var
		regs: Registers;
	begin
		VideoMDAInstalled := LastMode = 7;
		VideoVGAInstalled := false;

		regs.AH := $12;
		regs.BX := $FF10;
		Intr($10, regs);
		VideoEGAInstalled := regs.BH <> $FF;

		if VideoEGAInstalled then begin
			regs.AX := $1A00;
			Intr($10, regs);
			VideoVGAInstalled := regs.AL = $1A;
		end;
	end;

function VideoInstall(mode, borderColor: integer): boolean;
	var
		regs: Registers;
	begin
		VideoInstall := false;
		if mode > VideoMaxMode then exit;
		if (mode >= VIDEO_MODE_80X43) and (not VideoEGAInstalled) then exit;
		if (mode >= VIDEO_MODE_80X50) and (not VideoVGAInstalled) then exit;

		VideoColumns := 80;
		VideoRows := 25;
		if mode = VIDEO_MODE_40X25 then
			VideoColumns := 40
		else if mode = VIDEO_MODE_80X43 then
			VideoRows := 43
		else if mode = VIDEO_MODE_80X50 then
			VideoRows := 50;

		if VideoVGAInstalled then begin
			if mode = VIDEO_MODE_80X50 then
				regs.AX := $1202
			else if (mode = VIDEO_MODE_80X43) or (not VideoUseCustomFont) then
				regs.AX := $1201
			else
				regs.AX := $1200;
			regs.BL := $30;
			Intr($10, regs);

			if (regs.AL <> $12) and (VideoRows <> 25) then exit;
		end;

		if VideoMonochrome then begin
			if VideoEGAInstalled or VideoMDAInstalled or VideoForceNoSnow then
				VideoWriteText := VideoWriteTextFastBW
			else
				VideoWriteText := VideoWriteTextCGABW;

			if (LastMode >= 0) and (LastMode <= 3) then begin
				if VideoColumns = 80 then begin
					TextMode(BW80);
				end else begin
					TextMode(BW40);
				end;
			end else begin
				TextMode(7);
				VideoColumns := 80;
			end;
		end else begin
			if VideoEGAInstalled or VideoMDAInstalled or VideoForceNoSnow then
				VideoWriteText := VideoWriteTextFast
			else
				VideoWriteText := VideoWriteTextCGA;

			if VideoColumns = 80 then begin
				TextMode(CO80);
			end else begin
				TextMode(CO40);
			end;

			TextBackground(borderColor);
		end;

		if VideoEGAInstalled then begin
			{ set default charset }
			if VideoRows >= 43 then
				regs.AX := $1112
			else
				regs.AX := $1111;
			regs.BL := $00;
			Intr($10, regs);

			{ set palette }
			{ regs.AX := $1002;
			regs.BX := $0000;
			regs.ES := Seg(VideoEGAPalette);
			regs.DX := Ofs(VideoEGAPalette);
			VideoEGAPalette[16] := VideoEGAPalette[borderColor];
			Intr($10, regs); }
		end;

		VideoClear(borderColor);

		if not VideoCursorVisible then
			VideoHideCursor;
		VideoSetBorderColor(borderColor);

		if VideoVGAInstalled then begin
			{ Set 8-dot-clock character mode.  }
			Port[$3C4] := $01;
			Port[$3C5] := (Port[$3C5]) or $01;
			Port[$3C4] := $01;

			if (VideoRows = 25) then begin
				Port[$3D4] := $09;
				Port[$3D5] := (Port[$3D5]) or $80;
				Port[$3D4] := $09;
			end;
		end;

		VideoCurrentMode := mode;
		VideoInstall := true;
	end;

procedure VideoUninstall;
	var
		regs: Registers;
	begin
		if VideoEGAInstalled then begin
			regs.AX := $1201;
			regs.BL := $30;
			Intr($10, regs);
		end;

		TextBackground(0);
		VideoColumns := 80;
		if VideoMonochrome then
			TextMode(BW80)
		else
			TextMode(CO80);
		VideoSetBorderColor(0);
		ClrScr;
	end;

procedure VideoSetCursorShape(value: integer);
	var
		regs: Registers;
	begin
		regs.AH := $01;
		regs.CX := value;
		Intr($10, regs);
	end;

procedure VideoShowCursor;
	begin
		VideoSetCursorShape($0607);
		VideoCursorVisible := true;
	end;

procedure VideoHideCursor;
	begin
		VideoSetCursorShape($2000);
		VideoCursorVisible := false;
	end;

procedure VideoSetBorderColor(value: integer);
	begin
		Port[PORT_CGA_PALETTE] := value;
	end;

procedure VideoSetBlink(value: boolean);
	var
		regs: Registers;
	begin
		{ CGA route }
		if value then
			Port[PORT_CGA_MODE] := Port[PORT_CGA_MODE] or $20
		else
			Port[PORT_CGA_MODE] := Port[PORT_CGA_MODE] and $DF;
		{ EGA/VGA route }
		regs.AX := $1003;
		regs.BH := 0;
		regs.BL := Byte(value);
		Intr($10, regs);
	end;

procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	var
		offset: integer;
	begin
		offset := (y * VideoColumns + x) * 2;
		if toVideo then
			Move(data^, Ptr(VideoTextSegment, offset)^, chars * 2)
		else
			Move(Ptr(VideoTextSegment, offset)^, data^, chars * 2);
	end;

procedure VideoClear(bgColor: integer);
	begin
		if VideoMonochrome then begin
			TextBackground(0);
			ClrScr;
		end else begin
			TextBackground(bgColor);
			FillChar(Ptr(VideoTextSegment, $0000)^, VideoColumns * VideoRows * 2, bgColor * $11);
		end;
	end;

procedure VideoInvert(x1, y1, x2, y2: integer);
	var
		ix, iy, offset: integer;
	begin
		{ moved to EditorBoardInvert }
		{ if x2 < x1 then begin
			ix := x1;
			x1 := x2;
			x2 := ix;
		end;
		if y2 < y1 then begin
			ix := y1;
			y1 := y2;
			y2 := ix;
		end; }
		for iy := y1 to y2 do begin
			offset := (((iy * VideoColumns) + x1) shl 1) + 1;
			for ix := x1 to x2 do begin
				Mem[VideoTextSegment:offset] := Mem[VideoTextSegment:offset] xor $7F;
				Inc(offset, 2);
			end;
		end;
	end;

begin
	VideoColumns := 80;
	VideoWriteText := VideoWriteTextCGA;
	if LastMode = 7 then begin
		VideoTextSegment := $B000;
		VideoMonochrome := true;
	end else begin
		VideoTextSegment := $B800;
		VideoMonochrome := false;
	end;
	VideoTextPointer := Ptr(VideoTextSegment, $0000);
	VideoCursorVisible := true;
	VideoForceNoSnow := false;
	VideoMaxMode := VIDEO_MODE_80X25;

	VideoPreInstall;
end.
