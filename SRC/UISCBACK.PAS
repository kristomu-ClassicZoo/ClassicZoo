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

{ Inspired by zzo38's FreeZZT implementation. }

{$I-}
{$V-}
unit UiScBack; { Scrollback }

interface
	uses GameVars;
	type
		TScrollbackString = string[60];
	const
		SCROLLBACK_MAX_SIZE = 256;
	var
		ScrollbackSize: integer;
	procedure ScrollbackClear(size: integer);
	procedure ScrollbackAppend(message: TScrollbackString);
	procedure ScrollbackDisplay;

implementation
uses TxtWind;

type
	TScrollbackList = array[0 .. (SCROLLBACK_MAX_SIZE - 1)] of TScrollbackString;
var
	ScrollbackList: ^TScrollbackList;
	ScrollbackIndex: integer;

procedure ScrollbackClear(size: integer);
begin
	if size > SCROLLBACK_MAX_SIZE then
		size := SCROLLBACK_MAX_SIZE;

	if (size >= 0) and (size <> ScrollbackSize) then begin
		if ScrollbackSize > 0 then
			FreeMem(ScrollbackList, ScrollbackSize * 61);
		ScrollbackSize := size;
		if ScrollbackSize > 0 then
			GetMem(ScrollbackList, ScrollbackSize * 61);
	end;

	if ScrollbackSize > 0 then begin
		ScrollbackIndex := ScrollbackSize - 1;
		ScrollbackList^[ScrollbackSize - 1] := '';
	end;
end;

procedure ScrollbackAppend(message: TScrollbackString);
begin
	if ScrollbackSize <= 0 then exit;
	if Length(message) <= 0 then exit;

	Inc(ScrollbackIndex);
	while ScrollbackIndex >= ScrollbackSize do
		Dec(ScrollbackIndex, ScrollbackSize);
	ScrollbackList^[ScrollbackIndex] := message;
end;

procedure ScrollbackDisplay;
var
	i: integer;
	message: TScrollbackString;
	window: TTextWindowState;
label FoundAll;
begin
	if ScrollbackSize <= 0 then exit;

	TextWindowInitState(window);
	window.Title := 'Message Scrollback';
	i := ScrollbackIndex;
	repeat
		message := ScrollbackList^[i];
		if Length(message) <= 0 then
			goto FoundAll;
		if window.LineCount > 0 then
			TextWindowAppend(window, '');
		while Length(message) > (TextWindowWidth - 8) do begin
			TextWindowAppend(window, Copy(message, 1, (TextWindowWidth - 8)));
			message := Copy(message, (TextWindowWidth - 8) + 1, Length(message) - (TextWindowWidth - 8));
		end;
		TextWindowAppend(window, message);
		Dec(i);
		while i < 0 do
			Inc(i, ScrollbackSize);
	until i = ScrollbackIndex;
FoundAll:
	if window.LineCount <= 0 then
		TextWindowAppend(window, '$No messages');
	TextWindowDrawOpen(window);
	TextWindowSelect(window, 0);
	TextWindowDrawClose(window);
	TextWindowFree(window);
end;

begin
	ScrollbackIndex := 0;
	ScrollbackSize := 0;
end.
