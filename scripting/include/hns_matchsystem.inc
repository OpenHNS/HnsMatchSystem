#if defined _hns_matchsystem_included
	#endinput
#endif
#define _hns_matchsystem_included

#define rg_get_user_team(%0) get_member(%0, m_iTeam)

enum _:HNS_MODES
{
	MODE_TRAINING,
	MODE_KNIFE,
	MODE_PUB,
	MODE_DM,
	MODE_ZM,
	MODE_MIX
}

enum MATCH_STATUS
{
	MATCH_NONE,
	MATCH_CAPTAINPICK,
	MATCH_CAPTAINKNIFE,
	MATCH_TEAMPICK,
	MATCH_TEAMKNIFE,
	MATCH_MAPPICK,
	MATCH_WAITCONNECT,
	MATCH_STARTED
}

enum MODE_STATES
{
    STATE_DISABLED,
    STATE_PREPARE,
    STATE_PAUSED,
    STATE_ENABLED
}

enum NATCH_RULES {
	RULES_MR,
	RULES_TIMER,
	RULES_DUEL
}

/*
* Gets the system prefix.
*
* @param szPrefix   Buffer to copy prefix to
* @param iLen Maximum buffer size
*
* @noreturn
*/
native hns_get_prefix(szPrefix[], iLen);

/*
* 
*
* 
* 
*
* 
*/
native hns_get_flag_watcher();

/*
* 
*
* 
* 
*
* 
*/
native hns_get_flag_fullwatcher();

/*
* 
*
* 
* 
*
* 
*/
native hns_get_flag_admin();

/*
* Gets mode system.
*
* @return enum HNS_MODES
*/
native hns_get_mode();

/*
* Set mode system.
*
* @noreturn
*/
native hns_set_mode(iMode);

/*
* Gets match status.
*
* @return type MATCH_STATUS
*/
native MATCH_STATUS:hns_get_status();

/*
* Gets match state
*
* @return type MODE_STATES
*/
native MODE_STATES:hns_get_state();

/*
* Gets match rules
*
* @return type NATCH_RULES
*/
native NATCH_RULES:hns_get_rules();

/*
* Set match rules
*
* @return type NATCH_RULES
*/
native hns_set_rules(NATCH_RULES:iRules);

/* 
* Gets score in match (For RULES_DUEL)
*
* @return type Score TT

native hns_get_score_tt();

* Gets score in match (For RULES_DUEL)
*
* @return type Score CT

native hns_get_score_ct(); */

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
*				0 - TT
*				1 - CT
* @noreturn
*/
forward hns_match_finished(iWinTeam);

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