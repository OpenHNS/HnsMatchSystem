// Для новой дуэли нужен свой матч мод (по типу wintime или mr)
// В HnsMatchSystem новая дуэль проверяется значением RULES_DUEL

#define TASK_POINTS 54445 // Таск для крутилки поинтов

// TODO: Избавиться от привязке ко времени
new Float:g_flPointsMatchTime;

new Float:g_flPointsMatchTimeSnap;
new Float:g_flPointsSnap[HNS_TEAM];
new HNS_TEAM:g_iPointsTeamSnap;

new bool:g_bDuelHasRespawnOrigin[MAX_PLAYERS + 1];
new Float:g_flDuelRespawnOrigin[MAX_PLAYERS + 1][3];
new bool:g_bDuelFallDeath[MAX_PLAYERS + 1];
new bool:g_bDuelWaitRespawnMove[MAX_PLAYERS + 1];
new Float:g_flDuelRespawnMoveOrigin[MAX_PLAYERS + 1][3];

new const Float:g_flDuelRespawnRadius[] = {16.0, 32.0, 48.0, 64.0, 80.0, 96.0, 128.0};
new const Float:g_flDuelRespawnHeight[] = {0.0, 18.0, -18.0, 36.0, -36.0, 54.0};

// Вызывается при старте матча в микс системе
public duel_start() {
	duel_clear_respawn_data();

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
	duel_clear_respawn_data();
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

	new bool:bFallDeath = g_bDuelFallDeath[victim];
	g_bDuelFallDeath[victim] = false;
	g_bDuelWaitRespawnMove[victim] = true;

	if (preVictimTeam == TEAM_TERRORIST && preKillerTeam == TEAM_CT && !bFallDeath) {
		get_entvar(victim, var_origin, g_flDuelRespawnOrigin[victim]);
		g_bDuelHasRespawnOrigin[victim] = true;
	} else {
		g_bDuelHasRespawnOrigin[victim] = false;
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
	new Float:flHealth;
	get_entvar(id, var_health, flHealth);
	g_bDuelFallDeath[id] = (flDmg > 0.0 && flDmg >= flHealth);

	dm_falldamage(id, flDmg); // DeathMatch падение (реализация в mode_dm.inl)

	if (preTeam == TEAM_TERRORIST && getUserTeam(id) == TEAM_CT) {
		g_isTeamTT = HNS_TEAM:!g_isTeamTT;
		points_save_state();
	}
}

// Возвращает пойманного TT на место смерти уже после смены его роли на CT.
public duel_player_spawn(id) {
	if (g_iCurrentMode != MODE_MIX || g_iCurrentRules != RULES_DUEL || !is_user_alive(id)) {
		return;
	}

	g_bDuelFallDeath[id] = false;

	if (g_bDuelHasRespawnOrigin[id]) {
		g_bDuelHasRespawnOrigin[id] = false;

		if (getUserTeam(id) == TEAM_CT) {
			new Float:flTargetOrigin[3];
			if (duel_find_safe_respawn_origin(id, g_flDuelRespawnOrigin[id], flTargetOrigin)) {
				set_entvar(id, var_origin, flTargetOrigin);

				static const Float:flZero[3] = {0.0, 0.0, 0.0};
				set_entvar(id, var_velocity, flZero);
			}
		}
	}

	if (g_bDuelWaitRespawnMove[id]) {
		get_entvar(id, var_origin, g_flDuelRespawnMoveOrigin[id]);
	}
}

stock duel_clear_player_respawn(id) {
	if (id < 1 || id > MaxClients) {
		return;
	}

	g_bDuelHasRespawnOrigin[id] = false;
	g_bDuelFallDeath[id] = false;
	g_bDuelWaitRespawnMove[id] = false;
	arrayset(g_flDuelRespawnMoveOrigin[id], 0.0, sizeof(g_flDuelRespawnMoveOrigin[]));
}

stock duel_clear_respawn_data() {
	for (new id = 1; id <= MaxClients; id++) {
		duel_clear_player_respawn(id);
	}
}

stock bool:duel_find_safe_respawn_origin(id, const Float:flBaseOrigin[3], Float:flOutOrigin[3]) {
	if (duel_is_position_free(id, flBaseOrigin)) {
		flOutOrigin[0] = flBaseOrigin[0];
		flOutOrigin[1] = flBaseOrigin[1];
		flOutOrigin[2] = flBaseOrigin[2];
		return true;
	}

	new Float:flCandidate[3];

	for (new iHeight; iHeight < sizeof(g_flDuelRespawnHeight); iHeight++) {
		for (new iRadius; iRadius < sizeof(g_flDuelRespawnRadius); iRadius++) {
			new Float:flRadius = g_flDuelRespawnRadius[iRadius];

			for (new iAngle; iAngle < 360; iAngle += 45) {
				new Float:flYaw = float(iAngle);

				flCandidate[0] = flBaseOrigin[0] + floatcos(flYaw, degrees) * flRadius;
				flCandidate[1] = flBaseOrigin[1] + floatsin(flYaw, degrees) * flRadius;
				flCandidate[2] = flBaseOrigin[2] + g_flDuelRespawnHeight[iHeight];

				if (!duel_is_position_free(id, flCandidate)) {
					continue;
				}

				flOutOrigin[0] = flCandidate[0];
				flOutOrigin[1] = flCandidate[1];
				flOutOrigin[2] = flCandidate[2];
				return true;
			}
		}
	}

	return false;
}

stock bool:duel_is_position_free(id, const Float:flOrigin[3]) {
	new iTrace = create_tr2();
	new iHull = (get_entvar(id, var_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;

	engfunc(EngFunc_TraceHull, flOrigin, flOrigin, 0, iHull, id, iTrace);

	new bool:bStartSolid = bool:get_tr2(iTrace, TR_StartSolid);
	new bool:bAllSolid = bool:get_tr2(iTrace, TR_AllSolid);
	new Float:flFraction;
	get_tr2(iTrace, TR_flFraction, flFraction);

	free_tr2(iTrace);

	return !bStartSolid && !bAllSolid && flFraction >= 1.0;
}

stock bool:duel_is_waiting_for_respawn_move(id) {
	if (!g_bDuelWaitRespawnMove[id]) {
		return false;
	}

	new Float:flOrigin[3];
	get_entvar(id, var_origin, flOrigin);

	// Тот же порог движения, который используется в AFK-проверке.
	if (get_distance_f(g_flDuelRespawnMoveOrigin[id], flOrigin) <= 1.0) {
		return true;
	}

	g_bDuelWaitRespawnMove[id] = false;
	return false;
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

	new bool:bTtWaitingForMove = duel_is_waiting_for_respawn_move(ttPlayers[0]);
	new bool:bCtWaitingForMove = duel_is_waiting_for_respawn_move(ctPlayers[0]);
	if (bTtWaitingForMove || bCtWaitingForMove) {
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

	client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "DUEL_POINTS_WINNER", g_iSettings[PREFIX],
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
