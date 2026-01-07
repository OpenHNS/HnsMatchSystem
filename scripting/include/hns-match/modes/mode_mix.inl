public mix_init() {
	g_ModFuncs[MODE_MIX][MODEFUNC_START]		= CreateOneForward(g_PluginId, "mix_start");
	g_ModFuncs[MODE_MIX][MODEFUNC_END]			= CreateOneForward(g_PluginId, "mix_stop");
	g_ModFuncs[MODE_MIX][MODEFUNC_PAUSE]		= CreateOneForward(g_PluginId, "mix_pause");
	g_ModFuncs[MODE_MIX][MODEFUNC_UNPAUSE]		= CreateOneForward(g_PluginId, "mix_unpause");
	g_ModFuncs[MODE_MIX][MODEFUNC_ROUNDSTART]	= CreateOneForward(g_PluginId, "mix_roundstart");
	g_ModFuncs[MODE_MIX][MODEFUNC_ROUNDEND]		= CreateOneForward(g_PluginId, "mix_roundend", FP_CELL);
	g_ModFuncs[MODE_MIX][MODEFUNC_FREEZEEND]	= CreateOneForward(g_PluginId, "mix_freezeend");
	g_ModFuncs[MODE_MIX][MODEFUNC_RESTARTROUND]	= CreateOneForward(g_PluginId, "mix_restartround");
	g_ModFuncs[MODE_MIX][MODEFUNC_SWAP]			= CreateOneForward(g_PluginId, "mix_swap");
	g_ModFuncs[MODE_MIX][MODEFUNC_PLAYER_JOIN]	= CreateOneForward(g_PluginId, "mix_player_join", FP_CELL);
	g_ModFuncs[MODE_MIX][MODEFUNC_PLAYER_LEAVE]	= CreateOneForward(g_PluginId, "mix_player_leave", FP_CELL);
}

public mix_start() {
	match_reset_data();

	ChangeGameplay(GAMEPLAY_HNS);

	g_iCurrentMode = MODE_MIX;
	g_iMatchStatus = MATCH_STARTED;
	g_eMatchState = STATE_PREPARE;

	g_isTeamTT = HNS_TEAM_A;

	g_eSurrenderData[e_sFlDelay] = get_gametime() + g_iSettings[SURTIMEDELAY];

	set_cvars_mode(MODE_MIX);

	loadMapCFG();

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ce", "TERRORIST");
	g_eMatchInfo[e_mTeamSizeTT] = iNum;
	g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();

	hns_restart_round(2.0);

	rg_send_audio(0, "plats/elevbell1.wav");
	setTaskHud(0, 0.0, 1, 255, 255, 255, 3.0, "%L", LANG_SERVER, "HUD_STARTMIX1");
	setTaskHud(0, 3.1, 1, 255, 255, 255, 3.0, "%L", LANG_SERVER, "HUD_STARTMIX2");

	ExecuteForward(g_hForwards[MATCH_START], _);
}


public mix_freezeend() {
	if (g_eMatchState != STATE_ENABLED) {
		return PLUGIN_HANDLED;
	}

	set_task(5.0, "taskCheckAfk");
	
	if (g_bHnsBannedInit) {
		if (checkUserBan()) {
			return PLUGIN_HANDLED;
		}
	}

	if (g_iCurrentRules == RULES_POINTS) {
		if (task_exists(TASK_POINTS)) {
			remove_task(TASK_POINTS);
		}
		set_task(0.5, "taskPoints1v1", .id = TASK_POINTS, .flags = "b");
	} else {
		set_task(0.25, "taskRoundEvent", .id = TASK_TIMER, .flags = "b");
	}

	if(g_eMatchInfo[e_mLeaved]) {
		set_task(1.0, "mix_pause");
	}

	return PLUGIN_HANDLED;
}

public mix_restartround() {
	if (g_eMatchState == STATE_ENABLED) {
		mix_reverttimer();
		g_eMatchState = STATE_PREPARE;
	}

	ResetAfkData();
}


