#if defined _hns_matchsystem_filter_included
	#endinput
#endif
#define _hns_matchsystem_filter_included


public match_system_additons(const szNativeName[], iNativeID, iTrapMode) {
	if (equal(szNativeName, "hns_mysql_stats_init") || equal(szNativeName, "hns_mysql_stats_data") || equal(szNativeName, "hns_mysql_stats_get_ownage") || equal(szNativeName, "hns_mysql_stats_set_ownage")) { 
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

	if (equal(szNativeName, "hnsmatch_maps_init")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hnsmatch_maps_is_knife")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hnsmatch_maps_load_settings")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_cup_enabled") || equal(szNativeName, "hns_cup_is_veto_active") || equal(szNativeName, "hns_cup_stop_veto") || equal(szNativeName, "hns_cup_set_veto_turn_by_team")) { 
		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE;
}
