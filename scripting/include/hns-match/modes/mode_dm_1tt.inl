public dm_1tt_init() {
	g_ModFuncs[MODE_DM_1TT][MODEFUNC_KILL] = CreateOneForward(g_PluginId, "dm_1tt_killed", FP_CELL, FP_CELL);
	g_ModFuncs[MODE_DM_1TT][MODEFUNC_FALLDAMAGE] = CreateOneForward(g_PluginId, "dm_1tt_falldamage", FP_CELL, FP_FLOAT);
	g_ModFuncs[MODE_DM_1TT][MODEFUNC_PLAYER_JOIN] = CreateOneForward(g_PluginId, "dm_1tt_player_join", FP_CELL);
	g_ModFuncs[MODE_DM_1TT][MODEFUNC_PLAYER_LEAVE] = CreateOneForward(g_PluginId, "dm_1tt_player_leave", FP_CELL);
}

public dm_1tt_start() {
	ChangeGameplay(GAMEPLAY_HNS);
	g_iCurrentMode = MODE_DM_1TT;
	g_iMatchStatus = MATCH_NONE;
	g_iSettings[FLASH] = 1;
	g_iSettings[SMOKE] = 1;
	set_cvars_mode(MODE_DM_1TT);

	dm_1tt_set_teams();
	hns_restart_round(0.5);
}

public dm_1tt_killed(victim, killer) {
	new bool:bVictimTT = (getUserTeam(victim) == TEAM_TERRORIST);

	if (killer != victim && is_user_connected(killer) && getUserTeam(killer) == TEAM_CT && bVictimTT) {
		rg_set_user_team(killer, TEAM_TERRORIST);
		rg_set_user_team(victim, TEAM_CT);

		if (!g_iSettings[ONEHPMODE]) {
			set_entvar(killer, var_health, 100.0);
		}

		hns_setrole(killer);
	} else if (bVictimTT) {
		dm_1tt_transfer_tt(victim);
	}

	set_task(g_iSettings[DMRESPAWN], "RespawnPlayer", victim);
}

public dm_1tt_falldamage(id, Float:flDmg) {
	new Float:flHp;
	get_entvar(id, var_health, flHp);

	if (flHp > flDmg) {
		return;
	}

	if (getUserTeam(id) == TEAM_TERRORIST) {
		dm_1tt_transfer_tt(id);
	}
}

public dm_1tt_player_join(id) {
	if (!is_user_connected(id)) {
		return;
	}

	if (getUserTeam(id) != TEAM_CT) {
		rg_set_user_team(id, TEAM_CT);
	}

	if (!is_user_alive(id)) {
		rg_round_respawn(id);
	}
}

public dm_1tt_player_leave(id) {
	if (getUserTeam(id) != TEAM_TERRORIST && get_playersnum_ex(GetPlayers_MatchTeam, "TERRORIST") > 0) {
		return;
	}

	new iNextTT = dm_1tt_get_random_ct();
	if (!iNextTT) {
		return;
	}

	rg_set_user_team(iNextTT, TEAM_TERRORIST);

	if (!g_iSettings[ONEHPMODE]) {
		set_entvar(iNextTT, var_health, 100.0);
	}

	hns_setrole(iNextTT);
	rg_round_respawn(iNextTT);
}

public dm_1tt_set_teams() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	if (!iNum) {
		return;
	}

	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];

		if (getUserTeam(iPlayer) == TEAM_SPECTATOR) {
			continue;
		}

		rg_set_user_team(iPlayer, TEAM_CT);
	}

	new iTT = dm_1tt_get_random_ct();
	if (!iTT) {
		return;
	}

	rg_set_user_team(iTT, TEAM_TERRORIST);
	hns_setrole(iTT);
}

stock dm_1tt_transfer_tt(iPrevTT) {
	new iNextTT = dm_1tt_get_random_ct();
	if (!iNextTT) {
		return 0;
	}

	rg_set_user_team(iNextTT, TEAM_TERRORIST);
	rg_set_user_team(iPrevTT, TEAM_CT);
	chat_print(0, "%L", LANG_PLAYER, "DM_TRANSF", iNextTT);

	if (!g_iSettings[ONEHPMODE]) {
		set_entvar(iNextTT, var_health, 100.0);
	}

	hns_setrole(iNextTT);

	return 1;
}

stock dm_1tt_get_random_ct() {
	static iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ahe", "CT");

	if (!iNum) {
		return 0;
	}

	return iNum > 1 ? iPlayers[random(iNum)] : iPlayers[0];
}
