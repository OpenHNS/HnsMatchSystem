public pub_init() {
	g_ModFuncs[MODE_PUB][MODEFUNC_START] = CreateOneForward(g_PluginId, "pub_start");
}

public pub_start() {
	g_iCurrentMode = MODE_PUB;
	g_iMatchStatus = MATCH_NONE;
	g_iSettings[FLASH] = 1;
	g_iSettings[SMOKE] = 1;

	ChangeGameplay(GAMEPLAY_HNS);
	set_semiclip(SEMICLIP_ON, true);
	set_cvars_mode(MODE_PUB);
	loadMapCFG();
	g_iSettings[FLASH] = 1;

	hns_restart_round(0.5);
}