#if defined _cmds_included
  #endinput
#endif

#define _cmds_included

stock cmds_init() {
	register_clcmd("say", "sayHandle");

	//register_clcmd("nightvision", "mainMatchMenu");

	register_clcmd("chooseteam", 	"blockCmd");
	register_clcmd("jointeam", 		"blockCmd");
	register_clcmd("joinclass", 	"blockCmd");

	new iWatcherAccess = read_flags(g_iSettings[WATCHER_FLAG]);

	RegisterSayCmd("mix", 	"mix", 	"mainMatchMenu",	iWatcherAccess, "Main menu admin");
	RegisterSayCmd("mode", 	"type", "menuSelectMode",	iWatcherAccess, "Mode match menu");

	RegisterSayCmd("mr", 		"maxround", 	"cmdMrMode",		iWatcherAccess, "Choose MR mode");
	RegisterSayCmd("timer", 	"wintime", 		"cmdWintimeMode",	iWatcherAccess, "Choose Wintime mode");
	RegisterSayCmd("duel", 		"versus", 		"cmdDuelMode",		iWatcherAccess, "Choose 1x1 mode");
	RegisterSayCmd("pub", 		"public", 		"cmdPubMode", 		iWatcherAccess, "Public mode");
	RegisterSayCmd("dm", 		"deathmatch", 	"cmdDMMode", 		iWatcherAccess, "DeathMatch mode");
	RegisterSayCmd("zm", 		"zombie", 		"cmdZMMode", 		iWatcherAccess, "Zombie mode");
	RegisterSayCmd("bld", 		"blend", 		"cmdBlend", 		iWatcherAccess, "Blend teams");
	RegisterSayCmd("specall", 	"specall", 		"cmdTransferSpec", 	iWatcherAccess, "Spec Transfer");
	RegisterSayCmd("ttall", 	"ttall", 		"cmdTransferTT", 	iWatcherAccess, "TT Transfer");
	RegisterSayCmd("ctall", 	"ctall", 		"cmdTransferCT", 	iWatcherAccess, "CT Transfer");
	RegisterSayCmd("startmix", 	"start", 		"cmdStartMatch", 	iWatcherAccess, "Starts Round");
	RegisterSayCmd("kniferound", "kf", 			"cmdKnifeRound", 	iWatcherAccess, "Knife Round");
	RegisterSayCmd("captain", 	"cap", 			"cmdCaptain", 		iWatcherAccess, "Captain Mode");
	RegisterSayCmd("stop", 		"cancel", 		"cmdStopMode", 		iWatcherAccess, "Stop Current Mode");
	RegisterSayCmd("skill", 	"skill", 		"cmdSkillMode", 	iWatcherAccess, "Skill mode");
	RegisterSayCmd("boost", 	"boost", 		"cmdBoostMode", 	iWatcherAccess, "Boost mode");
	RegisterSayCmd("rr", 		"restart", 		"cmdRestartRound", 	iWatcherAccess, "Restart round");
	RegisterSayCmd("swap", 		"swap", 		"cmdSwapTeams", 	iWatcherAccess, "Swap Teams");
	RegisterSayCmd("pause", 	"ps", 			"cmdStartPause", 	iWatcherAccess, "Start pause");
	RegisterSayCmd("live", 		"unpause", 		"cmdStopPause",		iWatcherAccess, "Unpause");
	RegisterSayCmd("surrender", "sur", 			"cmdSurrender", 	0, "Surrender vote");
	RegisterSayCmd("score", 	"s", 			"cmdShowTimers", 	0, "Score");
	RegisterSayCmd("back", 		"spec", 		"cmdTeamSpec", 		0, "Spec/Back player");
	RegisterSayCmd("pick", 		"pick", 		"pickMenu", 		0, "Pick player");
	RegisterSayCmd("np", 		"noplay", 		"cmdNoplay", 		0, "No play");
	RegisterSayCmd("ip", 		"play", 		"cmdPlay", 			0, "Play");
	RegisterSayCmd("save", 		"sv", 		"Save_d", 			0, "Show top");
	RegisterSayCmd("load", 		"ld", 		"Load_d", 			0, "Show top");
}

