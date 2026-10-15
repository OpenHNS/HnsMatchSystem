public retake_init() {
	g_ModFuncs[MODE_RETAKE][MODEFUNC_START] = CreateOneForward(g_PluginId, "retake_start");
	g_ModFuncs[MODE_RETAKE][MODEFUNC_PLAYER_JOIN] = CreateOneForward(g_PluginId, "retake_player_join", FP_CELL);
}

public retake_start() {
	g_iCurrentMode = MODE_RETAKE;
	g_iMatchStatus = MATCH_NONE;

	// Retake uses the standard HNS rules, but always keeps boost collision.
	g_iSettings[HNSBOOST] = 1;
	g_iSettings[FLASH] = 1;
	g_iSettings[SMOKE] = 1;

	ChangeGameplay(GAMEPLAY_HNS);
	set_semiclip(SEMICLIP_OFF);
	set_cvars_mode(MODE_RETAKE);

	// Keep these values deterministic even before the queued cfg is executed.
	set_cvar_num("hns_boost", 1);
	set_cvar_num("mp_freezetime", 5);
	set_cvar_float("mp_roundtime", 2.5);

	hns_restart_round(0.5);
}

public retake_player_join(id) {
	rg_join_team(id, rg_get_join_team_priority());
}
