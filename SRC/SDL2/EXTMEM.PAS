{
	Copyright (c) 2020 Alan Williams

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
unit ExtMem;

interface
	type
		TExtMemType = (NoMem, Conv);
		TExtMemBlockPtr = ^TExtMemBlock;
		TExtMemBlock = record
			case MemType: TExtMemType of
				Conv: (Ptr: pointer);
				NoMem: ();
		end;
	procedure ExtMemInstall(useEms: boolean; useXms: boolean);
	function ExtMemGet(var block: TExtMemBlock; size: word): boolean;
	procedure ExtMemWrite(var block: TExtMemBlock; var data; count: word);
	procedure ExtMemRead(var block: TExtMemBlock; var data; count: word);
	procedure ExtMemFree(var block: TExtMemBlock; size: word);
	procedure ExtMemUninstall;

implementation

function ExtMemGet(var block: TExtMemBlock; size: word): boolean;
	begin
		if size = 0 then begin
			block.MemType := NoMem;
			exit;
		end;

		ReturnNilIfGrowHeapfails := true;

		GetMem(block.Ptr, size);
		if block.Ptr <> nil then
			block.MemType := Conv
		else
			block.MemType := NoMem;

		ReturnNilIfGrowHeapfails := false;
	end;

procedure ExtMemWrite(var block: TExtMemBlock; var data; count: word);
	begin
		if count = 0 then exit;
		if block.MemType <> Conv then RunError(204);
		Move(data, block.Ptr^, count);
	end;

procedure ExtMemRead(var block: TExtMemBlock; var data; count: word);
	begin
		if count = 0 then exit;
		if block.MemType <> Conv then RunError(204);
		Move(block.Ptr^, data, count);
	end;

procedure ExtMemFree(var block: TExtMemBlock; size: word);
	begin
		if block.MemType = Conv then
			FreeMem(block.Ptr, size);
		block.MemType := NoMem;
	end;

procedure ExtMemInstall(useEms: boolean; useXms: boolean);
	begin
		ReturnNilIfGrowHeapfails := false;
	end;

procedure ExtMemUninstall;
	begin
	end;

begin
end.
