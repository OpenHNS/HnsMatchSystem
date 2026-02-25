#if defined _captain_included
  #endinput
#endif

#define _captain_included

new Float:RandomPickTime;
new Float:CaptainLeaveTime;

forward hns_players_replaced(requested_id, id);

/*

LogSendMessage("[MATCH]");

// TODO: Если вручную закинули игроков
// TODO: Если ливнуло 2 капитана

*/

public captain_start(id) {
	resetCaptainData();

	hns_reset_users_roles();

	g_iMatchStatus = MATCH_CAPTAINPICK;

	g_iCurrentMode = MODE_TRAINING;

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

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_CAP_CHOSE");
	new hMenu = menu_create(szMsg, "chooseCapsHandler");

	new iPlayers[MAX_PLAYERS], iNum, szPlayer[10], iPlayer;
	get_players(iPlayers, iNum, "ch");

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

	if (!iCaptainA) {
		hns_set_user_role(iPlayer, ROLE_CAP_A);
		LogSendMessage("[MATCH] Captain pick A (%n)", iPlayer);
		
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
		LogSendMessage("[MATCH] Captain pick B (%n)", iPlayer);

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

			if (hns_battle_init() && hns_battle_arenas_init()) {
				captainDecideMethodMenu(id);
			} else {
				start_captain_decide();
			}
		} else {
			chat_print(0, "%L", LANG_PLAYER, "CAP_HAS_LEFT");
			
			LogSendMessage("[MATCH] Captains (%d) (%d) NOT OK! Stop captain pick", iCaptainA, iCaptainB);
			
			resetCaptainData();
		}
	}
	return PLUGIN_HANDLED;
}

stock captainDecideMethodMenu(id) {
	if (!is_user_connected(id) || g_iMatchStatus != MATCH_CAPTAINPICK) {
		return;
	}

	new hMenu = menu_create("\rCaptain decide method", "captainDecideMethodHandler");
	menu_additem(hMenu, "Knife round");
	menu_additem(hMenu, "Battle race");
	menu_additem(hMenu, "Battle race (chance)");
	menu_setprop(hMenu, MPROP_EXITNAME, "Knife");
	menu_setprop(hMenu, MPROP_SHOWPAGE, 0);
	menu_display(id, hMenu, 0);
}

public captainDecideMethodHandler(id, hMenu, item) {
	menu_destroy(hMenu);

	if (g_iMatchStatus != MATCH_CAPTAINPICK) {
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT || item == 0) {
		start_captain_decide();
		return PLUGIN_HANDLED;
	}

	if (item == 1) {
		start_captain_battle_decide(id, false);
		return PLUGIN_HANDLED;
	}

	if (item == 2) {
		start_captain_battle_decide(id, true);
		return PLUGIN_HANDLED;
	}

	start_captain_decide();
	return PLUGIN_HANDLED;
}

public pickMenu(id, bool:bStartWait) {
	if (!is_user_connected(id)) {
		return PLUGIN_HANDLED;
	}

	if (hns_cup_enabled()) {
		return PLUGIN_CONTINUE;
	}

	if (g_iMatchStatus != MATCH_TEAMPICK) {
		return PLUGIN_HANDLED;
	}

	if (id != g_iCaptainPick) {
		return PLUGIN_HANDLED;
	}

	if(bStartWait == true && g_iSettings[RANDOMPICK] == 1) {
		WaitPick();
	}

	LogSendMessage("[MATCH] Open pickMenu (%n)", id);

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_CAP_PICK");
	new hMenu = menu_create(szMsg, "pickHandler");

	new iPlayers[MAX_PLAYERS], iNum, szPlayer[10], iPlayer;
	get_players(iPlayers, iNum, "che", "SPECTATOR");

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

	LogSendMessage("[MATCH] Captain (%n) pick (%n)", id, iPlayer);

	// TODO: Надо убрать hns_distribute_roles_teams делает тоже самое.
	rg_set_user_team(iPlayer, getUserTeam(id));
	rg_round_respawn(iPlayer);
	//

	hns_distribute_roles_teams();

	next_pick_menu_cap();

	return PLUGIN_HANDLED;
}

