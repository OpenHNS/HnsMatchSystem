#if defined _hns_matchsystem_stats_included
	#endinput
#endif
#define _hns_matchsystem_stats_included

enum _:TYPE_STATS
{
	STATS_ROUND = 0,
	STATS_ALL = 1
}

/**
* Gets players kills while playing CT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_kills(type, id);

/**
* Gets players deaths while playing CT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_deaths(type, id);

/**
* Gets players assists while playing CT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_assists(type, id);

/**
* Gets players stabs while playing CT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_stabs(type, id);

/**
* Gets knife stab attempts by CT.
* Counted on primary/secondary knife attack event when at least one alive TT
* is within 80 units.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_stabs_attempt(type, id);

/**
* Gets fall damage received while playing CT.
* Damage per fall is capped at 100.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_falldmg_ct(type, id);

/**
* Gets fall damage received while playing TT.
* Damage per fall is capped at 100.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return damage TT num
*/
native hns_get_stats_falldmg_tt(type, id);

/**
* Gets knife damage dealt by CT (damage per hit capped at 100).
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_damage(type, id);

/**
* Gets number of CTs blinded by TT (per blind event).
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_flashcount(type, id);

/**
* Gets number of flashbang throws by TT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_flash(type, id);

/**
* Gets number of flashbang fails by TT (flash exploded without blinding any CT).
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_flashfail(type, id);

/**
* Gets total time (seconds) of CTs blinded by TT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_flashtime(type, id);

/**
* Gets time (seconds) when player was the only alive TT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_last_tt_time(type, id);

/**
* Gets first kills by CT (first CT kill in a round).
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_fk(type, id);

/**
* Gets first deaths of TT (first TT death in a round).
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_fd(type, id);

/**
* Gets number of CT rounds with 1 kill.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_mk1(type, id);

/**
* Gets number of CT rounds with 2 kills.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_mk2(type, id);

/**
* Gets number of CT rounds with 3 kills.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_mk3(type, id);

/**
* Gets number of CT rounds with 4 kills.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_mk4(type, id);

/**
* Gets number of CT rounds with 5+ kills.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_mk5(type, id);


/**
* Gets players play time. (How many seconds the player was in the active game)
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_playtime(type, id);

/**
* Gets number of rounds player was TT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_tt_rounds(type, id);

/**
* Gets number of rounds player was CT.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_ct_rounds(type, id);

/**
* Gets number of confirmed spotted rounds.
* A round is confirmed if TT had visible contact with CT for 2 continuous seconds
* after 5 seconds from freeze end, within height delta limit and 700 units distance.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_spotted_rounds(type, id);

/**
* Gets total survive time (seconds) in rounds where spotted contact was confirmed.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_spotted_survived_time(type, id);

/**
* Gets players survive time.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_surv(type, id);

/**
* Gets players ownages.
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_ownages(type, id);


/**
* Get the number of bhops in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_bhop_count(type, id);

/**
* Get the percentage of perfect bhops in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_bhop_percent(type, id);

/**
* Get the number of sgs in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_sgs_count(type, id);

/**
* Get the percentage of perfect sgs in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_sgs_percent(type, id);

/**
* Get the number of ddrun in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return num
*/
native hns_get_stats_ddrun_count(type, id);

/**
* Get the percentage of perfect ddrun in sessions
*
* @param type Stats type: TYPE_STATS
* @param id Client index
*
* @return float
*/
native Float:hns_get_stats_ddrun_percent(type, id);

/**
* Called when round/match stats should be applied.
*
* @param iIsEndMatch	Non-zero value if match is finished
*
* @noreturn
*/
forward hns_apply_stats(iIsEndMatch);

/**
* Called when player leaves active match and stats should be saved.
*
* @param id		Player index
* @param iTeam		Player team (TeamName)
*
* @noreturn
*/
forward hns_save_leave_stats(id, TeamName:iTeam);
