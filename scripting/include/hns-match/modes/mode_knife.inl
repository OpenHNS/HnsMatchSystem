public kniferound_init() {
	g_ModFuncs[MODE_KNIFE][MODEFUNC_START]		= CreateOneForward(g_PluginId, "kniferound_start");
	g_ModFuncs[MODE_KNIFE][MODEFUNC_END]		= CreateOneForward(g_PluginId, "kniferound_stop");
	g_ModFuncs[MODE_KNIFE][MODEFUNC_PAUSE]		= CreateOneForward(g_PluginId, "kniferound_pause");
	g_ModFuncs[MODE_KNIFE][MODEFUNC_UNPAUSE]	= CreateOneForward(g_PluginId, "kniferound_unpause");
	g_ModFuncs[MODE_KNIFE][MODEFUNC_ROUNDSTART]	= CreateOneForward(g_PluginId, "kniferound_roundstart");
	g_ModFuncs[MODE_KNIFE][MODEFUNC_ROUNDEND]	= CreateOneForward(g_PluginId, "kniferound_roundend", FP_CELL);
	g_ModFuncs[MODE_KNIFE][MODEFUNC_PLAYER_JOIN]= CreateOneForward(g_PluginId, "kniferound_player_join", FP_CELL);
}

public kniferound_start() {
	g_iCurrentMode = MODE_KNIFE;
	ChangeGameplay(GAMEPLAY_KNIFE);
	set_cvars_mode(MODE_KNIFE);
	g_eMatchState = STATE_PREPARE;
	restartRound(1.0);
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

	restartRound(1.0);

	ChangeGameplay(GAMEPLAY_KNIFE);

	set_unpause_settings();
}
 
public kniferound_roundstart() {
	switch (g_iMatchStatus) {
		case MATCH_CAPTAINKNIFE: {
			setTaskHud(0, 2.0, 1, 255, 255, 255, 3.0, "%L", LANG_PLAYER, "HUD_START_CAPKF");
			chat_print(0, "%L", LANG_PLAYER, "START_KNIFE");
			ChangeGameplay(GAMEPLAY_KNIFE);
			g_eMatchState = STATE_ENABLED;
		}
		case MATCH_TEAMKNIFE: {
			setTaskHud(0, 2.0, 1, 255, 255, 255, 3.0, "%L", LANG_PLAYER, "HUD_STARTKNIFE");
			chat_print(0, "%L", LANG_PLAYER, "START_KNIFE");
			ChangeGameplay(GAMEPLAY_KNIFE);
			g_eMatchState = STATE_ENABLED;

			if (g_bHnsBannedInit) {
				checkUserBan();
			}

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
			g_iCaptainPick = win_ct ? g_iCaptainSecond : g_iCaptainFirst;

			setTaskHud(0, 2.0, 1, 255, 255, 255, 3.0, fmt("%L", LANG_SERVER, "HUD_CAPWIN", g_iCaptainPick));

			training_start();

			g_iMatchStatus = MATCH_TEAMPICK;

			g_eMatchState = STATE_DISABLED;

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

			g_eMatchState = STATE_DISABLED;

			Save_players(win_ct ? TEAM_CT : TEAM_TERRORIST);
			training_start();
			g_iMatchStatus = MATCH_MAPPICK;
			StartVoteRules();
		}
	}
	ChangeGameplay(GAMEPLAY_TRAINING);
}

public kniferound_player_join(id) {
	transferUserToSpec(id);
}