/* Copyright 2000 Kjetil S. Matheussen

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








#include "nsmtracker.h"
#include "windows_proc.h"
#include "clipboard_track_paste_proc.h"
#include "clipboard_localzooms_proc.h"
#include "clipboard_tempos_copy_proc.h"
#include "reallines_proc.h"
#include "wblocks_proc.h"
#include <string.h>
#include "block_properties_proc.h"
#include "time_proc.h"
#include "list_proc.h"
#include "undo_blocks_proc.h"
#include "player_proc.h"
#include "player_pause_proc.h"
#include "OS_Bs_edit_proc.h"
#include "Beats_proc.h"

#include "clipboard_block_paste_proc.h"


extern struct WBlocks *cb_wblock;


/* Note, 'wblock' MUST have been generated by CB_CopyBlock.
   Note 2: Fixed. (can be copied from a normal wblock)
*/

void CB_PasteBlock(
	struct Tracker_Windows *window,
	struct WBlocks *wblock,
	struct WBlocks *towblock
){

	struct Blocks *block=wblock->block;
	struct Blocks *toblock=towblock->block;
	struct WTracks *towtrack=towblock->wtracks;
	struct WTracks *towtrack_wtrack=towblock->wtrack;
	struct Tracks *totrack=toblock->tracks;
	struct WTracks *wtrack;

	NInt wblocknum=towblock->l.num;
	struct ListHeader1 *nextwblock=towblock->l.next;

	NInt blocknum=toblock->l.num;
	struct ListHeader1 *nextblock=toblock->l.next;

        unsigned int org_color = toblock->color;
          
	NInt org_num_tracks=toblock->num_tracks;

	memcpy(towblock,wblock,sizeof(struct WBlocks));
	memcpy(toblock,block,sizeof(struct Blocks));

        toblock->color = org_color; // Don't want to paste color.
        
	towblock->l.next=nextwblock;
	towblock->l.num=wblocknum;

	towblock->block=toblock;
	towblock->wtracks=towtrack;
	towblock->wtrack=towtrack_wtrack;
	toblock->tracks=totrack;

	toblock->l.next=nextblock;
	toblock->l.num=blocknum;

        //printf("org num_tracks: %d, before: %d\n",org_num_tracks,toblock->num_tracks);

	toblock->num_tracks=org_num_tracks;

	Block_Set_num_tracks(toblock,block->num_tracks);

	toblock->name=talloc_atomic((int)strlen(block->name)+1);
	memcpy(toblock->name,block->name,(int)strlen(block->name)+1);

	towblock->localzooms=NULL;
	CB_UnpackLocalZooms(&towblock->localzooms,wblock->localzooms,block->num_lines);
	towblock->reallines=NULL;
	UpdateRealLines(window,towblock);

	//towblock->wtempos=NULL;
	//towblock->wlpbs=NULL;

        toblock->swings=CB_CopySwings(block->swings, NULL);
        toblock->signatures=CB_CopySignatures(block->signatures);
	toblock->lpbs=CB_CopyLPBs(block->lpbs);

	toblock->tempos=CB_CopyTempos(block->tempos);
	toblock->temponodes=CB_CopyTempoNodes(block->temponodes);
	toblock->lasttemponode=(struct TempoNodes *)ListLast3(&toblock->temponodes->l);

        TIME_everything_in_block_has_changed(towblock->block, root->tempo, root->lpb, root->signature);
        
	UpdateReallinesDependens(window,towblock);

	wtrack=wblock->wtracks;
	towtrack=towblock->wtracks;
	while(wtrack!=NULL){
		if(towtrack==NULL){
			RError("Error in funtion CB_PasteBlock in file clipboard_block_paste.c; towtrack=NULL\n");
			break;
		}
		if(towtrack->l.num!=wtrack->l.num){
			RError("Error in funtion CB_PasteBlock in file clipboard_block_paste.c; towtrack->l.num!=wtrack->l.num\n");
			break;
		}

		co_CB_PasteTrack(towblock,wtrack,towtrack);
		towtrack=NextWTrack(towtrack);
		wtrack=NextWTrack(wtrack);
	}

	if(towtrack!=NULL){
		RError("Error in funtion CB_PasteBlock in file clipboard_block_paste.c; towtrack!=NULL when wtrack==NULL\n");
	}

	BS_UpdateBlockList();
	BS_UpdatePlayList();
}
	

void CB_PasteBlock_CurrPos(
	struct Tracker_Windows *window
){
	if(cb_wblock==NULL) return;

        PC_Pause();{

          ADD_UNDO(Block_CurrPos(window));

          CB_PasteBlock(window,cb_wblock,window->wblock);
          SelectWBlock(window,window->wblock);
          
        }PC_StopPause(window);
}




