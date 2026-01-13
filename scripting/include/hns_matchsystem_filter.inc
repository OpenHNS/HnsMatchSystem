#if defined _hns_matchsystem_filter_included
	#endinput
#endif
#define _hns_matchsystem_filter_included


public match_system_additons(const szNativeName[], iNativeID, iTrapMode) {
	if (equal(szNativeName, "hns_mysql_stats_init")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_mysql_stats_data")) { 
		return PLUGIN_HANDLED
	}
	
	if (equal(szNativeName, "hns_mysql_stats_get_ownage")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_mysql_stats_set_ownage")) { 
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

	if (equal(szNativeName, "hns_cup_enabled")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_cup_is_veto_active")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_cup_stop_veto")) { 
		return PLUGIN_HANDLED
	}

	if (equal(szNativeName, "hns_cup_set_veto_turn_by_team")) { 
		return PLUGIN_HANDLED
	}

	return PLUGIN_CONTINUE;
}