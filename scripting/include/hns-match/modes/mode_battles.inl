public battlesmode_init() {
	g_ModFuncs[MODE_BATTLES][MODEFUNC_START] = CreateOneForward(g_PluginId, "battlesmode_start");
	g_ModFuncs[MODE_BATTLES][MODEFUNC_ROUNDSTART] = CreateOneForward(g_PluginId, "battlesmode_roundstart");
	g_ModFuncs[MODE_BATTLES][MODEFUNC_ROUNDEND] = CreateOneForward(g_PluginId, "battlesmode_roundend", FP_CELL);
	g_ModFuncs[MODE_BATTLES][MODEFUNC_PLAYER_JOIN] = CreateOneForward(g_PluginId, "battlesmode_player_join", FP_CELL);
	g_ModFuncs[MODE_BATTLES][MODEFUNC_PLAYER_LEAVE] = CreateOneForward(g_PluginId, "battlesmode_player_leave", FP_CELL);
}

public hns_battles_started(iArena, bool:bRaceMode) {
	if (g_ModFuncs[MODE_BATTLES][MODEFUNC_START]) {
		ExecuteForward(g_ModFuncs[MODE_BATTLES][MODEFUNC_START], _);
	} else {
		battlesmode_start();
	}
}

public hns_battles_finished(TeamName:iWinnerTeam, bool:bRaceMode) {
	if (bRaceMode) {
		return;
	}

	if (g_ModFuncs[MODE_BATTLES][MODEFUNC_ROUNDEND]) {
		ExecuteForward(g_ModFuncs[MODE_BATTLES][MODEFUNC_ROUNDEND], _, iWinnerTeam == TEAM_CT);
	}
}

public battlesmode_start() {
	g_iCurrentMode = MODE_BATTLES;
	ChangeGameplay(GAMEPLAY_BATTLERACE);
	set_cvars_mode(MODE_BATTLES);
	set_semiclip(SEMICLIP_ON);
}

public battlesmode_roundstart() {
	if (g_iCurrentGameplay != GAMEPLAY_BATTLERACE) {
		ChangeGameplay(GAMEPLAY_BATTLERACE);
	} else {
		set_semiclip(SEMICLIP_ON);
	}
}

public battlesmode_roundend(bool:win_ct) {
	switch (g_iMatchStatus) {
		case MATCH_CAPTAINBATTLE: {
			g_iCaptainPick = win_ct ? hns_get_captain_role(ROLE_CAP_B) : hns_get_captain_role(ROLE_CAP_A);
			get_user_authid(g_iCaptainPick, g_iCaptainPickSteam, charsmax(g_iCaptainPickSteam));

			training_start();
			g_iMatchStatus = MATCH_TEAMPICK;
			g_eMatchState = STATE_DISABLED;

			LogSendMessage("[MATCH] Captain (%n) win battle, choose player.", g_iCaptainPick);

			pickMenu(g_iCaptainPick, true);
			if (g_iSettings[RANDOMPICK] == 1) {
				set_task(1.0, "WaitPick");
			}
		}
		case MATCH_TEAMBATTLE: {
			if (win_ct) {
				setTaskHud(0, 2.0, 1, 255, 255, 255, 3.0, "%L", LANG_SERVER, "HUD_KF_WIN_CT");
			} else {
				setTaskHud(0, 2.0, 1, 255, 255, 255, 3.0, "%L", LANG_SERVER, "HUD_KF_WIN_TT");
			}

			training_start();
			g_iMatchStatus = MATCH_MAPPICK;
			g_eMatchState = STATE_DISABLED;

			Save_players(win_ct ? TEAM_CT : TEAM_TERRORIST);
			if (!hns_cup_enabled()) {
				StartVoteRules();
			}
		}
		case MATCH_BATTLERACE: {
			training_start();
			g_iMatchStatus = MATCH_NONE;
			g_eMatchState = STATE_DISABLED;
		}
	}

	ChangeGameplay(GAMEPLAY_TRAINING);
}

public battlesmode_player_join(id) {
	if (g_iMatchStatus == MATCH_CAPTAINBATTLE || g_iMatchStatus == MATCH_TEAMBATTLE) {
		transferUserToSpec(id);
		return;
	}

	if (!is_user_connected(id) || getUserTeam(id) == TEAM_SPECTATOR) {
		return;
	}

	if (!is_user_alive(id)) {
		rg_round_respawn(id);
	}
}

public battlesmode_player_leave(id) {
	if (g_iMatchStatus == MATCH_CAPTAINBATTLE) {
		if (hns_is_user_role(id, ROLE_CAP_A) || hns_is_user_role(id, ROLE_CAP_B)) {
			LogSendMessage("[MATCH] Player captain (%n) leave! (MATCH_CAPTAINBATTLE)", id);
			chat_print(0, "Captain ^3%n^1 leave, stop captain battle mode.", id);
			captain_stop();
			training_start();
		}
	}

	arrayset(g_ePlayerInfo[id], 0, PLAYER_INFO);
}
