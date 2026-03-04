#include <hns-match/index>

public plugin_precache() {
	engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "func_buyzone"));
	g_iRegisterSpawn = register_forward(FM_Spawn, "fwdSpawn", 1);

	precache_sound(sndUseSound);

	iBeam = precache_model("sprites/laserbeam.spr");
}

public plugin_cfg() {
	get_localinfo("amxx_logs", g_szLogPath, charsmax(g_szLogPath));
	add(g_szLogPath, charsmax(g_szLogPath), "/hnsmatchsystem");

	if (!dir_exists(g_szLogPath))
		mkdir(g_szLogPath);
}

public plugin_init() {
	g_PluginId = register_plugin("Hide'n'Seek Match System", "2.2.0", "OpenHNS"); // Спасибо: Cultura, Garey, Medusa, Ruffman, Conor, Juice

	rh_get_mapname(g_szMapName, charsmax(g_szMapName));

	cvars_init();

	init_gameplay();
	InitGameModes();

	cmds_init();

	register_forward(FM_EmitSound, "fwdEmitSoundPre", 0);
	register_forward(FM_ClientKill, "fwdClientKill");
	register_forward(FM_GetGameDescription, "fwdGameNameDesc");

	RegisterHookChain(RG_RoundEnd, "rgRoundEnd", false);
	RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "rgResetMaxSpeed", false);
	RegisterHookChain(RG_CSGameRules_RestartRound, "rgRestartRound", false);
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "rgOnRoundFreezeEnd", true);
	RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "rgFlPlayerFallDamage", true);
	RegisterHookChain(RG_CBasePlayer_Spawn, "rgPlayerSpawn", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "rgPlayerKilled", true);
	RegisterHookChain(RG_PlayerBlind, "rgPlayerBlind", false);
	RegisterHookChain(RG_CBasePlayer_MakeBomber, "rgPlayerMakeBomber", false);
	RegisterHookChain(RG_ShowMenu, "rgShowMenu", false);
	RegisterHookChain(RG_ShowVGUIMenu, "rgShowVGUIMenu", false);

	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_knife", "Knife_PrimaryAttack", false);

	register_message(get_user_msgid("HostagePos"), "msgHostagePos");
	register_message(get_user_msgid("HideWeapon"), "msgHideWeapon");

	unregister_forward(FM_Spawn, g_iRegisterSpawn, 1);
	

	set_msg_block(get_user_msgid("HudTextArgs"), BLOCK_SET);
	set_msg_block(g_msgMoney = get_user_msgid("Money"), BLOCK_SET);

	set_task(0.1, "ShowTimeAsMoney", 15671983, .flags="b"); // TODO: Что это за число

	g_aPlayersLoadData = ArrayCreate(SAVE_PLAYER_DATA);
	loadPlayers();

	forward_init();

	registerMode();


	g_eMatchInfo[e_tLeaveData] = TrieCreate();

	register_dictionary("mixsystem.txt");

	new szPath[PLATFORM_MAX_PATH];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	format(szPath, charsmax(szPath), "%s/mixsystem/%s", szPath, "matchsystem.cfg");
	server_cmd("exec %s", szPath);

	g_bDebugMode = bool:(plugin_flags() & AMX_FLAG_DEBUG);

	set_task(1.0, "HudTask", .flags = "b");
}

