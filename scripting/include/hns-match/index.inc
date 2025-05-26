#if defined _index_included
  #endinput
#endif

#define _index_included

#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta_util>
#include <reapi>
#include <json>
#include <PersistentDataStorage>

#include <hns_matchsystem_pts.inc>
#include <hns_matchsystem_bans.inc>

#include <hns-match/globals>

#include <hns-match/gameplay/gameplays.inc>
#include <hns-match/modes/modes.inc>

#include <hns-match/addition/cvars>
#include <hns-match/utils>
#include <hns-match/user>
#include <hns-match/save>
#include <hns-match/natives>

#include <hns-match/gameplay/gameplay_hns.inc>
#include <hns-match/gameplay/gameplay_knife.inc>
#include <hns-match/gameplay/gameplay_training.inc>

#include <hns-match/modes/mode_training.inl>
#include <hns-match/modes/mode_pub.inl>
#include <hns-match/modes/mode_dm.inl>
#include <hns-match/modes/mode_zombie.inl>
#include <hns-match/modes/mode_mix.inl>
#include <hns-match/modes/mode_manager.inl>

#include <hns-match/addition/cmds>
#include <hns-match/addition/afk>
#include <hns-match/addition/surrender>
#include <hns-match/addition/captain>
#include <hns-match/modes/mode_knife.inl>
#include <hns-match/addition/hnsmenu>