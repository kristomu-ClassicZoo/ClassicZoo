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
unit GameIo;

interface
	uses GameVars;
	{ Ensures IoTmpBuf is at least [newSize] bytes. }
	{ Returns: 1 if IoTmpBuf was wiped, 2 if the size is too large. }
	function EnsureIoTmpBufSize(newSize: word): integer;
	function BoardCurrentStorageSize: longint;
	procedure BoardClose;
	procedure BoardOpen(boardId: integer);

implementation
uses
{$IFDEF DEBUGWND}
DebugWnd,
{$ENDIF}
{$IFNDEF RAWMEM}
GameVSer,
{$ENDIF}
GameSh, ExtMem;

function EnsureIoTmpBufSize(newSize: word): integer;
	var
		oldSize: word;
	begin
		if newSize > IO_BUFFER_MAXIMUM_SIZE then begin
			EnsureIoTmpBufSize := 2;
			exit;
		end;
		oldSize := IoTmpBufSize;
		EnsureIoTmpBufSize := 0;
		while IoTmpBufSize < newSize do
			Inc(IoTmpBufSize, IO_BUFFER_SIZE_INCREMENT);
		if oldSize <> IoTmpBufSize then begin
			FreeMem(IoTmpBuf, oldSize);
			GetMem(IoTmpBuf, IoTmpBufSize);
			EnsureIoTmpBufSize := 1;
		end;
	end;

procedure BoardWriteRle(var ptr: pointer);
	var
		ix, iy: integer;
		rle: TRleTile;
	begin
		ix := 1;
		iy := 1;
		rle.Count := 1;
		rle.Tile := Board.Tiles[ix][iy];
		repeat
			Inc(ix);
			if ix > BOARD_WIDTH then begin
				ix := 1;
				Inc(iy);
			end;
			if (Board.Tiles[ix][iy].Color = rle.Tile.Color) and
				(Board.Tiles[ix][iy].Element = rle.Tile.Element) and
				(rle.Count < 255) and (iy <= BOARD_HEIGHT) then
			begin
				Inc(rle.Count);
			end else begin
				Move(rle, ptr^, SizeOf(rle));
				AdvancePointer(ptr, SizeOf(rle));
				rle.Tile := Board.Tiles[ix][iy];
				rle.Count := 1;
			end;
		until iy > BOARD_HEIGHT;
	end;

function BoardCurrentStorageSize: longint;
	var
		ix, iy: word;
		iz: boolean;
		isize: longint;
		ptr: pointer;
	label StatFound;
	begin
		ptr := IoTmpBuf;
		BoardWriteRle(ptr);

		{ We will always have enough size to store the above in the default IoTmpBuf. }
		{ From here, do size estimation. }
{$IFDEF FPC}
		isize := Word(ptr - IoTmpBuf)
{$ELSE}
		isize := (Ofs(ptr^) - Ofs(IoTmpBuf^))
{$ENDIF}
			 + ((Board.StatCount + 1) * STAT_SIZE_BYTES)
			+ SizeOf(Board.Name) + BOARD_INFO_BYTES + 2 { StatCount };

		for ix := 0 to Board.StatCount do begin
			with Board.Stats[ix] do begin
				if DataLen > 0 then begin
					iz := false;
					for iy := 1 to (ix - 1) do begin
						if Board.Stats[iy].Data = Data then begin
							iz := true;
							goto StatFound;
						end;
					end;
StatFound:
					if not iz then
						Inc(isize, DataLen);
				end;
			end;
		end;

		BoardCurrentStorageSize := isize;
	end;

procedure BoardClose;
	var
		ix, iy: integer;
		isize: word;
		ptr: pointer;
	label RestartWrite;
	begin
		{ Bind stats early. }
		for ix := 0 to Board.StatCount do begin
			with Board.Stats[ix] do begin
				if DataLen > 0 then begin
					for iy := 1 to (ix - 1) do begin
						if Board.Stats[iy].Data = Data then
							DataLen := -iy;
					end;
				end;
			end;
		end;

	RestartWrite:
		ptr := IoTmpBuf;

		Move(Board.Name, ptr^, SizeOf(Board.Name));
		AdvancePointer(ptr, SizeOf(Board.Name));

		BoardWriteRle(ptr);

{$IFDEF RAWMEM}
		Move(Board.Info, ptr^, SizeOf(Board.Info));
		AdvancePointer(ptr, SizeOf(Board.Info));
{$ELSE}
		CopyBoardInfoFromLocal(ptr);
{$ENDIF}

{$IFDEF ENDIAN_BIG}
		Board.StatCount := NtoLE(Board.StatCount);
{$ENDIF}
		Move(Board.StatCount, ptr^, SizeOf(Board.StatCount));
		AdvancePointer(ptr, SizeOf(Board.StatCount));
{$IFDEF ENDIAN_BIG}
		Board.StatCount := LEtoN(Board.StatCount);
{$ENDIF}

		{ We will always have enough size to store the above in the default IoTmpBuf. }
		{ From here, do size estimation. }
{$IFDEF FPC}
		isize := Word(ptr - IoTmpBuf)
{$ELSE}
		isize := (Ofs(ptr^) - Ofs(IoTmpBuf^))
{$ENDIF}
			+ ((Board.StatCount + 1) * STAT_SIZE_BYTES);

		for ix := 0 to Board.StatCount do begin
			with Board.Stats[ix] do begin
				if DataLen > 0 then
					Inc(isize, DataLen);
			end;
		end;

		case EnsureIoTmpBufSize(isize) of
			0: begin end; { We good. }
			1: goto RestartWrite; { Not so good. }
			2: RunError(203);
		end;

