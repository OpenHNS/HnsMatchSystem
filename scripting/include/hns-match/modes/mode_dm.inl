public dm_init() {
	g_ModFuncs[MODE_DM][MODEFUNC_KILL] = CreateOneForward(g_PluginId, "dm_killed", FP_CELL, FP_CELL);
	g_ModFuncs[MODE_DM][MODEFUNC_FALLDAMAGE] = CreateOneForward(g_PluginId, "dm_falldamage", FP_CELL, FP_FLOAT);
}

public dm_start() {
	ChangeGameplay(GAMEPLAY_HNS);
	g_iCurrentMode = MODE_DM;
	g_iMatchStatus = MATCH_NONE;
	g_iSettings[FLASH] = 1;
	g_iSettings[SMOKE] = 1;
	set_cvars_mode(MODE_DM);
	hns_restart_round(0.5);
}

public dm_killed(victim, killer) {
	if (killer != victim) {
		if (is_user_connected(killer)) {
			if (getUserTeam(killer) == TEAM_CT) {
				rg_set_user_team(killer, TEAM_TERRORIST);
				rg_set_user_team(victim, TEAM_CT);

				if (!g_iSettings[ONEHPMODE])
					set_entvar(killer, var_health, 100.0);
				
				hns_setrole(killer);
			}
		} else {
			new DeadVictim = get_entvar(victim, var_health, 0.0);
			if (DeadVictim) {
				LuckyTransferToTT(victim);
			}
		}
	}

	set_task(g_iSettings[DMRESPAWN], "RespawnPlayer", victim);
}

public dm_falldamage(id, Float:flDmg) {
	new Float:flHp;
	get_entvar(id, var_health, flHp);

	if (flHp > flDmg) {
		return;
	}

	if (getUserTeam(id) == TEAM_TERRORIST) {
		LuckyTransferToTT(id);
	}
}

public RespawnPlayer(id) {
	if (!is_user_connected(id))
		return;

	if (getUserTeam(id) != TEAM_SPECTATOR)
		rg_round_respawn(id);
}

public LuckyTransferToTT(id) {
	if (!is_user_connected(id))
		return;

	new lucky = GetRandomCT();
	if (lucky) {
		rg_set_user_team(lucky, TEAM_TERRORIST);
		chat_print(0, "%L", LANG_PLAYER, "DM_TRANSF", lucky)
		rg_set_user_team(id, TEAM_CT);

		if (!g_iSettings[ONEHPMODE])
			set_entvar(lucky, var_health, 100.0);

		hns_setrole(lucky);
	}
}

GetRandomCT() {
	static iPlayers[32], iCTNum
	get_players(iPlayers, iCTNum, "ache", "CT");

	if (!iCTNum)
		return 0

	return iCTNum > 1 ? iPlayers[random(iCTNum)] : iPlayers[iCTNum - 1];
}