#if defined _hns_matchsystem_filter_included
	#endinput
#endif
#define _hns_matchsystem_filter_included


public match_system_additons(const szNativeName[], iNativeID, iTrapMode) {
	if (equal(szNativeName, "hns_db_init")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_get_pts_data")) { 
		return PLUGIN_HANDLED
	}
	
	if (equal(szNativeName, "hns_get_ownage")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_set_ownage")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_api_stats_init")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_api_stats_place")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_api_stats_rating")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_api_stats_rank")) { 
		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE;
}