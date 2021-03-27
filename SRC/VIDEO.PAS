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
unit Video;

interface
	type
		TVideoLine = string[80];
		TVideoWriteTextProc = procedure(x, y, color: byte; text: TVideoLine);
	const
		PORT_CGA_PALETTE = $03D9;
		EGA_PALETTE_INDICES: array[0..16] of char = (
			#$00, #$01, #$02, #$03, #$04, #$05, #$06, #$07,
			#$08, #$09, #$0A, #$0B, #$0C, #$0D, #$0E, #$0F, #$00
		);
		PALLETTE: array[0..6] of array[1..48] of char = (
		{Fade - Starts as Normal}
		(
			#$00, #$00, #$00, 
			#$00, #$00, #$28, 
			#$04, #$26, #$00, 
			#$00, #$26, #$28, 
			#$28, #$00, #$00, 
			#$26, #$00, #$28, 
			#$26, #$13, #$00, 
			#$23, #$23, #$26, 
			#$0F, #$0F, #$0F, 
			#$13, #$0A, #$00, 
			#$0A, #$3C, #$14, 
			#$14, #$39, #$3C, 
			#$3C, #$17, #$17, 
			#$39, #$14, #$3C, 
			#$3C, #$3C, #$14, 
			#$3C, #$3C, #$3C
		),
		{Normal}
		(
			#$00, #$00, #$00, 
			#$00, #$00, #$28, 
			#$04, #$26, #$00, 
			#$00, #$26, #$28, 
			#$28, #$00, #$00, 
			#$26, #$00, #$28, 
			#$26, #$13, #$00, 
			#$23, #$23, #$26, 
			#$0F, #$0F, #$0F, 
			#$13, #$0A, #$00, 
			#$0A, #$3C, #$14, 
			#$14, #$39, #$3C, 
			#$3C, #$17, #$17, 
			#$39, #$14, #$3C, 
			#$3C, #$3C, #$14, 
			#$3C, #$3C, #$3C
		),
		{Bright}
		(
			#$00, #$00, #$00,
			#$00, #$00, #$2F,
			#$05, #$2F, #$00,
			#$00, #$2F, #$2F,
			#$35, #$00, #$00,
			#$32, #$00, #$2F,
			#$32, #$18, #$00,
			#$2D, #$2A, #$2D,
			#$13, #$12, #$11,
			#$19, #$0C, #$00,
			#$0D, #$3F, #$18,
			#$1B, #$3F, #$3F,
			#$3F, #$1C, #$1B,
			#$3F, #$19, #$3F,
			#$3F, #$3F, #$18,
			#$3F, #$3F, #$3F
		),
		{Dim}
		(
			#$00, #$00, #$00,
			#$00, #$00, #$1B,
			#$02, #$16, #$00,
			#$00, #$16, #$1B,
			#$13, #$00, #$00,
			#$12, #$00, #$1B,
			#$12, #$0B, #$00,
			#$10, #$14, #$19,
			#$07, #$08, #$0A,
			#$09, #$06, #$00,
			#$05, #$22, #$0E,
			#$0A, #$20, #$28,
			#$1C, #$0D, #$0F,
			#$1A, #$0C, #$28,
			#$1C, #$22, #$0E,
			#$1C, #$22, #$28
		),
		{Dank}
		(
			#$00, #$00, #$00,
			#$00, #$00, #$12,
			#$00, #$0D, #$00,
			#$00, #$0D, #$12,
			#$08, #$00, #$00,
			#$07, #$00, #$12,
			#$07, #$08, #$00,
			#$07, #$0C, #$11,
			#$02, #$06, #$09,
			#$03, #$05, #$00,
			#$01, #$13, #$0B,
			#$04, #$12, #$18,
			#$0D, #$09, #$0C,
			#$0C, #$08, #$18,
			#$0D, #$13, #$0B,
			#$0D, #$13, #$18
		),
		{Deep}
		(
			#$00, #$00, #$00,
			#$00, #$00, #$09,
			#$00, #$06, #$00,
			#$00, #$06, #$09,
			#$03, #$00, #$00,
			#$02, #$00, #$09,
			#$02, #$04, #$00,
			#$02, #$06, #$09,
			#$00, #$03, #$05,
			#$01, #$02, #$00,
			#$00, #$09, #$06,
			#$01, #$09, #$0D,
			#$05, #$04, #$07,
			#$05, #$04, #$0D,
			#$05, #$09, #$06,
			#$05, #$09, #$0D
		),
		{Poisoned}
		(
			#$00, #$10, #$00,
			#$00, #$10, #$1B,
			#$02, #$26, #$00,
			#$00, #$26, #$1B,
			#$13, #$10, #$00,
			#$12, #$10, #$1B,
			#$12, #$1B, #$00,
			#$10, #$24, #$19,
			#$07, #$18, #$0A,
			#$09, #$16, #$00,
			#$05, #$32, #$0E,
			#$0A, #$30, #$28,
			#$1C, #$1D, #$0F,
			#$1A, #$1C, #$28,
			#$1C, #$32, #$0E,
			#$1C, #$32, #$28
		));
	var
		VideoWriteText: TVideoWriteTextProc;
		VideoColumns: integer;
		VideoTextSegment: word;
	function VideoConfigure: boolean;
	procedure VideoInstall(columns, borderColor: integer);
	procedure VideoUninstall;
	procedure VideoShowCursor;
	procedure VideoHideCursor;
	procedure VideoSetBorderColor(value: integer);
	procedure VideoMove(x, y, chars: integer; data: pointer; toVideo: boolean);
	procedure SetNoBlink;
	procedure SetFont;
	procedure SetPal(value: integer);
	procedure SetColor(c, r, g, b: byte);
	procedure FadePalSet(value: integer);
	function FadeOut: boolean;
	function FadeWhite: boolean;
	function FadeIn(value: integer): boolean;
	function FadeDown(value: integer): boolean;
	procedure TrueDelay(value: word);

