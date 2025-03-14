static g_pRoundTime;

enum _: CVARS
{
	RULES,
	Float:WINTIME,
	MAXROUNDS,
	DUELROUNDS,
	HNSBOOST,
	ONEHPMODE,
	FLASH,
	SMOKE,
	LASTGRENADE,
	Float:DMRESPAWN,
	SUTVOTETIME,
	SURTIMEDELAY,
	RANDOMPICK,
	Float:TIME_RANDOMPICK,
	KNIFEMAP[24],
	PREFIX[24],
	GAMENAME,
	WATCHER_FLAG[4],
	FULL_WATCHER_FLAG[4],
	ADMIN_FLAG[4],
}

new pCvar[CVARS];
new _:g_iSettings[CVARS];

stock cvars_init() {
	g_pRoundTime = get_cvar_pointer("mp_roundtime");

	pCvar[RULES] = create_cvar("hns_rules", "0", FCVAR_NONE, "Match rules (0 - MR 1 - Timer)", true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar[RULES], g_iSettings[RULES]);

	pCvar[WINTIME] = _:create_cvar("hns_wintime", "15", FCVAR_NONE, "Match wintime (Timer)", true, 0.0, true, 30.0);
	bind_pcvar_float(_:pCvar[WINTIME], g_iSettings[WINTIME]);

	pCvar[MAXROUNDS] = create_cvar("hns_rounds", "6", FCVAR_NONE, "Match rounds (MR)", true, 0.0, true, 10.0);
	bind_pcvar_num(pCvar[MAXROUNDS], g_iSettings[MAXROUNDS]);

	pCvar[DUELROUNDS] = create_cvar("hns_duel", "3", FCVAR_NONE, "Match 1x1 rounds", true, 0.0, true, 10.0);
	bind_pcvar_num(pCvar[DUELROUNDS], g_iSettings[DUELROUNDS]);

	pCvar[HNSBOOST] = create_cvar("hns_boost", "0", FCVAR_NONE, "Boost mode (0/1)", true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar[HNSBOOST], g_iSettings[HNSBOOST]);

	pCvar[ONEHPMODE] = create_cvar("hns_onehpmode", "0", FCVAR_NONE, "One hp mode (0/1)", true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar[ONEHPMODE], g_iSettings[ONEHPMODE]);

	pCvar[FLASH] = create_cvar("hns_flash", "1", FCVAR_NONE, "Flash num", true, 0.0, true, 10.0);
	bind_pcvar_num(pCvar[FLASH], g_iSettings[FLASH]);

	pCvar[SMOKE] = create_cvar("hns_smoke", "1", FCVAR_NONE, "Smoke num", true, 0.0, true, 10.0);
	bind_pcvar_num(pCvar[SMOKE], g_iSettings[SMOKE]);

	pCvar[LASTGRENADE] = create_cvar("hns_last", "1", FCVAR_NONE, "Last grenade TT (0/1)", true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar[LASTGRENADE], g_iSettings[LASTGRENADE]);

	pCvar[DMRESPAWN] = _:create_cvar("hns_dmrespawn", "3", FCVAR_NONE, "Respawn deathmatch time", true, 0.0, true, 10.0);
	bind_pcvar_float(_:pCvar[DMRESPAWN], g_iSettings[DMRESPAWN]);

	pCvar[SUTVOTETIME] = create_cvar("hns_survotetime", "10", FCVAR_NONE, "Surrender vote time", true, 0.0, true, 20.0);
	bind_pcvar_num(pCvar[SUTVOTETIME], g_iSettings[SUTVOTETIME]);

	pCvar[SURTIMEDELAY] = create_cvar("hns_surtimedelay", "120", FCVAR_NONE, "Surrender time delay", true, 0.0);
	bind_pcvar_num(pCvar[SURTIMEDELAY], g_iSettings[SURTIMEDELAY]);

	pCvar[RANDOMPICK] = create_cvar("hns_randompick", "1", FCVAR_NONE, "Random pick", true, 0.0, true, 1.0);
	bind_pcvar_num(pCvar[RANDOMPICK], g_iSettings[RANDOMPICK]);

	pCvar[TIME_RANDOMPICK] = _:create_cvar("hns_time_randompick", "25", FCVAR_NONE, "Time Random pick", true, 10.0, true, 45.0);
	bind_pcvar_float(_:pCvar[TIME_RANDOMPICK], g_iSettings[TIME_RANDOMPICK]);

	pCvar[KNIFEMAP] = create_cvar("hns_knifemap", "35hp_2", FCVAR_NONE, "Knife map");
	bind_pcvar_string(pCvar[KNIFEMAP], g_iSettings[KNIFEMAP], charsmax(g_iSettings[KNIFEMAP]));

	pCvar[PREFIX] = create_cvar("hns_prefix", "Match", FCVAR_NONE, "System prefix");
	bind_pcvar_string(pCvar[PREFIX], g_iSettings[PREFIX], charsmax(g_iSettings[PREFIX]));

	pCvar[GAMENAME] = create_cvar("hns_gamename", "Hide'n'Seek", FCVAR_NONE, "Game name");
	bind_pcvar_string(pCvar[GAMENAME], g_iSettings[GAMENAME], charsmax(g_iSettings[GAMENAME]));

	pCvar[WATCHER_FLAG] = create_cvar("hns_watcher_flag", "f", FCVAR_NONE, "Watcher access flag");
	bind_pcvar_string(pCvar[WATCHER_FLAG], g_iSettings[WATCHER_FLAG], charsmax(g_iSettings[WATCHER_FLAG]));

	pCvar[FULL_WATCHER_FLAG] = create_cvar("hns_fullwatcher_flag", "m", FCVAR_NONE, "Full watcher access flag");
	bind_pcvar_string(pCvar[FULL_WATCHER_FLAG], g_iSettings[FULL_WATCHER_FLAG], charsmax(g_iSettings[FULL_WATCHER_FLAG]));

	pCvar[ADMIN_FLAG] = create_cvar("hns_admin_flag", "b", FCVAR_NONE, "Admin access flag");
	bind_pcvar_string(pCvar[ADMIN_FLAG], g_iSettings[ADMIN_FLAG], charsmax(g_iSettings[ADMIN_FLAG]));
}

stock Float:get_round_time() {
	return get_pcvar_float(g_pRoundTime);
}

stock set_round_time(str[]) {
	set_pcvar_float(g_pRoundTime, str_to_float(str));
}