public mix_pause() {
	if (g_eMatchState == STATE_PAUSED) {
		return;
	}

	mix_reverttimer();

	g_eMatchState = STATE_PAUSED;

	ChangeGameplay(GAMEPLAY_TRAINING);

	set_pause_settings();
}

public mix_unpause() {
	if (g_eMatchState != STATE_PAUSED) {
		return;
	}

	g_eMatchState = STATE_PREPARE;

	hns_restart_round(1.0);

	g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();

	ChangeGameplay(GAMEPLAY_HNS);

	set_unpause_settings();
}


public mix_swap() {
	g_isTeamTT = HNS_TEAM:!g_isTeamTT;

	ResetAfkData();
}


public mix_stop() {
	ExecuteForward(g_hForwards[MATCH_CANCEL], _);

	match_reset_data();

	training_start();
}


public mix_roundstart() {
	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}
	if(task_exists(TASK_POINTS)) {
		remove_task(TASK_POINTS);
	}

	if (g_eMatchState == STATE_PREPARE) {
		g_eMatchState = STATE_ENABLED;
	}

	g_flRoundTime = 0.0;

	cmdShowTimers(0);

	ResetAfkData();

	if (g_bHnsBannedInit) {
		checkUserBan();
	}

	taskCheckLeave();																

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "che", "TERRORIST");
	g_eMatchInfo[e_mTeamSizeTT] = iNum;

	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];

		if (!is_user_connected(id)) {
			continue;
		}
	
		if (getUserTeam(id) == TEAM_TERRORIST || getUserTeam(id) == TEAM_CT) {
			g_ePlayerInfo[id][PLAYER_MATCH] = true;
			copy(g_ePlayerInfo[id][PLAYER_TEAM], charsmax(g_ePlayerInfo[][PLAYER_TEAM]), fmt("%s", getUserTeam(id) == TEAM_TERRORIST ? "TERRORIST" : "CT"));
		} else {
			g_ePlayerInfo[id][PLAYER_MATCH] = false;
		}
	}

	set_task(0.3, "taskSaveAfk");

	set_task(3.0, "taskCheckAfk");
}

public taskCheckLeave() {
	if (g_iCurrentMode != MODE_MIX) {
		return;
	}

	new iNum = get_num_players_in_match();

	if (iNum < g_eMatchInfo[e_mTeamSize]) {
		// Pause Need Players
		g_eMatchInfo[e_mLeaved] = true;
		chat_print(0, "%L", LANG_PLAYER, "NEED_PAUSE", g_eMatchInfo[e_mTeamSize] - iNum)
	} else {
		iNum = iNum - g_eMatchInfo[e_mTeamSize];
		if (iNum >= 2) {
			g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();
		}

		if (g_eMatchInfo[e_tLeaveData] != Invalid_Trie) {
			new iPlayers[MAX_PLAYERS], iCount;
			get_players(iPlayers, iCount, "ch");
			for (new i; i < iCount; i++) {
				TrieDeleteKey(g_eMatchInfo[e_tLeaveData], getUserKey(iPlayers[i]));
			}
		}

		g_eMatchInfo[e_mLeaved] = false;
	}
}

public MixFinishedMR(iWinTeam) {
	ExecuteForward(g_hForwards[MATCH_FINISH], _, iWinTeam);

	new Float:TimeDiff = floatabs(g_eMatchInfo[e_flSidesTime][g_isTeamTT] - g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]);
	new szTime[24];
	fnConvertTime(TimeDiff, szTime, charsmax(szTime));
	chat_print(0, "%L", LANG_PLAYER, "MR_WIN", iWinTeam == 1 ? "TT" : "CT", szTime);
	
	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "%L", LANG_SERVER, "HUD_GAMEOVER");
	
	match_reset_data();
	
	training_start();

	ExecuteForward(g_hForwards[MATCH_FINISH_POST], _, iWinTeam);
}

