#if defined _captain_included
  #endinput
#endif

#define _captain_included

enum _:CaptainTeam_s {
	e_cTT,
	e_cCT
};

new g_eCaptain[CaptainTeam_s], g_iCaptainPick;

new g_iCaptainFirst;
new g_iCaptainSecond;

new Float:RandomPickTime;

public captain_start(id) {
	resetCaptainData();

	g_iMatchStatus = MATCH_CAPTAINPICK;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];

		if (getUserTeam(iPlayer) == TEAM_SPECTATOR)
			continue;

		transferUserToSpec(iPlayer);
	}
	
	chooseCapsMenu(id);

	chat_print(0, "%L", LANG_PLAYER, "CAP_CHOOSE", id);
}

public chooseCapsMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (g_iMatchStatus != MATCH_CAPTAINPICK)
		return PLUGIN_HANDLED;

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_CAP_CHOSE");
	new hMenu = menu_create(szMsg, "chooseCapsHandler");

	new iPlayers[MAX_PLAYERS], iNum, szPlayer[10], iPlayer;
	get_players(iPlayers, iNum, "ch");

	new szBuffer[256];
	for (new i; i < iNum; i++) {
		iPlayer = iPlayers[i];

		if (iPlayer == g_iCaptainFirst || iPlayer == g_iCaptainSecond)
			continue;

		num_to_str(iPlayer, szPlayer, charsmax(szPlayer));

		if ((g_bHnsBannedInit && e_bBanned[iPlayer]) || g_bNoplay[iPlayer]) {
			add(szBuffer, charsmax(szBuffer), fmt("\d%n ", iPlayer));
		}
		else {
			add(szBuffer, charsmax(szBuffer), fmt("%n ", iPlayer));
		}

		if (g_ePlayerPtsData[iPlayer][e_bInit]) {
			new szPts[16];
			formatex(szPts, charsmax(szPts), "\d%d (%s) ", g_ePlayerPtsData[iPlayer][e_iPts], g_ePlayerPtsData[iPlayer][e_szRank]);
			add(szBuffer, charsmax(szBuffer), szPts);
		}

		if (g_bNoplay[iPlayer])
			add(szBuffer, charsmax(szBuffer), "\r[Noplay] ");

		if (g_bHnsBannedInit) {
			if (e_bBanned[iPlayer]) {
				add(szBuffer, charsmax(szBuffer), "\r[Banned] ");
			}
		}

		menu_additem(hMenu, szBuffer, szPlayer);
		szBuffer = "";
	}

	menu_setprop(hMenu, MPROP_EXITNAME, "Refresh");
	menu_setprop(hMenu, MPROP_SHOWPAGE, 0);
	menu_display(id, hMenu, 0);
	return PLUGIN_HANDLED;
}

public chooseCapsHandler(id, hMenu, item) {
	if (!is_user_connected(id)) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (g_iMatchStatus != MATCH_CAPTAINPICK) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		chooseCapsMenu(id);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new iPlayer = str_to_num(szData);

	if (!is_user_connected(iPlayer)) {
		chooseCapsMenu(id);
		return PLUGIN_HANDLED;
	}

	if (g_bNoplay[iPlayer]) {
		chooseCapsMenu(id);
		return PLUGIN_HANDLED;
	}

	if (g_bHnsBannedInit) {
		if (e_bBanned[iPlayer]) {
			chooseCapsMenu(id);
			return PLUGIN_HANDLED;
		}
	}

	if (!g_iCaptainFirst) {
		g_iCaptainFirst = iPlayer;
		g_ePlayerInfo[g_iCaptainFirst][PLAYER_ROLE] = ROLE_CAP_A;
		
		if (g_ePlayerPtsData[iPlayer][e_bInit])
			chat_print(0, "%L", LANG_PLAYER, "CAP_FIRST_PTS", iPlayer, g_ePlayerPtsData[iPlayer][e_iPts], g_ePlayerPtsData[iPlayer][e_szRank]);
		else
			chat_print(0, "%L", LANG_PLAYER, "CAP_FIRST", iPlayer);

		chooseCapsMenu(id);
	} else if (!g_iCaptainSecond) {
		g_iCaptainSecond = iPlayer;
		g_ePlayerInfo[g_iCaptainSecond][PLAYER_ROLE] = ROLE_CAP_B

		if (g_ePlayerPtsData[iPlayer][e_bInit])
			chat_print(0, "%L", LANG_PLAYER, "CAP_SECOND_PTS", iPlayer, g_ePlayerPtsData[iPlayer][e_iPts], g_ePlayerPtsData[iPlayer][e_szRank]);
		else
			chat_print(0, "%L", LANG_PLAYER, "CAP_SECOND", iPlayer);

		if (is_user_connected(g_iCaptainFirst) && is_user_connected(g_iCaptainSecond)) {
			rg_set_user_team(g_iCaptainFirst, TEAM_TERRORIST);
			rg_set_user_team(g_iCaptainSecond, TEAM_CT);

			g_iMatchStatus = MATCH_CAPTAINKNIFE;

			kniferound_start();
		} else {
			chat_print(0, "%L", LANG_PLAYER, "CAP_HAS_LEFT");
			resetCaptainData();
		}
	}
	return PLUGIN_HANDLED;
}