public WaitPick() {
	if (g_iMatchStatus != MATCH_TEAMPICK) {
		return PLUGIN_HANDLED;
	}

	if (task_exists(TASK_WAITCAP)) {
		remove_task(TASK_WAITCAP)
	}

	RandomPickTime = 35.0;

	LogSendMessage("[MATCH] Wait pick started.");

	set_task(1.0, "wait_function", .id = TASK_WAITCAP, .flags = "b");

	return PLUGIN_HANDLED;
}

public wait_function(id) {
	if (g_iCaptainPick == -1) {
		if (task_exists(TASK_WAITCAP)) {
			remove_task(TASK_WAITCAP)
		}
		return;
	}

	if (!is_user_connected(g_iCaptainPick)) {
		resetCaptainData();
		return;
	}

	RandomPickTime -= 1.0;
	
	if (RandomPickTime <= 10) {
		setTaskHud(0, 0.0, 1, 255, 255, 255, 1.0, "%L", LANG_SERVER, "HUD_WAITPICK", g_iCaptainPick, RandomPickTime);
	}
	
	if(RandomPickTime <= 0.0) {
		new iRandomPlayer = hns_get_random_role(ROLE_SPEC);
		if(iRandomPlayer && (iRandomPlayer != -1)) {
			new pPlayer = g_iCaptainPick;

			if (hns_is_user_role(pPlayer, ROLE_CAP_A)) {
				hns_set_user_role(iRandomPlayer, ROLE_TEAM_A);
			} else {
				hns_set_user_role(iRandomPlayer, ROLE_TEAM_B);
			}

			rg_set_user_team(iRandomPlayer, getUserTeam(pPlayer));
			rg_round_respawn(iRandomPlayer);

			chat_print(0, "%L", LANG_PLAYER, "PLAYER_CHOOSE_RANDOM", pPlayer, iRandomPlayer);

			next_pick_menu_cap();

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

public next_pick_menu_cap() {
	new iCaptainA = hns_get_captain_role(ROLE_CAP_A);
	new iCaptainB = hns_get_captain_role(ROLE_CAP_B);

	if (iCaptainA && iCaptainB) {
		g_iCaptainPick = g_iCaptainPick == iCaptainA ? iCaptainB : iCaptainA;
		get_user_authid(g_iCaptainPick, g_iCaptainPickSteam, charsmax(g_iCaptainPickSteam));

		LogSendMessage("[MATCH] Captains (%n) (%n) OK! Next pick menu (%n)", iCaptainA, iCaptainB, g_iCaptainPick);

		pickMenu(g_iCaptainPick, true);

		checkFullTeams();
	} else {
		if (!iCaptainA) {
			chat_print(0, "Captain team TT leave! Wait join captain 10 sec.");
		} else if (!iCaptainB) {
			chat_print(0, "Captain team CT leave! Wait join captain 10 sec.");
		}

		LogSendMessage("[MATCH] Captains (%n) (%n) NOT OK! Next pick menu (-1)", iCaptainA, iCaptainB);

		CaptainLeaveTime = 10.0;
		
		set_task(1.0, "WaitLeaveCap", .id = TASK_WAITLEAVECAP, .flags = "b");

		g_iCaptainPick = -1;
	}
}

public checkFullTeams() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

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
		chat_print(0, "%L", LANG_PLAYER, "TEAM_FULL"); // TODO: Чат: Ножевой раунд начнется через 5 сек
		start_team_decide(); // TODO: Добавить в худ таймер: Ножевой раунд/батл начнется через %d сек
	}
}

stock start_captain_decide() {
	new iCaptainA = hns_get_captain_role(ROLE_CAP_A);
	new iCaptainB = hns_get_captain_role(ROLE_CAP_B);

	g_iMatchStatus = MATCH_CAPTAINKNIFE;
	LogSendMessage("[MATCH] Captains (%n) (%n) OK! Start captain knife", iCaptainA, iCaptainB);
	kniferound_start();
}

stock start_captain_battle_decide(id, bool:bChance = false) {
	new iCaptainA = hns_get_captain_role(ROLE_CAP_A);
	new iCaptainB = hns_get_captain_role(ROLE_CAP_B);

	if (hns_battle_init() && hns_battle_arenas_init()) {
		if (hns_battle_menu(id, true, bChance)) {
			LogSendMessage("[MATCH] Captains (%n) (%n) OK! Open captain battle menu (chance: %d)", iCaptainA, iCaptainB, bChance);
			return;
		}
	}

	chat_print(0, "Battle menu unavailable. Fallback to knife decide.");
	LogSendMessage("[MATCH] Captains (%n) (%n) battle menu unavailable, fallback to knife", iCaptainA, iCaptainB);
	start_captain_decide();
}

stock start_team_decide() {
	g_iMatchStatus = MATCH_TEAMKNIFE;
	LogSendMessage("[MATCH] Team decide: start knife");
	kniferound_start();
}

public WaitLeaveCap() {
	if (g_iMatchStatus != MATCH_TEAMPICK) {
		if (task_exists(TASK_WAITLEAVECAP)) {
			remove_task(TASK_WAITLEAVECAP)
		}
		return;
	}

	new iCaptainA = hns_get_captain_role(ROLE_CAP_A);
	new iCaptainB = hns_get_captain_role(ROLE_CAP_B);

	if (!iCaptainA || !iCaptainB) {
		if (task_exists(TASK_WAITCAP)) {
			remove_task(TASK_WAITCAP)
		}

		setTaskHud(0, 0.0, 1, 255, 255, 255, 1.0, "Captain leave! Wait %0.f sec.", CaptainLeaveTime);

		LogSendMessage("[MATCH] Wait captain... (%n) (%n)", iCaptainA, iCaptainB);

		CaptainLeaveTime -= 1.0;

		if(CaptainLeaveTime <= 0.0) {
			if (!iCaptainA) {
				new iRandomPlayer = hns_get_random_role(ROLE_TEAM_A);

				LogSendMessage("[MATCH] (A) hns_get_random_role - (%d)", iRandomPlayer);

				if (iRandomPlayer == -1) {
					chat_print(0, "Players not found. stop team pick mode.");
					captain_stop();
					training_start();

					return;
				}

				hns_set_user_role(iRandomPlayer, ROLE_CAP_A);

				chat_print(0, "New captain team TT ^3%n^1", iRandomPlayer);

				g_iCaptainFirst = iRandomPlayer;
				g_iCaptainPick = g_iCaptainFirst;
				get_user_authid(g_iCaptainPick, g_iCaptainPickSteam, charsmax(g_iCaptainPickSteam));

				LogSendMessage("[MATCH] (A) New captain (%n)", g_iCaptainPick);

				pickMenu(g_iCaptainPick, true);
			}

			if (!iCaptainB) {
				new iRandomPlayer = hns_get_random_role(ROLE_TEAM_B);

				LogSendMessage("[MATCH] (B) hns_get_random_role - (%d)", iRandomPlayer);

				if (iRandomPlayer == -1) {
					chat_print(0, "Players not found. stop team pick mode.");
					captain_stop();
					training_start();

					return;
				}

				hns_set_user_role(iRandomPlayer, ROLE_CAP_B);
				chat_print(0, "New captain team CT ^3%n^1", iRandomPlayer);

				g_iCaptainSecond = iRandomPlayer;
				g_iCaptainPick = g_iCaptainSecond;
				get_user_authid(g_iCaptainPick, g_iCaptainPickSteam, charsmax(g_iCaptainPickSteam));

				LogSendMessage("[MATCH] (B) New captain (%n)", g_iCaptainPick);

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

	if (task_exists(TASK_WAITLEAVECAP)) {
		remove_task(TASK_WAITLEAVECAP)
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

public hns_players_replaced(requested_id, id) {
	new PLAYER_ROLES:tmpRole = g_ePlayerInfo[requested_id][PLAYER_ROLE];
	hns_set_user_role(requested_id, g_ePlayerInfo[id][PLAYER_ROLE]);
	hns_set_user_role(id, tmpRole);
}
