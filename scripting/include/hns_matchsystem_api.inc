#if defined _hns_matchsystem_api_included
	#endinput
#endif
#define _hns_matchsystem_api_included

native hns_api_stats_init();

// native hns_api_stats_place(id, GET_SITE_STATS_TYPES:eType);

native Float:hns_api_stats_rating(id);

native hns_api_stats_rank(id, szLen[10], ilen);