public kniferound_init() {
	g_ModFuncs[MODE_KNIFE][MODEFUNC_START]			= CreateOneForward(g_PluginId, "kniferound_start");
	g_ModFuncs[MODE_KNIFE][MODEFUNC_END]			= CreateOneForward(g_PluginId, "kniferound_stop");
	g_ModFuncs[MODE_KNIFE][MODEFUNC_PAUSE]			= CreateOneForward(g_PluginId, "kniferound_pause");
	g_ModFuncs[MODE_KNIFE][MODEFUNC_UNPAUSE]		= CreateOneForward(g_PluginId, "kniferound_unpause");
	g_ModFuncs[MODE_KNIFE][MODEFUNC_ROUNDSTART]		= CreateOneForward(g_PluginId, "kniferound_roundstart");
	g_ModFuncs[MODE_KNIFE][MODEFUNC_ROUNDEND]		= CreateOneForward(g_PluginId, "kniferound_roundend", FP_CELL);
	g_ModFuncs[MODE_KNIFE][MODEFUNC_PLAYER_LEAVE]	= CreateOneForward(g_PluginId, "kniferound_player_leave", FP_CELL);
	g_ModFuncs[MODE_KNIFE][MODEFUNC_PLAYER_JOIN]	= CreateOneForward(g_PluginId, "kniferound_player_join", FP_CELL);
}

public kniferound_start() {
	g_iCurrentMode = MODE_KNIFE;
	ChangeGameplay(GAMEPLAY_KNIFE);
	set_cvars_mode(MODE_KNIFE);
	g_eMatchState = STATE_PREPARE;
	hns_restart_round(1.0);
}

public kniferound_stop() {
	g_iMatchStatus = MATCH_NONE;
	training_start();
}

public kniferound_pause() {
	if (g_eMatchState == STATE_PAUSED) {
		return;
	}
	g_eMatchState = STATE_PAUSED;

	ChangeGameplay(GAMEPLAY_TRAINING);

	set_pause_settings();
}

public kniferound_unpause() {
	if (g_eMatchState != STATE_PAUSED) {
		return;
	}
	g_eMatchState = STATE_PREPARE;

	hns_restart_round(1.0);

	ChangeGameplay(GAMEPLAY_KNIFE);

	set_unpause_settings();
}
 
public kniferound_roundstart() {
	switch (g_iMatchStatus) {
		case MATCH_CAPTAINKNIFE: {
			setTaskHud(0, 2.0, 1, 255, 255, 255, 3.0, "%L", LANG_PLAYER, "HUD_START_CAPKF");
			
			chat_print(0, "%L", LANG_PLAYER, "START_KNIFE");

			g_eMatchState = STATE_ENABLED;

			ChangeGameplay(GAMEPLAY_KNIFE);
		}
		case MATCH_TEAMKNIFE: {
			setTaskHud(0, 2.0, 1, 255, 255, 255, 3.0, "%L", LANG_PLAYER, "HUD_STARTKNIFE");
			
			chat_print(0, "%L", LANG_PLAYER, "START_KNIFE");

			g_eMatchState = STATE_ENABLED;

			ChangeGameplay(GAMEPLAY_KNIFE);

			if (g_bHnsBannedInit) {
				if (checkUserBan()) {
					return;
				}
			}

			ResetAfkData();
			set_task(2.0, "taskSaveAfk");
			set_task(4.0, "taskCheckAfk");
		}
		case MATCH_CUPKNIFE: {
			setTaskHud(0, 2.0, 1, 255, 255, 255, 3.0, "Pick/Ban knife started!");
			
			chat_print(0, "Started ^3knife Pick/Ban^1 round!");

			g_eMatchState = STATE_ENABLED;

			ChangeGameplay(GAMEPLAY_KNIFE);

			ResetAfkData();
			set_task(2.0, "taskSaveAfk");
			set_task(4.0, "taskCheckAfk");
		}
		default: {
			ChangeGameplay(GAMEPLAY_TRAINING);
		}
	}
}

public kniferound_roundend(bool:win_ct) {
	switch(g_iMatchStatus) {
		case MATCH_CAPTAINKNIFE: {
			g_iCaptainPick = win_ct ? hns_get_captain_role(ROLE_CAP_B) : hns_get_captain_role(ROLE_CAP_A);
			get_user_authid(g_iCaptainPick, g_iCaptainPickSteam, charsmax(g_iCaptainPickSteam))

			//setTaskHud(0, 2.0, 1, 255, 255, 255, 3.0, fmt("%L", LANG_SERVER, "HUD_CAPWIN", g_iCaptainPick));

			training_start();

			g_iMatchStatus = MATCH_TEAMPICK;

			g_eMatchState = STATE_DISABLED;

			LogSendMessage("[MATCH] Captain (%n) win kf, choose player.", g_iCaptainPick);

			pickMenu(g_iCaptainPick, true);

			if (g_iSettings[RANDOMPICK] == 1) {
				set_task(1.0, "WaitPick");
			}
		}
		case MATCH_TEAMKNIFE: {
			if (win_ct) {
				setTaskHud(0, 2.0, 1, 255, 255, 255, 3.0, "%L", LANG_SERVER, "HUD_KF_WIN_CT");
			} else {
				setTaskHud(0, 2.0, 1, 255, 255, 255, 3.0, "%L", LANG_SERVER, "HUD_KF_WIN_TT");
			}

			training_start();

			g_iMatchStatus = MATCH_MAPPICK;

			g_eMatchState = STATE_DISABLED;

			Save_players(win_ct ? TEAM_CT : TEAM_TERRORIST);

			StartVoteRules();
		}
		case MATCH_CUPKNIFE: {
			training_start();

			g_iMatchStatus = MATCH_CUPPICK;

			g_eMatchState = STATE_DISABLED;

			// TODO: Старт веты победителю (win_ct)
		}
	}
	ChangeGameplay(GAMEPLAY_TRAINING);

	// TODO: Кайф без state
}

public kniferound_player_leave(id) {
	switch (g_iMatchStatus) {
		case MATCH_CAPTAINKNIFE: {
			if (hns_is_user_role(id, ROLE_CAP_A) || hns_is_user_role(id, ROLE_CAP_B)) {
				LogSendMessage("[MATCH] Player captain (%n) leave! (MATCH_CAPTAINKNIFE)", id);
				chat_print(0, "Captain ^3%n^1 leave, stop captain knife mode.", id);
				captain_stop();
				training_start();
			}
		}
	}
}

public kniferound_player_join(id) {
	transferUserToSpec(id);
}