// TODO: Перенести в cup
public HudTask() {
	if (g_iCurrentMode == MODE_MIX && hns_cup_enabled()) {
		new szTimeToWin[HNS_TEAM][24], szTimeDiff[24];

		new Float:fTimeDiff = floatabs(g_eMatchInfo[e_flSidesTime][g_isTeamTT] - g_eMatchInfo[e_flSidesTime][HNS_TEAM:!g_isTeamTT]);
		fnConvertTime(fTimeDiff, szTimeDiff, charsmax(szTimeDiff), false);

		new Float:flCapTime = floatmul(g_eMatchInfo[e_mWintime], 60.0);
		new Float:flTimeToWinA = floatsub(flCapTime, Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_A]);
		new Float:flTimeToWinB = floatsub(flCapTime, Float:g_eMatchInfo[e_flSidesTime][HNS_TEAM_B]);
		fnConvertTime(flTimeToWinA, szTimeToWin[HNS_TEAM_A], 23, false);
		fnConvertTime(flTimeToWinB, szTimeToWin[HNS_TEAM_B], 23, false);

		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ce", "SPECTATOR");
		for (new id, i = 0; i < iNum; i++) {
			id = iPlayers[i];

			if (!is_user_hltv(id)) {
				continue;
			}

			set_hudmessage(0, 190, 255, -1.0, 0.98, 0, 0.0, 1.0, 0.1, 0.1, -1);
			if (g_isTeamTT == HNS_TEAM_A) {
				show_hudmessage(id, "TT [%s] vs [%s] CT (%s diff)", szTimeToWin[HNS_TEAM_A], szTimeToWin[HNS_TEAM_B], szTimeDiff);
			} else {
				show_hudmessage(id, "TT [%s] vs [%s] CT (%s diff)", szTimeToWin[HNS_TEAM_B], szTimeToWin[HNS_TEAM_A], szTimeDiff);
			}
		}

	}
}

public forward_init() {
	g_hForwards[MATCH_START] = CreateMultiForward("hns_match_started", ET_CONTINUE);
	g_hForwards[MATCH_RESET_ROUND] = CreateMultiForward("hns_match_reset_round", ET_CONTINUE);
	g_hForwards[MATCH_FINISH] = CreateMultiForward("hns_match_finished", ET_CONTINUE, FP_CELL);
	g_hForwards[MATCH_FINISH_POST] = CreateMultiForward("hns_match_finished_post", ET_CONTINUE, FP_CELL);
	g_hForwards[MATCH_CANCEL] = CreateMultiForward("hns_match_canceled", ET_CONTINUE);
	g_hForwards[MATCH_LEAVE_PLAYER] = CreateMultiForward("hns_player_leave_inmatch", ET_CONTINUE, FP_CELL);
	g_hForwards[MATCH_JOIN_PLAYER] = CreateMultiForward("hns_player_join_inmatch", ET_CONTINUE, FP_CELL, FP_CELL);

	g_hForwards[HNS_ROUND_START] = CreateMultiForward("hns_round_start", ET_CONTINUE);
	g_hForwards[HNS_ROUND_FREEZEEND] = CreateMultiForward("hns_round_freezeend", ET_CONTINUE);
	g_hForwards[HNS_ROUND_END] = CreateMultiForward("hns_round_end", ET_CONTINUE);
}

public MATCH_STATUS:native_get_status(amxx, params) {
	return g_iMatchStatus;
}

public MODE_STATES:native_get_state(amxx, params) {
	return g_eMatchState;
}

public NATCH_RULES:native_get_rules(amxx, params) {
	return g_iCurrentRules;
}

public fwdEmitSoundPre(id, iChannel, szSample[], Float:volume, Float:attenuation, fFlags, pitch) {
	if (equal(szSample, "weapons/knife_deploy1.wav")) {
		return FMRES_SUPERCEDE;
	}

	if (is_user_alive(id) && getUserTeam(id) == TEAM_TERRORIST && equal(szSample, sndDenySelect)) {
		emit_sound(id, iChannel, sndUseSound, volume, attenuation, fFlags, pitch);
		return FMRES_SUPERCEDE;
	}
	return FMRES_IGNORED;
}

public fwdClientKill(id) {
	if (g_iCurrentMode == MODE_DM || g_iCurrentMode == MODE_DM_1TT) {
		client_print_color(id, print_team_blue, "%L", id, "KILL_NOT", g_iSettings[PREFIX]);
		return FMRES_SUPERCEDE;
	} else if (g_iCurrentMode == MODE_MIX && g_iCurrentRules == RULES_MR && g_flRoundTime < 90.0) {
		client_print_color(id, print_team_blue, "%L", id, "KILL_NOT_MIX", g_iSettings[PREFIX]);
		return FMRES_SUPERCEDE;
	} else {
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "KILL_HIMSELF", g_iSettings[PREFIX], id);
	}
	return FMRES_IGNORED;
}

public fwdGameNameDesc()
{
	static gamename[32];
	get_pcvar_string(pCvar[GAMENAME], gamename, 31);
	forward_return(FMV_STRING, gamename);
	return FMRES_SUPERCEDE;
}