{$IFDEF DEBUGWND}
		if DebugCompatEnabled and (isize > ZZT_32_BOARD_MAX_SIZE) then
			DebugShowSizeTooLarge(ZZT_32_BOARD_MAX_SIZE, isize, World.Info.CurrentBoard,
				'Board', 'is above the vanilla ZZT limit!');
{$ENDIF}

		for ix := 0 to Board.StatCount do begin
			with Board.Stats[ix] do begin
{$IFDEF RAWMEM}
				Move(Board.Stats[ix], ptr^, STAT_SIZE_BYTES);
				AdvancePointer(ptr, STAT_SIZE_BYTES);
{$ELSE}
				CopyStatFromLocal(ptr, Board.Stats[ix]);
{$ENDIF}
				if DataLen > 0 then begin
					Move(Data^, ptr^, DataLen);
					FreeMem(Data, DataLen);
					AdvancePointer(ptr, DataLen);
				end;
			end;
		end;

		ExtMemFree(WorldExt.BoardData[World.Info.CurrentBoard], WorldExt.BoardLen[World.Info.CurrentBoard]);
		WorldExt.BoardLen[World.Info.CurrentBoard] := Ofs(ptr^) - Ofs(IoTmpBuf^);
		if ExtMemGet(WorldExt.BoardData[World.Info.CurrentBoard], WorldExt.BoardLen[World.Info.CurrentBoard]) then begin
			ExtMemWrite(WorldExt.BoardData[World.Info.CurrentBoard], IoTmpBuf^, WorldExt.BoardLen[World.Info.CurrentBoard]);
		end else RunError(203);
	end;

procedure BoardOpen(boardId: integer);
	var
		ptr: pointer;
		ix, iy: integer;
		rle: TRleTile;
	begin
		if boardId > World.BoardCount then
			boardId := World.Info.CurrentBoard;

		case EnsureIoTmpBufSize(WorldExt.BoardLen[boardId]) of
			0, 1: begin end;
			2: RunError(203);
		end;

		ExtMemRead(WorldExt.BoardData[boardId], IoTmpBuf^, WorldExt.BoardLen[boardId]);

		ptr := IoTmpBuf;

		Move(ptr^, Board.Name, SizeOf(Board.Name));
		AdvancePointer(ptr, SizeOf(Board.Name));

		ix := 1;
		iy := 1;
		rle.Count := 0;
		repeat
			if rle.Count <= 0 then begin
				Move(ptr^, rle, SizeOf(rle));
				AdvancePointer(ptr, SizeOf(rle));
			end;
			Board.Tiles[ix][iy] := rle.Tile;
			Inc(ix);
			if ix > BOARD_WIDTH then begin
				ix := 1;
				Inc(iy);
			end;
			Dec(rle.Count);
		until iy > BOARD_HEIGHT;

{$IFDEF RAWMEM}
		Move(ptr^, Board.Info, SizeOf(Board.Info));
		AdvancePointer(ptr, SizeOf(Board.Info));
{$ELSE}
		CopyBoardInfoToLocal(ptr);
{$ENDIF}

		Move(ptr^, Board.StatCount, SizeOf(Board.StatCount));
		AdvancePointer(ptr, SizeOf(Board.StatCount));
{$IFDEF ENDIAN_BIG}
		Board.StatCount := LEtoN(Board.StatCount);
{$ENDIF}

		for ix := 0 to Board.StatCount do
			with Board.Stats[ix] do begin
{$IFDEF RAWMEM}
				Move(ptr^, Board.Stats[ix], STAT_SIZE_BYTES);
				AdvancePointer(ptr, STAT_SIZE_BYTES);
				{$IFDEF FPC} Data := Nil; {$ENDIF}
{$ELSE}
				CopyStatToLocal(ptr, Board.Stats[ix]);
{$ENDIF}
				if DataLen > 0 then begin
{ -- From Super ZZT
					if MaxAvail < DataLen then begin
						VideoClear(0);
						Writeln('Out of Memory!');
						Writeln('Mem ', MaxAvail, '..', DataLen);
						Writeln('Obj ', ix, '..', Board.StatCount);
						Writeln('Bd  ', boardId);
					end;
}
					GetMem(Data, DataLen);
					Move(ptr^, Data^, DataLen);
					AdvancePointer(ptr, DataLen);
{$IFNDEF E_SUPERZ}
				end else if DataLen < 0 then begin
					Data := Board.Stats[-DataLen].Data;
					DataLen := Board.Stats[-DataLen].DataLen;
{$ENDIF}
				end;
			end;

{$IFDEF E_SUPERZ}
		for ix := 0 to Board.StatCount do
			with Board.Stats[ix] do begin
				if DataLen < 0 then begin
					Data := Board.Stats[-DataLen].Data;
					DataLen := Board.Stats[-DataLen].DataLen;
				end;
			end;
{$ENDIF}

		World.Info.CurrentBoard := boardId;
	end;

end.
