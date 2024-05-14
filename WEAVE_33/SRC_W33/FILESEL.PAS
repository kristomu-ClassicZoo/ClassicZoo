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
unit FileSel;

interface
	uses GameVars;
	function FileExists(name: TFilenameString): boolean;
	function FileSelect(title, extension: TString50; var cachedLinePos: integer): TFilenameString;
	function FileIsMult: boolean;

implementation
uses Dos, Game, TxtWind;
const
	PATH_PREVIEW_LENGTH = 24;

function FileExists(name: TFilenameString): boolean;
	var
		f: file;
	begin
		Assign(f, name);
		Reset(f);
		if IOResult = 0 then begin
			Close(f);
			FileExists := true;
		end else FileExists := false;
	end;

function FileSelect(title, extension: TString50; var cachedLinePos: integer): TFilenameString;
	var
		textWindow: TTextWindowState;
		fileSearchRec: SearchRec;
		entryName: TFilenameString;
		searching: boolean;
		i: integer;
		lastDirLinePos: integer;
		curPath: TFilenameString;
		startPath: TFilenameString;
		previewPath: string[PATH_PREVIEW_LENGTH + 4];
	begin
		searching := true;
		GetDir(0, startPath);

		while searching do begin
			TextWindowInitState(textWindow);
			GetDir(0, curPath);
			if Length(curPath) > PATH_PREVIEW_LENGTH then
				previewPath := '...' + Copy(curPath, Length(curPath) - PATH_PREVIEW_LENGTH + 1, PATH_PREVIEW_LENGTH)
			else
				previewPath := curPath;
			textWindow.Title := title + ': ' + previewPath;
			textWindow.Selectable := true;
			textWIndow.Hyperlink := '';

			{ Directories }
			FindFirst('*', Directory, fileSearchRec);
			while DosError = 0 do begin
				if (fileSearchRec.Attr and Directory) <> 0 then begin
					entryName := fileSearchRec.Name;
					if (Length(entryName) > 0) and (entryName <> '.') then
						if (Length(curPath) > 3) or (entryName <> '..') then
							TextWindowAppend(textWindow, '!' + entryName + ';[' + entryName + ']');
				end;
				FindNext(fileSearchRec);
			end;
			lastDirLinePos := textWindow.LineCount;

			{ Files }
			FindFirst('*' + extension, AnyFile, fileSearchRec);
			while DosError = 0 do begin
				if (fileSearchRec.Attr and Directory) = 0 then begin
					entryName := Copy(fileSearchRec.Name, 1, Length(fileSearchRec.name) - Length(extension));
					TextWindowAppend(textWindow, entryName);
				end;
				FindNext(fileSearchRec);
			end;

			textWindow.LinePos := cachedLinePos;

			TextWindowAppend(textWindow, 'Exit');

			TextWindowDrawOpen(textWindow);
			TextWindowSelect(textWindow, TWS_HYPERLINK_AS_SELECT);
			TextWindowDrawClose(textWindow);

			if (textWindow.LinePos = textWindow.LineCount) or TextWindowRejected then begin
				{ Exit }
				FileSelect := '';
				searching := false;
				ChDir(startPath);
			end else if textWindow.LinePos <= lastDirLinePos then begin
				{ Directory }
				ChDir(textWindow.Hyperlink);
			end else begin
				{ File }
				entryName := textWindow.Lines[textWindow.LinePos]^;
				FileSelect := entryName;
				searching := false;

				if startPath <> curPath then
					ResetCachedLinePos;
				cachedLinePos := textWindow.LinePos;
			end;

			TextWindowFree(textWindow);

			{ Clear IOResult }
			if IOResult <> 0 then begin end;
		end;
	end;

function FileIsMult: boolean;
	var
		fileSearchRec: SearchRec;
	begin
		FileIsMult := false;
		FindFirst('*.ZZT', AnyFile, fileSearchRec);
		if DosError = 0 then FindNext(fileSearchRec);
		if DosError = 0 then FileIsMult := true;
	end;

end.