public fwdSpawn(entid) {
	static szClassName[32];
	if (pev_valid(entid)) {
		pev(entid, pev_classname, szClassName, 31);
		if (equal(szClassName, "func_buyzone")) engfunc(EngFunc_RemoveEntity, entid);

		for (new i = 0; i < sizeof g_szDefaultEntities; i++) {
			if (equal(szClassName, g_szDefaultEntities[i])) {
				engfunc(EngFunc_RemoveEntity, entid);
				break;
			}
		}
	}
}


public rgRoundEnd(WinStatus:status, ScenarioEventEndRound:event, Float:tmDelay) {
	if (event == ROUND_GAME_COMMENCE) {
		set_member_game(m_bGameStarted, true);
		SetHookChainReturn(ATYPE_BOOL, false);
		return HC_SUPERCEDE;
	}

	if (g_iCurrentMode == MODE_ZM && event == ROUND_TERRORISTS_WIN) {
        set_member_game(m_bGameStarted, true);
        SetHookChainReturn(ATYPE_BOOL, false);
        return HC_SUPERCEDE;
    }

	ExecuteForward(g_hForwards[HNS_ROUND_END]);

	if (g_GPFuncs[g_iCurrentGameplay][GP_ROUNDEND])
		ExecuteForward(g_GPFuncs[g_iCurrentGameplay][GP_ROUNDEND], _, (status == WINSTATUS_CTS) ? true : false);

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDEND])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDEND], _, (status == WINSTATUS_CTS) ? true : false);
	
	return HC_CONTINUE;
}

public rgResetMaxSpeed(id) {
	if (get_member_game(m_bFreezePeriod)) {
		if (g_iCurrentMode == MODE_TRAINING) {
			set_entvar(id, var_maxspeed, 250.0);
			return HC_SUPERCEDE;
		}

		if (getUserTeam(id) == TEAM_TERRORIST) {
			set_entvar(id, var_maxspeed, 250.0);
			return HC_SUPERCEDE;
		}
	}
	return HC_CONTINUE;
}

public rgRestartRound() { // Сделать красиво
	set_task(1.0, "taskDestroyBreakables");

	if (g_GPFuncs[g_iCurrentGameplay][GP_ROUNDSTART])
		ExecuteForward(g_GPFuncs[g_iCurrentGameplay][GP_ROUNDSTART], _);

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDSTART])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_ROUNDSTART], _);

	ExecuteForward(g_hForwards[HNS_ROUND_START]);
}

public taskDestroyBreakables() {
	new iEntity = -1;
	while ((iEntity = rg_find_ent_by_class(iEntity, "func_breakable"))) {
		if (get_entvar(iEntity, var_takedamage)) {
			set_entvar(iEntity, var_origin, Float:{ 10000.0, 10000.0, 10000.0 });
		}
	}
}

public rgOnRoundFreezeEnd() {
	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_FREEZEEND], _);

	ExecuteForward(g_hForwards[HNS_ROUND_FREEZEEND]);
}

public rgFlPlayerFallDamage(const id) {
	new Float:flDmg = Float:GetHookChainReturn(ATYPE_FLOAT);

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_FALLDAMAGE])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_FALLDAMAGE], _, id, flDmg);
}

public rgPlayerSpawn(id) {
	if (!is_user_alive(id) || is_user_bot(id) || is_user_hltv(id))
		return;

	if (g_GPFuncs[g_iCurrentGameplay][GP_SETROLE])
	{
		ExecuteForward(g_GPFuncs[g_iCurrentGameplay][GP_SETROLE], _, id);
	}
}

public rgPlayerKilled(victim, attacker) {
	if (g_GPFuncs[g_iCurrentGameplay][GP_KILLED])
		ExecuteForward(g_GPFuncs[g_iCurrentGameplay][GP_KILLED], _, victim, attacker);

	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_KILL])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_KILL], _, victim, attacker);
}

public rgPlayerBlind(const index, const inflictor, const attacker, const Float:fadeTime, const Float:fadeHold, alpha) {
	if (getUserTeam(index) == TEAM_TERRORIST || getUserTeam(index) == TEAM_SPECTATOR)
		return HC_SUPERCEDE;

	return HC_CONTINUE;
}

