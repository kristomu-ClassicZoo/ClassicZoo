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
Dos, ExtMem, FileSys, ZVideo, Keys, Sounds, Input, TxtWind, GameConf, GameVars, Elements, Editor, Oop, Game;

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

	StartupWorldFileName := 'TOWN';
{$IFDEF SUBDIRS}
	ResourceDataFileName := FExpand('ZZT.DAT');
{$ELSE}
	ResourceDataFileName := 'ZZT.DAT';
{$ENDIF}
	GameTitleExitRequested := false;
	IoTmpBufSize := IO_BUFFER_DEFAULT_SIZE;

	EditorEnabled := true;
	GameVersion := '%VERSION%';
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

	ParseArguments;
	if not GameConfigLoad then begin
		if not GameConfigSave then begin end;
		JustStarted := true;
	end;

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
		SavedGameFileName := 'SAVED';
		SavedBoardFileName := 'TEMP';
		ResetCachedLinePos;
		WorldCreate;

{$IFDEF EDITONLY}
		EditorLoop;
{$ELSE}
		GameTitleLoop;
{$ENDIF}

		FreeMem(IoTmpBuf, IoTmpBufSize);
		ExtMemUninstall;
	end;

	SoundClearQueue;

	VideoUninstall;
	SoundUninstall;
end.
