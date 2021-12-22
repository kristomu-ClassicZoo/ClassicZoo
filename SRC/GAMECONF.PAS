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
	procedure GameAboutScreen;
	procedure GameOptionsScreen;

implementation
uses
{$IFDEF SDL2} AudioSim, {$ENDIF}
Game, GameVars, Sounds, ZVideo, Input, TxtWind;

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
	end;

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

{$IFNDEF SDL2}
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
{$IFDEF SDL2}
	ConfigEntryCount = 5;
{$ELSE}
	ConfigEntryCount = 2;
{$ENDIF}
	ConfigEntries: array[1 .. ConfigEntryCount] of TConfigEntry = (
		(
			Category: CCEngine;
			Key: 'ECompat';
			Name: 'Compatibility';
			GetValue: ConfigCompatibilityGetValue;
			SetValue: ConfigCompatibilitySetValue;
			ShowValue: ConfigCompatibilityShowValue;
			CustomAction: ConfigCustomActionNone;
		),
{$IFNDEF SDL2}
		(
			Category: CCFrontend;
			Key: 'FSoundOn';
			Name: 'Sound';
			GetValue: ConfigSoundGetValue;
			SetValue: ConfigSoundSetValue;
			ShowValue: ConfigSoundShowValue;
			CustomAction: ConfigCustomActionNone;
		),
{$ELSE}
		(
			Category: CCFrontend;
			Key: 'FVidWin';
			Name: 'Display mode';
			GetValue: ConfigFullscreenGetValue;
			SetValue: ConfigFullscreenSetValue;
			ShowValue: ConfigFullscreenShowValue;
			CustomAction: ConfigCustomActionNone;
		),
		(
			Category: CCFrontend;
			Key: 'FVidScal';
			Name: 'Display scaling';
			GetValue: ConfigVideoScalingGetValue;
			SetValue: ConfigVideoScalingSetValue;
			ShowValue: ConfigVideoScalingShowValue;
			CustomAction: ConfigCustomActionNone;
		),
		(
			Category: CCFrontend;
			Key: 'FSndVol';
			Name: 'Volume';
			GetValue: ConfigSoundVolumeGetValue;
			SetValue: ConfigSoundVolumeSetValue;
			ShowValue: ConfigSoundVolumeShowValue;
			CustomAction: ConfigCustomActionNone;
		),
		(
			Category: CCFrontend;
			Key: 'FSndHQ';
			Name: 'HQ Sound';
			GetValue: ConfigHQSoundGetValue;
			SetValue: ConfigHQSoundSetValue;
			ShowValue: ConfigHQSoundShowValue;
			CustomAction: ConfigCustomActionNone;
		)
{$ENDIF}
	);

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
			state.Lines[state.LineCount]^ := '';
			Inc(state.LineCount);
			New(state.Lines[state.LineCount]);
			state.Lines[state.LineCount]^ := '!;Return';

			TextWindowSelect(state, TWS_HYPERLINK_AS_SELECT);
			if (InputKeyPressed = KEY_ENTER) and (state.LinePos <> state.LineCount) then begin
				with ConfigEntries[actionMap[state.LinePos]] do begin
					SetValue(GetValue + 1);
				end;
			end else begin
				exitRequested := true;
			end;
		until exitRequested;
	end;

procedure GameAboutScreen;
	begin
		TextWindowDisplayFile('ABOUT.HLP', 'About ClassicZoo...');
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
		state.LinePos := 1;
		exitRequested := false;

		repeat
			state.Selectable := true;
			state.LineCount := 6;
			for i := 1 to state.LineCount do
				New(state.Lines[i]);

			state.Lines[1]^ := '!;Engine';
			state.Lines[2]^ := '!;Frontend';
			state.Lines[3]^ := '!;Editor';
			state.Lines[4]^ := '';
			state.Lines[5]^ := '!;About ClassicZoo...';
			state.Lines[6]^ := '!;Exit';

			TextWindowSelect(state, TWS_HYPERLINK_AS_SELECT);
			if (InputKeyPressed = KEY_ENTER) and (state.LinePos <> state.LineCount) then begin
				case state.LinePos of
					1: GameSubOptionsScreen(CCEngine, state);
					2: GameSubOptionsScreen(CCFrontend, state);
					3: GameSubOptionsScreen(CCEditor, state);
					5: GameAboutScreen;
				end;
			end else begin
				exitRequested := true;
				TextWindowDrawClose(state);
			end;

			TextWindowFreeEdit(state);
		until exitRequested;
	end;

end.
