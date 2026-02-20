#if defined _hns_matchsystem_api_included
	#endinput
#endif
#define _hns_matchsystem_api_included

/**
* Returns API stats module init state.
*
* @return		1 if API stats module is available, otherwise 0
*/
native hns_api_stats_init();

// native hns_api_stats_place(id, GET_SITE_STATS_TYPES:eType);

/**
* Returns player rating from API stats module.
*
* @param id	Client index
*
* @return		Player rating
*/
native Float:hns_api_stats_rating(id);

/**
* Returns player rank/skill label from API stats module.
*
* @param id	Client index
* @param szLen	Output buffer
* @param ilen	Output buffer size
*
* @noreturn
*/
native hns_api_stats_rank(id, szLen[10], ilen);
