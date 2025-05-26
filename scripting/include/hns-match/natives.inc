#if defined _natives_included
  #endinput
#endif

#define _natives_included

public plugin_natives() {
	register_native("hns_get_prefix", "native_get_prefix");
	register_native("hns_get_flag_watcher", "native_flag_watcher");
	register_native("hns_get_flag_fullwatcher", "native_flag_fullwatcher");
	register_native("hns_get_flag_admin", "native_get_flag_admin");

	register_native("hns_get_mode", "native_get_mode");
	register_native("hns_set_mode", "native_set_mode");

	register_native("hns_get_status", "native_get_status");
	register_native("hns_get_state", "native_get_state");

	register_native("hns_get_rules", "native_get_rules");
	register_native("hns_set_rules", "native_set_rules");

	//register_native("hns_get_score_tt", "native_get_score_TT");
	//register_native("hns_get_score_ct", "native_get_score_CT");
}


public native_get_prefix(amxx, params) {
	enum { argPrefix = 1, argLen };
	new szPrefix[24];
	format(szPrefix, charsmax(szPrefix), "[^3%s^1]", g_iSettings[PREFIX]);
	set_string(argPrefix, szPrefix, get_param(argLen));
}

public native_flag_watcher(amxx, params) {
	return read_flags(g_iSettings[WATCHER_FLAG]);
}

public native_flag_fullwatcher(amxx, params) {
	return read_flags(g_iSettings[FULL_WATCHER_FLAG]);
}

public native_get_flag_admin(amxx, params) {
	return read_flags(g_iSettings[ADMIN_FLAG]);
}

public native_get_mode(amxx, params) {
	return g_iCurrentMode;
}

public native_set_mode(amxx, params) {
	enum { iSetMode = 1 };
	switch (get_param(iSetMode)) {
		case MODE_TRAINING: {
			training_start()
		}
		case MODE_KNIFE: {
			kniferound_start()
		}
		case MODE_PUB: {
			pub_start()
		}
		case MODE_DM: {
			dm_start()
		}
		case MODE_ZM: {
			zm_start()
		}
		case MODE_MIX: {
			mix_start()
		}
	}
}

public MATCH_STATUS:native_get_status(amxx, params) {
	return g_iMatchStatus;
}

public MODE_STATES:native_get_state(amxx, params) {
	return g_eMatchState;
}

public NATCH_RULES:native_get_rules(amxx, params) {
	return g_iCurrentRules;
}

public native_set_rules(amxx, params) {
	enum { iRules = 1 };
	switch (get_param(iRules)) {
		case RULES_MR: {
			g_iCurrentRules = RULES_MR;
		}
		case RULES_TIMER: {
			g_iCurrentRules = RULES_TIMER;
		}
		case RULES_DUEL: {
			g_iCurrentRules = RULES_DUEL;
		}
	}
	
}