public sayHandle(id) {
	new szArgs[64];

	read_args(szArgs, charsmax(szArgs));
	remove_quotes(szArgs);
	trim(szArgs);

	if (!szArgs[0])
		return PLUGIN_HANDLED;

	if (szArgs[0] != '/')
		return PLUGIN_CONTINUE;

	new szTarget[32];

	parse(szArgs, \
		  szArgs, charsmax(szArgs), \
		  szTarget, charsmax(szTarget));

	if (equali(szArgs, "/roundtime", 10)) {
		trim(szTarget);

		if (!isUserWatcher(id))
			return PLUGIN_HANDLED;

		if (is_str_num(szTarget)) {
			set_round_time(szTarget);
			chat_print(0, "%l", "SET_ROUNDTIME", id, str_to_float(szTarget));
		}
		return PLUGIN_CONTINUE;
	}

	if (equali(szArgs, "/mr", 10)) {
		trim(szTarget);

		if (!isUserWatcher(id))
			return PLUGIN_HANDLED;
			
		if (!is_str_num(szTarget))
			return PLUGIN_CONTINUE;

		if (str_to_num(szTarget) > 0) {
			g_iSettings[MAXROUNDS] = str_to_num(szTarget);
			chat_print(0, "%l", "SET_MAXROUNDS", id, str_to_num(szTarget), str_to_num(szTarget) * 2);
		}
		return PLUGIN_CONTINUE;
	}

	if (equali(szArgs, "/wintime", 10)) {
		trim(szTarget);

		if (!isUserWatcher(id))
			return PLUGIN_HANDLED;
			
		if (!is_str_num(szTarget))
			return PLUGIN_CONTINUE;

		if (str_to_float(szTarget) >= 0.0) {
			g_eMatchInfo[e_mWintime] = str_to_float(szTarget);
			cvar_update_wintime(g_eMatchInfo[e_mWintime]);
			
			chat_print(0, "%l", "SET_WINTIME", id, str_to_num(szTarget));
		}
		return PLUGIN_CONTINUE;
	}

	return PLUGIN_CONTINUE;
}

public blockCmd(id) {
	if (g_iCurrentMode != MODE_TRAINING || (g_iMatchStatus < MATCH_WAITCONNECT && g_iMatchStatus > MATCH_NONE))
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

public cmdMrMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentRules == RULES_MR) {
		chat_print(0, "%l", "MODE_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX) {
		chat_print(0, "%l", "MODE_NOT_MIX");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "MODE_SET_MR", id);
	g_iCurrentRules = RULES_MR;

	return PLUGIN_HANDLED;
}

public cmdWintimeMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentRules == RULES_TIMER) {
		chat_print(0, "%l", "MODE_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX) {
		chat_print(0, "%l", "MODE_NOT_MIX");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "MODE_SET_WT", id);
	g_iCurrentRules = RULES_TIMER;

	return PLUGIN_HANDLED;
}

public cmdDuelMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentRules == RULES_DUEL) {
		chat_print(0, "%l", "MODE_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX) {
		chat_print(0, "%l", "MODE_NOT_MIX");
		return PLUGIN_HANDLED;
	}

	if (get_num_players_in_match() > 2) {
		chat_print(0, "%l", "MODE_NOT_SET_DUEL");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "MODE_SET_DUEL", id);
	g_iCurrentRules = RULES_DUEL;

	return PLUGIN_HANDLED;
}

public cmdPubMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_PUB) {
		chat_print(id, "%L", id, "PUB_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_TRAINING || g_iMatchStatus != MATCH_NONE) {
		chat_print(id, "%L", id, "PUB_CANC");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "PUB_ACTIVATED", id);

	pub_start();

	return PLUGIN_HANDLED;
}

public cmdDMMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_DM) {
		chat_print(id, "%L", id, "DM_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_TRAINING || g_iMatchStatus != MATCH_NONE) {
		chat_print(id, "%L", id, "DM_CANC");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "DM_ACTIVATED", id);

	dm_start();

	return PLUGIN_HANDLED;
}

public cmdZMMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_ZM) {
		chat_print(id, "%L", id, "ZM_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_TRAINING || g_iMatchStatus != MATCH_NONE) {
		chat_print(id, "%L", id, "ZM_CANC");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "ZM_ACTIVATED", id);

	zm_start();

	return PLUGIN_HANDLED;
}

public cmdBlend(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_ZM) {
		chat_print(0, "%l", "BLEND_TEAMS", id);
		blendZM();
		return PLUGIN_HANDLED; 
	}

	if (g_iCurrentMode != MODE_PUB && g_iCurrentMode != MODE_DM) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "BLEND_TEAMS", id);

	new Players[MAX_PLAYERS], Num;
	get_players(Players, Num, "ch");

	for (new i; i < Num; i++) {
		if (!getUserTeam(Players[i])) {
			Players[i--] = Players[--Num];
		}
	}

	new Player, Team = random(2) ? 1 : 2;
	new Random;

	while (Num) {
		Random = random(Num);
		Player = Players[Random];
		rg_set_user_team(Player, TeamName:Team);
		Players[Random] = Players[--Num];
		Team = (Team % 2 + 1);
	}

	hns_restart_round();
	return PLUGIN_HANDLED;
}

public blendZM() {
	zm_set_teams();
	hns_restart_round(2.0);
}

public cmdTransferSpec(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}
	
	if (g_iCurrentMode == MODE_MIX) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "TRANSF_SPEC", id);

	transferUsers(TEAM_SPECTATOR);
	
	return PLUGIN_HANDLED;
}

public cmdTransferTT(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "TRANSF_TT", id);

	transferUsers(TEAM_TERRORIST);

	return PLUGIN_HANDLED;
}

public cmdTransferCT(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "TRANSF_CT", id);

	transferUsers(TEAM_CT);

	return PLUGIN_HANDLED;
}

public cmdStartMatch(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_TRAINING) {
		chat_print(id, "%L", id, "NOT_START_MIX");
		return PLUGIN_HANDLED;
	} 
	
	if (hns_is_knife_map()) {
		return PLUGIN_HANDLED;
	}

	if (task_exists(TASK_STARTED)) {
		remove_task(TASK_STARTED);
	}

	if (task_exists(TASK_WAIT)) {
		remove_task(TASK_WAIT);
	}

	chat_print(0, "%l", "START_MIX", id);

	mix_start();

	return PLUGIN_HANDLED;
}

public cmdKnifeRound(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode != MODE_TRAINING) {
		chat_print(id, "%L", id, "NOT_START_KNIFE");
		return PLUGIN_HANDLED;
	}

	if (g_iMatchStatus == MATCH_CAPTAINKNIFE || g_iMatchStatus == MATCH_TEAMKNIFE) {
		chat_print(id, "%L", id, "KNIFE_ALREADY");
		return PLUGIN_HANDLED;
	}

	chat_print(id, "%L", id, "START_KNIFE_1", id);

	g_iMatchStatus = MATCH_TEAMKNIFE;
	kniferound_start();

	return PLUGIN_HANDLED;
}

public cmdCaptain(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (!hns_is_knife_map()) {
		chat_print(id, "%L", id, "NOT_CAPTAIN");
		return PLUGIN_HANDLED;
	}

	// if (g_iCurrentMode != MODE_TRAINING) {
	// 	chat_print(id, "Отключите другой режим.");
	// }

	captain_start(id);

	return PLUGIN_HANDLED;
}

public cmdStopMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_MIX) {
		verifMenu(id);
	} else {
		cmdStop(id);
	}

	return PLUGIN_HANDLED;
}

