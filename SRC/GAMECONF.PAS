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
Game, GameVars, Sounds, Input, TxtWind;

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

			state.Lines[1]^ := '!;Compatibility: ';
			if HighCompatAuto then
				state.Lines[1]^ := state.Lines[1]^ + 'Automatic'
			else if HighCompat then
				state.Lines[1]^ := state.Lines[1]^ + 'Strict'
			else
				state.Lines[1]^ := state.Lines[1]^ + 'Normal';

{$IFNDEF SDL2}
			state.Lines[2]^ := '!;Sound: ';
			if SoundEnabled then
				state.Lines[2]^ := state.Lines[2]^ + 'On'
			else
				state.Lines[2]^ := state.Lines[2]^ + 'Off';
{$ELSE}
			state.Lines[2]^ := '!;Sound: ';
			if AudioGetVolume >= 64 then
				state.Lines[2]^ := state.Lines[2]^ + '100%'
			else if AudioGetVolume >= 48 then
				state.Lines[2]^ := state.Lines[2]^ + '75%'
			else if AudioGetVolume >= 32 then
				state.Lines[2]^ := state.Lines[2]^ + '50%'
			else if AudioGetVolume >= 16 then
				state.Lines[2]^ := state.Lines[2]^ + '25%'
			else
				state.Lines[2]^ := state.Lines[2]^ + 'Off';
{$ENDIF}

			state.Lines[3]^ := '_________________________________________';
			state.Lines[4]^ := '';
			state.Lines[5]^ := '!;About ClassicZoo...';
			state.Lines[6]^ := '!;Exit';

			TextWindowSelect(state, TWS_HYPERLINK_AS_SELECT);
			if (InputKeyPressed = KEY_ENTER) and (state.LinePos <> 6) then begin
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
{$ELSE}
					2: begin
						i := AudioGetVolume;
						if i >= 64 then begin
							i := 0;
							SoundClearQueue;
						end else begin
							i := (i and $F0) + 16;
						end;
						AudioSetVolume(i);
					end;
{$ENDIF}
					5: begin
						GameAboutScreen;
					end;
				end;
			end else begin
				exitRequested := true;
				TextWindowDrawClose(state);
			end;

			TextWindowFreeEdit(state);
		until exitRequested;
	end;

end.
