#if defined _hns_matchsystem_stats_included
	#endinput
#endif
#define _hns_matchsystem_stats_included

enum _:TYPE_STATS
{
	STATS_ROUND = 0,
	STATS_ALL = 1
}

/*
* Gets players kills.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_kills(type, id);

/*
* Gets players deaths.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_deaths(type, id);

/*
* Gets players assists.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_assists(type, id);

/*
* Gets players stabs.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_stabs(type, id);

/*
* Gets players damage CT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_dmg_ct(type, id);

/*
* Gets players damage TT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return damage TT num
*/
native hns_get_stats_dmg_tt(type, id);


/*
* Gets players runned distance.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_runned(type, id);

/*
* Gets players runned time.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_runnedtime(type, id);

/*
* Gets players avg speed.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_avg_speed(type, id);

/*
* Gets players flash time.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_flashtime(type, id);

/*
* Gets players hide time.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_hidetime(type, id);


/*
* Gets players play time. (How many seconds the player was in the active game)
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/

native Float:hns_get_stats_playtime(type, id);
/*
* Gets players survive time.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_surv(type, id);

/*
* Gets players ownages.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_ownages(type, id);


/*
* Get the number of bhops in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_bhop_count(type, id);

/*
* Get the percentage of perfect bhops in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_bhop_percent(type, id);

/*
* Get the number of sgs in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_sgs_count(type, id);

/*
* Get the percentage of perfect sgs in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_sgs_percent(type, id);

/*
* Get the number of ddrun in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_ddrun_count(type, id);

/*
* Get the percentage of perfect ddrun in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_ddrun_percent(type, id);

forward hns_apply_stats(iIsEndMatch);

forward hns_save_leave_stats(id);