public MixFinishedWT() {
	ExecuteForward(g_hForwards[MATCH_FINISH], _, 1);

	new Float:TimeDiff = floatabs(g_eMatchInfo[e_flSidesTime][g_isTeamTT] - g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]);
	
	new szTime[24];
	fnConvertTime(TimeDiff, szTime, charsmax(szTime), false);
	
	chat_print(0, "%L", LANG_PLAYER, "TT_WIN", szTime);
	
	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "%L", LANG_SERVER, "HUD_GAMEOVER");

	match_reset_data(true);

	training_start();

	ExecuteForward(g_hForwards[MATCH_FINISH_POST], _, 1);
}

public MixFinishedDuel() {
	ExecuteForward(g_hForwards[MATCH_FINISH], _, 1);
	
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "che", "TERRORIST");

	chat_print(0, "%L", LANG_PLAYER, "DUEL_WIN", iPlayers[0]);
	
	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "%L", LANG_SERVER, "HUD_GAMEOVER");

	match_reset_data(true);

	training_start();

	ExecuteForward(g_hForwards[MATCH_FINISH_POST], _, 1);
}

public MixFinishedPoints(iWinTeam) {
	ExecuteForward(g_hForwards[MATCH_FINISH], _, iWinTeam);

	new Float:pointsDiff = floatabs(g_eMatchInfo[e_flSidesTime][g_isTeamTT] - g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]);
	chat_print(0, "Points 1vs1 winner: %s (diff %.1f)", iWinTeam == 1 ? "TT" : "CT", pointsDiff);

	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "%L", LANG_SERVER, "HUD_GAMEOVER");

	match_reset_data();

	training_start();

	ExecuteForward(g_hForwards[MATCH_FINISH_POST], _, iWinTeam);
}

public mix_roundend(bool:win_ct) {
	if (g_eMatchState != STATE_ENABLED) {
		return;
	}

	g_eMatchState = STATE_PREPARE;

	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}
	if(task_exists(TASK_POINTS)) {
		remove_task(TASK_POINTS);
	}

	switch (g_iCurrentRules) {
		case RULES_MR: {
			g_eMatchInfo[e_iSidesRounds][g_isTeamTT]++;

			new iPlayers[MAX_PLAYERS], iNum;
			get_players(iPlayers, iNum, "ache", "CT");

			if (!iNum) {
				new Float:roundtime = get_round_time() * 60.0;
				g_eMatchInfo[e_flSidesTime][g_isTeamTT] += roundtime - g_flRoundTime;
			}

			if (g_eMatchInfo[e_iSidesRounds][g_isTeamTT] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM:!g_isTeamTT] >= g_iSettings[MAXROUNDS] * 2) {
				new HNS_TEAM:win_team = HNS_TEAM:-1;
				if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] > g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]) {
					win_team = g_isTeamTT;
				} else if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] < g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]) {
					win_team = HNS_TEAM:!g_isTeamTT;
				}

				if (win_team != HNS_TEAM:-1)
					MixFinishedMR(win_team == g_isTeamTT ? 1 : 2);
				else {
					hns_swap_teams();
					chat_print(0, "%L", LANG_PLAYER, "SAME_TIMER");
					g_iSettings[MAXROUNDS] += 2;
				}
			} else {
				hns_swap_teams();
				if (g_eMatchInfo[e_iSidesRounds][g_isTeamTT] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM:!g_isTeamTT] >= (g_iSettings[MAXROUNDS] * 2) - 1) {
					new sTime[24];
					if (g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] - (get_round_time() * 60.0) > g_eMatchInfo[e_flSidesTime][g_isTeamTT]) {
						// variant kogda tt josko proebivaut (bolwe 4em roundtime)
						fnConvertTime(g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] - g_eMatchInfo[e_flSidesTime][g_isTeamTT], sTime, charsmax(sTime));
						setTaskHud(0, 3.0, 1, 255, 255, 255, 5.0, "%L", LANG_SERVER, "HUD_WIN_CT", sTime);
					} else if (g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] > g_eMatchInfo[e_flSidesTime][g_isTeamTT]) {
						// samii default variant
						fnConvertTime(g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] - g_eMatchInfo[e_flSidesTime][g_isTeamTT], sTime, charsmax(sTime));
						setTaskHud(0, 3.0, 1, 255, 255, 255, 5.0, fmt("%L", LANG_SERVER, "HUD_TIMETOWIN", sTime));
					} else {
						setTaskHud(0, 3.0, 1, 255, 255, 255, 5.0, "%L", LANG_SERVER, "HUD_WIN_TT");
					}
				}
			}
		}
		case RULES_TIMER: {
			g_eMatchInfo[e_iSidesRounds][g_isTeamTT]++

			new iPlayers[MAX_PLAYERS], iNum;
			get_players(iPlayers, iNum, "ache", "CT");

			if (!iNum) {
				new Float:roundtime = get_round_time() * 60.0;
				g_eMatchInfo[e_flSidesTime][g_isTeamTT] += roundtime - g_flRoundTime;
			}

			if (win_ct) {
				hns_swap_teams();
			}
		}
		case RULES_DUEL: {
			if (win_ct) {
				hns_swap_teams();
			} else {
				g_eMatchInfo[e_iSidesRounds][g_isTeamTT]++
			}
			
			if(g_eMatchInfo[e_iSidesRounds][g_isTeamTT] >= g_iSettings[DUELROUNDS]) {
				MixFinishedDuel();
			}
		}
		case RULES_POINTS: {
			g_eMatchInfo[e_iSidesRounds][g_isTeamTT]++;

			if (g_eMatchInfo[e_iSidesRounds][g_isTeamTT] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM:!g_isTeamTT] >= g_iSettings[MAXROUNDS] * 2) {
				new HNS_TEAM:win_team = HNS_TEAM:-1;
				if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] > g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]) {
					win_team = g_isTeamTT;
				} else if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] < g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]) {
					win_team = HNS_TEAM:!g_isTeamTT;
				}

				if (win_team != HNS_TEAM:-1) {
					MixFinishedPoints(win_team == g_isTeamTT ? 1 : 2);
				} else {
					hns_swap_teams();
					chat_print(0, "Points tied. Adding extra rounds.");
					g_iSettings[MAXROUNDS] += 2;
				}
			} else {
				hns_swap_teams();
			}
		}
	}
}


