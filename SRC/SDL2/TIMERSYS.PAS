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

unit TimerSys;

interface
	type
		TIdleMode = (IMUntilPit, IMUntilFrame);
		TDrumData = record
			Len: integer;
			Data: array[1 .. 15] of word;
		end;
{$I SNDFREQ.INC}
	var
		TimerTicks: word;
	procedure AccurateDelay(ms: word);
	procedure TimerSysIdle(mode: TIdleMode);
	procedure TimerSysWake(mode: TIdleMode);
	procedure TimerSysLockTimer(mode: TIdleMode);
	procedure TimerSysUnlockTimer(mode: TIdleMode);
	procedure TimerSysLockSoundBuffer;
	procedure TimerSysUnlockSoundBuffer;
	procedure TimerSysStopSound;
	function TimerSysGetHsecs: word;
	procedure TimerSysInstall;
	procedure TimerSysUninstall;

implementation
uses AudioSim, Sounds, ZDemo, SDL2;

const
	PIT_SPEED_MS = 55;
var
	PitTimerId: TSDL_TimerID;
	TimerHsecs: word;
	SoundBufferMutex: PSDL_Mutex;
	TimerMutexes: array [Low(TIdleMode)..High(TIdleMode)] of PSDL_Mutex;
	TimerConds: array [Low(TIdleMode)..High(TIdleMode)] of PSDL_Cond;
	{ }
	AudioDevice: TSDL_AudioDeviceID;
	AudioSpec: TSDL_AudioSpec;

procedure AccurateDelay(ms: word);
	begin
		if DemoFastForward then exit;
		SDL_Delay(ms);
	end;

procedure AudioCallback(userdata: pointer; stream: PUint8; len: Int32); cdecl;
	begin
		AudioSimulate(stream, len);
	end;

procedure TimerSysIdle(mode: TIdleMode);
	begin
		if DemoFastForward then exit;
		SDL_LockMutex(TimerMutexes[mode]);
		SDL_CondWait(TimerConds[mode], TimerMutexes[mode]);
		SDL_UnlockMutex(TimerMutexes[mode]);
	end;

procedure TimerSysWake(mode: TIdleMode);
	begin
		SDL_LockMutex(TimerMutexes[mode]);
		SDL_CondBroadcast(TimerConds[mode]);
		SDL_UnlockMutex(TimerMutexes[mode]);
	end;

procedure TimerSysLockTimer(mode: TIdleMode);
	begin
		SDL_LockMutex(TimerMutexes[mode]);
	end;

procedure TimerSysUnlockTimer(mode: TIdleMode);
	begin
		SDL_UnlockMutex(TimerMutexes[mode]);
	end;

procedure TimerSysLockSoundBuffer;
	begin
		SDL_LockMutex(SoundBufferMutex);
	end;

procedure TimerSysUnlockSoundBuffer;
	begin
		if (not SoundEnabled) or (not SoundIsPlaying) then
			AudioSimulateClear;
		SDL_UnlockMutex(SoundBufferMutex);
	end;

procedure TimerSysStopSound;
	begin
		SDL_LockMutex(SoundBufferMutex);
		AudioSimulateClear;
		SDL_UnlockMutex(SoundBufferMutex);
	end;

function TimerSysGetHsecs: word;
	begin
		TimerSysGetHsecs := TimerHsecs shr 1;
	end;

function PitTimerCallback(interval: Uint32; param: Pointer): Uint32; cdecl;
	begin
		Inc(TimerTicks);
		TimerHsecs := TimerHsecs + (PIT_SPEED_MS div 5);
		AudioSimulationAllowed := SoundIsPlaying;

		DemoOnPitTick;

		TimerSysWake(IMUntilPit);
		PitTimerCallback := PIT_SPEED_MS;
	end;

procedure TimerSysInstall;
	var
		mode: TIdleMode;
		requestedAudioSpec: TSDL_AudioSpec;
	begin
		SDL_Init(SDL_INIT_VIDEO or SDL_INIT_AUDIO or SDL_INIT_TIMER);
		SDL_StartTextInput;
		PitTimerId := SDL_AddTimer(PIT_SPEED_MS, PitTimerCallback, nil);

		SoundBufferMutex := SDL_CreateMutex;
		for mode in TIdleMode do begin
			TimerMutexes[mode] := SDL_CreateMutex;
			TimerConds[mode] := SDL_CreateCond;
		end;

		requestedAudioSpec := Default(TSDL_AudioSpec);
		requestedAudioSpec.freq := 48000;
		requestedAudioSpec.format := AUDIO_U8;
		requestedAudioSpec.channels := 1;
		requestedAudioSpec.samples := 2048;
		requestedAudioSpec.callback := AudioCallback;

		AudioDevice := SDL_OpenAudioDevice(nil, 0, @requestedAudioSpec, @AudioSpec, 0);
		SDL_PauseAudioDevice(AudioDevice, 0);
	end;

procedure TimerSysUninstall;
	var
		mode: TIdleMode;
	begin
		if AudioDevice <> 0 then SDL_CloseAudioDevice(AudioDevice);

		for mode in TIdleMode do begin
			SDL_DestroyCond(TimerConds[mode]);
			SDL_DestroyMutex(TimerMutexes[mode]);
		end;
		SDL_DestroyMutex(SoundBufferMutex);

		SDL_RemoveTimer(PitTimerId);
		SDL_StopTextInput;
		SDL_Quit;
	end;

begin
	TimerTicks := 0;
	TimerHsecs := 0;
end.
