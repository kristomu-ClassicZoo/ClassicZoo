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
Crt,
{$ENDIF}
Dos, ExtMem, FileSys, ZVideo, Keys, Sounds, Input, TxtWind, GameVars, Elements, Editor, Oop, Game;

{$IFNDEF NEC98}
{$IFNDEF SDL2}
{$DEFINE TEXTCFG}
{$ENDIF}
{$ENDIF}

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

{$IFDEF TEXTCFG}
procedure WritelnCentered(s: string);
	var
		y: byte;
	begin
		y := WhereY;
		GotoXY(1 + ((80 - Length(s)) shr 1), y);
		Writeln(s);
	end;
{$ENDIF}

procedure GameConfigure;
	var
		unk1: integer;
		joystickEnabled, mouseEnabled: boolean;
		cfgFile: text;
	begin
		ParsingConfigFile := true;
		EditorEnabled := true;
{$IFDEF CONFREGI}
		ConfigRegistration := '';
{$ENDIF}
		ConfigWorldFile := '';
		GameVersion := '%VERSION%';

		AssignFSysText(cfgFile, 'zzt.cfg');
		Reset(cfgFile);
		if IOResult = 0 then begin
			Readln(cfgFile, ConfigWorldFile);
{$IFDEF CONFREGI}
			Readln(cfgFile, ConfigRegistration);
{$ENDIF}
			Close(cfgFile);
		end;

		if ConfigWorldFile[1] = '*' then begin
			EditorEnabled := false;
			ConfigWorldFile := Copy(ConfigWorldFile, 2, Length(ConfigWorldFile) - 1);
		end;
		if Length(ConfigWorldFile) <> 0 then begin
			StartupWorldFileName := ConfigWorldFile;
		end;

		InputInitDevices;
		joystickEnabled := InputJoystickEnabled;
		mouseEnabled := InputMouseEnabled;

		ParsingConfigFile := false;

{$IFDEF TEXTCFG}
		Window(1, 1, 80, 25);
		TextBackground(Black);
		ClrScr;
		TextColor(White);
		TextColor(White);
		Writeln;
		WritelnCentered('<=-  %NAME%  -=>');
		TextColor(Yellow);
		WritelnCentered('Version %VERSION%');
		WritelnCentered('%CONFIG_SUBTITLE%');
		GotoXY(1, 7);
		TextColor(Blue);
		Write('================================================================================');
		GotoXY(1, 24);
		Write('================================================================================');
		TextColor(White);
		GotoXY(30, 7);
		Write(' Game Configuration ');
		GotoXY(1, 25);
		Write(' %COPYRIGHT% ');
		GotoXY(59, 25);
		Write(' Press ... to abort ');
		TextColor(Black);
		TextBackground(LightGray);
		GotoXY(66, 25);
		Write('ESC');
		Window(1, 8, 80, 23);
		TextColor(Yellow);
		TextBackground(Black);
		ClrScr;
		TextColor(Yellow);
{$ELSE}
{$IFNDEF SDL2}
		Writeln('%NAME% %VERSION%');
		Writeln('%COPYRIGHT%');
{$ENDIF}
{$ENDIF}
		if not InputConfigure then
			GameTitleExitRequested := true
		else begin
{$IFDEF TEXTCFG}
			TextColor(LightGreen);
{$ENDIF}
			if not VideoConfigure then
				GameTitleExitRequested := true;
		end;
{$IFDEF TEXTCFG}
		Window(1, 1, 80, 25);
{$ENDIF}
	end;

begin
	Randomize;
{$IFDEF TEXTCFG}
	SetCBreak(false);
	InitialTextAttr := TextAttr;
{$ENDIF}

	StartupWorldFileName := 'TOWN';
{$IFDEF SUBDIRS}
	ResourceDataFileName := FExpand('ZZT.DAT');
{$ELSE}
	ResourceDataFileName := 'ZZT.DAT';
{$ENDIF}
	ResetConfig := false;
	GameTitleExitRequested := false;
	IoTmpBufSize := IO_BUFFER_DEFAULT_SIZE;
	GameConfigure;
	ParseArguments;

	if not GameTitleExitRequested then begin
		VideoInstall(Blue);
		{ OrderPrintId := @GameVersion; }
		TextWindowInit; { (5, 3, 50, 18) }
		GetMem(IoTmpBuf, IoTmpBufSize);

{$IFNDEF SDL2}
		VideoHideCursor;
		ClrScr;
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
{$IFDEF TEXTCFG}
	TextAttr := InitialTextAttr;
{$ENDIF}
{$IFNDEF SDL2}
	ClrScr;

	VideoShowCursor;
{$ENDIF}
end.
