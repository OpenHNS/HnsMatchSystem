// Для новой дуэли нужен свой матч мод (по типу wintime или mr)
// В HnsMatchSystem новая дуэль проверяется значением RULES_DUEL

#define TASK_POINTS 54445 // Таск для крутилки поинтов

// TODO: Избавиться от привязке ко времени
new Float:g_flPointsMatchTime;

new Float:g_flPointsMatchTimeSnap;
new Float:g_flPointsSnap[HNS_TEAM];
new HNS_TEAM:g_iPointsTeamSnap;

// Вызывается при старте матча в микс системе
public duel_start() {

	g_flPointsMatchTime = g_eMatchInfo[e_mWintime] * 60.0;

	points_save_state();

	g_iSettings[FLASH] = 1;
	g_iSettings[SMOKE] = 0;
	server_cmd("mp_freezetime 0");
	server_cmd("mp_forcecamera 0");
	server_cmd("mp_round_infinite 1");
	server_cmd("mp_roundrespawn_time -1");
	server_cmd("mp_roundtime 0");
}

// Вызывается под конец фризтайма (reapi: RG_CSGameRules_OnRoundFreezeEnd)
public duel_freezeend() {
	if (task_exists(TASK_POINTS)) {
		remove_task(TASK_POINTS);
	}

	set_task(0.25, "taskDuelPoints", .id = TASK_POINTS, .flags = "b");
}

// Вызывается под рестерт раунда (reapi: RG_CSGameRules_RestartRound)
public duel_roundstart() {
	if(task_exists(TASK_POINTS)) {
		remove_task(TASK_POINTS);
	}
}

// Вызывается под конец раунда (reapi: RG_CSGameRules_RestartRound)
public duel_roundend() {
	if(task_exists(TASK_POINTS)) {
		remove_task(TASK_POINTS);
	}
}

// Вызывается при рестарте раунда (reapi:  RG_RoundEnd)
public duel_restartround() {
	points_restore_state();
}

// Вызывается, когда срабатывает матч пауза.
public duel_pause() {
	points_restore_state();
}

// Вызывается, когда срабатывает свап команд. 
// TODO: Не сейвить поинты, а сбросить.
public duel_swap() {
	points_save_state();
}

// Вызывается, при сбросе таймеров микс системы. (Необязательно)
public duel_reverttimer() {
	if(task_exists(TASK_POINTS)) {
		remove_task(TASK_POINTS);
	}
}

// Вызывается при убийстве игрока.
public duel_killed(victim, killer) {
	new TeamName:preVictimTeam = getUserTeam(victim);
	new TeamName:preKillerTeam = TEAM_UNASSIGNED;
	if (killer && killer != victim && is_user_connected(killer)) {
		preKillerTeam = getUserTeam(killer);
	}

	dm_killed(victim, killer); // DeathMatch убийство (реализация в mode_dm.inl)

	if (preKillerTeam == TEAM_CT && killer != victim) {
		g_isTeamTT = HNS_TEAM:!g_isTeamTT;
		points_save_state();
	} else if (preVictimTeam == TEAM_TERRORIST && getUserTeam(victim) == TEAM_CT) {
		g_isTeamTT = HNS_TEAM:!g_isTeamTT;
		points_save_state();
	}
}

// Вызывается при падении игрока (reapi:  RG_CSGameRules_FlPlayerFallDamage)
public duel_falldamage(id, Float:flDmg) {
	new TeamName:preTeam = getUserTeam(id);

	dm_falldamage(id, flDmg); // DeathMatch падение (реализация в mode_dm.inl)

	if (preTeam == TEAM_TERRORIST && getUserTeam(id) == TEAM_CT) {
		g_isTeamTT = HNS_TEAM:!g_isTeamTT;
		points_save_state();
	}
}


// Логика distance duel


public taskDuelPoints() {
	if (g_iCurrentMode != MODE_MIX || g_iCurrentRules != RULES_DUEL || g_eMatchState != STATE_ENABLED) {
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

	g_flPointsMatchTime -= 0.25;
	if (g_flPointsMatchTime <= 0) {
		if (g_eMatchInfo[e_flSidesTime][HNS_TEAM_A] > g_eMatchInfo[e_flSidesTime][HNS_TEAM_B]) {
			MixFinishedPoints(HNS_TEAM_A);
		} else {
			MixFinishedPoints(HNS_TEAM_B);
		}
	}
}

stock MixFinishedPoints(HNS_TEAM:hns_team) {
	if (g_iCurrentRules != RULES_DUEL) {
		return;
	}

	new iWinTeam = (hns_team == g_isTeamTT) ? 1 : 2;
	ExecuteForward(g_hForwards[MATCH_FINISH], _, iWinTeam);

	new Float:flScoreA = Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_A];
	new Float:flScoreB = Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_B];

	new ttPlayers[MAX_PLAYERS], ctPlayers[MAX_PLAYERS], ttNum, ctNum;
	get_players(ttPlayers, ttNum, "he", "TERRORIST");
	get_players(ctPlayers, ctNum, "he", "CT");

	new iPlayerA, iPlayerB;
	if (g_isTeamTT == HNS_TEAM_A) {
		iPlayerA = ttPlayers[0];
		iPlayerB = ctPlayers[0];
	} else {
		iPlayerA = ctPlayers[0];
		iPlayerB = ttPlayers[0];
	}

	chat_print(0, "Points: ^3%n^1 ^4%.1f^1 vs ^4%.1f^1 ^3%n^1 | Winner: ^3%n^1 ^3%.1f^1", 
		iPlayerA, flScoreA, flScoreB, iPlayerB, 
		hns_team == HNS_TEAM_A ? iPlayerA : iPlayerB,
		hns_team == HNS_TEAM_A ? flScoreA : flScoreB);

	setTaskHud(0, 1.0, 1, 255, 255, 255, 4.0, "%L", LANG_SERVER, "HUD_GAMEOVER");

	match_reset_data();

	training_start();

	ExecuteForward(g_hForwards[MATCH_FINISH_POST], _, iWinTeam);
}

stock points_save_state() {
	if (g_iCurrentRules != RULES_DUEL) {
		return;
	}

	g_flPointsMatchTimeSnap = g_flPointsMatchTime;
	g_flPointsSnap[HNS_TEAM_A] = Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_A];
	g_flPointsSnap[HNS_TEAM_B] = Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_B];
	g_iPointsTeamSnap = g_isTeamTT;

	cmdShowTimers(0);
}

stock points_restore_state() {
	if (g_iCurrentRules != RULES_DUEL) {
		return;
	}

	g_flPointsMatchTime = g_flPointsMatchTimeSnap;
	g_eMatchInfo[e_flSidesTime][HNS_TEAM_A] = g_flPointsSnap[HNS_TEAM_A];
	g_eMatchInfo[e_flSidesTime][HNS_TEAM_B] = g_flPointsSnap[HNS_TEAM_B];
	g_isTeamTT = g_iPointsTeamSnap;
	g_iPointsDistance = 0;
	g_iPlayerDistance = 0;
}


stock duel_reset() {
	if(task_exists(TASK_POINTS)) {
		remove_task(TASK_POINTS);
	}

	g_flPointsMatchTime = g_eMatchInfo[e_mWintime] * 60.0;
	g_flPointsMatchTimeSnap = g_eMatchInfo[e_mWintime] * 60.0;
	g_iPointsDistance = 0;
	g_iPlayerDistance = 0;
	g_flPointsSnap[HNS_TEAM_A] = 0.0;
	g_flPointsSnap[HNS_TEAM_B] = 0.0;
	g_iPointsTeamSnap = HNS_TEAM_A;
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
