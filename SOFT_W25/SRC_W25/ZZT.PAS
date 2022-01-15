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
{$M 49152,163840,655360}
program ZZT;
uses Crt, Dos, ExtMem, Video, Keys, Sounds, Input, TxtWind, GameVars, Elements, Oop, Game;

procedure ParseArguments;
	begin
		StartupWorldFileName := ParamStr(1);
		ExtMemInstall(true, true);
	end;

procedure GameConfigure;
	var
		i: integer;
		joystickEnabled, mouseEnabled: boolean;
		cfgFile: text;
	begin
		ConfigWorldFile := '';
		Assign(cfgFile, 'zzt.cfg');
		Reset(cfgFile);
		if IOResult = 0 then begin
			Readln(cfgFile, ConfigWorldFile);
			for i := 1 to 4 do
				ReadLn(cfgFile, Accessibility[i]);
		end;
		if Length(ConfigWorldFile) <> 0 then begin
			StartupWorldFileName := ConfigWorldFile;
		end;

		InputInitDevices;
		joystickEnabled := InputJoystickEnabled;
		mouseEnabled := InputMouseEnabled;

		Window(1, 1, 80, 25);
		TextBackground(Black);
		ClrScr;
		TextColor(White);
		TextColor(White);
		Writeln;
		Writeln('                                <=-  Weave  -=>');
		TextColor(Yellow);
		Writeln('                                 Version   2.5 [soft] [beta 1]');
		Writeln('                         based on '#39'ZZT'#39' by Tim Sweeney');
		GotoXY(1, 7);
		TextColor(Blue);
		Write('================================================================================');
		GotoXY(1, 24);
		Write('================================================================================');
		TextColor(White);
		GotoXY(30, 7);
		Write(' Game Configuration ');
		GotoXY(1, 25);
		Write(' This game is MIT licensed free software.                  Press ... to abort');
		TextColor(Black);
		TextBackground(LightGray);
		GotoXY(66, 25);
		Write('ESC');
		Window(1, 8, 80, 23);
		TextColor(Yellow);
		TextBackground(Black);
		ClrScr;
		TextColor(Yellow);
		NeuromotorAssist := false;
		HearingImpaired := false;
		Diffkeys := false;
		if Accessibility[1] = 'ACCESSIBLE' then begin
			if Accessibility[2] = '' then begin
				NeuromotorAssist :=	NeuromotorConfigure;
				HearingImpaired :=	HearingConfigure;
				Diffkeys := KeydiffConfigure;
			end else begin
				for i := 2 to 4 do begin
					if Accessibility[i] = 'NEUROMOTORASSIST' then
						NeuromotorAssist :=	true;
					if Accessibility[i] = 'VISUALSOUND' then
						HearingImpaired :=	true;
					if Accessibility[i] = 'DISTINCTKEYS' then
						Diffkeys :=	true;
				end;
			end;
		end;
		if not InputConfigure then
			GameTitleExitRequested := true
		else begin
			TextColor(LightGreen);
			if not VideoConfigure then
				GameTitleExitRequested := true;
		end;
		Window(1, 1, 80, 25);
	end;

begin
	WorldFileDescCount := 7;
	WorldFileDescKeys[1] := 'TOWN';
	WorldFileDescValues[1] := 'TOWN       The Town of ZZT';
	WorldFileDescKeys[2] := 'DEMO';
	WorldFileDescValues[2] := 'DEMO       Demo of the ZZT World';
	WorldFileDescKeys[3] := 'CAVES';
	WorldFileDescValues[3] := 'CAVES      The Caves of ZZT';
	WorldFileDescKeys[4] := 'DUNGEONS';
	WorldFileDescValues[4] := 'DUNGEONS   The Dungeons of ZZT';
	WorldFileDescKeys[5] := 'CITY';
	WorldFileDescValues[5] := 'CITY       Underground City of ZZT';
	WorldFileDescKeys[6] := 'BEST';
	WorldFileDescValues[6] := 'BEST       The Best of ZZT';
	WorldFileDescKeys[7] := 'TOUR';
	WorldFileDescValues[7] := 'TOUR       Guided Tour ZZT'#39's Other Worlds';

	Randomize;
	SetCBreak(false);
	InitialTextAttr := TextAttr;

	StartupWorldFileName := '';
	ResourceDataFileName := 'ZZT.DAT';
	IoTmpBufSize := IO_BUFFER_DEFAULT_SIZE;
	GameTitleExitRequested := false;
	GameConfigure;
	ParseArguments;

	if not GameTitleExitRequested then begin
		VideoInstall(80, Blue);
		TextWindowInit;
		GetMem(IoTmpBuf, IoTmpBufSize);

		VideoHideCursor;
		ClrScr;

		TickSpeed := 4;
		DebugEnabled := false;
		SavedGameFileName := 'SAVED';
		SavedBoardFileName := 'TEMP';
		WorldCreate;
		if Diffkeys then
			SetAccKeys;

		GameTitleLoop;

		FreeMem(IoTmpBuf, IoTmpBufSize);
		ExtMemUninstall;
	end;

	SoundUninstall;
	SoundClearQueue;

	VideoUninstall;
	Port[PORT_CGA_PALETTE] := 0;
	TextAttr := InitialTextAttr;
	ClrScr;

	VideoShowCursor;
end.
