{
	Copyright (c) 2021 Adrian Siekierka

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
		TEditorZxtHyperlinkFunc = function(var state: TTextWindowState): boolean;
		TEditorZxtInfo = record
			ExtType: TExtensionType;
			ExtFlags: word;
			Name: string[36];
			HasHyperlink: boolean;
		end;
	{ Returns true if the ZXT header was modified. }
	function ZxtEditorOpenSettings(var state: TTextWindowState): boolean;
	function ZxtEditorOpenHyperlink(var state: TTextWindowState; var extBlock: TExtensionBlock; extType: TExtensionType): boolean;

implementation
uses Dos, FileSel, ZVideo, ZInput;

{ START YOUR EDITS HERE }

const
	FZxtEditorCustomAdd = $8000;
{$IFDEF NEC98}
	EDITOR_ZXT_INFOS_COUNT = 17;
{$ELSE}
	EDITOR_ZXT_INFOS_COUNT = 18;
{$ENDIF}
	EditorZxtInfos: array[1 .. EDITOR_ZXT_INFOS_COUNT] of TEditorZxtInfo =
		(
			(ExtType: ExtFixPutBottomRow;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'FIX: #PUT on bottom row'),
			(ExtType: ExtFixBlinkWallShift;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'FIX: Blink wall shift to left'),
			(ExtType: ExtFixBoardEdgeTouch;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'FIX: Board edge touch direction'),
			(ExtType: ExtFixConveyorStatSwapping;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'FIX: Conveyor stat swapping'),
			(ExtType: ExtFixConveyorStatCheck;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'FIX: Conveyor statless movement'),
			(ExtType: ExtFixConveyorMissingFinalDraw;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'FIX: Conveyor visual bug'),
			(ExtType: ExtFixKoopoBug;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'FIX: Duplicator "Koopo" bug'),
			(ExtType: ExtFixBindDoubleFree;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'FIX: Nested #BIND calls'),
			(ExtType: ExtFixRecursiveElementPush;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'FIX: Recursive element push'),
{$IFNDEF NEC98}
			(ExtType: ExtZZOCustomCharset;
			ExtFlags: FZxtExtPlayingShould or FZxtEditorCustomAdd;
			Name: 'GFX: Custom character set';
			HasHyperlink: true),
{$ENDIF}
			(ExtType: ExtGMDirByAt;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'OOP: BY/AT directions'),
			(ExtType: ExtSuperzEnter;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'OOP: :ENTER'),
			(ExtType: ExtDieItem;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'OOP: #DIE ITEM'),
			(ExtType: ExtDieUnderTile;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'OOP: #DIE preserves tile under'),
			(ExtType: ExtIfRnd;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'OOP: #IF RND'),
			(ExtType: ExtUnlockExtensions;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'OOP: #IFEXT'),
			(ExtType: ExtGMPutPlayer;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'OOP: #PUTPLAYER'),
			(ExtType: ExtQuirkArgTile2;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'QUIRK: World uses argTile2 trick')
		);

{ END YOUR EDITS HERE }

procedure EditorZxtFree(var extBlock: TExtensionBlock);
	begin
		with extBlock do begin
			if Header.FieldLength > 0 then
				FreeMem(Data, Header.FieldLength);
		end;
	end;

procedure EditorZxtUnloadFreeRemove(i: word);
	var
		extBlockO: PTExtensionBlock;
	begin
		extBlockO := ZxtBlockGet(i);
		if ZxtBlockUnload(i) <> ExtResultSuccess then begin end;
		EditorZxtFree(extBlockO^);
		ZxtBlockRemove(i);
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

{ START YOUR EDITS HERE }

{$IFNDEF NEC98}
function EditZZOCharsetSettings(var state: TTextWIndowState; var extBlock: TExtensionBlock): boolean;
	var
		i: integer;
		filename: string;
	begin
		i := 0;
		filename := FileSelect('Load character set', '.CHR', i);
		if Length(filename) <> 0 then begin
			i := 0;
			extBlock.Header.FieldLength := FileReadAll(filename + '.CHR', extBlock.Data, 256 * 14);
			if extBlock.Header.FieldLength = 256 * 14 then begin
				if VideoSetCharset(extBlock.Data, 14) then begin
					if ZxtBlockAppend(ZXT_APPEND_END, extBlock) then begin
						i := 1;
					end;
				end;
			end;
			if i = 0 then EditorZxtFree(extBlock);
		end else begin
			EditorZxtUnloadFreeRemoveByType(extBlock.ExtType);
		end;
	end;
{$ENDIF}

function ZxtEditorOpenHyperlink(var state: TTextWindowState; var extBlock: TExtensionBlock; extType: TExtensionType): boolean;
	begin
		ZxtEditorOpenHyperlink := false;
{$IFNDEF NEC98}
		if extType = ExtZZOCustomCharset then
			ZxtEditorOpenHyperlink := EditZZOCharsetSettings(state, extBlock);
{$ENDIF}			
	end;

{ END YOUR EDITS HERE }

function ZxtEditorOpenSettings(var state: TTextWindowState): boolean;
	var
		i: integer;
		iPos: integer;
		extBlock: TExtensionBlock;
		extBlockO: PTExtensionBlock;
		tmpPtr: pointer;
		exitRequested: boolean;
		posToEditorInfo: array[1 .. (EDITOR_ZXT_INFOS_COUNT*2)] of byte;
	procedure AppendInfoLine;
		begin
			Inc(iPos);
			New(state.Lines[iPos]);
			posToEditorInfo[iPos] := i;
		end;
	begin
		ZxtEditorOpenSettings := false;

		state.Title := 'Extension Settings';
		state.LinePos := 1;
		exitRequested := false;
			repeat
			state.Selectable := true;
			iPos := 0;
			for i := 1 to EDITOR_ZXT_INFOS_COUNT do begin
				AppendInfoLine;
				with EditorZxtInfos[i] do begin
					if ExtensionEnabled[ExtType] then begin
						extBlockO := ZxtBlockGetByType(ExtType, 0);
						if (extBlockO^.Header.Flags and $1F) = $08 then
							state.Lines[iPos]^ := '[x] ' + Name
						else
							state.Lines[iPos]^ := '[X] ' + Name;
					end else
						state.Lines[iPos]^ := '[ ] ' + Name;
					if HasHyperlink then begin
						AppendInfoLine;
						state.Lines[iPos]^ := '!c;Configure';
					end;
				end;
			end;
			AppendInfoLine;
			state.Lines[iPos]^ := '!;Exit';
			state.LineCount := iPos;
			TextWindowSelect(state, TWS_HYPERLINK_AS_SELECT);
			if (InputKeyPressed = KEY_ENTER) and (state.LinePos <> state.LineCount) then begin
				with EditorZxtInfos[posToEditorInfo[state.LinePos]] do begin
					{ Prepare extBlock }
					extBlock.ExtType := ExtType;
					ZxtGetExtId(ExtType, extBlock.Header.Id);
					extBlock.Header.Flags := (ExtFlags and $EF) or $40;

					if state.Hyperlink = 'c' then begin
						if ZxtEditorOpenHyperlink(state, extBlock, ExtType) then
							ZxtEditorOpenSettings := true;
					end else case state.Lines[state.LinePos]^[2] of
						{ [ ] -> [x] -> [X] -> [ ] }
						' ': if (ExtFlags and FZxtEditorCustomAdd) = 0 then begin
							extBlock.Header.FieldLength := 0;
							if ZxtBlockAppend(ZXT_APPEND_END, extBlock) then begin
								ZxtEditorOpenSettings := true;
							end;
						end;
						'x': if (ExtFlags and $10) <> 0 then begin 
							if ZxtBlockGetCountByType(ExtType) = 1 then begin
								extBlockO := ZxtBlockGetByType(ExtType, 0);
								extBlockO^.Header.Flags := ExtFlags;
								ZxtEditorOpenSettings := true;
							end;
						end else begin
							EditorZxtUnloadFreeRemoveByType(ExtType);
							ZxtEditorOpenSettings := true;
						end;
						'X': begin
							EditorZxtUnloadFreeRemoveByType(ExtType);
							ZxtEditorOpenSettings := true;
						end;
					end;
				end;
			end else begin
				exitRequested := true;
				TextWindowDrawClose(state);
			end;

			TextWindowFree(state);
		until exitRequested;
	end;

end.
