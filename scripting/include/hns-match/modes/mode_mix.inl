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
	ChangeGameplay(GAMEPLAY_HNS);
	g_iCurrentMode = MODE_MIX;
	g_eMatchState = STATE_PREPARE;
	hns_enable_rules();
	g_iMatchStatus = MATCH_STARTED;

	arrayset(g_eMatchInfo, 0, MatchInfo_s);
	g_isTeamTT = HNS_TEAM_A;
	g_eSurrenderData[e_sFlDelay] = get_gametime() + g_iSettings[SURTIMEDELAY];

	set_cvars_mode(MODE_MIX);

	loadMapCFG();

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ce", "TERRORIST");
	g_eMatchInfo[e_mTeamSizeTT] = iNum;
	g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();

	rg_send_audio(0, "plats/elevbell1.wav");
	setTaskHud(0, 0.0, 1, 255, 255, 255, 3.0, "%L", LANG_SERVER, "HUD_STARTMIX1");
	setTaskHud(0, 3.1, 1, 255, 255, 255, 3.0, "%L", LANG_SERVER, "HUD_STARTMIX2");

	hns_restart_round(2.0);

	if (g_iCurrentRules == RULES_TIMER) {
		if (g_iSettings[WINTIME] == 0.0) {
			g_iSettings[WINTIME] = 15.0
		}
	}

	g_bPlayersLeaved = false;

	ExecuteForward(g_hForwards[MATCH_START], _);
}


public mix_freezeend() {
	if (g_eMatchState == STATE_ENABLED) {
		set_task(5.0, "taskCheckAfk");
		
		if (g_bHnsBannedInit) {
			if (checkUserBan()) {
				return;
			}
		}

		//set_task(10.0, "mix_pause");
		set_task(0.25, "taskRoundEvent", .id = TASK_TIMER, .flags = "b");

		if(g_bPlayersLeaved) {
			//mix_pause();
			set_task(1.0, "mix_pause");
		}	
	}
}

public mix_restartround() {
	if (g_eMatchState == STATE_ENABLED) {
		mix_reverttimer();
		g_eMatchState = STATE_PREPARE;
	}
}


public mix_pause() {
	if (g_eMatchState == STATE_PAUSED) {
		return;
	}
	g_eMatchState = STATE_PAUSED;

	mix_reverttimer();

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
	g_eMatchInfo[e_iMatchSwapped]++;
}


public mix_stop() {
	// ResetTeams();
	g_iMatchStatus = MATCH_NONE;
	g_eMatchState = STATE_DISABLED;
	arrayset(g_eMatchInfo, 0, MatchInfo_s);
	training_start();
	if(task_exists(HUD_PAUSE)) {
		remove_task(HUD_PAUSE);
	}
	ExecuteForward(g_hForwards[MATCH_CANCEL], _);
	g_bPlayersListLoaded = false;
	g_bPlayersLeaved = false;
}


public mix_roundstart() {
	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
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
	//set_task(5.0, "taskCheckLeave");
}

public taskCheckLeave() {
	if (g_iCurrentMode != MODE_MIX) {
		return;
	}

	new iNum = get_num_players_in_match();

	if (iNum < g_eMatchInfo[e_mTeamSize]) {
		// Pause Need Players
		g_bPlayersLeaved = true;
		chat_print(0, "%L", LANG_PLAYER, "NEED_PAUSE", g_eMatchInfo[e_mTeamSize] - iNum)
	} else {
		iNum = iNum - g_eMatchInfo[e_mTeamSize];
		if (iNum >= 2) {
			g_eMatchInfo[e_mTeamSize] = get_num_players_in_match();
		}

		if (g_PlayersLeaveData != Invalid_Trie) {
			TrieClear(g_PlayersLeaveData);
		}

		g_bPlayersLeaved = false;
	}
}

public MixFinishedMR(iWinTeam) {
	ExecuteForward(g_hForwards[MATCH_FINISH], _, iWinTeam);
	g_iMatchStatus = MATCH_NONE;
	new Float:TimeDiff = floatabs(g_eMatchInfo[e_flSidesTime][g_isTeamTT] - g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]);
	new szTime[24];
	fnConvertTime(TimeDiff, szTime, charsmax(szTime));
	chat_print(0, "%L", LANG_PLAYER, "MR_WIN", iWinTeam == 1 ? "TT" : "CT", szTime);
	
	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "%L", LANG_SERVER, "HUD_GAMEOVER");
	training_start();

	g_bPlayersListLoaded = false;
	arrayset(g_eMatchInfo, 0, MatchInfo_s);
	if(g_PlayersLeaveData != Invalid_Trie) {
		TrieClear(g_PlayersLeaveData);
	}
	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}
}

public MixFinishedWT() {
	g_iMatchStatus = MATCH_NONE;
	
	new Float:TimeDiff = floatabs(g_eMatchInfo[e_flSidesTime][g_isTeamTT] - g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]);
	
	new szTime[24];
	fnConvertTime(TimeDiff, szTime, charsmax(szTime), false);
	
	chat_print(0, "%L", LANG_PLAYER, "TT_WIN", szTime);
	
	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "%L", LANG_SERVER, "HUD_GAMEOVER");
	training_start();

	g_bPlayersListLoaded = false;
	arrayset(g_eMatchInfo, 0, MatchInfo_s);
	if(g_PlayersLeaveData != Invalid_Trie) {
		TrieClear(g_PlayersLeaveData);
	}
	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}

	ExecuteForward(g_hForwards[MATCH_FINISH], _, 1);
}

