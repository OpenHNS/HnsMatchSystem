#if defined _hns_matchsystem_included
	#endinput
#endif
#define _hns_matchsystem_included

#define rg_get_user_team(%0) get_member(%0, m_iTeam)

new g_szMatchPrefix[24];


/* Hns match modes */

enum HNS_MODES
{
	MODE_TRAINING,
	MODE_KNIFE,
	MODE_PUB,
	MODE_DM,
	MODE_ZM,
	MODE_MIX
}

/*
* Gets mode system.
*
* @return enum HNS_MODES
*/
native HNS_MODES:hns_get_mode();

/*
* Set mode system.
*
* @noreturn
*/
native hns_set_mode(HNS_MODES:iMode);


/* Hns mode states */

enum MODE_STATES
{
    STATE_DISABLED,
    STATE_PREPARE,
    STATE_PAUSED,
    STATE_ENABLED
}

/*
* Gets match state
*
* @return type MODE_STATES
*/
native MODE_STATES:hns_get_state();


/* Hns match status */

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

/*
* Gets match status.
*
* @return type MATCH_STATUS
*/
native MATCH_STATUS:hns_get_status();


/* Hns match rules */

enum NATCH_RULES {
	RULES_MR,
	RULES_TIMER,
	RULES_DUEL
}

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
* Gets the system prefix.
*
* @param szPrefix   Buffer to copy prefix to
* @param iLen Maximum buffer size
*
* @noreturn
*/
native hns_get_prefix(szPrefix[], iLen);

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

/* -- Utils -- */

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

stock chat_print(const id, const message[], any:...) {
	new msgFormated[191];

	vformat(msgFormated, charsmax(msgFormated), message, 3);

	if (!g_szMatchPrefix[0])
		client_print_color(id, print_team_blue, "%s", msgFormated);
	else
		client_print_color(id, print_team_blue, "[^3%s^1] %s", g_szMatchPrefix, msgFormated);
}

stock get_num_players_in_match() { // TODO: Сделать 1 утилиту с точными игроками в матче
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	new numGameplr;
	for (new i; i < iNum; i++) {
		new tempid = iPlayers[i];
		if (rg_get_user_team(tempid) == TEAM_SPECTATOR) continue;
		numGameplr++;
	}
	return numGameplr;
}

/* -- Utils -- */