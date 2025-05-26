new Float:flWaitPlayersTime;

public mode_init() {
	set_task(30.0, "Task_CheckTime", 120, .flags = "b");

	set_task(0.5, "delayed_mode");
}

public delayed_mode() {
	PDS_GetCell("match_mode", g_iCurrentMode);
	PDS_GetCell("match_gameplay", g_iCurrentGameplay);
	PDS_GetCell("match_status", g_iMatchStatus);
	PDS_GetCell("match_rules", g_iCurrentRules);

	if (equali(g_iSettings[KNIFEMAP], g_szMapName)) {
		g_iMatchStatus = MATCH_NONE;
		training_start();
	} else if (g_iMatchStatus == MATCH_MAPPICK || g_iMatchStatus == MATCH_WAITCONNECT) {
		g_iMatchStatus = MATCH_WAITCONNECT;
		training_start();
		if (g_aPlayersLoadData) {
			flWaitPlayersTime = 180.0;
			set_task(1.0, "wait_players", .id = TASK_WAIT, .flags = "b");
		}
	} else if (g_iCurrentGameplay == GAMEPLAY_HNS && g_iCurrentMode == MODE_PUB) {
		pub_start();
	} else if (g_iCurrentGameplay == GAMEPLAY_HNS && g_iCurrentMode == MODE_DM) {
		dm_start();
	} else {
		if (!g_iSettings[RULES]) {
			g_iCurrentRules = RULES_MR;
		} else {
			g_iCurrentRules = RULES_TIMER;
		}
		g_iMatchStatus = MATCH_NONE;
		training_start();
	}
}

public wait_players() {
	if (g_iMatchStatus == MATCH_STARTED) {
		if(task_exists(TASK_WAIT)) {
			remove_task(TASK_WAIT);
		}
		return PLUGIN_HANDLED;
	}

	if (task_exists(TASK_STARTED)) {
		setTaskHud(0, 0.0, 1, 255, 255, 255, 1.0, "%L", LANG_SERVER, "HUD_START_LAST");
	} else {
		new iNum = get_num_players_in_match();

		if (iNum >= ArraySize(g_aPlayersLoadData)) {
			set_task(15.0, "mix_start", TASK_STARTED);
			return PLUGIN_HANDLED;
		}

		flWaitPlayersTime -= 1.0;

		new sTime[24];
		fnConvertTime(flWaitPlayersTime, sTime, charsmax(sTime));
		setTaskHud(0, 0.0, 1, 255, 255, 255, 1.0, "%L", LANG_SERVER, "HUD_START_WAIT", sTime, ArraySize(g_aPlayersLoadData) - iNum);

		if (flWaitPlayersTime <= 0.0) {
			if(task_exists(TASK_WAIT)) {
				remove_task(TASK_WAIT);
			}
		}
	}

	return PLUGIN_HANDLED;
}

public Task_CheckTime() {
	if(g_iCurrentMode == MODE_MIX) {
		return PLUGIN_HANDLED;
	}

	if((g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_ZM) && g_iCurrentGameplay == GAMEPLAY_HNS) {
		return PLUGIN_HANDLED;
	}

	new iPlayers[MAX_PLAYERS], iNum
	get_players(iPlayers, iNum, "ch");

	if (iNum == 0) {
		// if (equali(g_szMapName, g_iSettings[KNIFEMAP]))
		// {
		// 	server_cmd("changelevel boost_qube02");
		// }
		dm_start();
	}
	
	return PLUGIN_CONTINUE;
}