public MixFinishedDuel() {
	g_iMatchStatus = MATCH_NONE;
	
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "che", "TERRORIST");

	chat_print(0, "%L", LANG_PLAYER, "DUEL_WIN", iPlayers[0]);
	
	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "%L", LANG_SERVER, "HUD_GAMEOVER");
	training_start();

	g_bPlayersListLoaded = false;
	arrayset(g_eMatchInfo, 0, MatchInfo_s);
	if(g_PlayersLeaveData != Invalid_Trie) {
		TrieClear(g_PlayersLeaveData);
	}
	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}

	ExecuteForward(g_hForwards[MATCH_FINISH], _, 1);
}

public mix_roundend(bool:win_ct) {
	if (g_eMatchState != STATE_ENABLED) {
		return;
	}

	g_eMatchState = STATE_PREPARE;
	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}

	switch (g_iCurrentRules) {
		case RULES_MR: {
			g_eMatchInfo[e_iRoundsPlayed][g_isTeamTT]++;

			new iPlayers[MAX_PLAYERS], iNum;
			get_players(iPlayers, iNum, "ache", "CT");

			if (!iNum) {
				new Float:roundtime = get_round_time() * 60.0;
				g_eMatchInfo[e_flSidesTime][g_isTeamTT] += roundtime - g_flRoundTime;
			}

			if (g_eMatchInfo[e_iRoundsPlayed][g_isTeamTT] + g_eMatchInfo[e_iRoundsPlayed][HNS_TEAM:!g_isTeamTT] >= g_iSettings[MAXROUNDS] * 2) {
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
				if (g_eMatchInfo[e_iRoundsPlayed][g_isTeamTT] + g_eMatchInfo[e_iRoundsPlayed][HNS_TEAM:!g_isTeamTT] >= (g_iSettings[MAXROUNDS] * 2) - 1) {
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
			if (win_ct) {
				hns_swap_teams();
			}
		}
		case RULES_DUEL: {
			if (win_ct) {
				hns_swap_teams();
			} else {
				g_eMatchInfo[e_iRoundsPlayed][g_isTeamTT]++
			}
			
			if(g_eMatchInfo[e_iRoundsPlayed][g_isTeamTT] >= g_iSettings[DUELROUNDS]) {
				MixFinishedDuel();
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
			if (g_eMatchInfo[e_iRoundsPlayed][g_isTeamTT] + g_eMatchInfo[e_iRoundsPlayed][HNS_TEAM:!g_isTeamTT] >= (g_iSettings[MAXROUNDS] * 2) - 1) {
				if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] > g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] || g_eMatchInfo[e_flSidesTime][g_isTeamTT] < (g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] - get_round_time() * 60.0)) {
					new HNS_TEAM:iWinTeam = g_eMatchInfo[e_flSidesTime][g_isTeamTT] > g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT] ? g_isTeamTT : HNS_TEAM:!g_isTeamTT;
					MixFinishedMR(iWinTeam == g_isTeamTT ? 1 : 2);
				}
			}
		}
		case RULES_TIMER: {
			new Float:flCapTime = floatmul(g_iSettings[WINTIME], 60.0);
			if (g_eMatchInfo[e_flSidesTime][g_isTeamTT] >= flCapTime) {
				MixFinishedWT()
			}
		}
	}
}


public mix_reverttimer() {
	if (!task_exists(TASK_TIMER) && g_iCurrentMode != MODE_MIX) {
		return;
	}

	if(task_exists(TASK_TIMER)) {
		remove_task(TASK_TIMER);
	}

	g_eMatchInfo[e_flSidesTime][g_isTeamTT] -= g_flRoundTime;

	ExecuteForward(g_hForwards[MATCH_RESET_ROUND], _);
}

public mix_player_join(id) {
	TrieGetArray(g_PlayersLeaveData, getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);
	if (g_ePlayerInfo[id][PLAYER_MATCH]) {
		new iNum = get_num_players_in_match();
		if (iNum >= g_eMatchInfo[e_mTeamSize]) {
			transferUserToSpec(id);
			return;
		}


		if (g_eMatchInfo[e_iMatchSwapped] == g_ePlayerInfo[id][PLAYER_SAVE_SWAP]) {
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
	if (g_ePlayerInfo[id][PLAYER_MATCH]) {
		g_ePlayerInfo[id][PLAYER_SAVE_SWAP] = g_eMatchInfo[e_iMatchSwapped];

		if (g_iCurrentRules == RULES_DUEL) {
			if (g_ModFuncs[MODE_MIX][MODEFUNC_PAUSE])
				ExecuteForward(g_ModFuncs[MODE_MIX][MODEFUNC_PAUSE], _);
		}
	}

	TrieSetArray(g_PlayersLeaveData, getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);

	arrayset(g_ePlayerInfo[id], 0, PLAYER_INFO);
}