public rgPlayerMakeBomber(const this) {
	SetHookChainReturn(ATYPE_BOOL, false);
	return HC_SUPERCEDE;
}

public registerMode() {
	g_iHostageEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "hostage_entity"));
	set_pev(g_iHostageEnt, pev_origin, Float:{ 0.0, 0.0, -55000.0 });
	set_pev(g_iHostageEnt, pev_size, Float:{ -1.0, -1.0, -1.0 }, Float:{ 1.0, 1.0, 1.0 });
	dllfunc(DLLFunc_Spawn, g_iHostageEnt);
}

public client_disconnected(id) {
	if (g_ModFuncs[g_iCurrentMode][MODEFUNC_PLAYER_LEAVE])
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_PLAYER_LEAVE], _, id);

	e_bBanned[id] = false;
	g_iBanExpired[id] = 0;

	g_bNoplay[id] = false;
	g_eSpecBack[id] = TEAM_UNASSIGNED;

	arrayset(eAfkData[id], 0, AfkData_s);
	arrayset(flAfkOrigin[id], 0.0, sizeof(flAfkOrigin[]));
	g_bSurrenderVoted[id] = false;
	isHook[id] = false;
}

public Knife_PrimaryAttack(ent)
{
	//new id = get_member(ent, m_pPlayer); // TODO
	/* get_member(id, m_iTeam) == _:CS_TEAM_CT */ // Условие тоже TODO

	if (g_iCurrentMode || g_iCurrentGameplay == GAMEPLAY_KNIFE)
	{
		ExecuteHamB(Ham_Weapon_SecondaryAttack, ent);
		return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}

public msgHostagePos(msgid, dest, id) {
	return PLUGIN_HANDLED;
}

public rgShowMenu(const index, const bitsSlots, const iDisplayTime, const iNeedMore, const szText[]) {
	LogSendMessage("rgShowMenu: enter id=%d bits=%d display=%d needMore=%d text='%s' mode=%d status=%d team=%d task_exists=%d",
		index, bitsSlots, iDisplayTime, iNeedMore, szText, g_iCurrentMode, g_iMatchStatus, get_user_team(index), task_exists(index));

	if (!shouldAutoJoin(index)) {
		return HC_CONTINUE;
	}

	new bool:bKnifeMap = hns_is_knife_map();
	new bool:bCupEnabled = bool:hns_cup_enabled();
	if (bKnifeMap && bCupEnabled) {
		new bool:bNeedControl = first_join_need_control();
		if (!bNeedControl) {
			return HC_CONTINUE;
		}
	}

	if (!equal(szText, "#Team_Select")) {
		LogSendMessage("rgShowMenu: id=%d -> HC_CONTINUE (text!='#Team_Select', text='%s')", index, szText);
		return HC_CONTINUE;
	}

	setForceTeamJoinTask(index, get_user_msgid("ShowMenu"));
	LogSendMessage("rgShowMenu: id=%d -> HC_SUPERCEDE (scheduled force team join, msgid=%d)", index, get_user_msgid("ShowMenu"));

	return HC_SUPERCEDE;
}

public rgShowVGUIMenu(const index, VGUIMenu:menuType, const bitsSlots, const szOldMenu[]) {
	LogSendMessage("rgShowVGUIMenu: enter id=%d menuType=%d bits=%d oldMenu='%s' mode=%d status=%d team=%d task_exists=%d",
		index, _:menuType, bitsSlots, szOldMenu, g_iCurrentMode, g_iMatchStatus, get_user_team(index), task_exists(index));

	if (menuType != VGUI_Menu_Team) {
		LogSendMessage("rgShowVGUIMenu: id=%d -> HC_CONTINUE (menuType=%d != VGUI_Menu_Team)", index, _:menuType);
		return HC_CONTINUE;
	}

	if (!shouldAutoJoin(index)) {
		return HC_CONTINUE;
	}
	
	new bool:bKnifeMap = hns_is_knife_map();
	new bool:bCupEnabled = bool:hns_cup_enabled();
	if (bKnifeMap && bCupEnabled) {
		new bool:bNeedControl = first_join_need_control();
		if (!bNeedControl) {
			LogSendMessage("rgShowVGUIMenu: id=%d -> HC_CONTINUE (knife_map=1 cup_enabled=1 need_control=0)", index);
			return HC_CONTINUE;
		}
	}

	setForceTeamJoinTask(index, get_user_msgid("VGUIMenu"));
	LogSendMessage("rgShowVGUIMenu: id=%d -> HC_SUPERCEDE (scheduled force team join, msgid=%d)", index, get_user_msgid("VGUIMenu"));

	return HC_SUPERCEDE;
}

public msgHideWeapon(msgid, dest, id) {
	if (g_iCurrentMode != MODE_MIX) {
		const money = (1 << 5);
		set_msg_arg_int(1, ARG_BYTE, get_msg_arg_int(1) | money);
	}
}

bool:shouldAutoJoin(id) {
	new iTeam = get_user_team(id);
	new bool:bTaskExists = bool:task_exists(id);
	new bool:bResult = (!iTeam && !bTaskExists);
	LogSendMessage("shouldAutoJoin: id=%d team=%d task_exists=%d -> %d", id, iTeam, bTaskExists, bResult);
	return bResult;
}

setForceTeamJoinTask(id, menu_msgid) {
	static param_menu_msgid[2];
	param_menu_msgid[0] = menu_msgid;
	LogSendMessage("setForceTeamJoinTask: id=%d menu_msgid=%d delay=0.1", id, menu_msgid);

	set_task(0.1, "taskForceTeamJoin", id, param_menu_msgid, sizeof param_menu_msgid);
}

public taskForceTeamJoin(menu_msgid[], id) {
	new iTeam = get_user_team(id);
	LogSendMessage("taskForceTeamJoin: enter id=%d team=%d menu_msgid=%d mode=%d status=%d",
		id, iTeam, menu_msgid[0], g_iCurrentMode, g_iMatchStatus);

	if (iTeam) {
		LogSendMessage("taskForceTeamJoin: id=%d return (already has team=%d)", id, iTeam);
		return;
	}

	if (first_join_control(id, menu_msgid[0])) {
		LogSendMessage("taskForceTeamJoin: id=%d return (first_join_control handled)", id);
		return;
	}

	if (g_iCurrentMode == MODE_DM_1TT) {
		LogSendMessage("taskForceTeamJoin: id=%d MODE_DM_1TT -> forceTeamJoin(team='2', class='5')", id);
		forceTeamJoin(id, menu_msgid[0], "2", "5");
		return;
	}

	LogSendMessage("taskForceTeamJoin: id=%d default -> forceTeamJoin(team='5', class='5')", id);
	forceTeamJoin(id, menu_msgid[0], "5", "5");
}

stock bool:first_join_control(id, menu_msgid) {
	LogSendMessage("first_join_control: enter id=%d mode=%d status=%d menu_msgid=%d", id, g_iCurrentMode, g_iMatchStatus, menu_msgid);

	switch (g_iMatchStatus) {
		case MATCH_CAPTAINKNIFE, MATCH_CAPTAINBATTLE, MATCH_CUPKNIFE, MATCH_CUPPICK, MATCH_TEAMKNIFE, MATCH_TEAMBATTLE: {
			LogSendMessage("first_join_control: id=%d status=%d -> force spec/team choose ('6')", id, g_iMatchStatus);
			forceTeamJoin(id, menu_msgid, "6");
			return true;
		}
		case MATCH_CAPTAINPICK, MATCH_TEAMPICK, MATCH_MAPPICK: {
			new bool:bMatchPlayer = first_join_is_match_player(id);
			LogSendMessage("first_join_control: id=%d status=%d is_match_player=%d", id, g_iMatchStatus, bMatchPlayer);
			if (!bMatchPlayer) {
				LogSendMessage("first_join_control: id=%d -> force spec/team choose ('6')", id);
				forceTeamJoin(id, menu_msgid, "6");
				return true;
			}
		}
		case MATCH_STARTED: {
			if (g_iCurrentMode == MODE_MIX) {
				new bool:bMatchPlayer = first_join_is_match_player(id);
				LogSendMessage("first_join_control: id=%d MATCH_STARTED MODE_MIX is_match_player=%d", id, bMatchPlayer);
				if (!bMatchPlayer) {
					LogSendMessage("first_join_control: id=%d -> force spec/team choose ('6')", id);
					forceTeamJoin(id, menu_msgid, "6");
					return true;
				}
			}
		}
	}

	LogSendMessage("first_join_control: id=%d -> false (no special handling)", id);
	return false;
}

stock bool:first_join_need_control() {
	if (g_iCurrentMode == MODE_MIX && g_iMatchStatus == MATCH_STARTED) {
		return true;
	}

	switch (g_iMatchStatus) {
		case MATCH_CAPTAINPICK, MATCH_CAPTAINKNIFE, MATCH_CAPTAINBATTLE, MATCH_TEAMPICK, MATCH_CUPKNIFE, MATCH_CUPPICK, MATCH_TEAMKNIFE, MATCH_TEAMBATTLE, MATCH_MAPPICK: {
			return true;
		}
	}

	return false;
}

stock bool:first_join_is_match_player(id) {
	if (g_eMatchInfo[e_tLeaveData] == Invalid_Trie) {
		return false;
	}

	new eLeaveData[PLAYER_INFO];
	new szAuth[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuth, charsmax(szAuth));
	
	if (!TrieGetArray(g_eMatchInfo[e_tLeaveData], szAuth, eLeaveData, PLAYER_INFO)) {
		return false;
	}

	return eLeaveData[PLAYER_MATCH];
}


stock forceTeamJoin(id, menu_msgid, team[] = "5", class[] = "0") {
	LogSendMessage("forceTeamJoin: id=%d menu_msgid=%d team='%s' class='%s'", id, menu_msgid, team, class);

	static jointeam[] = "jointeam";
	if (class[0] == '0') {
		LogSendMessage("forceTeamJoin: id=%d jointeam only", id);
		engclient_cmd(id, jointeam, team);
		return;
	}

	static msg_block, joinclass[] = "joinclass";
	msg_block = get_msg_block(menu_msgid);
	LogSendMessage("forceTeamJoin: id=%d msg_block(old)=%d -> block menu message and send jointeam/joinclass", id, msg_block);
	set_msg_block(menu_msgid, BLOCK_SET);
	engclient_cmd(id, jointeam, team);
	engclient_cmd(id, joinclass, class);
	set_msg_block(menu_msgid, msg_block);

	LogSendMessage("forceTeamJoin: id=%d scheduled taskSetPlayerTeam delay=0.2", id);
	set_task(0.2, "taskSetPlayerTeam", id);
}

public taskSetPlayerTeam(id) {
	new bool:bConnected = bool:is_user_connected(id);
	LogSendMessage("taskSetPlayerTeam: enter id=%d connected=%d mode=%d status=%d", id, bConnected, g_iCurrentMode, g_iMatchStatus);

	if (!bConnected) {
		LogSendMessage("taskSetPlayerTeam: id=%d return (not connected)", id);
		return;
	}

	new iJoinForward = g_ModFuncs[g_iCurrentMode][MODEFUNC_PLAYER_JOIN];
	if (iJoinForward) {
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_PLAYER_JOIN], _, id);
	} else {
		LogSendMessage("taskSetPlayerTeam: id=%d skip ExecuteForward (forward not set)", id);
	}
}

public ShowTimeAsMoney()
{
	if (g_iCurrentMode == MODE_MIX && g_iMatchStatus == MATCH_STARTED && g_iCurrentRules == RULES_TIMER) {
		static players[32], num, id
		get_players(players, num, "ac");
		for(--num; num>=0; num--)
		{
			id = players[num];

			message_begin(MSG_ONE, g_msgMoney, .player=id);
			write_long(floatround((g_eMatchInfo[e_mWintime] * 60.0) - g_eMatchInfo[e_flSidesTime][g_isTeamTT], floatround_floor));
			write_byte(0);
			message_end();
		}
	}
}

public plugin_end() {
	TrieDestroy(g_eMatchInfo[e_tLeaveData]);
	ArrayDestroy(g_aPlayersLoadData);
}