public taskRoundEvent() {
	if (g_eMatchState != STATE_ENABLED) {
		if(task_exists(TASK_TIMER)) {
			remove_task(TASK_TIMER);
		}
		return;
	}

	g_flRoundTime += 0.25;
	g_eMatchInfo[e_flSidesTime][g_isTeamTT] += 0.25;

	if (g_flRoundTime / 60.0 >= get_round_time()) {
		remove_task(TASK_TIMER);
	}

	switch (g_iCurrentRules) {
		case RULES_MR: {
			if (g_eMatchInfo[e_iSidesRounds][g_isTeamTT] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM:!g_isTeamTT] >= (g_iSettings[MAXROUNDS] * 2) - 1) {
				if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] > g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] || g_eMatchInfo[e_flSidesTime][g_isTeamTT] < (g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] - get_round_time() * 60.0)) {
					new HNS_TEAM:iWinTeam = g_eMatchInfo[e_flSidesTime][g_isTeamTT] > g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] ? g_isTeamTT : HNS_TEAM:!g_isTeamTT;
					MixFinishedMR(iWinTeam == g_isTeamTT ? 1 : 2);
				}
			}
		}
		case RULES_TIMER: {
			new Float:flCapTime = floatmul(g_eMatchInfo[e_mWintime], 60.0);
			if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] >= flCapTime) {
				MixFinishedWT()
			}
		}
	}
}

