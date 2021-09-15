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

unit ZxtZoo;

interface
	uses ZxtMgr;
	function ZxtZZOCustomCharsetHandler(var block: TExtensionBlock; var state: TExtensionHandlerState)
		: TExtensionHandlerResult;

implementation
uses ZVideo;

function ZxtZZOCustomCharsetHandler(var block: TExtensionBlock; var state: TExtensionHandlerState)
	: TExtensionHandlerResult;
begin
	ZxtZZOCustomCharsetHandler := ExtResultFailure;
{$IFNDEF NEC98}
	with block do begin
		case state.Action of
			ExtActionLoad: begin
				if (Header.FieldLength and $FF) = 0 then
					if VideoSetCharset(Data, Header.FieldLength shr 8) then
						ZxtZZOCustomCharsetHandler := ExtResultSuccess;
			end;
			ExtActionUnload: begin
				if VideoSetCharset(Ptr(0, 0), 14) then
					ZxtZZOCustomCharsetHandler := ExtResultSuccess;
			end;
		end;
	end;
{$ENDIF}
end;

end.
