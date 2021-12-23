{
	Copyright (c) 2021 Adrian Siekierka

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
{$V-}
unit GameConf;

interface
	function GameConfigLoad: boolean;
	function GameConfigSave: boolean;
	procedure GameAboutScreen;
	procedure GameOptionsScreen;
{$IFNDEF FPC}
	function ConfigCustomActionNone: boolean;
	function ConfigCompatibilityGetValue: integer;
	procedure ConfigCompatibilitySetValue(value: integer);
	function ConfigCompatibilityShowValue: string;
	function ConfigEdAutoAppendGetValue: integer;
	procedure ConfigEdAutoAppendSetValue(value: integer);
	function ConfigEdAutoAppendShowValue: string;
	function ConfigVidColorGetValue: integer;
	procedure ConfigVidColorSetValue(value: integer);
	function ConfigVidColorShowValue: string;
{$IFNDEF SDL2}
	function ConfigInputGetValue: integer;
	procedure ConfigInputSetValue(value: integer);
	function ConfigInputShowValue: string;
	function ConfigSoundGetValue: integer;
	procedure ConfigSoundSetValue(value: integer);
	function ConfigSoundShowValue: string;
{$ENDIF}
{$ENDIF}

implementation
uses
{$IFDEF SDL2} AudioSim, {$ENDIF}
Editor, Game, GameVars, Sounds, ZVideo, Input, FileSys, TxtWind;

type
	TConfigCategory = (CCEngine, CCFrontend, CCEditor);
	TConfigGetValueProc = function: integer;
	TConfigSetValueProc = procedure(value: integer);
	TConfigShowValueProc = function: string;
	TConfigCustomActionProc = function: boolean;
	TConfigEntry = record
		Category: TConfigCategory;
		Key: string[8];
		Name: string[20];
		GetValue: TConfigGetValueProc;
		SetValue: TConfigSetValueProc;
		ShowValue: TConfigShowValueProc;
		CustomAction: TConfigCustomActionProc;
		Changed: boolean;
	end;
	TConfigHiddenEntry = record
		Key: string[8];
		IntPointer: ^integer;
	end;
var
	ConfigEntryInputPos: integer;
	HardEscapeHack: boolean;

function ConfigCustomActionNone: boolean;
	begin
		ConfigCustomActionNone := false;
	end;

function ConfigCompatibilityGetValue: integer;
	begin
		if HighCompatAuto then
			ConfigCompatibilityGetValue := 2
		else if HighCompat then
			ConfigCompatibilityGetValue := 1
		else
			ConfigCompatibilityGetValue := 0;
	end;

procedure ConfigCompatibilitySetValue(value: integer);
	begin
		if value > 2 then value := 0;
		HighCompatAuto := (value = 2);
		HighCompat := (value = 1);
	end;

function ConfigCompatibilityShowValue: string;
	begin
		if HighCompatAuto then
			ConfigCompatibilityShowValue := 'Automatic'
		else if HighCompat then
			ConfigCompatibilityShowValue := 'Strict'
		else
			ConfigCompatibilityShowValue := 'Normal';
	end;

function ConfigEdAutoAppendGetValue: integer;
	begin
		ConfigEdAutoAppendGetValue := Byte(EditorAutoAppendPats);
	end;

procedure ConfigEdAutoAppendSetValue(value: integer);
	begin
		if value > 1 then value := 0;
		EditorAutoAppendPats := Boolean(value);
	end;

function ConfigEdAutoAppendShowValue: string;
	begin
		if EditorAutoAppendPats then
			ConfigEdAutoAppendShowValue := 'Yes'
		else
			ConfigEdAutoAppendShowValue := 'No';
	end;

function ConfigVidColorGetValue: integer;
	begin
		ConfigVidColorGetValue := Byte(VideoMonochrome);
	end;

procedure ConfigVidColorSetValue(value: integer);
	begin
		if value > 1 then value := 0;
		VideoMonochrome := Boolean(value);
	end;

function ConfigVidColorShowValue: string;
	begin
		if VideoMonochrome then
			ConfigVidColorShowValue := 'Monochrome'
		else
			ConfigVidColorShowValue := 'Color';
	end;

{$IFNDEF SDL2}
function ConfigInputGetValue: integer;
	begin
		ConfigInputGetValue := Byte(InputMode);
	end;

procedure ConfigInputSetValue(value: integer);
	begin
		if value > 2 then value := 0;
{$IFDEF NEC98}
		if value = 1 then value := 2;
{$ENDIF}
		InputMode := TInputMode(value);
	end;

function ConfigInputShowValue: string;
	begin
		if InputMode = IMMouse then
			ConfigInputShowValue := 'Mouse'
{$IFNDEF NEC98}
		else if InputMode = IMJoystick then
			ConfigInputShowValue := 'Joystick'
{$ENDIF}
		else
			ConfigInputShowValue := 'Keyboard';
	end;

function ConfigSoundGetValue: integer;
	begin
		ConfigSoundGetValue := Byte(SoundEnabled);
	end;

procedure ConfigSoundSetValue(value: integer);
	begin
		if value > 1 then value := 0;
		SoundEnabled := Boolean(value);
	end;

function ConfigSoundShowValue: string;
	begin
		if SoundEnabled then
			ConfigSoundShowValue := 'On'
		else
			ConfigSoundShowValue := 'Off';
	end;
{$ELSE}
function ConfigVideoScalingGetValue: integer;
	begin
		ConfigVideoScalingGetValue := Byte(Ord(VideoGetSDLScalingMode));
	end;

procedure ConfigVideoScalingSetValue(value: integer);
	begin
		if value > Ord(High(TSDLScalingMode)) then value := 0;
		VideoSetSDLScalingMode(TSDLScalingMode(value));
	end;

function ConfigVideoScalingShowValue: string;
	begin
		case VideoGetSDLScalingMode of
			SMNone: ConfigVideoScalingShowValue := '1:1';
			SM2x: ConfigVideoScalingShowValue := '2:1';
			SM3x: ConfigVideoScalingShowValue := '3:1';
			SMInteger: ConfigVideoScalingShowValue := 'Integer';
			SMOrigAspect: ConfigVideoScalingShowValue := 'Keep Aspect';
			SM43Aspect: ConfigVideoScalingShowValue := '4:3 Aspect';
			SMIgnoreAspect: ConfigVideoScalingShowValue := 'Ignore';
		end;
	end;

function ConfigHQSoundGetValue: integer;
	begin
		ConfigHQSoundGetValue := Byte(AudioGetHighQuality);
	end;

procedure ConfigHQSoundSetValue(value: integer);
	begin
		if value > 1 then value := 0;
		AudioSetHighQuality(Boolean(value));
	end;

function ConfigHQSoundShowValue: string;
	begin
		if AudioGetHighQuality then
			ConfigHQSoundShowValue := 'On'
		else
			ConfigHQSoundShowValue := 'Off';
	end;

function ConfigFullscreenGetValue: integer;
	begin
		ConfigFullscreenGetValue := Byte(VideoGetSDLWindowed);
	end;

procedure ConfigFullscreenSetValue(value: integer);
	begin
		if value > 1 then value := 0;
		VideoSetSDLWindowed(Boolean(value));
	end;

function ConfigFullscreenShowValue: string;
	begin
		if VideoGetSDLWindowed then
			ConfigFullscreenShowValue := 'Windowed'
		else
			ConfigFullscreenShowValue := 'Fullscreen';
	end;

function ConfigSoundVolumeGetValue: integer;
	begin
		ConfigSoundVolumeGetValue := Byte(AudioGetVolume shr 4);
	end;

procedure ConfigSoundVolumeSetValue(value: integer);
	begin
		if value > 4 then value := 0;
		AudioSetVolume(Byte(value shl 4));
	end;

function ConfigSoundVolumeShowValue: string;
	begin
		if AudioGetVolume > 48 then
			ConfigSoundVolumeShowValue := '100%'
		else if AudioGetVolume > 32 then
			ConfigSoundVolumeShowValue := '75%'
		else if AudioGetVolume > 16 then
			ConfigSoundVolumeShowValue := '50%'
		else if AudioGetVolume > 0 then
			ConfigSoundVolumeShowValue := '25%'
		else
			ConfigSoundVolumeShowValue := 'Off';
	end;
{$ENDIF}

const
	ConfigEntryCount = 2
{$IFDEF EDITOR}
	+ 1
{$ENDIF}
{$IFDEF SDL2}
	+ 4
{$ELSE}
	+ 2
{$ENDIF}
	;
	ConfigHiddenEntryCount = 0
{$IFDEF MSDOS}
{$IFNDEF NEC98}
	+ 6
{$ENDIF}
{$ENDIF}
	;
var
	ConfigEntries: array[1 .. ConfigEntryCount] of TConfigEntry;
	ConfigHiddenEntries: array[1 .. ConfigHiddenEntryCount + 1] of TConfigHiddenEntry;

procedure ConfigInitEntries;
	var
		i: integer;
	begin
		i := 1;

		ConfigEntries[i].Category := CCEngine;
		ConfigEntries[i].Key := 'ECompat';
		ConfigEntries[i].Name := 'Compatibility';
		ConfigEntries[i].GetValue := ConfigCompatibilityGetValue;
		ConfigEntries[i].SetValue := ConfigCompatibilitySetValue;
		ConfigEntries[i].ShowValue := ConfigCompatibilityShowValue;
		ConfigEntries[i].CustomAction := ConfigCustomActionNone;
		Inc(i);
{$IFDEF EDITOR}
		ConfigEntries[i].Category := CCEditor;
		ConfigEntries[i].Key := 'EdApPats';
		ConfigEntries[i].Name := 'Auto-Append';
		ConfigEntries[i].GetValue := ConfigEdAutoAppendGetValue;
		ConfigEntries[i].SetValue := ConfigEdAutoAppendSetValue;
		ConfigEntries[i].ShowValue := ConfigEdAutoAppendShowValue;
		ConfigEntries[i].CustomAction := ConfigCustomActionNone;
		Inc(i);
{$ENDIF}
		ConfigEntries[i].Category := CCFrontend;
		ConfigEntries[i].Key := 'FVidMono';
		ConfigEntries[i].Name := 'Video';
		ConfigEntries[i].GetValue := ConfigVidColorGetValue;
		ConfigEntries[i].SetValue := ConfigVidColorSetValue;
		ConfigEntries[i].ShowValue := ConfigVidColorShowValue;
		ConfigEntries[i].CustomAction := ConfigCustomActionNone;
		Inc(i);
{$IFNDEF SDL2}
		ConfigEntries[i].Category := CCFrontend;
		ConfigEntries[i].Key := 'FSoundOn';
		ConfigEntries[i].Name := 'Sound';
		ConfigEntries[i].GetValue := ConfigSoundGetValue;
		ConfigEntries[i].SetValue := ConfigSoundSetValue;
		ConfigEntries[i].ShowValue := ConfigSoundShowValue;
		ConfigEntries[i].CustomAction := ConfigCustomActionNone;
		Inc(i);
		ConfigEntries[i].Category := CCFrontend;
		ConfigEntries[i].Key := 'FInpMode';
		ConfigEntries[i].Name := 'Input';
		ConfigEntries[i].GetValue := ConfigInputGetValue;
		ConfigEntries[i].SetValue := ConfigInputSetValue;
		ConfigEntries[i].ShowValue := ConfigInputShowValue;
		ConfigEntries[i].CustomAction := ConfigCustomActionNone;
		ConfigEntryInputPos := i;
		Inc(i);
{$ELSE}
		ConfigEntries[i].Category := CCFrontend;
		ConfigEntries[i].Key := 'FVidWin';
		ConfigEntries[i].Name := 'Display mode';
		ConfigEntries[i].GetValue := ConfigFullscreenGetValue;
		ConfigEntries[i].SetValue := ConfigFullscreenSetValue;
		ConfigEntries[i].ShowValue := ConfigFullscreenShowValue;
		ConfigEntries[i].CustomAction := ConfigCustomActionNone;
		Inc(i);

		ConfigEntries[i].Category := CCFrontend;
		ConfigEntries[i].Key := 'FVidScal';
		ConfigEntries[i].Name := 'Display scaling';
		ConfigEntries[i].GetValue := ConfigVideoScalingGetValue;
		ConfigEntries[i].SetValue := ConfigVideoScalingSetValue;
		ConfigEntries[i].ShowValue := ConfigVideoScalingShowValue;
		ConfigEntries[i].CustomAction := ConfigCustomActionNone;
		Inc(i);

		ConfigEntries[i].Category := CCFrontend;
		ConfigEntries[i].Key := 'FSndVol';
		ConfigEntries[i].Name := 'Volume';
		ConfigEntries[i].GetValue := ConfigSoundVolumeGetValue;
		ConfigEntries[i].SetValue := ConfigSoundVolumeSetValue;
		ConfigEntries[i].ShowValue := ConfigSoundVolumeShowValue;
		ConfigEntries[i].CustomAction := ConfigCustomActionNone;
		Inc(i);

		ConfigEntries[i].Category := CCFrontend;
		ConfigEntries[i].Key := 'FSndHQ';
		ConfigEntries[i].Name := 'HQ Sound';
		ConfigEntries[i].GetValue := ConfigHQSoundGetValue;
		ConfigEntries[i].SetValue := ConfigHQSoundSetValue;
		ConfigEntries[i].ShowValue := ConfigHQSoundShowValue;
		ConfigEntries[i].CustomAction := ConfigCustomActionNone;
		Inc(i);
{$ENDIF}

		i := 1;
{$IFDEF MSDOS}
{$IFNDEF NEC98}
		ConfigHiddenEntries[i].Key := 'FJoyXMin';
		ConfigHiddenEntries[i].IntPointer := @JoystickXMin;
		Inc(i);
		ConfigHiddenEntries[i].Key := 'FJoyXCtr';
		ConfigHiddenEntries[i].IntPointer := @JoystickXCenter;
		Inc(i);
		ConfigHiddenEntries[i].Key := 'FJoyXMax';
		ConfigHiddenEntries[i].IntPointer := @JoystickXMax;
		Inc(i);
		ConfigHiddenEntries[i].Key := 'FJoyYMin';
		ConfigHiddenEntries[i].IntPointer := @JoystickYMin;
		Inc(i);
		ConfigHiddenEntries[i].Key := 'FJoyYCtr';
		ConfigHiddenEntries[i].IntPointer := @JoystickYCenter;
		Inc(i);
		ConfigHiddenEntries[i].Key := 'FJoyYMax';
		ConfigHiddenEntries[i].IntPointer := @JoystickYMax;
		Inc(i);
{$ENDIF}
{$ENDIF}
	end;

procedure GameSubOptionsScreen(subCategory: TConfigCategory; var state: TTextWindowState);
	var
		i: integer;
		actionMap: array[1 .. ConfigEntryCount] of integer;
		exitRequested: boolean;
	begin
		exitRequested := false;
		state.LinePos := 1;

		repeat
			TextWindowFreeEdit(state);

			state.Selectable := true;
			state.LineCount := 1;

			for i := 1 to ConfigEntryCount do with ConfigEntries[i] do begin
				if Category = subCategory then begin
					actionMap[state.LineCount] := i;
					New(state.Lines[state.LineCount]);
					state.Lines[state.LineCount]^ := '!;' + Name + ': ' + ShowValue;
					Inc(state.LineCount);
				end;
			end;

			New(state.Lines[state.LineCount]);
			actionMap[state.LineCount] := 0;
			state.Lines[state.LineCount]^ := '';
			Inc(state.LineCount);
			New(state.Lines[state.LineCount]);
			state.Lines[state.LineCount]^ := '!;Return';

			TextWindowSelect(state, TWS_HYPERLINK_AS_SELECT);
			if (InputKeyPressed = KEY_ENTER) and (state.LinePos <> state.LineCount) then begin
				if actionMap[state.LinePos] <> 0 then begin
					with ConfigEntries[actionMap[state.LinePos]] do begin
						if not CustomAction then
							SetValue(GetValue + 1);
						Changed := true;
{$IFNDEF SDL2}
						if Key = 'FVidMono' then begin
							VideoUninstall;
							VideoInstall(1);
							HardEscapeHack := true;
						end;
{$ENDIF}
					end;
				end;
				if HardEscapeHack then begin
					exitRequested := true;
				end;
			end else begin
				exitRequested := true;
			end;
		until exitRequested;
	end;

function GameConfigLoad: boolean;
	var
		f: text;
		i, v, code: integer;
		s: string[128];
		k: string[12];
	begin
		GameConfigLoad := false;
		AssignFSysText(f, 'ZZT.INI');
		Reset(f);
		while (IOResult = 0) and (not Eof(f)) do begin
			ReadLn(f, s);
			if (Length(s) > 0) and (s[1] <> ';') and (s[1] <> '[') then begin
				v := Pos('=', s);
				if v <= 12 then begin
					k := Copy(s, 1, v - 1);
					s := Copy(s, v + 1, Length(s) - v);
					if Length(s) > 0 then begin
						Val(s, v, code);
						for i := 1 to ConfigEntryCount do with ConfigEntries[i] do begin
							if k = Key then
								SetValue(v);
						end;
						for i := 1 to ConfigHiddenEntryCount do with ConfigHiddenEntries[i] do begin
							if k = Key then
								IntPointer^ := v;
						end;
					end;
				end;
			end;
		end;
		Close(f);
		if IOResult = 0 then GameConfigLoad := true;
	end;

function GameConfigSave: boolean;
	var
		f: text;
		i, v: integer;
		s: string[20];
	begin
		GameConfigSave := false;
		AssignFSysText(f, 'ZZT.INI');
		Rewrite(f);
		WriteLn(f, '; Generated by %NAME% %VERSION%');
		WriteLn(f, '[Config]');
		for i := 1 to ConfigEntryCount do with ConfigEntries[i] do begin
			v := GetValue;
			Str(v, s);
			WriteLn(f, Key + '=' + s);
		end;
		for i := 1 to ConfigHiddenEntryCount do with ConfigHiddenEntries[i] do begin
			v := IntPointer^;
			Str(v, s);
			WriteLn(f, Key + '=' + s);
		end;
		Close(f);
		if IOResult = 0 then GameConfigSave := true;
	end;

procedure GameAboutScreen;
	begin
		TextWindowDisplayFile('ABOUT.HLP', 'About %NAME%...');
	end;

procedure GameOptionsScreen;
	var
		state: TTextWindowState;
		i: integer;
		numStr: TString50;
		exitRequested: boolean;
	begin
		state.Title := 'Options...';
		TextWindowDrawOpen(state);
		exitRequested := false;
		HardEscapeHack := false;
		state.LinePos := 1;

		for i := 1 to ConfigEntryCount do ConfigEntries[i].Changed := false;

		repeat
			state.Selectable := true;
{$IFDEF EDITOR}
			state.LineCount := 6;
{$ELSE}
			state.LineCount := 5;
{$ENDIF}
			for i := 1 to state.LineCount do
				New(state.Lines[i]);

			state.Lines[1]^ := '!;Engine';
			state.Lines[2]^ := '!;Frontend';
{$IFDEF EDITOR}
			state.Lines[3]^ := '!;Editor';
			state.Lines[4]^ := '';
			state.Lines[5]^ := '!;About %NAME%...';
			state.Lines[6]^ := '!;Exit';
{$ELSE}
			state.Lines[3]^ := '';
			state.Lines[4]^ := '!;About %NAME%...';
			state.Lines[5]^ := '!;Exit';
{$ENDIF}

			TextWindowSelect(state, TWS_HYPERLINK_AS_SELECT);
			if (InputKeyPressed = KEY_ENTER) and (state.LinePos <> state.LineCount) then begin
				case state.LinePos of
					1: GameSubOptionsScreen(CCEngine, state);
					2: GameSubOptionsScreen(CCFrontend, state);
{$IFDEF EDITOR}
					3: GameSubOptionsScreen(CCEditor, state);
					5: GameAboutScreen;
{$ELSE}
					4: GameAboutScreen;
{$ENDIF}
				end;
				if HardEscapeHack then begin
					exitRequested := true;
				end;
			end else begin
				exitRequested := true;
				TextWindowDrawClose(state);
			end;

			TextWindowFreeEdit(state);
		until exitRequested;

{$IFDEF MSDOS}
{$IFNDEF NEC98}
		if ConfigEntries[ConfigEntryInputPos].Changed then begin begin
			if InputMode = IMJoystick then
				VideoUninstall;
				if not InputCalibrateJoystick then
					InputMode := IMKeyboard;
				VideoInstall(1);
			end;
		end;
{$ENDIF}
{$ENDIF}

		if not GameConfigSave then begin
			{ TODO: Warn user. }
		end;
	end;

begin
	ConfigInitEntries;
end.