public taskPoints1v1() {
	if (g_iCurrentMode != MODE_MIX || g_iCurrentRules != RULES_POINTS || g_eMatchState != STATE_ENABLED) {
		if (task_exists(TASK_POINTS)) {
			remove_task(TASK_POINTS);
		}
		return;
	}

	new ttPlayers[MAX_PLAYERS], ctPlayers[MAX_PLAYERS], ttNum, ctNum;
	get_players(ttPlayers, ttNum, "ahe", "TERRORIST");
	get_players(ctPlayers, ctNum, "ahe", "CT");

	if (ttNum != 1 || ctNum != 1) {
		// TODO: учитывать ситуацию, когда игроков больше или один отсутствует.
		g_iPointsDistance = 0;
		g_iPlayerDistance = 0;
		return;
	}

	new ttOrigin[3], ctOrigin[3];
	get_user_origin(ttPlayers[0], ttOrigin);
	get_user_origin(ctPlayers[0], ctOrigin);

	new iDistance = get_distance(ttOrigin, ctOrigin);
	new iDist1 = g_iSettings[POINTS_DISTANCE_1];
	new iDist2 = g_iSettings[POINTS_DISTANCE_2];
	new iDist3 = g_iSettings[POINTS_DISTANCE_3];
	g_iPointsDistance = points_calc_distance_value(iDistance, iDist1, iDist2, iDist3);
	g_iPlayerDistance = iDistance;

	new Float:pointsAdd = 0.0;
	new iRange = 0;

	if (iDistance <= iDist1) {
		pointsAdd = g_iSettings[POINTS_ADD_1];
		iRange = 1;
	} else if (iDistance <= iDist2) {
		pointsAdd = g_iSettings[POINTS_ADD_2];
		iRange = 2;
	} else if (iDistance <= iDist3) {
		pointsAdd = g_iSettings[POINTS_ADD_3];
		iRange = 3;
	}

	if (g_iSettings[POINTS_B_DEBUG]) {
		new r, g, b;
		switch (iRange) {
			case 1: { r = 0; g = 255; b = 0; }
			case 2: { r = 255; g = 255; b = 0; }
			case 3: { r = 255; g = 255; b = 255; }
			default: { r = 255; g = 0; b = 0; }
		}
		te_create_beam_between_entities(ttPlayers[0], ctPlayers[0], iBeam, 0, 10, 5, 1, 0, r, g, b, 150, 0);
	}

	if (g_iSettings[POINTS_D_DEBUG]) {
		points_draw_debug_lines(ttOrigin, iDist1, 0, 255, 0);
		points_draw_debug_lines(ttOrigin, iDist2, 255, 255, 0);
		points_draw_debug_lines(ttOrigin, iDist3, 255, 255, 255);
	}

	if (pointsAdd > 0.0) {
		g_eMatchInfo[e_flSidesTime][g_isTeamTT] += pointsAdd;
	}
}

stock points_calc_distance_value(iDistance, iDist1, iDist2, iDist3) {
	if (iDist1 <= 0 || iDist2 <= iDist1 || iDist3 <= iDist2) {
		return 0;
	}

	if (iDistance <= iDist1) {
		return floatround(float(iDistance) / float(iDist1) * 3.0, floatround_floor);
	}

	if (iDistance <= iDist2) {
		return 3 + floatround(float(iDistance - iDist1) / float(iDist2 - iDist1) * 4.0, floatround_floor);
	}

	if (iDistance <= iDist3) {
		return 7 + floatround(float(iDistance - iDist2) / float(iDist3 - iDist2) * 3.0, floatround_floor);
	}

	return 10;
}

stock points_draw_debug_lines(origin[3], iDistance, r, g, b) {
	new endpos[3];

	endpos[0] = origin[0] + iDistance;
	endpos[1] = origin[1];
	endpos[2] = origin[2];
	te_create_beam_between_points(origin, endpos, iBeam, 0, 10, 5, 3, 0, r, g, b, 150, 0);

	endpos[0] = origin[0] - iDistance;
	endpos[1] = origin[1];
	endpos[2] = origin[2];
	te_create_beam_between_points(origin, endpos, iBeam, 0, 10, 5, 3, 0, r, g, b, 150, 0);

	endpos[0] = origin[0];
	endpos[1] = origin[1] + iDistance;
	endpos[2] = origin[2];
	te_create_beam_between_points(origin, endpos, iBeam, 0, 10, 5, 3, 0, r, g, b, 150, 0);

	endpos[0] = origin[0];
	endpos[1] = origin[1] - iDistance;
	endpos[2] = origin[2];
	te_create_beam_between_points(origin, endpos, iBeam, 0, 10, 5, 3, 0, r, g, b, 150, 0);

	endpos[0] = origin[0];
	endpos[1] = origin[1];
	endpos[2] = origin[2] - iDistance;
	te_create_beam_between_points(origin, endpos, iBeam, 0, 10, 5, 3, 0, r, g, b, 150, 0);
}