public cmdStop(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE) {
		//g_bPlayersListLoaded = false;
		return PLUGIN_HANDLED;
	}

	if (task_exists(TASK_WAIT)) {
		remove_task(TASK_WAIT)
	}

	switch (g_iCurrentMode) {
		case MODE_MIX: {
			mix_stop();	
			chat_print(0, "%l", "STOP_MIX", id);
		}
		case MODE_KNIFE: {
			if (g_iMatchStatus == MATCH_CAPTAINKNIFE) {
				resetCaptainData();
				chat_print(0, "%l", "STOP_CAP", id);
			} else {
				chat_print(0, "%l", "STOP_KNIFE", id);
			}
			kniferound_stop();
		}
		case MODE_TRAINING: {
			if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_TEAMPICK) {
				resetCaptainData();
				g_iMatchStatus = MATCH_NONE;
				training_start();
				chat_print(0, "%l", "STOP_CAP", id);
			} else if (g_iMatchStatus) {
				g_iMatchStatus = MATCH_NONE;
			}
		}
		case MODE_PUB: {
			training_start();
			chat_print(0, "%l", "STOP_PUB", id);
		}
		case MODE_DM: {
			training_start();
			chat_print(0, "%l", "STOP_DM", id);
		}
		case MODE_ZM: {
			training_start();
			chat_print(0, "%l", "STOP_ZM", id);
		}
	}

	rg_send_audio(0, "fvox/fuzz.wav");

	return PLUGIN_HANDLED;
}

public cmdSkillMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "TYPE_SKILL", id);

	if (g_iCurrentMode == MODE_MIX) {
		set_cvar_num("mp_freezetime", 5);
		g_iSettings[FLASH] = 1;
		g_iSettings[SMOKE] = 1;
	}

	g_iSettings[HNSBOOST] = 0;

	if (g_iCurrentMode == MODE_TRAINING)
		set_semiclip(SEMICLIP_ON);
	else
		set_semiclip(SEMICLIP_ON, true);

	return PLUGIN_HANDLED;
}

public cmdBoostMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "TYPE_BOOST", id);

	if (g_iCurrentMode == MODE_MIX) {
		set_cvar_num("mp_freezetime", 15);
		g_iSettings[FLASH] = 3;
		g_iSettings[SMOKE] = 1;
	}

	g_iSettings[HNSBOOST] = 1;

	set_semiclip(SEMICLIP_OFF);

	return PLUGIN_HANDLED;
}

public cmdRestartRound(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "GAME_RESTART", id);

	hns_restart_round();

	return PLUGIN_HANDLED;
}

public cmdSwapTeams(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "GAME_SWAP", id);

	if (g_iCurrentMode == MODE_MIX) {
		mix_reverttimer(); // TODO: Доработать
	}

	hns_swap_teams();

	hns_restart_round(0.5);

	return PLUGIN_HANDLED;
}

public cmdStartPause(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if ((g_iCurrentMode != MODE_MIX || g_iCurrentMode != MODE_KNIFE) && g_eMatchState == STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_PAUSE])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_PAUSE], _);

	chat_print(0, "%l", "GAME_PAUSED", id);

	return PLUGIN_HANDLED;
}

public cmdStopPause(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}
	
	if ((g_iCurrentMode != MODE_MIX || g_iCurrentMode != MODE_KNIFE) && g_eMatchState != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_UNPAUSE])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_UNPAUSE], _);

	chat_print(0, "%l", "GAME_UNPAUSED", id);

	return PLUGIN_HANDLED;
}

