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
* @return kills num
*/
native hns_get_stats_kills(type, id);

/*
* Gets players deaths.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return deaths num
*/
native hns_get_stats_deaths(type, id);

/*
* Gets players assists.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return assists num
*/
native hns_get_stats_assists(type, id);

/*
* Gets players stabs.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return stabs num
*/
native hns_get_stats_stabs(type, id);

/*
* Gets players damage CT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return damage CT num
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
* @return runned distance float
*/
native Float:hns_get_stats_runned(type, id);

/*
* Gets players flash time.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return flash time float
*/
native Float:hns_get_stats_flashtime(type, id);

/*
* Gets players survive time.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return survive time float
*/
native Float:hns_get_stats_surv(type, id);

/*
* Gets players ownages.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return ownages num
*/
native hns_get_stats_ownages(type, id);

/*
* Gets integer all stats of a player in a match.
*
* @param type Stats type: TYPE_STATS
* @param replacementid Client index
* @param substitutiveid Client index
*
* @return full stats
*/

native hns_stats_replace(type, replacementid, substitutiveid);