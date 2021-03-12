{
	Copyright (c) 2021 Adrian Siekierka

	Permission to use, copy, modify, and/or distribute this software for any
	purpose with or without fee is hereby granted.

	THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
	WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
	MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
	SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
	RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF
	CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
	CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
}

{$I-}
{$V-}
unit ZxtMgr;

interface
	uses GameVars;
	type
		{ Add your own extension types above ExtTypeEnd. }
		{ Don't forget to populate the ID list below. }
		TExtensionType = (
			ExtUnlockExtensions,
			ExtTypeEnd
		);
		{ Return true if the extension was read successfully. }
		TExtensionReadHandlerFunc = function(extType: TExtensionType; var flags: word;
			fieldLength: word; var extFile: file): boolean;
		{ Return true if the extension was written successfully. }
		TExtensionWriteHandlerFunc = function(extType: TExtensionType; var extFile: file): boolean;
	const
		FExtParsingMust = $0001;
		FExtReadingMust = $0002;
		FExtWritingMust = $0004;
		FExtPlayingShould = $0008;
		FExtPlayingMust = $0010;
		FExtEditingShould = $0020;
		FExtPreserveShould = $0040;
		FExtBlockHeaderKnown = $007F;
	var
		ExtensionEnabled: array[ExtUnlockExtensions .. ExtTypeEnd] of boolean;
		ExtensionFlags: array[ExtUnlockExtensions .. ExtTypeEnd] of word;
		ExtensionPlayShould: boolean;
		ExtensionEditShould: boolean;
		ExtensionWriteCan: boolean;
	{ Assumes that the engine MUST be capable of reading and playing this world. }
	{ As such, the only flags exposed above are ExtensionPlayShould, ExtensionEditShould }
	{ and ExtensionWriteCan. }
	function ExtensionAnyEnabled: boolean;
	function ExtensionEnabledById(eowner: longint; eselector: word): boolean;
	function ZxtLoadExtensions(var worldFile: file; filename: TString50): boolean;
	function ZxtWriteExtensions(var extFile: file): boolean;
	function ZxtShowFlagError(isEditing: boolean): boolean;
	procedure ZxtRegisterExtensionReadHandler(handler: TExtensionReadHandlerFunc);
	procedure ZxtRegisterExtensionWriteHandler(handler: TExtensionWriteHandlerFunc);

implementation
uses Dos, TxtWind;

type
	TExtensionId = record
		Owner: longint;
		Selector: word;
	end;
	TExtensionHeader = record
		Magic: integer;
		BlockCount: longint;
	end;
	TExtensionBlockHeader = record
		Flags: word;
		Id: TExtensionId;
		FieldType: byte;
		FieldLength: word;
	end;
const
	ZXT_MAGIC = -3545; { $F227 }
	ExtensionIdList: array[0 .. (Ord(ExtTypeEnd) - 1)] of TExtensionID =
	(
		(Owner: $00000000; Selector: $0001) { ExtUnlockExtensions }
	);
var
	ZxtExtensionReadHandlerFunc: TExtensionReadHandlerFunc;
	ZxtExtensionWriteHandlerFunc: TExtensionWriteHandlerFunc;

{$F+}

function ZxtExtensionReadHandlerDefault(extType: TExtensionType; var flags: word;
	fieldLength: word; var extFile: file): boolean;
begin
	ZxtExtensionReadHandlerDefault := true;
end;

function ZxtExtensionWriteHandlerDefault(extType: TExtensionType; var extFile: file): boolean;
begin
	ZxtExtensionWriteHandlerDefault := true;
end;

{$F-}

function ExtensionAnyEnabled: boolean;
var
	extId: word;
begin
	for extId := 0 to (Ord(ExtTypeEnd) - 1) do begin
		if ExtensionEnabled[TExtensionType(extId)] then begin
			ExtensionAnyEnabled := true;
			exit;
		end;
	end;

	ExtensionAnyEnabled := false;
end;

function ExtensionEnabledById(eowner: longint; eselector: word): boolean;
var
	extId: word;
begin
	for extId := 0 to (Ord(ExtTypeEnd) - 1) do begin
		with ExtensionIdList[extId] do begin
			if (Owner = eowner) and (Selector = eselector) then begin
				ExtensionEnabledById := true;
				exit;
			end;
		end;
	end;

	ExtensionEnabledById := false;
end;

function ZxtLoadExtensions(var worldFile: file; filename: TString50): boolean;
var
	hdr: TExtensionHeader;
	bhdr: TExtensionBlockHeader;
	zaxFile: file;
	extFile: ^file;
	bi: longint;
	extId: word;
	extFound: boolean;
label OnExtFound;
label OnError;
begin
	ZxtLoadExtensions := true;
	ExtensionPlayShould := true;
	ExtensionEditShould := true;
	ExtensionWriteCan := true;

	{ Clear all enabled extensions. }
	FillChar(ExtensionEnabled, Ord(ExtTypeEnd), 0);
	FillChar(ExtensionFlags, Ord(ExtTypeEnd) shl 1, 0);

	{ World.BoardCount is currently set to the world file's magic. }
	if World.BoardCount = ZXT_MAGIC then begin
		{ .ZXT file. }
		extFile := @worldFile;

		{ Read extension header. }
		hdr.Magic := ZXT_MAGIC;
		BlockRead(worldFile, hdr.BlockCount, 4);
	end else begin
		Assign(zaxFile, filename + '.ZAX');
		Reset(zaxFile, 1);
		if IOResult = 0 then begin
			{ .ZAX file. }
			extFile := @zaxFile;

			{ Read extension header. }
			BlockRead(extFile^, hdr, SizeOf(hdr));
		end else begin
			{ No extensions found. }
			exit;
		end;	
	end;

	{ Validate header. }
	if (IOResult <> 0) or (hdr.Magic <> ZXT_MAGIC) or (hdr.BlockCount < 0) then begin
		ZxtLoadExtensions := false;
		goto OnError;
	end;

	for bi := 1 to hdr.BlockCount do begin
		{ Parse extension. }
		BlockRead(extFile^, bhdr, SizeOf(bhdr));
		if (IOResult <> 0)
			or ((bhdr.Flags and (not FExtBlockHeaderKnown)) <> 0)
			or (bhdr.FieldLength = $FFFF)
		then begin
			ZxtLoadExtensions := false;
			goto OnError;
		end;

		{ Figure out if we recognize this extension. }
		for extId := 0 to (Ord(ExtTypeEnd) - 1) do begin
			with ExtensionIdList[extId] do begin
				if (bhdr.Id.Owner = Owner) and (bhdr.Id.Selector = Selector) then begin
					extFound := true;	
					goto OnExtFound;
				end;
			end;
		end;

		extFound := false;

	OnExtFound:
		{ TODO: Implement FPreserveShould. }
		if extFound then begin
			ExtensionEnabled[TExtensionType(extId)] := true;

			if not ZxtExtensionReadHandlerFunc(TExtensionType(extId), bhdr.Flags, bhdr.FieldLength, extFile^) then begin
				ZxtLoadExtensions := false;
				goto OnError;
			end;

			ExtensionFlags[TExtensionType(extId)] := bhdr.Flags;
		end else begin
			{ Un-set flags, if we don't recognize it. }
			if (bhdr.Flags and (FExtParsingMust or FExtReadingMust or FExtPlayingMust)) <> 0 then begin
				ZxtLoadExtensions := false;
				goto OnError;
			end;
			if (bhdr.Flags and FExtPlayingShould) <> 0 then
				ExtensionPlayShould := false;
			if (bhdr.Flags and FExtEditingShould) <> 0 then
				ExtensionEditShould := false;
			if (bhdr.Flags and FExtWritingMust) <> 0 then
				ExtensionWriteCan := false;
		end;
	end;
OnError:
	{ Finish. }
	if World.BoardCount = ZXT_MAGIC then begin
		{ .ZXT file. }
		BlockRead(extFile^, World.BoardCount, 2);
	end else begin
		{ .ZAX file. }
		Close(zaxFile);
	end;
end;

function ZxtWriteExtensions(var extFile: file): boolean;
var
	hdr: TExtensionHeader;
	bhdr: TExtensionBlockHeader;
	i: word;
	lenpos, retpos: longint;
begin
	if not ExtensionWriteCan then begin
		ZxtWriteExtensions := false;
		exit;
	end;

	hdr.Magic := ZXT_MAGIC;
	hdr.BlockCount := 0;
	for i := 0 to (Ord(ExtTypeEnd) - 1) do
		if ExtensionEnabled[TExtensionType(i)] then
			Inc(hdr.BlockCount);
	BlockWrite(extFile, hdr, SizeOf(hdr));
	if IOResult <> 0 then begin
		ZxtWriteExtensions := false;
		exit;
	end;

	for i := 0 to (Ord(ExtTypeEnd) - 1) do
		if ExtensionEnabled[TExtensionType(i)] then begin
			bhdr.Flags := ExtensionFlags[TExtensionType(i)];
			with ExtensionIdList[i] do begin
				bhdr.Id.Owner := Owner;
				bhdr.Id.Selector := Selector;
			end;
			bhdr.FieldType := $00;
			bhdr.FieldLength := 0;
			BlockWrite(extFile, bhdr, SizeOf(bhdr));
			lenpos := FilePos(extFile);

			if IOResult <> 0 then begin
				ZxtWriteExtensions := false;
				exit;
			end;

			if not ZxtExtensionWriteHandlerFunc(TExtensionType(i), extFile) then begin
				ZxtWriteExtensions := false;
				exit;
			end;

			retpos := FilePos(extFile);
			if (retpos <> lenpos) then begin
				bhdr.FieldLength := retpos - lenpos;
				Seek(extFile, lenpos - SizeOf(bhdr));
				BlockWrite(extFile, bhdr, SizeOf(bhdr));
				Seek(extFile, retpos);
			end;
		end;

	ZxtWriteExtensions := true;
end;

function ZxtShowFlagError(isEditing: boolean): boolean;
var
	textWindow: TTextWindowState;
	isFatal: boolean;
begin
	isFatal := (isEditing) and (not ExtensionWriteCan);
	ZxtShowFlagError := isFatal;

	if isFatal then
		textWindow.Title := 'Error'
	else begin
		if (isEditing and ExtensionEditShould) or ((not isEditing) and ExtensionPlayShould) then
			exit;
		textWindow.Title := 'Warning';
	end;

	TextWindowInitState(textWindow);
	TextWindowAppend(textWindow, 'This world uses extensions which are');
	TextWindowAppend(textWindow, 'not supported by this version of the');
	TextWindowAppend(textWindow, 'game engine.');
	TextWindowAppend(textWindow, '');
	if isFatal then
		TextWindowAppend(textWindow, 'This action is unavailable.')
	else if isEditing then
		TextWindowAppend(textWindow, 'Editing may be negatively impacted.')
	else
		TextWindowAppend(textWindow, 'Playing may be negatively impacted.');

	TextWindowDrawOpen(textWindow);
	TextWindowSelect(textWindow, false, false);
	TextWindowDrawClose(textWindow);
	TextWindowFree(textWindow);
end;

procedure ZxtRegisterExtensionReadHandler(handler: TExtensionReadHandlerFunc);
begin
	ZxtExtensionReadHandlerFunc := handler;
end;

procedure ZxtRegisterExtensionWriteHandler(handler: TExtensionWriteHandlerFunc);
begin
	ZxtExtensionWriteHandlerFunc := handler;
end;

begin
	ZxtExtensionReadHandlerFunc := ZxtExtensionReadHandlerDefault;
	ZxtExtensionWriteHandlerFunc := ZxtExtensionWriteHandlerDefault;
end.
