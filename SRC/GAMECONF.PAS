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
			state.LineCount := {$IFNDEF SDL2} 6 {$ELSE} 9 {$ENDIF};
			for i := 1 to state.LineCount do
				New(state.Lines[i]);

			i := 1;
			state.Lines[i]^ := '!;Compatibility: ';
			if HighCompatAuto then
				state.Lines[i]^ := state.Lines[1]^ + 'Automatic'
			else if HighCompat then
				state.Lines[i]^ := state.Lines[1]^ + 'Strict'
			else
				state.Lines[i]^ := state.Lines[1]^ + 'Normal';
			Inc(i);
{$IFNDEF SDL2}
			state.Lines[i]^ := '!;Sound: ';
			if SoundEnabled then
				state.Lines[i]^ := state.Lines[i]^ + 'On'
			else
				state.Lines[i]^ := state.Lines[i]^ + 'Off';
			Inc(i);
{$ELSE}
			state.Lines[i]^ := '!;Video scaling: ';
			case VideoGetSDLScalingMode of
				SMNone: state.Lines[i]^ := state.Lines[i]^ + '1:1';
				SM2x: state.Lines[i]^ := state.Lines[i]^ + '2:1';
				SM3x: state.Lines[i]^ := state.Lines[i]^ + '3:1';
				SMInteger: state.Lines[i]^ := state.Lines[i]^ + 'Integer';
				SMOrigAspect: state.Lines[i]^ := state.Lines[i]^ + 'Keep Aspect';
				SM43Aspect: state.Lines[i]^ := state.Lines[i]^ + '4:3 Aspect';
				SMIgnoreAspect: state.Lines[i]^ := state.Lines[i]^ + 'Ignore';
			end;
			Inc(i);

			state.Lines[i]^ := '!;Display mode: ';
			if VideoGetSDLWindowed then
				state.Lines[i]^ := state.Lines[i]^ + 'Windowed'
			else
				state.Lines[i]^ := state.Lines[i]^ + 'Fullscreen';
			Inc(i);

			state.Lines[i]^ := '!;Sound: ';
			if AudioGetVolume >= 64 then
				state.Lines[i]^ := state.Lines[i]^ + '100%'
			else if AudioGetVolume >= 48 then
				state.Lines[i]^ := state.Lines[i]^ + '75%'
			else if AudioGetVolume >= 32 then
				state.Lines[i]^ := state.Lines[i]^ + '50%'
			else if AudioGetVolume >= 16 then
				state.Lines[i]^ := state.Lines[i]^ + '25%'
			else
				state.Lines[i]^ := state.Lines[i]^ + 'Off';
			Inc(i);

			state.Lines[i]^ := '!;HQ Sound: ';
			if AudioGetHighQuality then
				state.Lines[i]^ := state.Lines[i]^ + 'On'
			else
				state.Lines[i]^ := state.Lines[i]^ + 'Off';
			Inc(i);
{$ENDIF}

			state.Lines[i]^ := '_________________________________________';
			state.Lines[i + 1]^ := '';
			state.Lines[i + 2]^ := '!;About ClassicZoo...';
			state.Lines[i + 3]^ := '!;Exit';

			TextWindowSelect(state, TWS_HYPERLINK_AS_SELECT);
			if (InputKeyPressed = KEY_ENTER) and (state.LinePos <> state.LineCount) then begin
				case state.LinePos of
					1: begin
						if HighCompatAuto then
							HighCompatAuto := false
						else
							HighCompat := not HighCompat;
					end;
{$IFNDEF SDL2}
					2: begin
						SoundEnabled := not SoundEnabled;
						SoundClearQueue;
					end;
					5: begin
						GameAboutScreen;
					end;
{$ELSE}
					2: begin
						if VideoGetSDLScalingMode = SMIgnoreAspect then
							VideoSetSDLScalingMode(SMNone)
						else
							VideoSetSDLScalingMode(Succ(VideoGetSDLScalingMode));
					end;
					3: begin
						VideoSetSDLWindowed(not VideoGetSDLWindowed);
					end;
					4: begin
						i := AudioGetVolume;
						if i >= 64 then begin
							i := 0;
							SoundClearQueue;
						end else begin
							i := (i and $F0) + 16;
						end;
						AudioSetVolume(i);
					end;
					5: begin
						AudioSetHighQuality(not AudioGetHighQuality);
					end;
					8: begin
						GameAboutScreen;
					end;
{$ENDIF}
				end;
			end else begin
				exitRequested := true;
				TextWindowDrawClose(state);
			end;

			TextWindowFreeEdit(state);
		until exitRequested;
	end;

end.
