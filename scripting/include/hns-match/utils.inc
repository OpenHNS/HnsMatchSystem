#if defined _utils_included
  #endinput
#endif

#define _utils_included

enum {
	SEMICLIP_ON,
	SEMICLIP_OFF
}

stock hns_restart_round(Float:delay = 0.5) {
	rg_round_end(delay, WINSTATUS_DRAW, ROUND_END_DRAW, "Round Restarted", "none");

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_RESTARTROUND])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_RESTARTROUND], _);
}

stock hns_swap_teams() {
	g_eMatchState = STATE_PREPARE;

	rg_swap_all_players();

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_SWAP])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_SWAP], _);
}

stock chat_print(const id, const message[], any:...) {
	new msgFormated[191];

	vformat(msgFormated, charsmax(msgFormated), message, 3);

	if (!g_iSettings[PREFIX][0])
		client_print_color(id, print_team_blue, "%s", msgFormated);
	else
		client_print_color(id, print_team_blue, "[^3%s^1] %s", g_iSettings[PREFIX], msgFormated);
}

stock set_semiclip(opt, bool:enemy = false) {
	switch(opt) {
		case SEMICLIP_ON: { 
			server_cmd("semiclip_option semiclip 1"); 
			server_cmd("semiclip_option team %d", enemy ? 3 : 0); 
		}
		case SEMICLIP_OFF: {
			server_cmd("semiclip_option semiclip 0"); // off
			server_cmd("semiclip_option team 0");
		}
	}
	server_cmd("semiclip_option time 0");
}

stock fnConvertTime(Float:time, convert_time[], len, bool:with_intpart = true) {
	new szTemp[24];
	new Float:flSeconds = time, iMinutes;

	iMinutes = floatround(flSeconds / 60.0, floatround_floor);
	flSeconds -= iMinutes * 60.0;
	new intpart = floatround(flSeconds, floatround_floor);
	new Float:decpart = (flSeconds - intpart) * 100.0;

	if (with_intpart) {
		intpart = floatround(decpart);
		formatex(szTemp, charsmax(szTemp), "%02i:%02.0f.%d", iMinutes, flSeconds, intpart);
	} else {
		formatex(szTemp, charsmax(szTemp), "%02i:%02.0f", iMinutes, flSeconds);
	}

	formatex(convert_time, len, "%s", szTemp);

	return PLUGIN_HANDLED;
}

stock setTaskHud(id, Float:Time, Dhud, Red, Green, Blue, Float:HoldTime, const Text[], any: ...) {
	new szMessage[128]; vformat(szMessage, charsmax(szMessage), Text, 9);
	new szArgs[7];
	szArgs[0] = id;
	szArgs[1] = encodeText(szMessage);
	szArgs[2] = Red;
	szArgs[3] = Green;
	szArgs[4] = Blue;
	szArgs[5] = Dhud;
	szArgs[6] = _:HoldTime;
	if (Time > 0.0)
		set_task(Time, "taskHudMessage", 89000, szArgs, 7);
	else
		taskHudMessage(szArgs);
}

public taskHudMessage(Params[]) {
	new id, Text[128], RRR, GGG, BBB, dhud, Float:HoldTime;
	id = Params[0];
	decodeText(Params[1], Text, charsmax(Text));
	RRR = Params[2];
	GGG = Params[3];
	BBB = Params[4];
	dhud = Params[5];
	HoldTime = Float:Params[6];
	if (!id || is_user_connected(id)) {
		if (dhud) {
			set_dhudmessage(RRR, GGG, BBB, -1.0, 0.2, 0, 0.0, HoldTime, 0.1, 0.1);

			show_dhudmessage(id, Text);
		} else {
			set_hudmessage(RRR, GGG, BBB, -1.0, 0.2, 0, 0.0, HoldTime, 0.1, 0.1, -1);
			show_hudmessage(id, Text);
		}
	}
}

stock encodeText(const text[]) {
	return engfunc(EngFunc_AllocString, text);
}

stock decodeText(const text, string[], const length) {
	global_get(glb_pStringBase, text, string, length);
}

stock loadMapCFG() {
	new szPath[128];
	get_configsdir(szPath, 127);
	format(szPath, 127, "%s/mixsystem", szPath);
	if (!dir_exists(szPath))
		mkdir(szPath);

	format(szPath, 127, "%s/mapcfg/%s.cfg", szPath, g_szMapName);

	if (file_exists(szPath)) {
		server_cmd("exec %s", szPath);
	} else {
		if (g_iSettings[HNSBOOST]) {
			set_cvar_num("mp_freezetime", 15);
			set_cvar_float("mp_roundtime", 3.5);
			g_iSettings[FLASH] = 3;
			g_iSettings[SMOKE] = 1;
		} else {
			set_cvar_num("mp_freezetime", 5);
			set_cvar_float("mp_roundtime", 2.5);
			g_iSettings[FLASH] = 1;
			g_iSettings[SMOKE] = 1;
		}
	}
}

remove_entity_m(const Zone[]) {
	new iEntity = 0;
	while ((iEntity = rg_find_ent_by_class(iEntity, Zone))) {
		set_entvar(iEntity, var_flags, get_entvar(iEntity, var_flags) | FL_KILLME);
		set_entvar(iEntity, var_nextthink, get_gametime());
	}
	
	set_member_game(m_bMapHasBuyZone, true);
	set_member_game(m_bMapHasBombZone, false);
}

public LogSendMessage(szData[1024], any:...) {
	if (!g_bDebugMode) {
		return
	}
	new szLogFile[128];

	new szPath[128];
	formatex(szPath, charsmax(szPath), "%s", g_szLogPath);

	new szTime[22];
	get_time("%m_%d", szTime, charsmax(szTime));
	formatex(szLogFile, charsmax(szLogFile), "%s/%s.log", szPath, szTime);

	new msgFormated[1024];

	vformat(msgFormated, charsmax(msgFormated), szData, 2);

	log_to_file(szLogFile, msgFormated)
}

stock bool:hns_is_knife_map() {
	if (hnsmatch_maps_init()) {
		return hnsmatch_maps_is_knife();
	}
	if (equali(g_szMapName, g_iSettings[KNIFEMAP])) {
		return true;
	} else {
		return false;
	}
}