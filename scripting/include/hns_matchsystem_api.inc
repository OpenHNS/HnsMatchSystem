#if defined _hns_matchsystem_api_included
	#endinput
#endif
#define _hns_matchsystem_api_included

enum GET_SITE_STATS_TYPES {
	GET_SKILL = 0,
	GET_BOOST = 1,
	GET_GOOD = 2,
}

native hns_api_stats_init();

native hns_api_stats_place(id, GET_SITE_STATS_TYPES:eType);

native hns_api_stats_rating(id, GET_SITE_STATS_TYPES:eType);

native hns_api_stats_rank(id, GET_SITE_STATS_TYPES:eType, szLen[10], ilen);