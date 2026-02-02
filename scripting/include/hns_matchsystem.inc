#if defined _hns_matchsystem_included
	#endinput
#endif
#define _hns_matchsystem_included

#define rg_get_user_team(%0) get_member(%0, m_iTeam)

/**
 * Game Modes.
 */
enum HNS_MODES {
	MODE_TRAINING,
	MODE_KNIFE,
	MODE_PUB,
	MODE_DM,
	MODE_ZM,
	MODE_MIX
};

/**
* Returns the game mode.
*
* @return		Mode status (HNS_MODES)
*/
native HNS_MODES:hns_get_mode();

/**
* Sets the game mode.
*
* @param iMode		Mode status (HNS_MODES)
*
* @noreturn
*/
native hns_set_mode(HNS_MODES:iMode);

/**
 * Match statuses.
 */
enum MATCH_STATUS {
	MATCH_NONE,
	MATCH_CAPTAINPICK,
	MATCH_CAPTAINKNIFE,
	MATCH_TEAMPICK,
	MATCH_CUPKNIFE,
	MATCH_CUPPICK,
	MATCH_TEAMKNIFE,
	MATCH_MAPPICK,
	MATCH_WAITCONNECT,
	MATCH_STARTED
}

/**
* Returns the match status
*
* @return		Match status (MATCH_STATUS)
*/
native MATCH_STATUS:hns_get_status();


enum MODE_STATES {
	STATE_DISABLED,
	STATE_PREPARE,
	STATE_PAUSED,
	STATE_ENABLED
};

/*
* Gets match state
*
* @return type MODE_STATES
*/
native MODE_STATES:hns_get_state();

enum MATCH_RULES {
	RULES_MR,
	RULES_TIMER,
	RULES_DUEL,
	RULES_POINTS
}

/*
* Gets match rules
*
* @return type MATCH_RULES
*/
native MATCH_RULES:hns_get_rules();

enum HNS_TEAM {
	HNS_TEAM_B,
	HNS_TEAM_A
}



/*
* Gets the system prefix.
*
* @param szPrefix	Buffer to copy prefix to
* @param iLen		Maximum buffer size
*
* @noreturn
*/
native hns_get_prefix(szPrefix[], iLen);

native hns_isboost();

native Float:hns_get_score_a();

/*
* Gets watcher flag
*
* @return Bitflag value
*/
native Float:hns_get_score_b();

native HNS_TEAM:hns_get_is_team_tt();

native hns_get_point_distance();

native hns_get_players_distance();

/*
* Gets watcher flag
*
* @return Bitflag value
*/
native hns_get_flag_watcher();

/*
* Gets full watcher flag
*
* @return Bitflag value
*/
native hns_get_flag_fullwatcher();

/*
* Gets admin flag
*
* @return Bitflag value
*/
native hns_get_flag_admin();

forward hns_player_leave_inmatch(id);

forward hns_player_join_inmatch(id, bool:bReplaced);

/*
* Called when the match play begins.
*
* @noreturn
*/
forward hns_match_started();

/*
* Called when a match round is reset.
*
* @noreturn
*/
forward hns_match_reset_round();

/*
* Called, the match is canceled.
*
* @noreturn
*/
forward hns_match_canceled();

/*
* Called when the match is over.
*
* @param iWinTeam The winning team
*				1 - TT
*				2 - CT
* @noreturn
*/
forward hns_match_finished(iWinTeam);

forward hns_match_finished_post(iWinTeam);

forward hns_round_start();

forward hns_round_freezeend();

forward hns_round_end();

stock RegisterSayCmd(const szCmd[], const szShort[], const szFunc[], flags = -1, szInfo[] = "") {
	new szTemp[65], szInfoLang[65];
	format(szInfoLang, 64, "%L", LANG_SERVER, szInfo);

	format(szTemp, 64, "say /%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say .%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "/%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say /%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say .%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "/%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	return 1;
}

stock bool:isUserWatcher(id) {
	if (get_user_flags(id) & hns_get_flag_watcher())
		return true;
	else
		return false;
}

stock bool:isUserFullWatcher(id) {
	if (get_user_flags(id) & hns_get_flag_fullwatcher())
		return true;
	else
		return false;
}

stock bool:isUserAdmin(id) {
	if (get_user_flags(id) & hns_get_flag_admin())
		return true;
	else
		return false;
}