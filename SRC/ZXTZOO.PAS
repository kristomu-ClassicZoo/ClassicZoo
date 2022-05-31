{
	Copyright (c) 2020 Adrian Siekierka

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

{$PACKRECORDS 1}

unit ZxtZoo;

interface
	uses ZxtMgr;
	procedure ZxtMaxStatCountEditor(editable: boolean; var block: TExtensionBlock);
	function ZxtMaxStatCountHandler(var block: TExtensionBlock; var state: TExtensionHandlerState)
		: TExtensionHandlerResult;

implementation
uses GameVars, Sidebar, ZVideo;
type
	TMaxStatCountData = record
		minCount, recCount: word;
	end;
	PTMaxStatCountData = ^TMaxStatCountData;

function AllocateHeaderData(var block: TExtensionBlock; len: word): boolean;
begin
	AllocateHeaderData := false;
	with block do begin
		if (Header.FieldLength <> len) then begin
			if Header.FieldLength > 0 then
				FreeMem(Data, Header.FieldLength);
			Data := nil;
			Header.FieldLength := len;
			if Header.FieldLength > 0 then
				GetMem(Data, Header.FieldLength);
			AllocateHeaderData := true;
		end;
	end;
end;


procedure ZxtMaxStatCountEditor(editable: boolean; var block: TExtensionBlock);
begin
	if AllocateHeaderData(block, 4) then begin
		with PTMaxStatCountData(block.Data)^ do begin
			minCount := DEFAULT_MAX_STAT;
			recCount := ACTUAL_MAX_STAT;
		end;
	end;

	with PTMaxStatCountData(block.Data)^ do begin
		SidebarPromptNumeric(editable, VideoSidebarX + 3, 9, 'Min. count?',
			1, ACTUAL_MAX_STAT, minCount);
		SidebarPromptNumeric(editable, VideoSidebarX + 3, 13, 'Rec. count?',
			minCount, ACTUAL_MAX_STAT, recCount);

		block.Header.Flags := (block.header.Flags and $FFC0);
		if recCount > DEFAULT_MAX_STAT then
			block.Header.Flags := block.Header.Flags or $08;
		if minCount > DEFAULT_MAX_STAT then
			block.Header.Flags := block.Header.Flags or $3E;
	end;
end;

function ZxtMaxStatCountHandler(var block: TExtensionBlock; var state: TExtensionHandlerState)
	: TExtensionHandlerResult;
var
	i: word;
begin
	ZxtMaxStatCountHandler := ExtResultFailure;
	with block do begin
		case state.Action of
			ExtActionLoad: begin
				if (Header.FieldLength <> 2) and (Header.FieldLength <> 4) then exit;
				with PTMaxStatCountData(Data)^ do begin
					if ACTUAL_MAX_STAT < LEToN(minCount) then exit;
					if Header.FieldLength = 2 then begin
						MAX_STAT := LEToN(minCount);
					end else begin
						MAX_STAT := LEToN(recCount);
						if MAX_STAT > ACTUAL_MAX_STAT then
							MAX_STAT := ACTUAL_MAX_STAT;
					end;
					ZxtMaxStatCountHandler := ExtResultSuccess;
				end;
			end;
			ExtActionUnload: begin
				{ TODO: This doesn't handle multiple MAX_STAT blocks properly. }
				MAX_STAT := DEFAULT_MAX_STAT;
				ZxtMaxStatCountHandler := ExtResultSuccess;
			end;
		end;
	end;
end;

end.