public cmdSurrender(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (g_iCurrentMode != MODE_MIX)
		return PLUGIN_HANDLED;

	if (!getUserInMatch(id))
		return PLUGIN_HANDLED;

	if (g_eSurrenderData[e_sStarted])
		return PLUGIN_HANDLED;

	if (g_eSurrenderData[e_sFlDelay] > get_gametime()) {
		new szTime[24];
		fnConvertTime(g_eSurrenderData[e_sFlDelay] - get_gametime(), szTime, 23, false);
		chat_print(id, "%L", id, "SUR_WAIT", szTime);
		return PLUGIN_HANDLED;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "che", getUserTeam(id) == TEAM_TERRORIST ? "TERRORIST" : "CT");

	if (iNum != g_eMatchInfo[e_mTeamSizeTT])
		return PLUGIN_HANDLED;

	g_eSurrenderData[e_sStarted] = true;
	g_eSurrenderData[e_sInitiator] = id;
	g_eSurrenderData[e_sFlDelay] = get_gametime() + g_iSettings[SURTIMEDELAY];
	chat_print(0, "%l", "SUR_PLAYER", id, getUserTeam(id) == TEAM_TERRORIST ? "TERRORISTS" : "CTS");

	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];
		surrenderMenu(iPlayer);
	}
	set_task(1.0, "taskSurrender", TASK_SURRENDER, .flags = "b");

	return PLUGIN_HANDLED;
}

public cmdShowTimers(id) {
	if (g_iCurrentMode != MODE_MIX) {
		return PLUGIN_HANDLED;
	}

	new szTimeToWin[HNS_TEAM][24], szTimeDiff[24];

	new Float:fTimeDiff = floatabs(g_eMatchInfo[e_flSidesTime][g_isTeamTT] - g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]);
	fnConvertTime(fTimeDiff, szTimeDiff, charsmax(szTimeDiff), false);

	switch (g_iCurrentRules) {
		case RULES_MR: {
			fnConvertTime(Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_B], szTimeToWin[HNS_TEAM_B], 23);
			fnConvertTime(Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_A], szTimeToWin[HNS_TEAM_A], 23);

			new iPlayers[MAX_PLAYERS], TTsize, CTSize;
			get_players(iPlayers, TTsize, "che", "TERRORIST");
			get_players(iPlayers, CTSize, "che", "CT");
			if (g_isTeamTT == HNS_TEAM_A) {
				chat_print(id, "%L", id, "SCORE_TIME",
					szTimeToWin[HNS_TEAM_A], TTsize, CTSize, szTimeToWin[HNS_TEAM_B],
					(g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B]) + 1, g_iSettings[MAXROUNDS] * 2,
					szTimeDiff);
			} else {
				chat_print(id, "%L", id, "SCORE_TIME",
					szTimeToWin[HNS_TEAM_B], TTsize, CTSize, szTimeToWin[HNS_TEAM_A],
					(g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B] + g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A]) + 1, g_iSettings[MAXROUNDS] * 2,
					szTimeDiff);
			}
		}
		case RULES_TIMER: {
			new Float:flCapTime = floatmul(g_eMatchInfo[e_mWintime], 60.0);
			new Float:flTimeToWinA = floatsub(flCapTime, Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_A]);
			new Float:flTimeToWinB = floatsub(flCapTime, Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_B]);
			fnConvertTime(flTimeToWinA, szTimeToWin[HNS_TEAM_A], 23);
			fnConvertTime(flTimeToWinB, szTimeToWin[HNS_TEAM_B], 23);
			if (g_isTeamTT == HNS_TEAM_A) {
				chat_print(id, "%L", id, "SCORE_TIME_WT", szTimeToWin[HNS_TEAM_A], szTimeToWin[HNS_TEAM_B], szTimeDiff);
			} else {
				chat_print(id, "%L", id, "SCORE_TIME_WT", szTimeToWin[HNS_TEAM_B], szTimeToWin[HNS_TEAM_A], szTimeDiff);
			}
		}
		case RULES_DUEL: {
			new iPlayers[MAX_PLAYERS], iNum;
			new hnsteamname[HNS_TEAM];
	
			get_players(iPlayers, iNum, "ch");

			for (new j; j < iNum; j++) {
				if (!g_ePlayerInfo[iPlayers[j]][PLAYER_MATCH]) {
					continue;                }
				if (g_isTeamTT == HNS_TEAM_A) {
					if (getUserTeam(iPlayers[j]) == TEAM_TERRORIST) {                        
						hnsteamname[HNS_TEAM_A] = iPlayers[j];
					} else if (getUserTeam(iPlayers[j]) == TEAM_CT) {                        
						hnsteamname[HNS_TEAM_B] = iPlayers[j];
					}               
				} else {
					if (getUserTeam(iPlayers[j]) == TEAM_CT) {                        
						hnsteamname[HNS_TEAM_A] = iPlayers[j];
					} else if (getUserTeam(iPlayers[j]) == TEAM_TERRORIST) {                       
						hnsteamname[HNS_TEAM_B] = iPlayers[j];
					}                
				}
			}	

			if(is_user_connected(hnsteamname[HNS_TEAM_A]) && is_user_connected(hnsteamname[HNS_TEAM_B])) { // TODO
				if (g_isTeamTT == HNS_TEAM_A) {
					chat_print(id, "%L", id, "SCORE_DUEL", hnsteamname[HNS_TEAM_A], g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A], g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B], hnsteamname[HNS_TEAM_B]);
				} else {
					chat_print(id, "%L", id, "SCORE_DUEL", hnsteamname[HNS_TEAM_B], g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B], g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A], hnsteamname[HNS_TEAM_A]);
				}
			}  else {
				if (g_isTeamTT == HNS_TEAM_A) {
					chat_print(id, "%L", id, "SCORE_DUEL_DEF", g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A], g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B]);
				} else {
					chat_print(id, "%L", id, "SCORE_DUEL_DEF", g_eMatchInfo[e_iSidesRounds][HNS_TEAM_B], g_eMatchInfo[e_iSidesRounds][HNS_TEAM_A]);
				}
			}
		}	
	}

	return PLUGIN_HANDLED;
}

