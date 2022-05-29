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
			EditorZxtCategoryQuirk
		);
		TEditorZxtInfo = record
			ExtType: TExtensionType;
			ExtFlags: word;
			EditCategory: TEditorZxtCategory;
			EditFlags: word;
			Name: string[28];
		end;
	function ZxtEditorRun: boolean;

implementation
uses Dos, FileSel, ZVideo, ZInput, TimerSys, Sidebar, Oop;

{ START YOUR EDITS HERE }

const
	HEX_DIGITS = '0123456789ABCDEF';
	EditorCategoryCharacters = 'FOQ';
	HEADER_BAR_Y = 0;
	EDITOR_ZXT_INFOS_COUNT = 14
	{$IFNDEF E_SUPERZ} + 2 {$ENDIF}
		;
	EditorZxtInfos: array[1 .. EDITOR_ZXT_INFOS_COUNT] of TEditorZxtInfo =
	(
		(
			ExtType: ExtUnlockExtensions;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: '#IFEXT'
		),
		(
			ExtType: ExtFixPutBottomRow;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: '#PUT on bottom row'
		),
		(
			ExtType: ExtFixBlinkWallShift;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Blink wall shift to left'
		),
{$IFNDEF E_SUPERZ}
		(
			ExtType: ExtFixBoardEdgeTouch;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Board edge touch direction'
		),
{$ENDIF}
		(
			ExtType: ExtFixConveyorStatSwapping;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Conveyor stat swapping'
		),
		(
			ExtType: ExtFixConveyorStatCheck;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Conveyor statless movement'
		),
		(
			ExtType: ExtFixConveyorMissingFinalDraw;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Conveyor visual bugs'
		),
		(
			ExtType: ExtFixKoopoBug;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Duplicator "Koopo" bug'
		),
		(
			ExtType: ExtFixBindDoubleFree;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Nested #BIND calls'
		),
		(
			ExtType: ExtFixRecursiveElementPush;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryFix;
			EditFlags: 0;
			Name: 'Recursive element push'
		),
		(
			ExtType: ExtGMDirByAt;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: 'BY/AT directions'
		),
{$IFNDEF E_SUPERZ}
		(
			ExtType: ExtSuperzEnter;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: ':ENTER'
		),
{$ENDIF}
		(
			ExtType: ExtDieItem;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: '#DIE ITEM'
		),
		(
			ExtType: ExtDieUnderTile;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: '#DIE preserves tile under'
		),
		(
			ExtType: ExtIfRnd;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			EditCategory: EditorZxtCategoryOop;
			EditFlags: 0;
			Name: '#IF RND'
		),
		(
			ExtType: ExtQuirkArgTile2;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
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
			ix, iy: integer;
		begin
			for iy := 0 to 24 do begin
				SidebarClearLine(iy);
				ZxtEditorClearLine(iy, $FF);
			end;

			VideoWriteText(4, HEADER_BAR_Y, $0F, 'I.D.');
			VideoWriteText(13, HEADER_BAR_Y, $07, #179);
			VideoWriteText(14 + 13, HEADER_BAR_Y, $0F, 'NAME');
			VideoWriteText(14 + 31, HEADER_BAR_Y, $07, #179);
			VideoWriteText(46 + 1, HEADER_BAR_Y, $0F, 'FLAGS');
			VideoWriteText(46 + 7, HEADER_BAR_Y, $07, #179);
			VideoWriteText(54 + 1, HEADER_BAR_Y, $0F, 'LEN.');

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

			VideoWriteText(VideoSidebarX + 1, 15, $70, ' Esc ');
			VideoWriteText(VideoSidebarX + 6, 15, $1F, ' Exit');
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
			ofs := selEntry - 12;
			if ofs <= 1 then ofs := 1
			else if ofs > (ZxtBlockGetCount - 23) then ofs := ZxtBlockGetCount - 23;

			for i := 1 to 24 do
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

	procedure ZxtEditorInsertNew;
		var
			i: integer;
			block: TExtensionBlock;
		begin
			i := ZxtEditorSelectType;
			if i < 0 then exit;

			EditorZxtUnloadAll;
			with EditorZxtInfos[i] do begin
				block.ExtType := EditorZxtInfos[i].ExtType;
				ZxtGetExtId(ExtType, block.Header.Id);
				block.Header.Flags := (block.Header.Flags and $EF) or $40;
				block.Data := nil;
			end;
			i := ZxtBlockAppend(ZXT_APPEND_END, block);
			EditorZxtLoadAll;
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

		ZxtEditorRun := false;		
	end;

end.
