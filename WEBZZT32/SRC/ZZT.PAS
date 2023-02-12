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
uses Crt, Dos, Video, Keys, Sounds, Input, TxtWind, GameVars, Elements, Oop, Game;

begin

	Randomize;
	SetCBreak(false);
	InitialTextAttr := TextAttr;

	ResetConfig := false;
	GameTitleExitRequested := false;
	WorldMenuChar := 'P';

	if not GameTitleExitRequested then begin
		VideoInstall(80, Blue);
		TextWindowInit(5, 3, 50, 18);
		New(IoTmpBuf);

		VideoHideCursor;
		ClrScr;

		TickSpeed := 4;
		DebugEnabled := false;
		SavedGameFileName := 'SAVED';
		GenerateTransitionTable;
		WorldCreate;

		GameTitleLoop;

		Dispose(IoTmpBuf);
	end;

	SoundUninstall;
	SoundClearQueue;

	VideoUninstall;
	Port[PORT_CGA_PALETTE] := 0;
	TextAttr := InitialTextAttr;
	ClrScr;

	VideoShowCursor;
end.