public cmdTeamSpec(id) {
	if (g_iCurrentMode == MODE_PUB || g_iCurrentMode == MODE_DM || (g_iCurrentMode == MODE_TRAINING && g_iMatchStatus == MATCH_NONE)) { // Переделать
		if (getUserTeam(id) == TEAM_SPECTATOR) {
			new iNumTT = get_playersnum_ex(GetPlayers_MatchTeam, "TERRORIST");
			new iNumCT = get_playersnum_ex(GetPlayers_MatchTeam, "CT");
			if (iNumTT == iNumCT && g_eSpecBack[id] != TEAM_UNASSIGNED) {
				rg_set_user_team(id, g_eSpecBack[id]);
			} else if (iNumTT < iNumCT) {
				rg_set_user_team(id, TEAM_TERRORIST);
			} else {
				rg_set_user_team(id, TEAM_CT);
			}
			if (g_iCurrentMode == MODE_PUB) {
				if (rg_is_player_can_respawn(id)) {
					rg_round_respawn(id);
				}
			} else {
				rg_round_respawn(id);
			}
		} else {
			g_eSpecBack[id] = getUserTeam(id);
			transferUserToSpec(id);
		}
	}
}

public cmdNoplay(id) {
	if (!g_bNoplay[id]) {
		g_bNoplay[id] = true;
		chat_print(0, "%l", "STATUS_NOPLAY", id);
	}
}

public cmdPlay(id) {
	if (g_bNoplay[id]) {
		g_bNoplay[id] = false;
		chat_print(0, "%l", "STATUS_PLAY", id);
	}
}

stock RegisterSayCmd(const szCmd[], const szShort[], const szFunc[], flags = -1, szInfo[] = "") {
	new szTemp[65], szInfoLang[65];
	format(szInfoLang, 64, "%L", LANG_SERVER, szInfo);

	format(szTemp, 64, "say /%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say .%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "/%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "%s", szCmd);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say /%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "say .%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "/%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	format(szTemp, 64, "%s", szShort);
	register_clcmd(szTemp, szFunc, flags, szInfoLang);

	return 1;
}