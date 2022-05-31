{
	Copyright (c) 2022 Adrian Siekierka

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

unit ZxtEdit;

interface
	uses GameVars, ZxtMgr, TxtWind;
	type
		TEditorZxtCategory = (
			EditorZxtCategoryFix,
			EditorZxtCategoryOop,
			EditorZxtCategoryQuirk,
			EditorZxtCategoryWorld
		);
		TEditorZxtInfo = record
			ExtType: TExtensionType;
			ExtAllowedFlags: word;
			ExtToggleableFlags: word;
			EditCategory: TEditorZxtCategory;
			EditFlags: word;
			Name: string[28];
		end;
	function ZxtEditorRun: boolean;

implementation
uses Dos, FileSel, ZVideo, ZInput, TimerSys, Sidebar, Oop, ZxtZoo;

{ START YOUR EDITS HERE }

const
	HEX_DIGITS = '0123456789ABCDEF';
	EditorCategoryCharacters = 'FOQW';

	EDITOR_ZXT_ALLOW_MULTIPLE = $0001;

	ALLOWED_FLAGS_PLAY = FZxtExtPlayingShould or FZxtExtPlayingMust;
	ALLOWED_FLAGS_PLAY_EDIT = ALLOWED_FLAGS_PLAY or FZxtExtEditingShould;
	ALLOWED_FLAGS_READ_WRITE = ALLOWED_FLAGS_PLAY_EDIT or FZxtExtReadingMust or FZxtExtWritingMust;

	TOGGLEABLE_FLAGS_DEFAULTS = FZxtExtPlayingShould or FZxtExtPlayingMust or FZxtExtEditingShould;
	TOGGLEABLE_FLAGS_PLAY = FZxtExtPlayingShould or FZxtExtPlayingMust;

	HEADER_BAR_Y = 0;
	EDITOR_ZXT_INFOS_COUNT = 16
	{$IFNDEF E_SUPERZ} + 2 {$ENDIF}
		;
	EditorZxtInfos: array[1 .. EDITOR_ZXT_INFOS_COUNT] of TEditorZxtInfo =
	(
		(
			ExtType: ExtUnlockExtensions;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: '#IFEXT'
		),
		(
			ExtType: ExtMaxStatCount;
			ExtAllowedFlags: ALLOWED_FLAGS_READ_WRITE;
			ExtToggleableFlags: 0;
			EditCategory: EditorZxtCategoryWorld;
			EditFlags: 0;
			Name: 'Maximum stat count'
		),
		(
			ExtType: ExtFixPutBottomRow;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: '#PUT on bottom row'
		),
		(
			ExtType: ExtFixBlinkWallShift;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Blink wall shift to left'
		),
{$IFNDEF E_SUPERZ}
		(
			ExtType: ExtFixBoardEdgeTouch;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Board edge touch direction'
		),
{$ENDIF}
		(
			ExtType: ExtFixConveyorStatSwapping;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Conveyor stat swapping'
		),
		(
			ExtType: ExtFixConveyorStatCheck;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Conveyor statless movement'
		),
		(
			ExtType: ExtFixConveyorMissingFinalDraw;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Conveyor visual bugs'
		),
		(
			ExtType: ExtFixKoopoBug;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Duplicator "Koopo" bug'
		),
		(
			ExtType: ExtFixBindDoubleFree;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Nested #BIND calls'
		),
		(
			ExtType: ExtFixRecursiveElementPush;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Recursive element push'
		),
		(
			ExtType: ExtGMDirByAt;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: 'BY/AT directions'
		),
{$IFNDEF E_SUPERZ}
		(
			ExtType: ExtSuperzEnter;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: ':ENTER'
		),
{$ENDIF}
		(
			ExtType: ExtDieItem;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: '#DIE ITEM'
		),
		(
			ExtType: ExtDieUnderTile;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: '#DIE preserves tile under'
		),
		(
			ExtType: ExtIfRnd;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: '#IF RND'
		),
		(
			ExtType: ExtOopViewport;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: '#VIEWPORT extension'
		),
		(
			ExtType: ExtQuirkArgTile2;
			ExtAllowedFlags: ALLOWED_FLAGS_PLAY;
			ExtToggleableFlags: TOGGLEABLE_FLAGS_PLAY;
			EditCategory: EditorZxtCategoryQuirk;
			EditFlags: 0;
			Name: 'Mark as using argTile2'
		)
	);

{ END YOUR EDITS HERE }

function EditorZxtGetInfoForId(extId: TExtensionId): integer;
	var
		destId: TExtensionId;
		i: integer;
	begin
		for i := 1 to EDITOR_ZXT_INFOS_COUNT do begin
			ZxtGetExtId(EditorZxtInfos[i].ExtType, destId);
			if (destId.Owner = extId.Owner) and (destId.Selector = extId.Selector) then begin
				EditorZxtGetInfoForId := i;
				exit;
			end;
		end;
		EditorZxtGetInfoForId := -1;
	end;

procedure EditorZxtUnloadFreeRemove(i: word);
	begin
		if ZxtBlockUnload(i) <> ExtResultSuccess then begin end;
		ZxtBlockRemove(i, true);
	end;

procedure EditorZxtUnloadFreeRemoveByType(targetExtType: TExtensionType);
	var
		i: integer;
	begin
		repeat
			i := ZxtBlockGetIdByType(targetExtType, 0);
			if i >= 0 then EditorZxtUnloadFreeRemove(i) else exit;
		until 1 = 0;
	end;

procedure EditorZxtUnloadAll;
	var
		i: integer;
	begin
		for i := ZxtBlockGetCount downto 1 do
			if ZxtBlockUnload(i) <> ExtResultSuccess then begin end;
	end;

procedure EditorZxtLoadAll;
	var
		i: integer;
	begin
		for i := 1 to ZxtBlockGetCount do
			if ZxtBlockLoad(i) <> ExtResultSuccess then begin end;
	end;

{ START YOUR EDITS HERE }

{ END YOUR EDITS HERE }

procedure ZxtEditorClearLine(iy: integer; color: byte);
	begin
		if color = $FF then begin
			color := $78;
			if (iy = HEADER_BAR_Y) then
				color := $08;
		end;
		VideoWriteText(0, iy, color,
			'               '
			+'               '
			+'               '
			+'               ');
	end;

function WordHexString(w: word): string;
	var
		buf: string[4];
		i: integer;
	begin
		for i := 4 downto 1 do begin
			buf[i] := HEX_DIGITS[(w and $F) + 1];
			w := w shr 4;
		end;
		buf[0] := #4;
		WordHexString := buf;
	end;

function ZxtEditorRun: boolean;
	var
		i, selEntry: integer;

	procedure ZxtEditorDrawBackground;
		var
			iy: integer;
		begin
			for iy := 0 to (VideoRows - 1) do
				ZxtEditorClearLine(iy, $FF);

			VideoWriteText(4, HEADER_BAR_Y, $0F, 'I.D.');
			VideoWriteText(13, HEADER_BAR_Y, $07, #179);
			VideoWriteText(14 + 13, HEADER_BAR_Y, $0F, 'NAME');
			VideoWriteText(14 + 31, HEADER_BAR_Y, $07, #179);
			VideoWriteText(46 + 1, HEADER_BAR_Y, $0F, 'FLAGS');
			VideoWriteText(46 + 7, HEADER_BAR_Y, $07, #179);
			VideoWriteText(54 + 1, HEADER_BAR_Y, $0F, 'LEN.');
		end;

	procedure ZxtEditorClearSidebar;
		var
			iy: integer;
		begin
			for iy := 3 to (VideoRows - 1) do
				SidebarClearLine(iy);
		end;

	procedure ZxtEditorDrawSidebar;
		var
			iy: integer;
		begin
			for iy := 0 to (VideoRows - 1) do
				SidebarClearLine(iy);

			VideoWriteText(VideoSidebarX + 1, 0, $1F,
				'__  /\\  /_ __|');
			VideoWriteText(VideoSidebarX + 4, 1, $1F,
				   '/  > <   |');
			VideoWriteText(VideoSidebarX + 1, 2, $1F,
				'____|//\_\ _| Edit');
			VideoWriteText(VideoSidebarX + 1, 7, $70, ' Return ');
			VideoWriteText(VideoSidebarX + 9, 7, $1F, ' Edit');
			VideoWriteText(VideoSidebarX + 1, 8, $30, ' Del ');
			VideoWriteText(VideoSidebarX + 6, 8, $1F, ' Delete');
			VideoWriteText(VideoSidebarX + 1, 9, $70, ' '#24#25' ');
			VideoWriteText(VideoSidebarX + 5, 9, $1F, ' Move cursor');

			VideoWriteText(VideoSidebarX + 1, 11, $30, ' N ');
			VideoWriteText(VideoSidebarX + 4, 11, $1F, ' New/Insert');
			VideoWriteText(VideoSidebarX + 1, 12, $70, ' I ');
			VideoWriteText(VideoSidebarX + 4, 12, $1F, ' Info');
			VideoWriteText(VideoSidebarX + 1, 13, $30, ' H ');
			VideoWriteText(VideoSidebarX + 4, 13, $1F, ' Help');

			VideoWriteText(VideoSidebarX + 1, 15, $70, ' F ');
			VideoWriteText(VideoSidebarX + 4, 15, $1F, ' Edit flags');

			VideoWriteText(VideoSidebarX + 1, 17, $30, ' Esc ');
			VideoWriteText(VideoSidebarX + 6, 17, $1F, ' Exit');
		end;

	procedure ZxtEditorDrawEntry(i, y: integer);
		var
			tmps: TSmallString;
			entry: PTExtensionBlock;
			entryInfoId: integer;
			color: byte;
		begin
			color := $70;
			if (i = selEntry) then
				color := $4F;
			ZxtEditorClearLine(y, color);

			if i > ZxtBlockGetCount then exit;
			entry := ZxtBlockGet(i);

			with entry^ do begin
				entryInfoId := EditorZxtGetInfoForId(Header.Id);

				VideoWriteText(0, y, color, WordHexString(Header.Id.Owner shr 16));
				VideoWriteText(4, y, color, WordHexString(Header.Id.Owner));
				VideoWriteText(8, y, color, ':');
				VideoWriteText(9, y, color, WordHexString(Header.Id.Selector));
				if entryInfoId >= 0 then begin
					VideoWriteText(14, y, color xor 2, 
						EditorCategoryCharacters[Ord(EditorZxtInfos[entryInfoId].EditCategory) + 1]);
					VideoWriteText(16, y, color, EditorZxtInfos[entryInfoId].Name);
				end else begin
					VideoWriteText(16, y, color, '?');
				end;

				if ((Header.Flags and FZxtExtReadingMust) <> 0) then VideoWriteText(46, y, color, 'R');
				if ((Header.Flags and FZxtExtWritingMust) <> 0) then VideoWriteText(47, y, color, 'W');
				if ((Header.Flags and FZxtExtPlayingShould) <> 0) then VideoWriteText(48, y, color, 'g');
				if ((Header.Flags and FZxtExtPlayingMust) <> 0) then VideoWriteText(49, y, color, 'G');
				if ((Header.Flags and FZxtExtEditingShould) <> 0) then VideoWriteText(50, y, color, 'e');
				if ((Header.Flags and FZxtExtPreserveShould) <> 0) then VideoWriteText(51, y, color, 'p');
				if ((Header.Flags and FZxtExtVanillaBehavior) <> 0) then VideoWriteText(52, y, color, 'v');

				if Header.FieldLength > 0 then begin
					Str(Header.FieldLength, tmps);
					VideoWriteText(60 - Length(tmps), y, color, tmps);
				end;
			end;
		end;

	procedure ZxtEditorDrawEntries;
		var
			i, ofs: integer;
		begin
			ofs := selEntry - (VideoRows div 2);
			if (ofs > (ZxtBlockGetCount - (VideoRows - 2))) then
				ofs := ZxtBlockGetCount - (VideoRows - 2);
			if ofs <= 1 then ofs := 1;

			for i := 1 to (VideoRows - 1) do
				ZxtEditorDrawEntry(i - 1 + ofs, i);
		end;

	function ZxtEditorSelectType: integer;
		var
			state: TTextWindowState;
			i: integer;
			running: boolean;
		begin
			TextWindowInitState(state);
			state.Title := 'Select type';
			state.LinePos := 1;
			state.Selectable := true;
			for i := 1 to EDITOR_ZXT_INFOS_COUNT do with EditorZxtInfos[i] do begin
				TextWindowAppend(state, '!;['
					+ EditorCategoryCharacters[Ord(EditCategory) + 1]
					+ '] ' + Name);
			end;
			TextWindowDrawOpen(state);		
			running := true;
			while running do begin
				TextWindowSelect(state, TWS_IGNORE_HYPERLINKS);
				running := false;
			end;
			TextWindowDrawClose(state);		
			TextWindowFree(state);

			if TextWindowRejected then ZxtEditorSelectType := -1
			else ZxtEditorSelectType := state.LinePos;
		end;

	procedure ZxtFlagEditorA(editable: boolean; var block: TExtensionBlock);
		var
			i, eidx: integer;
			ch: byte;
		procedure FlagToChoice(f: word);
			begin
				if f = 0 then ch := 0
				else ch := 1;
			end;
		function ChoiceToFlag(b, c: word): word;
			begin
				if ch <> 0 then ChoiceToFlag := b or c
				else ChoiceToFlag := b and (not c);
			end;
		begin
			i := 9;
			eidx := EditorZxtGetInfoForId(block.Header.Id);
			if eidx < 0 then exit;

			with EditorZxtInfos[eidx] do begin
				if (ExtToggleableFlags and FZxtExtPlayingMust) <> 0 then begin
					FlagToChoice(block.Header.Flags and FZxtExtPlayingMust);
					SidebarPromptChoice(editable,
						i, 'Req. for play?', 'No Yes', ch);
					block.Header.Flags := ChoiceToFlag(block.Header.Flags,
						FZxtExtPlayingMust);
					Inc(i, 4);
				end;
			end;
		end;

	procedure ZxtFlagEditor(var block: TExtensionBlock);
		begin
			ZxtEditorClearSidebar;
			ZxtFlagEditorA(false, block);
			ZxtFlagEditorA(true, block);
			ZxtEditorDrawSidebar;
		end;

	procedure ZxtEditorEdit(var block: TExtensionBlock);
		begin
			ZxtEditorClearSidebar;
			case block.ExtType of
				ExtMaxStatCount: begin
					ZxtMaxStatCountEditor(false, block);
					ZxtMaxStatCountEditor(true, block);
				end;
			end;
			ZxtEditorDrawSidebar;
		end;

	procedure ZxtEditorEditSelected;
		begin
			if selEntry > ZxtBlockGetCount then exit;
			ZxtEditorEdit(ZxtBlockGet(selEntry)^);
			ZxtEditorDrawEntries;
		end;

	procedure ZxtEditorEditSelectedFlags;
		begin
			if selEntry > ZxtBlockGetCount then exit;
			ZxtFlagEditor(ZxtBlockGet(selEntry)^);
			ZxtEditorDrawEntries;
		end;

	procedure ZxtEditorInsertNew;
		var
			i: integer;
			block: TExtensionBlock;
		label InsertFinished;
		begin
			i := ZxtEditorSelectType;
			if i < 0 then exit;

			with EditorZxtInfos[i] do begin
				block.ExtType := EditorZxtInfos[i].ExtType;
				if (ZxtBlockGetCountByType(block.ExtType) > 0)
				and ((EditFlags and EDITOR_ZXT_ALLOW_MULTIPLE) = 0) then begin
					selEntry := ZxtBlockGetIdByType(block.ExtType, 0);
					goto InsertFinished;
				end;
				ZxtGetExtId(ExtType, block.Header.Id);

				block.Header.Flags := (
					ExtAllowedFlags and ((not ExtToggleableFlags)
						or TOGGLEABLE_FLAGS_DEFAULTS)
				);
				block.Header.FieldLength := 0;
				block.Data := nil;
			end;
			EditorZxtUnloadAll;
			ZxtFlagEditor(block);
			ZxtEditorEdit(block);
			i := ZxtBlockAppend(ZXT_APPEND_END, block);
			EditorZxtLoadAll;

		InsertFinished:
			ZxtEditorDrawEntries;
		end;

	procedure ZxtEditorDelete;
		begin
			if selEntry > ZxtBlockGetCount then exit;
			if not SidebarPromptYesNo('Are you sure?  ', false) then exit;
				
			EditorZxtUnloadAll;
			ZxtBlockRemove(selEntry, true);
			EditorZxtLoadAll;
			ZxtEditorDrawEntries;
		end;

	procedure ZxtEditorMove(from, fto: integer);
		var
			block: TExtensionBlock;
		begin
			if from < 1 then from := 1;
			if fto < 1 then fto := 1;
			if from > ZxtBlockGetCount then from := ZxtBlockGetCount;
			if fto > ZxtBlockGetCount then fto := ZxtBlockGetCount;
			if from = fto then exit;

			EditorZxtUnloadAll;
			block := ZxtBlockGet(from)^;
			ZxtBlockRemove(from, false);
			Dec(fto);
			ZxtBlockAppend(fto, block);
			EditorZxtLoadAll;
		end;

	begin
		selEntry := 1;

		ZxtEditorDrawSidebar;
		ZxtEditorDrawBackground;
		ZxtEditorDrawEntries;

		repeat
			InputReadWaitKey;
			case UpCase(InputKeyPressed) of
				KEY_UP: begin
					if selEntry > 1 then
						Dec(selEntry);
					ZxtEditorDrawEntries;
				end;
				KEY_DOWN: begin
					if selEntry <= ZxtBlockGetCount then
						Inc(selEntry);
					ZxtEditorDrawEntries;
				end;
				KEY_PAGE_UP: begin
					if (selEntry > 1) and (selEntry <= ZxtBlockGetCount) then begin
						ZxtEditorMove(selEntry, selEntry - 1);
						Dec(selEntry);
						ZxtEditorDrawEntries;
					end;
				end;
				KEY_PAGE_DOWN: begin
					if selEntry < ZxtBlockGetCount then begin
						ZxtEditorMove(selEntry, selEntry + 1);
						Inc(selEntry);
						ZxtEditorDrawEntries;
					end;
				end;
				KEY_DELETE: ZxtEditorDelete;
				KEY_ENTER: ZxtEditorEditSelected;
				'F': ZxtEditorEditSelectedFlags;
				'N': ZxtEditorInsertNew;
				'H': begin
					TextWindowDisplayFile('zxtedit.hlp', 'ZXT editor help');
				end;
				'I': if selEntry <= ZxtBlockGetCount then begin
					i := EditorZxtGetInfoForId(ZxtBlockGet(selEntry)^.Header.Id);
					if i >= 0 then begin
						TextWindowDisplayFileLabel('zxtedit.hlp',
							OopStringToWord(EditorZxtInfos[i].Name),
							'ZXT editor help');
					end;
				end;
			end;
		until (InputKeyPressed = KEY_ESCAPE) or (UpCase(InputKeyPressed) = 'Q');

		ZxtEditorRun := true;		
	end;

end.
