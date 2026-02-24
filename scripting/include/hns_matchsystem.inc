#if defined _hns_matchsystem_included
	#endinput
#endif
#define _hns_matchsystem_included

#define rg_get_user_team(%0) get_member(%0, m_iTeam)

/**
* Game modes.
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
* Returns current game mode.
*
* @return		Game mode (HNS_MODES)
*/
native HNS_MODES:hns_get_mode();

/**
* Sets current game mode.
*
* @param iMode		Game mode (HNS_MODES)
*
* @noreturn
*/
native hns_set_mode(HNS_MODES:iMode);

/**
* Match statuses.
*/
enum MATCH_STATUS {
	MATCH_NONE,
	MATCH_BATTLERACE,
	MATCH_CAPTAINPICK,
	MATCH_CAPTAINKNIFE,
	MATCH_CAPTAINBATTLE,
	MATCH_TEAMPICK,
	MATCH_CUPKNIFE,
	MATCH_CUPPICK,
	MATCH_TEAMKNIFE,
	MATCH_TEAMBATTLE,
	MATCH_MAPPICK,
	MATCH_WAITCONNECT,
	MATCH_STARTED
}

/**
* Returns current match status.
*
* @return		Match status (MATCH_STATUS)
*/
native MATCH_STATUS:hns_get_status();

/**
* Sets current match status.
*
* @param iStatus	Match status (MATCH_STATUS)
*
* @noreturn
*/
native hns_set_status(MATCH_STATUS:iStatus);


enum MODE_STATES {
	STATE_DISABLED,
	STATE_PREPARE,
	STATE_PAUSED,
	STATE_ENABLED
};

/**
* Returns current match state.
*
* @return		Match state (MODE_STATES)
*/
native MODE_STATES:hns_get_state();

enum MATCH_RULES {
	RULES_MR,
	RULES_TIMER,
	RULES_DUEL
}

/**
* Returns current match rules.
*
* @return		Match rules (MATCH_RULES)
*/
native MATCH_RULES:hns_get_rules();

enum HNS_TEAM {
	HNS_TEAM_B,
	HNS_TEAM_A
}



/**
* Gets the system prefix.
*
* @param szPrefix	Buffer to copy prefix to
* @param iLen		Maximum buffer size
*
* @noreturn
*/
native hns_get_prefix(szPrefix[], iLen);

/**
* Returns whether boost mode is enabled.
*
* @return		0/1 value
*/
native hns_isboost();

/**
* Returns score for team A in duel(points) mode.
*
* @return		Float score
*/
native Float:hns_get_score_a();

/**
* Returns score for team B in duel(points) mode.
*
* @return		Float score
*/
native Float:hns_get_score_b();

/**
* Returns current TT owner side.
*
* @return		Team side (HNS_TEAM)
*/
native HNS_TEAM:hns_get_is_team_tt();

/**
* Returns current point distance bucket (0..10).
*
* @return		Integer distance bucket
*/
native hns_get_point_distance();

/**
* Returns current distance between duel players (units).
*
* @return		Integer distance
*/
native hns_get_players_distance();

/**
* Returns watcher access flag bitmask.
*
* @return		Bitflag value
*/
native hns_get_flag_watcher();

/**
* Returns full watcher access flag bitmask.
*
* @return		Bitflag value
*/
native hns_get_flag_fullwatcher();

/**
* Returns admin access flag bitmask.
*
* @return		Bitflag value
*/
native hns_get_flag_admin();

/**
* Called when a player leaves an active match.
*
* @param id		Player index
*
* @noreturn
*/
forward hns_player_leave_inmatch(id);

/**
* Called when a player joins an active match.
*
* @param id		Player index
* @param bReplaced	Whether player replaced someone
*
* @noreturn
*/
forward hns_player_join_inmatch(id, bool:bReplaced);

/**
* Called when match starts.
*
* @noreturn
*/
forward hns_match_started();

/**
* Called when current match round is reset.
*
* @noreturn
*/
forward hns_match_reset_round();

/**
* Called when match is canceled.
*
* @noreturn
*/
forward hns_match_canceled();

/**
* Called when match is finished.
*
* @param iWinTeam	Winning team:
*					1 - TT
*					2 - CT
*
* @noreturn
*/
forward hns_match_finished(iWinTeam);

/**
* Called after match finish logic is completed.
*
* @param iWinTeam	Winning team:
*					1 - TT
*					2 - CT
*
* @noreturn
*/
forward hns_match_finished_post(iWinTeam);

/**
* Called on round start.
*
* @noreturn
*/
forward hns_round_start();

/**
* Called on freeze end.
*
* @noreturn
*/
forward hns_round_freezeend();

/**
* Called on round end.
*
* @noreturn
*/
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
