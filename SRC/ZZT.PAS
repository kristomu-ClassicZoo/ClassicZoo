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
{$IFDEF MSDOS}
Crt,
{$ENDIF}
{$ENDIF}
Dos, ExtMem, FileSys, ZVideo, Keys, Sounds, ZInput, TxtWind,
GameConf, GameVars, Elements, Editor, Oop, Game;

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

{$IFDEF MSDOS}
{$IFNDEF NEC98}
				if pArg = '/NOSNOW' then
					VideoForceNoSnow := true
				else if pArg = '/SAFEV' then
					VideoForceSafe := true;
{$ENDIF}
{$ENDIF}
{$IFNDEF NOEXTMEM}
				if pArg = '/NOEMS' then
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
	Randomize;

{$IFNDEF SDL2}
{ TODO
	Writeln('%NAME% %VERSION%');
	Writeln('%COPYRIGHT%');
}
{$ENDIF}

	StartupWorldFileName := '';
{$IFDEF SUBDIRS}
	ResourceDataFileName := FExpand('ZZT.DAT');
	ConfigFileName := FExpand('ZZT.INI');
{$ELSE}
	ResourceDataFileName := 'ZZT.DAT';
	ConfigFileName := 'ZZT.INI';
{$ENDIF}
	GameTitleExitRequested := false;
	IoTmpBufSize := IO_BUFFER_DEFAULT_SIZE;

	EditorEnabled := true;
	InputInitDevices;

{$IFDEF FASTVID}
	TransitionBlocksPerFrame := 32767;
	TransitionTextWindowDelay := 25;
{$ENDIF}
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

{$IFDEF SDL2}
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

	if not GameConfigSave then begin end;

	SoundClearQueue;

	VideoUninstall;
	SoundUninstall;
end.
