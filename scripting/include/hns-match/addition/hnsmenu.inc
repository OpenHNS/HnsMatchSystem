#if defined _hnsmenu_included
  #endinput
#endif

#define _hnsmenu_included

new Float:g_flTimeToVoteMode;

public mainMatchMenu(id) {
	if (!is_user_connected(id) || !isUserWatcher(id))
		return PLUGIN_HANDLED;

	static szMsg[128];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MIX_TITLE");
	new hMenu = menu_create(szMsg, "mainMatchMenuHandler");

	if (hns_is_knife_map()) {
		if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_CAP");
		else if (g_iCurrentMode == MODE_KNIFE && g_iMatchStatus == MATCH_TEAMKNIFE && g_eMatchState == STATE_PAUSED)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_UNPAUSEKF");
		else if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_STOPCAP");
		else
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_NOTCAP");
	} else {
		if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_STOPCUSTOM");
		else if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus <= MATCH_WAITCONNECT)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_MIX");
		else {
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_STOPMIX");
		}
	}

	menu_additem(hMenu, szMsg, "1");


	if (hns_is_knife_map()) {
		if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_NOTSTARTKF");
		else if (g_iCurrentMode == MODE_KNIFE)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_STOPKF");
		else
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_STARTKF");
	} else {
		if (g_iCurrentMode == MODE_TRAINING)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_CUSTOM");
		else if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM)
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_BLEND");
		else {
			if (g_eMatchState != STATE_PAUSED)
				formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_PAUSE");
			else
				formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_UNPAUSE");
		}
	}
	
	menu_additem(hMenu, szMsg, "2");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_SETTINGS");
	menu_additem(hMenu, szMsg, "3");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_RESTART");
	menu_additem(hMenu, szMsg, "4");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_SWAP");
	menu_additem(hMenu, szMsg, "5");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_WTRMENU");
	menu_additem(hMenu, szMsg, "6");

	if (isUserAdmin(id)) {
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MAIN_ADMMENU");
	} else {
		formatex(szMsg, charsmax(szMsg), "\d%L", id, "MENU_MAIN_ADMMENU");
	}

	menu_additem(hMenu, szMsg, "7");

	menu_display(id, hMenu, 0);

	return PLUGIN_HANDLED;
}

public mainMatchMenuHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);
	
	new iKey = str_to_num(szData);
	
	switch (iKey) {
		case 1: {
			if (hns_is_knife_map()) {
				if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE)
					cmdCaptain(id);
				else if (g_iCurrentMode == MODE_KNIFE && g_iMatchStatus == MATCH_TEAMKNIFE && g_eMatchState == STATE_PAUSED)
					cmdStopPause(id);
				else if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE|| g_iMatchStatus == MATCH_TEAMPICK)
					cmdStop(id);
				else
					mainMatchMenu(id);
			} else {
				if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM || g_iMatchStatus == MATCH_WAITCONNECT) { // beta
					cmdStop(id);
				}
				else if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus <= MATCH_WAITCONNECT)
					cmdStartMatch(id);
				else {
					verifMenu(id);
				}
			}
		}
		case 2: {
			if (hns_is_knife_map()) {
				if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMPICK)
					mainMatchMenu(id);
				else if (g_iCurrentMode == MODE_KNIFE)
					cmdStop(id);
				else
					cmdKnifeRound(id);
			} else {
				if (g_iCurrentMode == MODE_TRAINING)
					customMenu(id);
				else if ((g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_ZM))
					cmdBlend(id);
				else {
					if (g_eMatchState != STATE_PAUSED)
						cmdStartPause(id);
					else
						cmdStopPause(id);
				}
			}
		}
		case 3: {
			settingsMatchMenu(id);
		}
		case 4: {
			cmdRestartRound(id);
		}
		case 5: {
			cmdSwapTeams(id);
		}
		case 6: {
			client_cmd(id, "watcher");
		}
		case 7: {
			if (isUserAdmin(id)) {
				client_cmd(id, "amxmodmenu");
			} else {
				mainMatchMenu(id);
			}
		}
	}

	return PLUGIN_HANDLED;
}

public customMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MIX_TITLE");
	new hMenu = menu_create(szMsg, "customMenuHandler");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_CUSTOM_PUB");
	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_CUSTOM_DM");
	menu_additem(hMenu, szMsg, "2");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_CUSTOM_ZM");
	menu_additem(hMenu, szMsg, "3");

	menu_display(id, hMenu, 0);
	return PLUGIN_HANDLED;
}

public customMenuHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);
	new iKey = str_to_num(szData);

	switch (iKey) {
		case 1: {
			cmdPubMode(id);
		}
		case 2: {
			cmdDMMode(id);
		}
		case 3: {
			cmdZMMode(id);
		}
	}
	return PLUGIN_HANDLED;
}

public settingsMatchMenu(id) {
	if (!is_user_connected(id) || !isUserWatcher(id))
		return PLUGIN_HANDLED;

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MIX_TITLE");
	new hMenu = menu_create(szMsg, "settingsMatchMenuHandler");

	if (g_iCurrentMode == MODE_TRAINING)
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ROUNDTIME_TRNG");
	else
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ROUNDTIME", get_cvar_float("mp_roundtime"));

	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_FREEZETIME", get_cvar_num("mp_freezetime"));
	menu_additem(hMenu, szMsg, "2");

	switch (g_iCurrentRules) {
		case RULES_MR: {
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_MAXROUND", g_iSettings[MAXROUNDS], g_iSettings[MAXROUNDS] * 2);
		}
		case RULES_TIMER: {
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_WINTIME", g_eMatchInfo[e_mWintime]);
		}
		case RULES_DUEL: {
			formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_DUEL", g_iSettings[DUELROUNDS]);
		}
	}
	
	menu_additem(hMenu, szMsg, "3");

	if (g_iSettings[ONEHPMODE] == 0)
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ONEHP_ON");
	else
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_ONEHP_OFF");
	
	menu_additem(hMenu, szMsg, "4");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_FLASH", g_iSettings[FLASH]);
	menu_additem(hMenu, szMsg, "5");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_STNGS_SMOKE", g_iSettings[SMOKE]);
	menu_additem(hMenu, szMsg, "6");

	menu_display(id, hMenu, 0);
	return PLUGIN_HANDLED;
}

public settingsMatchMenuHandler(id, hMenu, item) {
	if (!is_user_connected(id)) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		mainMatchMenu(id);
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new iKey = str_to_num(szData);
	switch (iKey) {
		case 1: {
			if (get_cvar_float("mp_roundtime") <= 2.5)
				set_cvar_float("mp_roundtime", 3.0);
			else if (get_cvar_float("mp_roundtime") <= 3.0)
				set_cvar_float("mp_roundtime", 3.5);
			else if (get_cvar_float("mp_roundtime") <= 3.5)
				set_cvar_float("mp_roundtime", 4.0);
			else if (get_cvar_float("mp_roundtime") >= 4.0)
				set_cvar_float("mp_roundtime", 2.5);

			settingsMatchMenu(id);
		}
		case 2: {
			if (get_cvar_num("mp_freezetime") == 0)
				set_cvar_num("mp_freezetime", 5);
			else if (get_cvar_num("mp_freezetime") <= 5)
				set_cvar_num("mp_freezetime", 10);
			else if (get_cvar_num("mp_freezetime") <= 10)
				set_cvar_num("mp_freezetime", 15);
			else if (get_cvar_num("mp_freezetime") >= 15)
				set_cvar_num("mp_freezetime", 0);

			settingsMatchMenu(id);
		}
		case 3: {
			switch (g_iCurrentRules) {
				case RULES_MR: {
					if (g_iSettings[MAXROUNDS] <= 6)
						g_iSettings[MAXROUNDS] = 8;
					else if (g_iSettings[MAXROUNDS] <= 8)
						g_iSettings[MAXROUNDS] = 10;
					else if (g_iSettings[MAXROUNDS] >= 10)
						g_iSettings[MAXROUNDS] = 6;
				}
				case RULES_TIMER: {
					if (g_eMatchInfo[e_mWintime] <= 10.0)
						g_eMatchInfo[e_mWintime] = 15.0;
					else if (g_eMatchInfo[e_mWintime] <= 15.0)
						g_eMatchInfo[e_mWintime] = 20.0;
					else if (g_eMatchInfo[e_mWintime] >= 20.0)
						g_eMatchInfo[e_mWintime] = 10.0;

					set_pcvar_float(pCvar[WINTIME], g_eMatchInfo[e_mWintime]);
				}
				case RULES_DUEL: {
					if (g_iSettings[DUELROUNDS] <= 2)
						g_iSettings[DUELROUNDS] = 3;
					else if (g_iSettings[DUELROUNDS] <= 3)
						g_iSettings[DUELROUNDS] = 4;
					else if (g_iSettings[DUELROUNDS] >= 4)
						g_iSettings[DUELROUNDS] = 2;
				}
			}

			settingsMatchMenu(id);
		}
		case 4: {
			if (!g_iSettings[ONEHPMODE])
				g_iSettings[ONEHPMODE] = 1;
			else
				g_iSettings[ONEHPMODE] = 0;

			settingsMatchMenu(id);
		}
		case 5: {
			if (g_iSettings[FLASH] == 0)
				g_iSettings[FLASH] = 1;
			else if (g_iSettings[FLASH] <= 1)
				g_iSettings[FLASH] = 2;
			else if (g_iSettings[FLASH] <= 2)
				g_iSettings[FLASH] = 3;
			else if (g_iSettings[FLASH] >= 3)
				g_iSettings[FLASH] = 0;

			settingsMatchMenu(id);
		}
		case 6: {
			if (g_iSettings[SMOKE] <= 1)
				g_iSettings[SMOKE] = 2;
			else if (g_iSettings[SMOKE] >= 2)
				g_iSettings[SMOKE] = 1;

			settingsMatchMenu(id);
		}
	}
	return PLUGIN_HANDLED;
}


public verifMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_VERIF_TITLE");
	new hMenu = menu_create(szMsg, "verifMenuHandler");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_NO");
	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_YES");
	menu_additem(hMenu, szMsg, "2");

	menu_display(id, hMenu, 0);
	return PLUGIN_HANDLED;
}

public verifMenuHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	menu_destroy(hMenu);

	switch (item) {
		case 0: {
			return PLUGIN_HANDLED;
		}
		case 1: {
			cmdStop(id);
		}
	}
	return PLUGIN_HANDLED;
}

public menuSelectMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}
	
	if (g_iCurrentMode == MODE_MIX) {
		chat_print(id, "%L", id, "MODE_NOT_MIX");
		return PLUGIN_HANDLED;
	}

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_TITLE");
	new hMenu = menu_create(szMsg, "HandlerSelectMode");
	
	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_MR");
	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_WINTIME");
	menu_additem(hMenu, szMsg, "2");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_DUEL");
	menu_additem(hMenu, szMsg, "3");
		
	menu_setprop(hMenu, MPROP_EXIT, MEXIT_ALL);
	
	menu_display(id, hMenu, 0);
	
	return PLUGIN_HANDLED;
}

public HandlerSelectMode(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new index = str_to_num(szData);

	switch (index) {
		case 1: {
			cmdMrMode(id);
		}
		case 2: {
			cmdWintimeMode(id);
		}
		case 3: {
			cmdDuelMode(id);
		}
	}

	return PLUGIN_HANDLED;
}

new iVoteRules[NATCH_RULES];

public StartVoteRules() {
	g_flTimeToVoteMode = get_gametime() + 15.0;
	iVoteRules[RULES_TIMER] = iVoteRules[RULES_MR] = 0;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if (!is_user_connected(id))
			continue;

		if(getUserTeam(id) != TEAM_CT && getUserTeam(id) != TEAM_TERRORIST) {
			continue;
		}

		new szMsg[64];

		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_TITLE");
		new hMenu = menu_create(szMsg, "HandlerStartVoteRules");
		
		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_MR");
		menu_additem(hMenu, szMsg, "1");

		formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_MODE_WINTIME");
		menu_additem(hMenu, szMsg, "2");
			
		menu_setprop(hMenu, MPROP_EXIT, MEXIT_ALL);
		
		menu_display(id, hMenu, 0);
	}

	set_task(15.0, "VoteFinished", 83129);
}

public HandlerStartVoteRules(id, hMenu, item) {
	if (item == MENU_EXIT || get_gametime() > g_flTimeToVoteMode) {
		menu_destroy(hMenu);
		return;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new index = str_to_num(szData);

	if(index == 1) {
		iVoteRules[RULES_MR]++;		
		chat_print(0, "%l", "VOTE_MR", id);
	} else {
		iVoteRules[RULES_TIMER]++;
		chat_print(0, "%l", "VOTE_WT", id);
	}
}

public VoteFinished() {
	if(iVoteRules[RULES_MR] > iVoteRules[RULES_TIMER]) {
		g_iCurrentRules = RULES_MR;
	} else if(iVoteRules[RULES_MR] < iVoteRules[RULES_TIMER]) {
		g_iCurrentRules = RULES_TIMER;
	} else {
		g_iCurrentRules = NATCH_RULES:random_num(0, 1);
	}

	chat_print(0, "%l", "VOTE_WIN", g_iCurrentRules == RULES_MR? "MR" : "Wintime");
	
	iVoteRules[RULES_MR] = iVoteRules[RULES_TIMER] = 0;	
}
