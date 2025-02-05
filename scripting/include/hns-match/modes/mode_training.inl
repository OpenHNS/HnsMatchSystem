public trainingmode_init() {
	g_ModFuncs[MODE_TRAINING][MODEFUNC_START]		= CreateOneForward(g_PluginId, "training_start");
	g_ModFuncs[MODE_TRAINING][MODEFUNC_PLAYER_JOIN]	= CreateOneForward(g_PluginId, "training_player_join", FP_CELL);
}

public training_start() {
	g_iCurrentMode = MODE_TRAINING;
	ChangeGameplay(GAMEPLAY_TRAINING);
	hns_restart_round(1.0);
	set_cvars_mode(MODE_TRAINING);
}

public training_player_join(id) {
	if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_TEAMPICK || g_iMatchStatus == MATCH_MAPPICK) {
		transferUserToSpec(id);
		return;
	}
	
	if (equali(g_szMapName, g_iSettings[KNIFEMAP])) {
		rg_round_respawn(id);
		return;
	}

	if (g_bPlayersListLoaded) {
		if (!checkPlayer(id))
			transferUserToSpec(id);
		else
			rg_round_respawn(id);
	}
	else
		rg_round_respawn(id);
}