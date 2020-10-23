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
{$V-}
unit FileMgmt;

interface
	uses GameVars;
	function FilenameFindIgnoreCase(fn: string): string;
	function FileSelect(title, extension: TString50): string;

{ Pulling in all of SysUtlils on DOS/8086 increases filesize unreasonably. }
{$IFDEF FPC}
{$IFNDEF CPUI8086}
{$DEFINE EXTFNSUP}
{$ELSE}
{$IFNDEF MSDOS}
{$DEFINE EXTFNSUP}
{$ENDIF}
{$ENDIF}
{$ENDIF}

implementation
{$IFDEF EXTFNSUP}
uses SysUtils, TxtWind;
{$ELSE}
uses Dos, TxtWind;
{$ENDIF}
const
	PATH_PREVIEW_LENGTH = 24;
	MAX_FILENAME_LENGTH = 20;

{$IFDEF EXTFNSUP}
function FilenameFindIgnoreCase(fn: string): string;
	var
		fileSearchRec: TRawbyteSearchRec;
		startPath: string;
		basePath: string;
		newFn: string;
		fnFilename: string;
	begin
		basePath := ExpandFileName(ExtractFileDir(fn));
		fnFilename := UpCase(ExtractFileName(fn));
		newFn := fn;

		GetDir(0, startPath);
		ChDir(basePath);

		FindFirst('*', faAnyFile, fileSearchRec);
		repeat
			if ((fileSearchRec.Attr and faDirectory) = 0) then begin
				if UpCase(fileSearchRec.Name) = fnFilename then begin
					newFn := ExpandFileName(IncludeTrailingPathDelimiter(basePath) + fileSearchRec.Name);
					break;
				end;
			end;
		until FindNext(fileSearchRec) <> 0;
		FindClose(fileSearchRec);

		ChDir(startPath);
		FilenameFindIgnoreCase := newFn;
	end;
{$ELSE}
function FilenameFindIgnoreCase(fn: string): string;
	begin
		FilenameFindIgnoreCase := fn;
	end;
{$ENDIF}

function FileSelect(title, extension: TString50): string;
	var
		textWindow: TTextWindowState;
{$IFDEF EXTFNSUP}
		fileSearchRec: TRawbyteSearchRec;
{$ELSE}
		fileSearchRec: SearchRec;
{$ENDIF}
		entryName: string;
		useWorldFileDesc: boolean;
		searching: boolean;
		i: integer;
		curPath: string;
		startPath: string;
		previewPath: string[PATH_PREVIEW_LENGTH + 4];
	begin
		useWorldFileDesc := extension = '.ZZT';
		searching := true;
		GetDir(0, startPath);

		while searching do begin
			GetDir(0, curPath);
			if Length(curPath) > PATH_PREVIEW_LENGTH then
				previewPath := '...' + Copy(curPath, Length(curPath) - PATH_PREVIEW_LENGTH + 1, PATH_PREVIEW_LENGTH)
			else
				previewPath := curPath;

			TextWindowInitState(textWindow);
			textWindow.Title := title + ': ' + previewPath;
			textWindow.Selectable := true;
			textWIndow.Hyperlink := '';

		{$IFDEF EXTFNSUP}
			{ .. }
			if ExpandFileName(curPath) <> ExpandFileName(IncludeTrailingPathDelimiter(curPath) + '..') then
				TextWindowAppend(textWindow, '!..;[..]');

			{ Directories }
			FindFirst('*', faDirectory, fileSearchRec);
			repeat
				if (fileSearchRec.Attr and faDirectory) <> 0 then begin
					entryName := fileSearchRec.Name;
					if Length(entryName) <= MAX_FILENAME_LENGTH then
						if (Length(entryName) > 0) and (entryName <> '.') and (entryName <> '..') then
							TextWindowAppend(textWindow, '!' + entryName + ';[' + entryName + ']');
				end;
			until FindNext(fileSearchRec) <> 0;
			FindClose(fileSearchRec);
		
			{ Files }
			FindFirst('*', faAnyFile, fileSearchRec);
			repeat
				if ((fileSearchRec.Attr and faDirectory) = 0) then begin
					if UpCase(Copy(fileSearchRec.Name,
						Length(fileSearchRec.name) - Length(extension) + 1,
						Length(extension))) = extension then begin
						entryName := Copy(fileSearchRec.Name, 1, Length(fileSearchRec.name) - Length(extension));

						if Length(entryName) <= MAX_FILENAME_LENGTH then
							TextWindowAppend(textWindow, entryName);
					end;
				end;
			until FindNext(fileSearchRec) <> 0;
			FindClose(fileSearchRec);
		{$ELSE}
			{ .. }
			if Length(curPath) > 3 then
				TextWindowAppend(textWindow, '!..;[..]');

			{ Directories }
			FindFirst('*', Directory, fileSearchRec);
			while DosError = 0 do begin
				if (fileSearchRec.Attr and Directory) <> 0 then begin
					entryName := fileSearchRec.Name;
					if Length(entryName) <= MAX_FILENAME_LENGTH then
						if (Length(entryName) > 0) and (entryName <> '.') and (entryName <> '..') then
							TextWindowAppend(textWindow, '!' + entryName + ';[' + entryName + ']');
				end;
				FindNext(fileSearchRec);
			end;
		
			{ Files }
			FindFirst('*' + extension, AnyFile, fileSearchRec);
			while DosError = 0 do begin
				if (fileSearchRec.Attr and Directory) = 0 then begin
					if Length(entryName) <= MAX_FILENAME_LENGTH then
						TextWindowAppend(textWindow, entryName);
				end;
				FindNext(fileSearchRec);
			end;
		{$ENDIF}

			TextWindowAppend(textWindow, 'Exit');

			TextWindowDrawOpen(textWindow);
			TextWindowSelect(textWindow, true, false);
			TextWindowDrawClose(textWindow);

			if (textWindow.LinePos = textWindow.LineCount) or TextWindowRejected then begin
				{ Exit }
				FileSelect := '';
				searching := false;
			end else if Length(textWindow.Hyperlink) > 0 then begin
				{ Directory }
				ChDir(textWindow.Hyperlink);
			end else begin
				{ File }
				entryName := textWindow.Lines[textWindow.LinePos]^;
			{$IFDEF EXTFNSUP}
				FileSelect := IncludeTrailingPathDelimiter(curPath) + entryName;
			{$ELSE}
				FileSelect := curPath + '\' + entryName;
			{$ENDIF}
				searching := false;
			end;
		end;

		TextWindowFree(textWindow);

		ChDir(startPath);
	end;

end.
