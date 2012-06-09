/* Copyright 2001 Kjetil S. Matheussen

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA. */




struct Tracker_Windows *getWindowFromNum(int windownum);


struct WBlocks *getWBlockFromNum(int windownum,int wblocknum);


struct WBlocks *getWBlockFromNumA(
	int windownum,
	struct Tracker_Windows **window,
	int blocknum
);

struct Blocks *getBlockFromNum(int blocknum);

struct Tracks *getTrackFromNum(int blocknum,int tracknum);

struct WTracks *getWTrackFromNum(
	int windownum,
	int blocknum,
	int wtracknum
);


struct WTracks *getWTrackFromNumA(
	int windownum,
	struct Tracker_Windows **window,
	int wblocknum,
	struct WBlocks **wblock,
	int wtracknum
);

struct Notes *getNoteFromNum(int blocknum,int tracknum,int notenum);

struct Notes *getNoteFromNumA(int windownum,int blocknum,int tracknum,int notenum);

int getInstrumentPatchNum(int instrument_num, int patch_num);
struct Instruments *getInstrumentFromNum(int instrument_num);
struct Patch *getPatchFromNum(int instrument_patch_num);