public mix_reverttimer() {
	if (g_eMatchState != STATE_ENABLED) {
		return;
	}

	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}
	if(task_exists(TASK_POINTS)) {
		remove_task(TASK_POINTS);
	}

	g_eMatchInfo[e_flSidesTime][g_isTeamTT] -= g_flRoundTime;

	ExecuteForward(g_hForwards[MATCH_RESET_ROUND], _);
}

public mix_player_join(id) {
	TrieGetArray(g_eMatchInfo[e_tLeaveData], getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);

	if (g_ePlayerInfo[id][PLAYER_MATCH]) {
		new iNum = get_num_players_in_match(id);

		new bool:bReplaced = iNum >= g_eMatchInfo[e_mTeamSize] ? true : false;

		if (g_bDebugMode) server_print("[MATCH] mix_player_join | %n %d", id, bReplaced)

		ExecuteForward(g_hForwards[MATCH_JOIN_PLAYER], _, id, bReplaced);

		if (bReplaced) {
			transferUserToSpec(id);
			return;
		}

		new iMatchRounds = g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B];

		if (iMatchRounds == g_ePlayerInfo[id][LEAVE_IN_ROUND]) {
			rg_set_user_team(id, g_ePlayerInfo[id][PLAYER_TEAM][0] == 'T' ? TEAM_TERRORIST : TEAM_CT);
		} else {
			rg_set_user_team(id, g_ePlayerInfo[id][PLAYER_TEAM][0] == 'T' ? TEAM_CT : TEAM_TERRORIST);
		}

		if (g_eMatchState == STATE_PAUSED)
			rg_round_respawn(id);
	} else {
		transferUserToSpec(id);
		return;
	}
}

public mix_player_leave(id) {
	if (g_bDebugMode) server_print("[MATCH] mix_player_leave START | %n", id)
	if (g_ePlayerInfo[id][PLAYER_MATCH]) {
		new iMatchRounds = g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B];

		if (g_bDebugMode) {
			server_print("[MATCH] mix_player_leave PLAYER_MATCH | %n %d", id, iMatchRounds)
		}

		g_ePlayerInfo[id][LEAVE_IN_ROUND] = iMatchRounds;

		if (g_iCurrentRules == RULES_DUEL) {
			if (g_ModFuncs[MODE_MIX][MODEFUNC_PAUSE])
				ExecuteForward(g_ModFuncs[MODE_MIX][MODEFUNC_PAUSE], _);
		}
	}
	
	ExecuteForward(g_hForwards[MATCH_LEAVE_PLAYER], _, id);

	TrieSetArray(g_eMatchInfo[e_tLeaveData], getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);

	arrayset(g_ePlayerInfo[id], 0, PLAYER_INFO);
}

// bMatchFinish
stock match_reset_data(bool:bMatchFinish = false) {
	g_iMatchStatus = MATCH_NONE;
	g_eMatchState = STATE_DISABLED;

	g_eMatchInfo[e_mTeamSize] = 0;
	g_eMatchInfo[e_mTeamSizeTT] = 0;
	g_eMatchInfo[e_flSidesTime][HNS_TEAM_B] = 0;
	g_eMatchInfo[e_flSidesTime][HNS_TEAM_A] = 0;
	g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B] = 0;
	g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] = 0;
	g_eMatchInfo[e_mLeaved] = false;
	g_iPointsDistance = 0;
	g_iPlayerDistance = 0;

	if (g_eMatchInfo[e_mWintime] == 0.0) {
		cvar_update_wintime(15.0);
	}

	if(g_eMatchInfo[e_tLeaveData] != Invalid_Trie) {
		TrieClear(g_eMatchInfo[e_tLeaveData]);
	}

	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}
	if(task_exists(TASK_POINTS)) {
		remove_task(TASK_POINTS);
	}

	if(task_exists(HUD_PAUSE)) {
		remove_task(HUD_PAUSE);
	}

	if (bMatchFinish) {
		save_reset_data();
	}
}
