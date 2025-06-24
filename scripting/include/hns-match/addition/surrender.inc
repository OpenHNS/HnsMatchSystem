#if defined _surrender_included
  #endinput
#endif

#define _surrender_included

enum _:SurrenderVote {
	e_sYes,
	e_sNo
};
new g_eSurrenderVotes[SurrenderVote];
new bool:g_bSurrenderVoted[MAX_PLAYERS + 1];

public taskSurrender() {
	new id = g_eSurrenderData[e_sInitiator];
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "che", getUserTeam(id) == TEAM_TERRORIST ? "TERRORIST" : "CT");

	if (!is_user_connected(id)) {
		resetSurrenderData();
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_MIX) {
		resetSurrenderData();
		return PLUGIN_HANDLED;
	}

	if (getUserTeam(id) == TEAM_SPECTATOR) {
		resetSurrenderData();
		return PLUGIN_HANDLED;
	}

	if (iNum != g_eMatchInfo[e_mTeamSizeTT]) {
		resetSurrenderData();
		return PLUGIN_HANDLED;
	}

	if (g_eSurrenderVotes[e_sYes] == g_eMatchInfo[e_mTeamSizeTT]) {
		autoLose(getUserTeam(id));
		resetSurrenderData();
		return PLUGIN_HANDLED;
	}

	if (g_eSurrenderVotes[e_sNo] == g_eMatchInfo[e_mTeamSizeTT]) {
		resetSurrenderData();
		return PLUGIN_HANDLED;
	}

	if (g_eSurrenderData[e_sFlTime] == g_iSettings[SUTVOTETIME]) {
		for (new i; i < iNum; i++) {
			new iPlayer = iPlayers[i];
			chat_print(iPlayer, "%L", id, "SUR_NEED", g_eMatchInfo[e_mTeamSizeTT], g_eMatchInfo[e_mTeamSizeTT]);
		}
		resetSurrenderData();
		return PLUGIN_HANDLED;
	}
	g_eSurrenderData[e_sFlTime]++;

	return PLUGIN_HANDLED;
}

stock surrenderMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (g_iCurrentMode != MODE_MIX)
		return PLUGIN_HANDLED;

	if (!getUserInMatch(id))
		return PLUGIN_HANDLED;

	new iPlayer = g_eSurrenderData[e_sInitiator];
	if (getUserTeam(id) != getUserTeam(iPlayer))
		return PLUGIN_HANDLED;

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_SUR_TITLE", iPlayer);
	new hMenu = menu_create(szMsg, "surrenderMenuHandler");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_YES");
	menu_additem(hMenu, szMsg);

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_NO");
	menu_additem(hMenu, szMsg);

	menu_display(id, hMenu, 0);
	return PLUGIN_HANDLED;
}

public surrenderMenuHandler(id, hMenu, item) {
	menu_destroy(hMenu);
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (item == MENU_EXIT)
		return PLUGIN_HANDLED;

	if (g_iCurrentMode != MODE_MIX)
		return PLUGIN_HANDLED;

	if (!getUserInMatch(id))
		return PLUGIN_HANDLED;

	new iPlayer = g_eSurrenderData[e_sInitiator];

	if (!is_user_connected(iPlayer))
		return PLUGIN_HANDLED;

	if (getUserTeam(id) != getUserTeam(iPlayer))
		return PLUGIN_HANDLED;

	if (g_bSurrenderVoted[id])
		return PLUGIN_HANDLED;

	g_eSurrenderVotes[item]++;
	g_bSurrenderVoted[id] = true;
	return PLUGIN_HANDLED;
}

resetSurrenderData() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		g_bSurrenderVoted[id] = false;
	}

	arrayset(g_eSurrenderVotes, 0, SurrenderVote);
	arrayset(g_eSurrenderData, 0, SurrenderData_s);
	if (task_exists(TASK_SURRENDER)) {
		remove_task(TASK_SURRENDER);
	}
}

autoLose(TeamName:iTeam) {
	chat_print(0, "%L", LANG_PLAYER, "SUR_END", iTeam == TEAM_TERRORIST ? "TERRORISTS" : "CTS");

	setTaskHud(0, 0.0, 1, 255, 255, 255, 4.0, "%L", LANG_SERVER, "HUD_GAMEOVER");
	
	MixFinishedMR(iTeam == TEAM_TERRORIST ? 2 : 1);
}