public pickMenu(id, bool:bStartWait) {
	if (!is_user_connected(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iMatchStatus != MATCH_TEAMPICK) {
		return PLUGIN_HANDLED;
	}

	if (id != g_iCaptainPick) {
		return PLUGIN_HANDLED;
	}

	if(bStartWait == true && g_iSettings[RANDOMPICK] == 1)
	{
		WaitPick();
	}

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_CAP_PICK");
	new hMenu = menu_create(szMsg, "pickHandler");

	new iPlayers[MAX_PLAYERS], iNum, szPlayer[10], iPlayer;
	get_players(iPlayers, iNum, "che", "SPECTATOR");

	new szBuffer[256];
	for (new i; i < iNum; i++) {
		iPlayer = iPlayers[i];

		num_to_str(iPlayer, szPlayer, charsmax(szPlayer));

		if ((g_bHnsBannedInit && e_bBanned[iPlayer]) || g_bNoplay[iPlayer]) {
			add(szBuffer, charsmax(szBuffer), fmt("\d%n ", iPlayer));
		}
		else {
			add(szBuffer, charsmax(szBuffer), fmt("%n ", iPlayer));
		}

		if (g_ePlayerPtsData[iPlayer][e_bInit]) {
			new szPts[16];
			formatex(szPts, charsmax(szPts), "\d%d (%s) ", g_ePlayerPtsData[iPlayer][e_iPts], g_ePlayerPtsData[iPlayer][e_szRank]);
			add(szBuffer, charsmax(szBuffer), szPts);
		}

		if (g_bNoplay[iPlayer])
			add(szBuffer, charsmax(szBuffer), "\r[Noplay] ");

		if (g_bHnsBannedInit) {
			if (e_bBanned[iPlayer]) {
				add(szBuffer, charsmax(szBuffer), "\r[Banned] ");
			}
		}	

		menu_additem(hMenu, szBuffer, szPlayer);
		szBuffer = "";
	}

	menu_setprop(hMenu, MPROP_EXITNAME, "Refresh");
	menu_setprop(hMenu, MPROP_SHOWPAGE, false);
	menu_display(id, hMenu, 0);

	return PLUGIN_HANDLED;
}

public pickHandler(id, hMenu, item) {
	if (!is_user_connected(id)) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (g_iMatchStatus != MATCH_TEAMPICK) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (id != g_iCaptainPick) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (getUserTeam(id) == TEAM_SPECTATOR) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		pickMenu(id, false);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new iPlayer = str_to_num(szData);

	if (!is_user_connected(iPlayer)) {
		pickMenu(id, false);
		return PLUGIN_HANDLED;
	}

	if (g_bNoplay[iPlayer]) {
		pickMenu(id, false);
		return PLUGIN_HANDLED;
	}

	if (g_bHnsBannedInit) {
		if (e_bBanned[iPlayer]) {
			pickMenu(id, false);
			return PLUGIN_HANDLED;
		}
	}

	if (g_ePlayerPtsData[iPlayer][e_bInit])
		chat_print(0, "%L", LANG_PLAYER, "PLAYER_CHOOSE_PTS", id, iPlayer, g_ePlayerPtsData[iPlayer][e_iPts], g_ePlayerPtsData[iPlayer][e_szRank]);
	else
		chat_print(0, "%L", LANG_PLAYER, "PLAYER_CHOOSE", id, iPlayer);

	if (g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_CAP_A) {
		g_ePlayerInfo[iPlayer][PLAYER_ROLE] = ROLE_TEAM_A;
		g_iCaptainPick = g_iCaptainSecond;
	} else {
		g_ePlayerInfo[iPlayer][PLAYER_ROLE] = ROLE_TEAM_B;
		g_iCaptainPick = g_iCaptainFirst;
	}

	rg_set_user_team(iPlayer, getUserTeam(id));
	rg_round_respawn(iPlayer);

	pickMenu(g_iCaptainPick, true);
	checkFullTeams();

	return PLUGIN_HANDLED;
}

public WaitPick()
{
	if (g_iMatchStatus != MATCH_TEAMPICK) {
		return PLUGIN_HANDLED;
	}

	if (task_exists(TASK_WAITCAP)) {
		remove_task(TASK_WAITCAP)
	}

	RandomPickTime = g_iSettings[TIME_RANDOMPICK];

	set_task(1.0, "wait_function", .id = TASK_WAITCAP, .flags = "b");

	return PLUGIN_HANDLED;
}	

public wait_function(id)
{
	if (!is_user_connected(g_iCaptainPick)) {
		resetCaptainData();
		return;
	}

	RandomPickTime -= 1.0;
	  
	setTaskHud(0, 0.0, 1, 255, 255, 255, 1.0, "%L", LANG_SERVER, "HUD_WAITPICK", g_iCaptainPick, RandomPickTime);

	if(RandomPickTime <= 0.0) {
		new randomaizer = GetPickRandom();
		if(randomaizer) {
			new pPlayer = g_iCaptainPick;
			rg_set_user_team(randomaizer, getUserTeam(pPlayer));

			rg_round_respawn(randomaizer);
			chat_print(0, "%L", LANG_PLAYER, "PLAYER_CHOOSE_RANDOM", pPlayer, randomaizer);

			g_iCaptainPick = g_iCaptainPick == g_iCaptainFirst ? g_iCaptainSecond : g_iCaptainFirst;
			show_menu(pPlayer, 0, "^n", 1);

			if (task_exists(TASK_WAITCAP)) {
				remove_task(TASK_WAITCAP)
			}

			checkFullTeams();
			pickMenu(g_iCaptainPick, true);

			return;

		}
		else {
			if (task_exists(TASK_WAITCAP)) {
				remove_task(TASK_WAITCAP)
			}
		}
	}
}


GetPickRandom() {
	new iChoose;
	static iPlayers[MAX_PLAYERS], iNum
	get_players(iPlayers, iNum, "che", "SPECTATOR");

	new iSpecPlayers[MAX_PLAYERS], iSpecNum;

	for (new i; i < iNum; i++) {
		if (!is_user_connected(iPlayers[i])) {
			continue;
		}

		if (g_bNoplay[iPlayers[i]]) {
			continue;
		}

		iSpecPlayers[iSpecNum] = iPlayers[i];
		iSpecNum++;
	}

	if (iSpecNum == 0) {
		return 0;
	}

	if (iSpecNum > 1) {
		iChoose = iSpecPlayers[random(iSpecNum)];
	} else {
		iChoose = iSpecPlayers[iSpecNum - 1];
	}

	return iChoose;
}

public checkFullTeams() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	new iPlayersMatch;
	new iPlayersNotMatch;
	for (new i; i < iNum; i++) {
		new tempid = iPlayers[i];

		if(g_bNoplay[tempid]) { // TODO: Убрать ноплей, зачем он нужен?
			continue;
		}

		if (getUserTeam(tempid) == TEAM_SPECTATOR) {
			iPlayersNotMatch++;
			continue;
		}

		// TODO: Проверка на забаненого игрока, если он в команде и забанен, выкинуть в спеки и continue

		iPlayersMatch++;
	}

	if (iPlayersMatch == 10 || !iPlayersNotMatch || (iPlayersMatch % 2 == 0) && (iPlayersNotMatch <= 1)) {
		resetCaptainData();
		chat_print(0, "%L", LANG_PLAYER, "TEAM_FULL");
		g_iMatchStatus = MATCH_TEAMKNIFE;
		kniferound_start();
	}
}

resetCaptainData() {
	g_iCaptainPick = 0;

	if (task_exists(TASK_WAITCAP)) {
		remove_task(TASK_WAITCAP)
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];

		arrayset(g_ePlayerInfo[id], 0, PLAYER_INFO);
	}

	if (is_user_connected(g_iCaptainFirst)) {
		show_menu(g_iCaptainFirst, 0, "^n", 1);
	}

	if (is_user_connected(g_iCaptainSecond)) {
		show_menu(g_iCaptainSecond, 0, "^n", 1);
	}

	g_iCaptainFirst = 0;
	g_iCaptainSecond = 0;
}
