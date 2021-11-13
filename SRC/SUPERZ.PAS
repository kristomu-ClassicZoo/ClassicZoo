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
{$IFNDEF FPC}
{$M 24576,163840,655360}
{$ENDIF}
program SUPERZ;
uses Crt, Dos, ExtMem, Video, Keys, Sounds, Input, TxtWind, GameVars,
	Elements, Editor, Oop, Game, Uncrlib,
	S_CONFIG, M_MONSTE, M_FOREST, M_PROVIN;

procedure ParseArguments;
	var
		i: integer;
		pArg: string;
		enableEms: boolean;
		enableXms: boolean;
	begin
		enableEms := true;
		enableXms := true;

		for i := 1 to ParamCount do begin
			pArg := ParamStr(i);
			if pArg[1] = '/' then begin
				{ case UpCase(pArg[2]) of
				end; }

				if pArg = '/NOSNOW' then
					VideoForceNoSnow := true
				else if pArg = '/NOFONT' then
					VideoUseCUstomFont := false
				else if pArg = '/NOEMS' then
					enableEms := false
				else if pArg = '/NOXMS' then
					enableXms := false;
			end else begin
				StartupWorldFileName := pArg;
				if (Length(StartupWorldFileName) > 4) and (StartupWorldFileName[Length(StartupWorldFileName) - 3] = '.') then begin
					StartupWorldFileName := Copy(StartupWorldFileName, 1, Length(StartupWorldFileName) - 4);
				end;
			end;
		end;

		ExtMemInstall(enableEms, enableXms);
	end;

procedure WriteRightPaddedBottom(s: string);
	begin
		GotoXY(77 - Length(s), 25);
		Write(s);
	end;

procedure GameConfigure;
	var
		regFile: text;
	begin
		ResetConfig := true;

		InputInitDevices;
		if GameVideoInstall(VIDEO_MODE_80X25, VIEW_TITLE) then begin end;
		Window(1, 1, 80, 25);
		UnCrunch(S_CONFIGCSIData, VideoTextPointer^, S_CONFIGCSISize);

		TextBackground(White);
		TextColor(Black);
		WriteRightPaddedBottom('%NAME% %VERSION%');

		Window(3, 8, 78, 23);
		TextBackground(Blue);
		TextColor(Yellow);
		ClrScr;
		if not InputConfigure then begin
			GameTitleExitRequested := true
		end else begin
			TextColor(LightGreen);
			if not VideoConfigure then
				GameTitleExitRequested := true;
		end;

		Window(1, 1, 80, 25);
	end;

begin
{$IFDEF WORLDDSC}
	WorldFileDescCount := WORLD_FILE_DESC_COUNT;
	WorldFileDescKeys[1] := 'PROVING';
	WorldFileDescValues[1] := 'PROVING  ZZT'#39's Proving Grounds';
	WorldFileDescKeys[2] := 'FOREST';
	WorldFileDescValues[2] := 'FOREST   ZZT'#39's Lost Forest';
	WorldFileDescKeys[3] := 'MONSTER';
	WorldFileDescValues[3] := 'MONSTER  ZZT'#39's Monster Zoo';
{$ENDIF}

	{ WorldFileMenuScrPtrs[1] := @M_PROVINCSIData;
	WorldFileMenuScrLens[1] := M_PROVINCSISize;
	WorldFileMenuScrPtrs[2] := @M_FORESTCSIData;
	WorldFileMenuScrLens[2] := M_FORESTCSISize;
	WorldFileMenuScrPtrs[3] := @M_MONSTECSIData;
	WorldFileMenuScrLens[3] := M_MONSTECSISize; }

	Randomize;
	SetCBreak(false);
	InitialTextAttr := TextAttr;

	StartupWorldFileName := 'MONSTER';
	ResourceDataFileName := 'SUPERZ.DAT';
	IoTmpBufSize := IO_BUFFER_DEFAULT_SIZE;

	MenuScrPointer := @M_MONSTECSIData;
	MenuScrLen := M_MONSTECSISize;

	GameTitleExitRequested := false;
{$IFDEF EDITOR}
	EditorEnabled := true;
{$ELSE}
	EditorEnabled := false;
{$ENDIF}
	VideoUseCustomFont := true;

	ParseArguments;
	GameConfigure;

	if not GameTitleExitRequested then begin
		ClrScr;
		GetMem(IoTmpBuf, IoTmpBufSize);

		VideoHideCursor;
		TickSpeed := 4;
		DebugEnabled := false;
		HighCompat := false;
		HighCompatAuto := true;

		SavedBoardFileName := 'TEMP';
		SavedGameFileName := StartupWorldFileName;

		WorldCreate;

		GameTitleLoop;

		FreeMem(IoTmpBuf, IoTmpBufSize);
		ExtMemUninstall;
	end;

	SoundUninstall;
	SoundClearQueue;

	VideoUninstall;

	TextAttr := InitialTextAttr;
	GotoXY(1, 24);
	VideoShowCursor;
end.
