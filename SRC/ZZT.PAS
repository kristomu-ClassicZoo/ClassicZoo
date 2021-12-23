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
{$IFNDEF FPC}
{$IFDEF NEC98}
{$M 24576,163840,655360}
{$ELSE}
{$M 20480,163840,655360}
{$ENDIF}
{$ENDIF}
program ZZT;
uses 
{$IFDEF NEC98}
Pc98,
{$ELSE}
{$IFNDEF SDL2}
Crt,
{$ENDIF}
{$ENDIF}
Dos, ExtMem, FileSys, ZxtMgr, ZxtZoo, ZVideo, Keys, Sounds, Input, TxtWind,
ZDemo, GameConf, GameVars, Elements, Editor, Oop, Game;

procedure ParseArguments;
	var
		i: integer;
		pArg: string;
		enableEms: boolean;
		enableXms: boolean;
	begin
{$IFNDEF NOEXTMEM}
		enableEms := true;
		enableXms := true;
{$ENDIF}

		for i := 1 to ParamCount do begin
			pArg := ParamStr(i);
			if pArg[1] = '/' then begin
				pArg := UpCaseString(pArg);

				if pArg = '/NOSNOW' then
					VideoForceNoSnow := true
{$IFNDEF NOEXTMEM}
				else if pArg = '/NOEMS' then
					enableEms := false
				else if pArg = '/NOXMS' then
					enableXms := false;
{$ENDIF}
			end else begin
				StartupWorldFileName := pArg;
				if (Length(StartupWorldFileName) > 4) and (StartupWorldFileName[Length(StartupWorldFileName) - 3] = '.') then begin
					StartupWorldFileName := Copy(StartupWorldFileName, 1, Length(StartupWorldFileName) - 4);
				end;
			end;
		end;

		ExtMemInstall(enableEms, enableXms);
	end;

begin
{$IFNDEF SDL2}
	Writeln('%NAME% %VERSION%');
	Writeln('%COPYRIGHT%');
{$ENDIF}
	Randomize;

	StartupWorldFileName := '';
{$IFDEF SUBDIRS}
	ResourceDataFileName := FExpand('ZZT.DAT');
	ConfigFileName := FExpand('ZZT.INI');
{$ELSE}
	ResourceDataFileName := 'ZZT.DAT';
	ConfigFileName := 'ZZT.INI';
{$ENDIF}
	DemoEngineName := '%NAME% %VERSION%';
	GameTitleExitRequested := false;
	IoTmpBufSize := IO_BUFFER_DEFAULT_SIZE;

	EditorEnabled := true;
	InputInitDevices;

	TickSpeed := 4;
	DebugEnabled := false;
	HighCompat := false;
	HighCompatAuto := true;
{$IFDEF EXTCHEAT}
	CheatNoClip := false;
	CheatFreeze := false;
{$ENDIF}
{$IFDEF DEBUGWND}
	DebugCompatEnabled := false;
	DebugUndefEnabled := false;
{$ENDIF}

	GameConfigInit;
	if not GameConfigLoad then begin
		if not GameConfigSave then begin end;
		JustStarted := true;
	end else begin
		JustStarted := false;
	end;
	ParseArguments;

	if not GameTitleExitRequested then begin
		VideoInstall(1);
		TextWindowInit; { (5, 3, 50, 18) }
		GetMem(IoTmpBuf, IoTmpBufSize);

{$IFNDEF SDL2}
		VideoHideCursor;
		ClrScr;
{$ELSE}
		{ SDL2 - Fixes initial window size }
		InputUpdate;
{$ENDIF}

		ZxtRegisterExtensionSimple(ExtUnlockExtensions, $00000000, $0001);
		ZxtRegisterExtensionSimple(ExtFixPutBottomRow, $00000001, $0001);
		ZxtRegisterExtensionSimple(ExtFixBindDoubleFree, $00000001, $0002);
		ZxtRegisterExtensionSimple(ExtFixKoopoBug, $00000001, $0003);
		ZxtRegisterExtensionSimple(ExtFixRecursiveElementPush, $00000001, $0004);
		ZxtRegisterExtensionSimple(ExtFixConveyorStatCheck, $00000001, $0005);
		ZxtRegisterExtensionSimple(ExtFixConveyorMissingFinalDraw, $00000001, $0006);
		ZxtRegisterExtensionSimple(ExtFixConveyorStatSwapping, $00000001, $0007);
		ZxtRegisterExtensionSimple(ExtFixBlinkWallShift, $00000001, $0008);
		ZxtRegisterExtensionSimple(ExtFixBoardEdgeTouch, $00000001, $0009);
		ZxtRegisterExtensionSimple(ExtSuperzEnter, $00000002, $0001);
		ZxtRegisterExtensionSimple(ExtDieItem, $0000A51E, $0001);
		ZxtRegisterExtensionSimple(ExtDieUnderTile, $0000A51E, $0002);
		ZxtRegisterExtensionSimple(ExtIfRnd, $0000A51E, $0004);
{$IFNDEF NEC98}
		ZxtRegisterExtension(ExtZZOCustomCharset, $00022038, $0003,
			ZxtZZOCustomCharsetHandler);
{$ENDIF}
		ZxtRegisterExtensionSimple(ExtGMDirByAt, $79656D74, $0001);
		ZxtRegisterExtensionSimple(ExtGMPutPlayer, $79656D74, $0002);
		ZxtRegisterExtensionSimple(ExtQuirkArgTile2, $00000000, $1001);

		SavedGameFileName := 'SAVED';
		SavedBoardFileName := 'TEMP';
		ResetCachedLinePos;
		WorldCreate;

{$IFDEF EDITONLY}
		EditorLoop;
{$ELSE}
{$IFDEF ZDEMOVAL}
		GameValidateRun;
{$ELSE}
		GameTitleLoop;
{$ENDIF}
{$ENDIF}

		FreeMem(IoTmpBuf, IoTmpBufSize);
		ExtMemUninstall;
	end;

	if not GameConfigSave then begin end;

	SoundClearQueue;

	VideoUninstall;
	SoundUninstall;
end.
