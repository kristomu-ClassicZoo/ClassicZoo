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
		{ Return true if the extension was handled successfully. }
		TExtensionHandlerFunc = function(extType: TExtensionType; fieldLength: word; var extFile: file): boolean;
	var
		ExtensionEnabled: array[ExtUnlockExtensions .. ExtTypeEnd] of boolean;
		ExtensionAnyEnabled: boolean;
		ExtensionPlayShould: boolean;
		ExtensionEditShould: boolean;
		ExtensionWriteCan: boolean;
	{ Assumes that the engine MUST be capable of reading and playing this world. }
	{ As such, the only flags exposed above are ExtensionPlayShould, ExtensionEditShould }
	{ and ExtensionWriteCan. }
	function ExtensionEnabledById(eowner: longint; eselector: word): boolean;
	function ZxtLoadExtensions(var worldFile: file; filename: TString50): boolean;
	procedure ZxtRegisterExtensionHandler(extHandlerFunc: TExtensionHandlerFunc);

implementation
uses Dos;

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
	FParsingMust = $0001;
	FReadingMust = $0002;
	FWritingMust = $0004;
	FPlayingShould = $0008;
	FPlayingMust = $0010;
	FEditingShould = $0020;
	FPreserveShould = $0040;
	FBlockHeaderKnown = $007F;
	ExtensionIdList: array[0 .. (Ord(ExtTypeEnd) - 1)] of TExtensionID =
	(
		(Owner: $00000000; Selector: $0001) { ExtUnlockExtensions }
	);
var
	ZxtExtensionHandlerFunc: TExtensionHandlerFunc;

{$F+}

function ZxtExtensionHandlerDummy(extType: TExtensionType; fieldLength: word; var extFile: file): boolean;
begin
	ZxtExtensionHandlerDummy := true;
end;

{$F-}

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
	ExtensionAnyEnabled := false;
	ExtensionPlayShould := true;
	ExtensionEditShould := true;
	ExtensionWriteCan := true;

	{ Clear all enabled extensions. }
	FillChar(ExtensionEnabled, Ord(ExtTypeEnd), 0);

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
		if (IOResult <> 0) or ((bhdr.Flags and (not FBlockHeaderKnown)) <> 0) or (bhdr.FieldLength = $FFFF) then begin
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
			ExtensionAnyEnabled := true;

			if not ZxtExtensionHandlerFunc(TExtensionType(extId), bhdr.FieldLength, extFile^) then begin
				ZxtLoadExtensions := false;
				goto OnError;
			end;
		end else begin
			{ Un-set flags, if we don't recognize it. }
			if (bhdr.Flags and (FParsingMust or FReadingMust or FPlayingMust)) <> 0 then begin
				ZxtLoadExtensions := false;
				goto OnError;
			end;
			if (bhdr.Flags and FPlayingShould) <> 0 then
				ExtensionPlayShould := false;
			if (bhdr.Flags and FEditingShould) <> 0 then
				ExtensionEditShould := false;
			if (bhdr.Flags and FWritingMust) <> 0 then
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

procedure ZxtRegisterExtensionHandler(extHandlerFunc: TExtensionHandlerFunc);
begin
	ZxtExtensionHandlerFunc := extHandlerFunc;
end;

begin
	ZxtExtensionHandlerFunc := ZxtExtensionHandlerDummy;
end.
