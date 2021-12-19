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
uses Dos, ZVideo, Input;

{ START YOUR EDITS HERE }

const
	FZxtEditorCustomAdd = $8000;
	EDITOR_ZXT_INFOS_COUNT = 1;
	EditorZxtInfos: array[1 .. EDITOR_ZXT_INFOS_COUNT] of TEditorZxtInfo =
		(
			(ExtType: ExtUnlockExtensions;
			ExtFlags: FZxtExtPlayingShould or FZxtExtPlayingMust;
			Name: 'OOP: #IFEXT')
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

function ZxtEditorOpenHyperlink(var state: TTextWindowState; var extBlock: TExtensionBlock; extType: TExtensionType): boolean;
	begin
		ZxtEditorOpenHyperlink := false;
		{ if extType = ExtWithHyperlink then ... }
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
