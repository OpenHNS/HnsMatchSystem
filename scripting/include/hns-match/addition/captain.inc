#if defined _captain_included
  #endinput
#endif

#define _captain_included

new Float:RandomPickTime;
new Float:CaptainLeaveTime;
/*

LogSendMessage("[MATCH]");

// TODO: Если вручную закинули игроков

*/

public captain_start(id) {
	resetCaptainData();

	hns_reset_users_roles();

	g_iMatchStatus = MATCH_CAPTAINPICK;

	g_iCurrentMode = MODE_TRAINING;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "c");
	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];

		if (getUserTeam(iPlayer) == TEAM_SPECTATOR)
			continue;

		transferUserToSpec(iPlayer);
	}
	
	chooseCapsMenu(id);

	chat_print(0, "%L", LANG_PLAYER, "CAP_CHOOSE", id);

	LogSendMessage("[MATCH] Start captain");
}

public captain_stop() {
	resetCaptainData();
	g_iMatchStatus = MATCH_NONE;
}

public chooseCapsMenu(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (g_iMatchStatus != MATCH_CAPTAINPICK)
		return PLUGIN_HANDLED;

	LogSendMessage("[MATCH] chooseCapsMenu(%n)", id);

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_CAP_CHOSE");
	new hMenu = menu_create(szMsg, "chooseCapsHandler");

	new iPlayers[MAX_PLAYERS], iNum, szPlayer[10], iPlayer;
	get_players(iPlayers, iNum, "c");

	new szBuffer[256];
	for (new i; i < iNum; i++) {
		iPlayer = iPlayers[i];

		if (g_ePlayerInfo[iPlayer][PLAYER_ROLE] == ROLE_CAP_A || g_ePlayerInfo[iPlayer][PLAYER_ROLE] == ROLE_CAP_B) {
			continue;
		}

		num_to_str(iPlayer, szPlayer, charsmax(szPlayer));

		if ((g_bHnsBannedInit && e_bBanned[iPlayer]) || g_bNoplay[iPlayer]) {
			add(szBuffer, charsmax(szBuffer), fmt("\d%n ", iPlayer));
		}
		else {
			add(szBuffer, charsmax(szBuffer), fmt("%n ", iPlayer));
		}

		if (hns_mysql_stats_init()) {
			new szPts[16];
			formatex(szPts, charsmax(szPts), "\d%d (%s) ", hns_mysql_stats_data(iPlayer, e_iPts), hns_mysql_stats_skill(iPlayer));
			add(szBuffer, charsmax(szBuffer), szPts);
		} else if (hns_api_stats_init()) {
			new szSkill[10];
			hns_api_stats_rank(iPlayer, szSkill, charsmax(szSkill));

			new szPts[16];
			formatex(szPts, charsmax(szPts), "\d%0.f (%s) ", hns_api_stats_rating(iPlayer), szSkill);
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
	LogSendMessage("[MATCH] chooseCapsHandler (%d)", id);

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

	new iCaptainA = hns_get_captain_role(ROLE_CAP_A);
	new iCaptainB = hns_get_captain_role(ROLE_CAP_B);

	LogSendMessage("[MATCH] GET CAPTAINS ROLE (%d) (%d)", iCaptainA, iCaptainB);

	if (!iCaptainA) {

		hns_set_user_role(iPlayer, ROLE_CAP_A);
		
		if (hns_mysql_stats_init()) {
			chat_print(0, "%L", LANG_PLAYER, "CAP_FIRST_PTS", iPlayer, hns_mysql_stats_data(iPlayer, e_iPts), hns_mysql_stats_skill(iPlayer));
		} else if (hns_api_stats_init()) {
			new szSkill[10];
			hns_api_stats_rank(iPlayer, szSkill, charsmax(szSkill));
			new iPts = floatround(hns_api_stats_rating(iPlayer))
			chat_print(0, "%L", LANG_PLAYER, "CAP_FIRST_PTS", iPlayer, iPts, szSkill);
		} else {
			chat_print(0, "%L", LANG_PLAYER, "CAP_FIRST", iPlayer);
		}
		chooseCapsMenu(id);
	} else if (!iCaptainB) {

		hns_set_user_role(iPlayer, ROLE_CAP_B);

		if (hns_mysql_stats_init()) {
			chat_print(0, "%L", LANG_PLAYER, "CAP_SECOND_PTS", iPlayer, hns_mysql_stats_data(iPlayer, e_iPts), hns_mysql_stats_skill(iPlayer));
		} else if (hns_api_stats_init()) {
			new szSkill[10];
			hns_api_stats_rank(iPlayer, szSkill, charsmax(szSkill));
			new iPts = floatround(hns_api_stats_rating(iPlayer))
			chat_print(0, "%L", LANG_PLAYER, "CAP_SECOND_PTS", iPlayer, iPts, szSkill);
		} else {
			chat_print(0, "%L", LANG_PLAYER, "CAP_SECOND", iPlayer);
		}

		iCaptainB = hns_get_captain_role(ROLE_CAP_B);


		if (is_user_connected(iCaptainA) && is_user_connected(iCaptainB)) {
			g_isTeamTT = HNS_TEAM_A;
			rg_set_user_team(iCaptainA, TEAM_TERRORIST);
			rg_set_user_team(iCaptainB, TEAM_CT);

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

	// TODO: Сбрасывается если /pick?
	if(bStartWait == true && g_iSettings[RANDOMPICK] == 1) {
		WaitPick();
	}

	LogSendMessage("[MATCH] pickMenu (%n)", id);

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_CAP_PICK");
	new hMenu = menu_create(szMsg, "pickHandler");

	new iPlayers[MAX_PLAYERS], iNum, szPlayer[10], iPlayer;
	get_players(iPlayers, iNum, "ce", "SPECTATOR");

	new szBuffer[256];
	for (new i; i < iNum; i++) {
		iPlayer = iPlayers[i];

		if (!hns_is_user_role(iPlayer, ROLE_SPEC)) {
			continue;
		}

		num_to_str(iPlayer, szPlayer, charsmax(szPlayer));

		if ((g_bHnsBannedInit && e_bBanned[iPlayer]) || g_bNoplay[iPlayer]) {
			add(szBuffer, charsmax(szBuffer), fmt("\d%n ", iPlayer));
		} else {
			add(szBuffer, charsmax(szBuffer), fmt("%n ", iPlayer));
		}

		if (hns_mysql_stats_init()) {
			new szPts[16];
			formatex(szPts, charsmax(szPts), "\d%d (%s) ", hns_mysql_stats_data(iPlayer, e_iPts), hns_mysql_stats_skill(iPlayer));
			add(szBuffer, charsmax(szBuffer), szPts);
		} else if (hns_api_stats_init()) {
			new szSkill[10];
			hns_api_stats_rank(iPlayer, szSkill, charsmax(szSkill));

			new szPts[16];
			formatex(szPts, charsmax(szPts), "\d%0.f (%s) ", hns_api_stats_rating(iPlayer), szSkill);
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

	if (hns_mysql_stats_init()) {
		chat_print(0, "%L", LANG_PLAYER, "PLAYER_CHOOSE_PTS", id, iPlayer, hns_mysql_stats_data(iPlayer, e_iPts), hns_mysql_stats_skill(iPlayer));
	} else if (hns_api_stats_init()) {
		new szSkill[10];
		hns_api_stats_rank(iPlayer, szSkill, charsmax(szSkill));
		new iPts = floatround(hns_api_stats_rating(iPlayer))
		chat_print(0, "%L", LANG_PLAYER, "PLAYER_CHOOSE_PTS", id, iPlayer, iPts, szSkill);
	} else {
		chat_print(0, "%L", LANG_PLAYER, "PLAYER_CHOOSE", id, iPlayer);
	}

	if (hns_is_user_role(id, ROLE_CAP_A)) {
		hns_set_user_role(iPlayer, ROLE_TEAM_A);
	} else {
		hns_set_user_role(iPlayer, ROLE_TEAM_B);
	}

	hns_distribute_roles_teams();

	rg_set_user_team(iPlayer, getUserTeam(id));
	rg_round_respawn(iPlayer);

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "c");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		
		server_print("[MATCH] DEBUG ROLE %n (%d)", id, g_ePlayerInfo[id][PLAYER_ROLE]);
	}

	// TODO: Вынести в отдельную функцию
	new iCaptainA = hns_get_captain_role(ROLE_CAP_A);
	new iCaptainB = hns_get_captain_role(ROLE_CAP_B);

	if (iCaptainA && iCaptainB) {
		// TODO: Придумать
		g_iCaptainPick = g_iCaptainPick == iCaptainA ? iCaptainB : iCaptainA;
		get_user_authid(g_iCaptainPick, g_iCaptainPickSteam, charsmax(g_iCaptainPickSteam));

		LogSendMessage("[MATCH] Captain (%n) pick (%n), next pick menu (%n)", id, iPlayer, g_iCaptainPick);

		pickMenu(g_iCaptainPick, true);

		checkFullTeams();
	} else {
		// TODO: Придумать если капитан ливнул
		// Капитан ливнул, 10 сек отчета, если не вернулся то дать другому игроку капитана ?
		if (!iCaptainA) {
			LogSendMessage("[HNSRU] Captain team TT leave! Wait join captain 10 sec.");
			chat_print(0, "[^3HNSRU^1] Captain team TT leave! Wait join captain 10 sec.");
		} else if (!iCaptainB) {
			LogSendMessage("[HNSRU] Captain team CT leave! Wait join captain 10 sec.");
			chat_print(0, "[^3HNSRU^1] Captain team CT leave! Wait join captain 10 sec.");
		}

		CaptainLeaveTime = 10.0;
		
		set_task(1.0, "WaitLeaveCap", .id = TASK_WAITLEAVECAP, .flags = "b");

		g_iCaptainPick = -1;
	}
	// TODO: Вынести в отдельную функцию

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
	if (g_iCaptainPick == -1) {
		if (task_exists(TASK_WAITCAP)) {
			remove_task(TASK_WAITCAP)
		}
		return;
	}

	if (!is_user_connected(g_iCaptainPick)) {
		server_print("uslovie wait_function")
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

			// TODO: Вынести в отдельную функцию
			new iCaptainA = hns_get_captain_role(ROLE_CAP_A);
			new iCaptainB = hns_get_captain_role(ROLE_CAP_B);

			server_print("[MATCH] wait_function");

			if (iCaptainA && iCaptainB) {
				g_iCaptainPick = g_iCaptainPick == iCaptainA ? iCaptainB : iCaptainA;
				get_user_authid(g_iCaptainPick, g_iCaptainPickSteam, charsmax(g_iCaptainPickSteam))

				LogSendMessage("[MATCH] pick (%n), next pick menu (%n)", pPlayer, g_iCaptainPick);

				pickMenu(g_iCaptainPick, true);

				checkFullTeams();
			} else {
				CaptainLeaveTime = 10.0;
		
				set_task(1.0, "WaitLeaveCap", .id = TASK_WAITLEAVECAP, .flags = "b");

				g_iCaptainPick = -1;
			}
			// TODO: Вынести в отдельную функцию

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

			LogSendMessage("[MATCH] wait_function - Players not found");
			chat_print(0, "[MATCH] wait_function - Players not found");
		}
	}
}


GetPickRandom() {
	new iChoose;
	static iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ce", "SPECTATOR");

	new iSpecPlayers[MAX_PLAYERS], iSpecNum;

	for (new i; i < iNum; i++) {
		new id = iPlayers[i]
		if (!is_user_connected(id)) {
			continue;
		}

		if (g_bNoplay[id]) {
			continue;
		}

		if (g_bHnsBannedInit && e_bBanned[id]) {
			continue;
		}

		if (!hns_is_user_role(id, ROLE_SPEC)) {
			continue;
		}

		iSpecPlayers[iSpecNum] = id;
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
	get_players(iPlayers, iNum, "c");

	new iPlayersMatch;
	new iPlayersNotMatch;
	for (new i; i < iNum; i++) {
		new tempid = iPlayers[i];

		if (g_bHnsBannedInit && e_bBanned[tempid]) {
			continue;
		}

		if(g_bNoplay[tempid]) {
			continue;
		}

		if (hns_is_user_role(tempid, ROLE_SPEC)) {
			iPlayersNotMatch++;
		} else {
			iPlayersMatch++;
		}
	}

	// [Если игроков в матче 10] || [Если нет игроков в спеках] || [(Количество игроков чётное) и (максимум 1 в спеках)]
	if (iPlayersMatch == 10 || !iPlayersNotMatch || (iPlayersMatch % 2 == 0) && (iPlayersNotMatch <= 1)) {
		resetCaptainData();
		server_print("tut x1?")
		chat_print(0, "%L", LANG_PLAYER, "TEAM_FULL"); // TODO: Чат: Ножевой раунд начнется через 5 сек
		g_iMatchStatus = MATCH_TEAMKNIFE;
		kniferound_start(); // TODO: Добавить в худ таймер: Ножевой раунд начнется через %d сек
	}
}

// Тут реализовать время ожидания.

public WaitLeaveCap() {
	if (g_iMatchStatus != MATCH_TEAMPICK) {
		if (task_exists(TASK_WAITLEAVECAP)) {
			remove_task(TASK_WAITLEAVECAP)
		}
		return;
	}

	new iCaptainA = hns_get_captain_role(ROLE_CAP_A);
	new iCaptainB = hns_get_captain_role(ROLE_CAP_B);

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "c");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		
		server_print("[MATCH] DEBUG ROLE %n (%d)", id, g_ePlayerInfo[id][PLAYER_ROLE]);
	}

	LogSendMessage("[MATCH] !WaitLeaveCap! (%n) --- (%n)", iCaptainA, iCaptainB);

	if (!iCaptainA || !iCaptainB) {
		if (task_exists(TASK_WAITCAP)) {
			remove_task(TASK_WAITCAP)
		}

		setTaskHud(0, 0.0, 1, 255, 255, 255, 1.0, "Captain leave! Wait %d sec.", CaptainLeaveTime);

		CaptainLeaveTime -= 1.0;




		if(CaptainLeaveTime <= 0.0) {
			// Выдать нового капитана.
			new iChoose;
			static iPlayers[MAX_PLAYERS], iNum;
			new iRandomPlayers[MAX_PLAYERS], iRandomNum;

			if (!iCaptainA) {
				get_players(iPlayers, iNum, "ce", "TERRORIST");
				for (new i; i < iNum; i++) {
					new id = iPlayers[i];

					if (!hns_is_user_role(id, ROLE_TEAM_A)) {
						continue;
					}

					iRandomPlayers[iRandomNum] = id;
					iRandomNum++;
				}

				if (iRandomNum == 0) {
					chat_print(0, "Players not found. stop team pick mode.");
					captain_stop();
					training_start();
					
					if (task_exists(TASK_WAITLEAVECAP)) {
						remove_task(TASK_WAITLEAVECAP)
					}
					return;
				}

				if (iRandomNum > 1) {
					iChoose = iRandomPlayers[random(iRandomNum)];
				} else {
					iChoose = iRandomPlayers[iRandomNum - 1];
				}

				hns_set_user_role(iChoose, ROLE_CAP_A);
				chat_print(0, "[^3HNSRU^1] New captain team TT ^3%n^1", iChoose);

				g_iCaptainFirst = iChoose;
				g_iCaptainPick = g_iCaptainFirst;
				get_user_authid(g_iCaptainPick, g_iCaptainPickSteam, charsmax(g_iCaptainPickSteam))
				pickMenu(g_iCaptainPick, true);
			}

			iRandomNum = 0;
			iNum = 0;

			if (!iCaptainB) {
				get_players(iPlayers, iNum, "ce", "CT");
				for (new i; i < iNum; i++) {
					new id = iPlayers[i];

					if (!hns_is_user_role(id, ROLE_TEAM_B)) {
						continue;
					}

					iRandomPlayers[iRandomNum] = id;
					iRandomNum++;
				}

				if (iRandomNum == 0) {
					chat_print(0, "Players not found. stop team pick mode.");
					captain_stop();
					training_start();

					if (task_exists(TASK_WAITLEAVECAP)) {
						remove_task(TASK_WAITLEAVECAP)
					}
					return;
				}

				if (iRandomNum > 1) {
					iChoose = iRandomPlayers[random(iRandomNum)];
				} else {
					iChoose = iRandomPlayers[iRandomNum - 1];
				}

				hns_set_user_role(iChoose, ROLE_CAP_B);
				chat_print(0, "[^3HNSRU^1] New captain team CT ^3%n^1", iChoose);

				g_iCaptainSecond = iChoose;
				g_iCaptainPick = g_iCaptainSecond;
				get_user_authid(g_iCaptainPick, g_iCaptainPickSteam, charsmax(g_iCaptainPickSteam))
				pickMenu(g_iCaptainPick, true);
			}
		}

	} else {
		if (task_exists(TASK_WAITLEAVECAP)) {
			
			remove_task(TASK_WAITLEAVECAP)
		}
	}

}

resetCaptainData() {
	g_iCaptainPick = 0;
	g_iCaptainPickSteam = "";

	if (task_exists(TASK_WAITCAP)) {
		remove_task(TASK_WAITCAP)
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "c");

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
