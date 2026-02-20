enum _:HNS_MODES
{
	MODE_TRAINING,
	MODE_KNIFE,
	MODE_PUB,
	MODE_DM,
	MODE_ZM,
	MODE_MIX
}
new g_iCurrentMode; 

enum _:MODE_FUNCS
{
	MODEFUNC_START,
	MODEFUNC_PAUSE,
	MODEFUNC_UNPAUSE,
	MODEFUNC_END,
	MODEFUNC_ROUNDSTART,
	MODEFUNC_ROUNDEND,
	MODEFUNC_FREEZEEND,
	MODEFUNC_KILL,
	MODEFUNC_RESTARTROUND,
	MODEFUNC_SWAP,
	MODEFUNC_PLAYER_JOIN,
	MODEFUNC_PLAYER_LEAVE,
	MODEFUNC_FALLDAMAGE
};

new g_ModFuncs[HNS_MODES][MODE_FUNCS];

public InitGameModes() {
	mix_init();
	kniferound_init();
	pub_init();
	dm_init();
	zm_init();
	mode_init();
	trainingmode_init();
}

public set_cvars_mode(iMode) {
	new szPath[128];
	get_configsdir(szPath, 127);
	format(szPath, 127, "%s/mixsystem/mode", szPath);

	switch (iMode) {
		case MODE_TRAINING: server_cmd("exec %s/training.cfg", szPath);
		case MODE_KNIFE: server_cmd("exec %s/knife.cfg", szPath);
		case MODE_PUB: server_cmd("exec %s/public.cfg", szPath);
		case MODE_DM: server_cmd("exec %s/deathmatch.cfg", szPath);
		case MODE_MIX: server_cmd("exec %s/match.cfg", szPath);
		case MODE_ZM: server_cmd("exec %s/zombie.cfg", szPath);
	}
}

stock set_pause_settings() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ahc");
	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];
		rg_remove_all_items(iPlayer);
		rg_give_item(iPlayer, "weapon_knife");
		setUserGodmode(iPlayer, true);
		rg_reset_maxspeed(iPlayer);
	}

	set_task(1.0, "taskHudPaused", .id = HUD_PAUSE, .flags = "b");
	rg_send_audio(0, "fvox/deactivated.wav");
	
	server_cmd("sv_alltalk 1");
}

stock set_unpause_settings() {
	if(task_exists(HUD_PAUSE)) {
		remove_task(HUD_PAUSE);
	}

	setTaskHud(0, 1.0, 1, 255, 255, 255, 3.0, "%L", LANG_SERVER, "HUD_UNPAUSE");
	rg_send_audio(0, "fvox/activated.wav");
	if (g_iCurrentRules != RULES_DUEL) {
		server_cmd("sv_alltalk 3");
	}
}

public taskHudPaused() { // убить таск
	if (g_eMatchState == STATE_PAUSED) {
		setTaskHud(0, 0.0, 1, 255, 255, 255, 1.0, "%L", LANG_SERVER, "HUD_PAUSE");
	}
}