implementation
uses Crt, Dos, ZetaSupp, AccDelay, Binb4;

procedure TrueDelay(value: word);
	var
		regs: Registers;
	begin
		if ZetaDetected then ZetaDelay(value) else AccurateDelay(value);
	end;

procedure FadePalSet(value: integer);
	begin
		if value < 2 then
			PALLETTE[0] := PALLETTE[1]
		else
			PALLETTE[0] := PALLETTE[value];
	end;

function FadeOut: boolean;
	var
		i: integer;
	begin
		for i := 1 to 48 do begin
			if PALLETTE[0][i] > #$04 then begin
				PALLETTE[0][i] := Chr(Ord(PALLETTE[0][i]) - 4);
				FadeOut := false;
			end else
				PALLETTE[0][i] := #$00;
		end;
		TrueDelay(17);
		SetPal(0);
	end;

function FadeWhite: boolean;
	var
		i: integer;
	begin
		for i := 1 to 48 do begin
			if PALLETTE[0][i] < #$3B then begin
				PALLETTE[0][i] := Chr(Ord(PALLETTE[0][i]) + 2);
				FadeWhite := false;
			end else
				PALLETTE[0][i] := #$3F;
		end;
		TrueDelay(25);
		SetPal(0);
	end;

function FadeDown(value: integer): boolean;
	var
		i, k: integer;
	begin
		if value < 2 then
			k := 1
		else
			k := value;
		FadeDown := true;
		for i := 1 to 48 do begin
			if PALLETTE[0][i] > PALLETTE[k][i] then begin
				FadeDown := false;
				PALLETTE[0][i] := Chr(Ord(PALLETTE[0][i]) - 2);
				if PALLETTE[0][i] < PALLETTE[k][i] then
					Inc(PALLETTE[0][i]);
			end;
		end;
		TrueDelay(17);
		SetPal(0);
	end;


function FadeIn(value: integer): boolean;
	var
		i, k: integer;
	begin
		if value < 2 then
			k := 1
		else
			k := value;
		FadeIn := true;
		for i := 1 to 48 do begin
			PALLETTE[0][i] := Chr(Ord(PALLETTE[0][i]) + 4);
			if PALLETTE[0][i] > PALLETTE[k][i] then
				PALLETTE[0][i] := PALLETTE[k][i]
			else
				FadeIn := false;
		end;
		TrueDelay(17);
		SetPal(0);
	end;

procedure SetNoBlink;
	var
		regs: Registers;
	begin
		regs.ax := $1003;
		regs.bx := $0000;
		Intr($10, regs);
	end;

procedure SetFont;
	var
		regs: Registers;
	begin
		regs.ax := $1110;
		regs.bh := $0E;                           (* bytes per character *)
		regs.bl := 0;                             (* load to block 0 *)
		regs.cx := 256;                           (* 256 characters *)
		regs.dx := 0;                             (* start with character 0 *)
		regs.es := Seg(b4);  				      (* segment of table *)
		regs.bp := Ofs(b4);     				  (* offset of the table *)
		intr($10, regs);
	end;

procedure SetPal(value: integer);
	var
		regs: Registers;
	begin
		regs.ax := $1002;
		regs.es := Seg(EGA_PALETTE_INDICES);
		regs.dx := Ofs(EGA_PALETTE_INDICES);
		Intr($10, regs);

		regs.ax := $1012;
		regs.bx := 0;
		regs.cx := 16;
		regs.es := Seg(PALLETTE[value]);        (* segment of table *)
		regs.dx := Ofs(PALLETTE[value]);        (* offset of the table *)
		intr($10, regs);
	end;

procedure SetColor(c, r, g, b: byte);
	var
		regs: Registers;
	begin
		regs.ax := $1010;
		regs.bx := c;
		regs.dh := r;
		regs.cl := g;
		regs.ch := b;
		intr($10, regs);
	end;

{$F+}

procedure VideoWriteTextCO80(x, y, color: byte; text: TVideoLine);
	begin
		inline(
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
			$FB                  { STI }
		{ finish: }
		);
	end;

{$F-}

function VideoConfigure: boolean;
	var
		charTyped: Char;
	begin
		charTyped := ' ';
		Writeln;
		Write('  Video mode:  C)olor,  M)onochrome?  ');
		repeat
			repeat until KeyPressed;
			charTyped := UpCase(ReadKey);
		until charTyped in [#27, 'C', 'M'];
		VideoConfigure := true;
	end;

procedure VideoInstall(columns, borderColor: integer);
	var
		regs: Registers;
	begin
		regs.AX := $1201;
		regs.BL := $30;
		Intr($10, regs);

		TextBackground(borderColor);
		VideoColumns := columns;
		TextMode(CO80);
		VideoWriteText := VideoWriteTextCO80;
		TextBackground(borderColor);
		ClrScr;
		VideoHideCursor;
		VideoSetBorderColor(borderColor);
	end;

procedure VideoUninstall;
	var
		regs: Registers;
	begin
		regs.AX := $1201;
		regs.BL := $30;
		Intr($10, regs);
		TextBackground(0);
		VideoColumns := 80;
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
	end;

procedure VideoHideCursor;
	begin
		VideoSetCursorShape($2000);
	end;

procedure VideoSetBorderColor(value: integer);
	begin
		Port[PORT_CGA_PALETTE] := value;
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


begin
	VideoColumns := 80;
	VideoWriteText := VideoWriteTextCO80;
	VideoTextSegment := $B800;
	if not ZetaDetected then AccurateDelayCalibrate;
end.
