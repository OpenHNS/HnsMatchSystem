#include <amxmodx>
#include <fakemeta_util>
#include <reapi>
#include <hns_matchsystem>
#include <hns_matchsystem_filter>
#include <hns_matchsystem_maps>

const TASK_START_BATTLE = 78291;
const TASK_PLAYER_CHANCE = 13901;

new const g_szSounds[][] = {
	"openhns/battle/prepare.wav",
	"openhns/battle/one.wav",
	"openhns/battle/two.wav",
	"openhns/battle/three.wav",
	"openhns/battle/fight.wav"
};

enum _: BattleData_s {
	bool:BATTLE_ENABLED,
	BATTLE_ARENA,
	BATTLE_INITIATOR,
	BATTLE_PREPARE,
	bool:BATTLE_CHANCE
};

enum _: CollideData_s {
	block_id,
	Float:dont_collide_after
};

enum _: ArenaInfo_s {
	a_name[32],
	a_target[32],
	a_entid
};

new g_sPrefix[24], g_szMap[32];
new g_eBattleData[BattleData_s], bool:g_bChanceForPlayers[MAX_PLAYERS + 1];
new Array:g_aColide[MAX_PLAYERS + 1], Float:g_flTouchDelay[MAX_PLAYERS + 1];

new Array:g_aArenas;
new bool:g_bArenasLoaded;

public plugin_precache() {
	for (new i; i < sizeof(g_szSounds); i++)
		precache_sound(g_szSounds[i]);
}

public plugin_natives() {
	register_native("hns_battle_init", "native_battle_init");
	register_native("hns_battle_arenas_init", "native_battle_arenas_init");
	register_native("hns_battle_start", "native_battle_start");
	register_native("hns_battle_end", "native_battle_end");
	register_native("hns_battle_menu", "native_battle_menu");

	set_native_filter("match_system_additons");
}

public native_battle_init(amxx, params) {
	return 1;
}

public native_battle_arenas_init(amxx, params) {
	if (!g_aArenas) {
		g_aArenas = ArrayCreate(ArenaInfo_s);
		get_mapname(g_szMap, charsmax(g_szMap));
	}

	if (!g_bArenasLoaded || !GetArenaCount()) {
		LoadArenasFromIni();
	}

	if (g_bArenasLoaded) {
		FindArenas();
	}

	return g_bArenasLoaded && GetArenaCount() > 0;
}

public bool:native_battle_start(amxx, params) {
	new iArena = 0;
	new bool:bChance = false;

	if (params >= 1) {
		iArena = get_param(1);
	}

	if (params >= 2) {
		bChance = bool:get_param(2);
	}

	if (hns_get_mode() == MODE_KNIFE && g_eBattleData[BATTLE_ENABLED]) {
		return true;
	}

	if (!can_start_battle_now()) {
		return false;
	}

	g_eBattleData[BATTLE_INITIATOR] = 0;
	g_eBattleData[BATTLE_CHANCE] = bChance;
	StartBattle(iArena);

	return g_eBattleData[BATTLE_ENABLED];
}

public bool:native_battle_end(amxx, params) {
	new bool:bSetTraining = true;

	if (params >= 1) {
		bSetTraining = bool:get_param(1);
	}

	EndBattle(bSetTraining);

	return !g_eBattleData[BATTLE_ENABLED];
}

public bool:native_battle_menu(amxx, params) {
	if (params < 1) {
		return false;
	}

	new id = get_param(1);
	if (!is_user_connected(id) || !isUserWatcher(id) || !can_start_race_now()) {
		return false;
	}

	CmdStartRace(id);
	return true;
}

public plugin_init() {
	register_plugin("Match: Battles (cfg)", "dev", "OpenHNS");
	register_dictionary("match_additons.txt");

	get_mapname(g_szMap, charsmax(g_szMap));

	// инициализация массивов
	for (new i = 1; i <= MaxClients; i++) {
		g_aColide[i] = ArrayCreate(CollideData_s);
	}

	g_aArenas = ArrayCreate(ArenaInfo_s);

	RegisterSayCmd("race", "racemenu",		"CmdStartRace", hns_get_flag_watcher(), "Battles race menu");
	RegisterSayCmd("arenas", "arenasmenu",	"CmdArenas", hns_get_flag_watcher(), "Battles arenas menu");

	// грузим только текущую карту
	LoadArenasFromIni();
	FindArenas();

	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", true);
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true);

	register_forward(FM_Touch, "touch_PlayerCollide", true);
	register_forward(FM_AddToFullPack, "AddToFullPack_Post", true);
}

public plugin_end() {
	for (new i = 1; i <= MaxClients; i++)
		ArrayDestroy(g_aColide[i]);

	if (g_aArenas) ArrayDestroy(g_aArenas);
}

public plugin_cfg() {
	hns_get_prefix(g_sPrefix, charsmax(g_sPrefix));
}

public client_putinserver(id) {
	g_bChanceForPlayers[id] = false;
	g_flTouchDelay[id] = 0.0;
	ResetColideData(id, false);
}

public CmdStartRace(id) {
	if (!is_user_connected(id)) {
		return PLUGIN_HANDLED;
	}
	
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (!can_start_race_now()) {
		return PLUGIN_HANDLED;
	}

	if (!g_bArenasLoaded || !GetArenaCount()) {
		client_print_color(id, print_team_red, "%s %L", g_sPrefix, id, "BATTLE_NO_ARENAS");
		return PLUGIN_HANDLED;
	}

	new hMenu = menu_create(fmt("%L", id, "BATTLE_MENU_RACE_TITLE"), "RaceHandler");

	new iCount = GetArenaCount(), name[48];
	for (new i = 0; i < iCount; i++) {
		GetArenaName(i, name, charsmax(name));
		menu_additem(hMenu, fmt("%s%s", name, i == iCount - 1 ? "^n" : ""));
	}

	// элемент-переключатель шанса
	new szChanceState[16], szChanceItem[64];
	formatex(szChanceState, charsmax(szChanceState), "%L", id, g_bChanceForPlayers[id] ? "BATTLE_MENU_YES" : "BATTLE_MENU_NO");
	formatex(szChanceItem, charsmax(szChanceItem), "%L", id, "BATTLE_MENU_CHANCE", szChanceState);
	menu_additem(hMenu, szChanceItem);

	menu_display(id, hMenu, 0);

	return PLUGIN_HANDLED;
}

public RaceHandler(id, hMenu, item) {
	if (!is_user_connected(id)) { 
		menu_destroy(hMenu); 
		return PLUGIN_HANDLED; 
	}

	if (item == MENU_EXIT) { 
		menu_destroy(hMenu); 
		return PLUGIN_HANDLED; 
	}

	if (!isUserWatcher(id)) {
		menu_destroy(hMenu); 
		return PLUGIN_HANDLED; 
	}

	if (!can_start_race_now()) {
		menu_destroy(hMenu); 
		return PLUGIN_HANDLED;
	}


	new iCount = GetArenaCount();

	if (!iCount) { 
		menu_destroy(hMenu); 
		return PLUGIN_HANDLED; 
	}

	if (item == iCount) {
		g_bChanceForPlayers[id] = !g_bChanceForPlayers[id];
		CmdStartRace(id);
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new iArenaID;
	if (!GetArenaByItemIndex(item, iArenaID)) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	g_eBattleData[BATTLE_INITIATOR] = id;
	g_eBattleData[BATTLE_CHANCE] = g_bChanceForPlayers[id];
	StartBattle(iArenaID);

	menu_destroy(hMenu);
	return PLUGIN_HANDLED;
}


public CmdArenas(id) {
	if (!is_user_connected(id)) {
		return PLUGIN_HANDLED;
	}
	
	if (!is_knife_map_safe()) {
		return PLUGIN_HANDLED;
	}

	if (!can_open_arenas_now()) {
		return PLUGIN_HANDLED;
	}

	if (rg_get_user_team(id) == TEAM_SPECTATOR) {
		return PLUGIN_HANDLED;
	}

	if (!g_bArenasLoaded || !GetArenaCount()) {
		client_print_color(id, print_team_red, "%s %L", g_sPrefix, id, "BATTLE_NO_TELEPORTS");
		return PLUGIN_HANDLED;
	}

	new hMenu = menu_create(fmt("%L", id, "BATTLE_MENU_TELEPORTS_TITLE"), "ArenasHandler");

	menu_additem(hMenu, fmt("%L", id, "BATTLE_MENU_TELEPORT_KNIFE"));

	new iCount = GetArenaCount(), szName[48];
	for (new i = 0; i < iCount; i++) {
		GetArenaName(i, szName, charsmax(szName));
		menu_additem(hMenu, szName);
	}

	menu_display(id, hMenu, 0);

	return PLUGIN_HANDLED;
}

public ArenasHandler(id, menu, item) {
	if (!is_user_connected(id)) {
		menu_destroy(menu); 
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) { 
		menu_destroy(menu); 
		return PLUGIN_HANDLED; 
	}

	if (!is_knife_map_safe()) {
		menu_destroy(menu); 
		return PLUGIN_HANDLED;
	}

	if (!can_open_arenas_now()) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (rg_get_user_team(id) == TEAM_SPECTATOR) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (!item) {
		rg_round_respawn(id);
		CmdArenas(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new iArenaID;
	if (!GetTeleportByItemIndex(item, iArenaID)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (!GetArenaEnt(iArenaID)) {
		FindArenas();
	}

	new iEnt = GetArenaEnt(iArenaID);
	if (!iEnt) {
		client_print_color(id, print_team_red, "%s %L", g_sPrefix, id, "BATTLE_TELEPORT_NOT_FOUND");
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new Float:flOrigin[3], Float:flAngles[3];
	get_entvar(iEnt, var_origin, flOrigin);
	get_entvar(iEnt, var_angles, flAngles);

	set_entvar(id, var_origin, flOrigin);
	set_entvar(id, var_angles, flAngles);
	set_entvar(id, var_v_angle, flAngles);
	set_entvar(id, var_fixangle, true);

	CmdArenas(id);
	menu_destroy(menu);

	return PLUGIN_HANDLED;
}


public StartBattle(iArenaID) {
	if (!can_start_battle_now()) {
		return PLUGIN_HANDLED;
	}

	if (!g_bArenasLoaded || iArenaID < 0 || iArenaID >= GetArenaCount()) {
		return PLUGIN_HANDLED;
	}

	new MATCH_STATUS:iStatus = hns_get_status();
	new bool:bRaceMode = iStatus == MATCH_NONE;

	g_eBattleData[BATTLE_ENABLED] = true;

	if (bRaceMode) {
		hns_set_status(MATCH_BATTLERACE);
	} else {
		hns_set_mode(MODE_KNIFE);
	}

	g_eBattleData[BATTLE_ARENA] = iArenaID;

	new szName[48];
	GetArenaName(iArenaID, szName, charsmax(szName));

	if (g_eBattleData[BATTLE_INITIATOR]) {
		client_print_color(0, print_team_blue, "%s %L", g_sPrefix, LANG_SERVER, "BATTLE_STARTED", g_eBattleData[BATTLE_INITIATOR], szName);
	}

	if (bRaceMode) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");

		for (new i; i < iNum; i++) {
			new id = iPlayers[i];
			PreparePlayer(id, true);
		}

		g_eBattleData[BATTLE_PREPARE] = 0;
		remove_task(TASK_START_BATTLE);
		set_task(1.0, "task_StartBattle", .id = TASK_START_BATTLE);
	}

	return PLUGIN_HANDLED;
}

public EndBattle(bool:set_training) {
	if (!g_eBattleData[BATTLE_ENABLED]) {
		return PLUGIN_HANDLED;
	}

	g_eBattleData[BATTLE_ENABLED] = false;
	remove_task(TASK_START_BATTLE);
	arrayset(g_eBattleData, 0, BattleData_s);

	if (hns_get_status() == MATCH_BATTLERACE) {
		hns_set_status(MATCH_NONE);
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		ResetColideData(id, false);
	}

	if (set_training) {
		hns_set_mode(MODE_TRAINING);
	}

	return PLUGIN_HANDLED;
}

public CSGameRules_RestartRound_Post() {
	if (!is_battle_knife_context()) {
		return;
	}

	if (!g_eBattleData[BATTLE_ENABLED]) {
		return
	}

	g_eBattleData[BATTLE_PREPARE] = 0;

	remove_task(TASK_START_BATTLE);
	
	set_task(1.0, "task_StartBattle", .id = TASK_START_BATTLE);
}

public task_StartBattle() {
	if (!is_battle_context()) {
		remove_task(TASK_START_BATTLE);
		return HC_CONTINUE;
	}

	if (g_eBattleData[BATTLE_PREPARE] >= sizeof(g_szSounds)) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");

		for (new i; i < iNum; i++) {
			new id = iPlayers[i];
			if (TeamName:get_member(id, m_iTeam) == TEAM_SPECTATOR || !is_user_alive(id))
				continue;
			PreparePlayer(id, false);
		}
		remove_task(TASK_START_BATTLE);
		return HC_CONTINUE;
	}

	if (g_eBattleData[BATTLE_PREPARE]) {
		new szBuff[16], szCounter[16], szChance[32];
		formatex(szBuff, charsmax(szBuff), "%d", g_eBattleData[BATTLE_PREPARE]);
		szChance[0] = 0;

		if (g_eBattleData[BATTLE_PREPARE] == 4) {
			formatex(szCounter, charsmax(szCounter), "%L", LANG_SERVER, "BATTLE_HUD_FIGHT");
		} else {
			copy(szCounter, charsmax(szCounter), szBuff);
		}

		if (g_eBattleData[BATTLE_CHANCE]) {
			formatex(szChance, charsmax(szChance), "%L", LANG_SERVER, "BATTLE_HUD_CHANCE");
		}

		set_dhudmessage(100, 100, 100, -1.0, 0.75, .holdtime = 1.0);
		show_dhudmessage(0, "%L", LANG_SERVER, "BATTLE_HUD_TEXT", szCounter, szChance);
	}

	rg_send_audio(0, g_szSounds[g_eBattleData[BATTLE_PREPARE]])
	g_eBattleData[BATTLE_PREPARE]++;

	if (g_eBattleData[BATTLE_PREPARE] == 1)
		set_task(2.0, "task_StartBattle", .id = TASK_START_BATTLE);
	else
		set_task(1.0, "task_StartBattle", .id = TASK_START_BATTLE);

	return HC_CONTINUE;
}

public CBasePlayer_Spawn_Post(id) {
	if (!is_user_alive(id)) {
		return HC_CONTINUE;
	}

	if (!is_battle_context()) {
		return HC_CONTINUE;
	}

	if (!g_eBattleData[BATTLE_ENABLED]) {
		return HC_CONTINUE;
	}

	PreparePlayer(id, true);

	return HC_CONTINUE;
}

stock bool:is_knife_map_safe() {
	if (hnsmatch_maps_init()) {
		return hnsmatch_maps_is_knife();
	}

	new szCurrentMap[32], szKnifeMap[32];
	get_mapname(szCurrentMap, charsmax(szCurrentMap));
	get_cvar_string("hns_knifemap", szKnifeMap, charsmax(szKnifeMap));

	return szKnifeMap[0] && equali(szCurrentMap, szKnifeMap);
}

stock bool:can_start_race_now() {
	return is_knife_map_safe() && hns_get_mode() == MODE_TRAINING && hns_get_status() == MATCH_NONE;
}

stock bool:can_start_battle_now() {
	if (!is_knife_map_safe()) {
		return false;
	}

	if (hns_get_mode() != MODE_TRAINING) {
		return false;
	}

	new MATCH_STATUS:iStatus = hns_get_status();
	return iStatus == MATCH_NONE || iStatus == MATCH_CAPTAINBATTLE;
}

stock bool:can_open_arenas_now() {
	if (hns_get_mode() != MODE_TRAINING) {
		return false;
	}

	new MATCH_STATUS:iStatus = hns_get_status();
	return iStatus == MATCH_NONE || iStatus == MATCH_TEAMPICK || iStatus == MATCH_CUPPICK || iStatus == MATCH_MAPPICK;
}

stock bool:is_battle_knife_context() {
	if (hns_get_mode() != MODE_KNIFE) {
		return false;
	}

	new MATCH_STATUS:iStatus = hns_get_status();
	return iStatus == MATCH_CAPTAINBATTLE || iStatus == MATCH_TEAMBATTLE;
}

stock bool:is_battle_race_context() {
	return hns_get_mode() == MODE_TRAINING && hns_get_status() == MATCH_BATTLERACE;
}

stock bool:is_battle_context() {
	return is_battle_knife_context() || is_battle_race_context();
}

// ======== Конфиг: загрузка секции текущей карты ========
stock LoadArenasFromIni()
{
	ArrayClear(g_aArenas);
	g_bArenasLoaded = false;

	new cfgPath[128];
	get_localinfo("amxx_configsdir", cfgPath, charsmax(cfgPath));
	add(cfgPath, charsmax(cfgPath), "/mixsystem/hns-arenas.ini");

	new file = fopen(cfgPath, "rt");
	if (!file) {
		log_amx("[HNS] Cannot open config: %s", cfgPath);
		return;
	}

	new line[192], curSection[64], bool:sectionMatched;
	while (!feof(file)) {
		fgets(file, line, charsmax(line));
		trim(line);

		if (!line[0] || line[0] == ';' || (line[0] == '/' && line[1] == '/')) continue;

		if (line[0] == '[') {
			new close = contain(line, "]");
			if (close == -1) { sectionMatched = false; continue; }

			copyc(curSection, charsmax(curSection), line[1], ']');
			trim(curSection);
			sectionMatched = bool:equali(curSection, g_szMap);
			continue;
		}

		if (!sectionMatched) continue;

		new posEq = contain(line, "=");
		if (posEq == -1) continue;

		new left[64];
		copyc(left, charsmax(left), line, '=');
		trim(left);

		new right[64];
		copy(right, charsmax(right), line[posEq + 1]);
		trim(right);

		if (!left[0] || !right[0]) continue;

		new info[ArenaInfo_s];
		copy(info[a_name], charsmax(info[a_name]), left);
		copy(info[a_target], charsmax(info[a_target]), right);
		info[a_entid] = 0;

		ArrayPushArray(g_aArenas, info);
		g_bArenasLoaded = true;

		log_amx("[HNS] Loaded arena '%s' -> '%s' for map '%s'", left, right, g_szMap);
	}

	fclose(file);

	if (g_bArenasLoaded)
		log_amx("[HNS] Loaded %d arenas for '%s'", GetArenaCount(), g_szMap);
	else
		log_amx("[HNS] No arenas for map '%s' in %s", g_szMap, cfgPath);
}
// Сопоставляет targetname -> entid
stock FindArenas() {
	if (!g_bArenasLoaded) return;

	// Сбросим кеш
	new count = GetArenaCount();
	new info[ArenaInfo_s];

	for (new i = 0; i < count; i++) {
		ArrayGetArray(g_aArenas, i, info);
		info[a_entid] = 0;

		new ent = -1, tn[32];
		while ((ent = rg_find_ent_by_class(ent, "info_teleport_destination"))) {
			get_entvar(ent, var_targetname, tn, charsmax(tn));
			if (equali(tn, info[a_target])) {
				info[a_entid] = ent;
				break;
			}
		}
		ArraySetArray(g_aArenas, i, info);

		if (!info[a_entid]) {
			log_amx("[HNS] target '%s' not found on map '%s' (arena '%s')",
				info[a_target], g_szMap, info[a_name]);
		}
	}
}

stock GetArenaCount() {
	return g_aArenas ? ArraySize(g_aArenas) : 0;
}

stock GetArenaName(index, out[], len) {
	out[0] = 0;
	if (index < 0 || index >= GetArenaCount()) {
		return 0;
	}

	new info[ArenaInfo_s];
	ArrayGetArray(g_aArenas, index, info);
	
	return copy(out, len, info[a_name]);
}

stock GetArenaEnt(index) {
	if (index < 0 || index >= GetArenaCount()) return 0;
	new info[ArenaInfo_s];
	ArrayGetArray(g_aArenas, index, info);
	return info[a_entid];
}

// для меню /race: пункты = [0..count-1], дальше — "Chance for players"
stock GetArenaByItemIndex(menu_item, &iArenaID) {
	iArenaID = -1;
	new cnt = GetArenaCount();
	if (menu_item < 0) return 0;
	if (menu_item < cnt) {
		iArenaID = menu_item;
		return 1;
	}
	return 0;
}

// для меню /arenas: item 0 — "knife", дальше 1..count
stock GetTeleportByItemIndex(menu_item, &iArenaID) {
	iArenaID = -1;
	if (menu_item <= 0) return 0;
	new idx = menu_item - 1;
	if (idx < 0 || idx >= GetArenaCount()) return 0;
	iArenaID = idx;
	return 1;
}

// ======== Оригинальная логика (с заменой на конфиговые арены) ========

public touch_PlayerCollide(iTouched, iToucher) {
	new iBlock, iPlayer;

	if (is_user_connected(iTouched)) {
		iPlayer = iTouched;
		iBlock = iToucher;
	} else if (is_user_connected(iToucher)) {
		iPlayer = iToucher;
		iBlock = iTouched;
	} else return;

	if (!g_eBattleData[BATTLE_ENABLED])
		return;

	new szClassName[32];
	get_entvar(iBlock, var_classname, szClassName, charsmax(szClassName));
	if (equal(szClassName, "trigger_multiple")) {
		new szTargetName[32];
		get_entvar(iBlock, var_targetname, szTargetName, charsmax(szTargetName));
		if (equali(szTargetName, "fail_", 5)) {
			CheckStatus(iPlayer, false);
		} else if (equali(szTargetName, "finish_", 5)) {
			CheckStatus(iPlayer, true);
		}
		return;
	}

	if (g_eBattleData[BATTLE_ARENA] != -1 /* FASTRUN раньше */) {
		if (g_flTouchDelay[iPlayer] > get_gametime())
			return;

		if (equal(szClassName, "func_wall")) {
			new szTargetName[32];
			get_entvar(iBlock, var_targetname, szTargetName, charsmax(szTargetName));
			if (szTargetName[2] == '_') {
				new block = GetBlockId(szTargetName);
				if (block != -1) {
					CheckColide(iPlayer, block);
				}
			}
		}
		g_flTouchDelay[iPlayer] = get_gametime() + 0.23;
	}
}

CheckStatus(id, bool:is_finish) {
	if (is_finish) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ache", TeamName:get_member(id, m_iTeam) == TEAM_TERRORIST ? "CT" : "TERRORIST");

		client_print_color(0, print_team_blue, "%s %L", g_sPrefix, LANG_SERVER, "BATTLE_WIN_PLAYER", id);
		EndBattle(false);

		for (new i; i < iNum; i++) {
			new iPlayer = iPlayers[i];
			user_kill(iPlayer, true);
		}
	} else {
		ResetColideData(id, true);
	}
}

CheckColide(id, block) {
	new found_block = FindBlock(id, block);
	new TempCollide[CollideData_s];

	if (found_block == -1) {
		TempCollide[block_id] = block;
		TempCollide[dont_collide_after] = get_gametime() + 0.23;
		ArrayPushArray(g_aColide[id], TempCollide);
	} else {
		ArrayGetArray(g_aColide[id], found_block, TempCollide);
		if (TempCollide[dont_collide_after] && TempCollide[dont_collide_after] < get_gametime())
			ResetColideData(id, true);
	}
}

ResetColideData(id, bool:kill) {
	ArrayClear(g_aColide[id]);
	if (kill) {
		if (g_eBattleData[BATTLE_CHANCE]) {
			PlayerChance(id);
		} else {
			new iPlayers[MAX_PLAYERS], iNum;
			get_players(iPlayers, iNum, "ache", TeamName:get_member(id, m_iTeam) == TEAM_TERRORIST ? "TERRORIST" : "CT");

			if (!(iNum - 1)) {
				new szWinnerTeam[16];
				formatex(szWinnerTeam, charsmax(szWinnerTeam), "%L", LANG_SERVER, TeamName:get_member(id, m_iTeam) == TEAM_TERRORIST ? "BATTLE_TEAM_CTS" : "BATTLE_TEAM_TERRORISTS");
				client_print_color(0, print_team_blue, "%s %L", g_sPrefix, LANG_SERVER, "BATTLE_WIN_TEAM", szWinnerTeam);
				EndBattle(false);
			}
			user_kill(id);
		}
	}
}

PlayerChance(id) {
	PreparePlayer(id, true);
	set_task(1.0, "task_PlayerChance", .id = id + TASK_PLAYER_CHANCE);
}

public task_PlayerChance(id) {
	id -= TASK_PLAYER_CHANCE;

	if (!g_eBattleData[BATTLE_ENABLED])
		return;

	if (!is_user_connected(id))
		return;

	PreparePlayer(id, false);
	rg_send_audio(id, g_szSounds[charsmax(g_szSounds)]);
}

public AddToFullPack_Post(es, e, iEnt, id, hostflags, player, pSet) {
	if (!g_eBattleData[BATTLE_ENABLED]) {
		return FMRES_IGNORED;
	}

	if (!is_battle_context()) {
		return FMRES_IGNORED;
	}

	if (id == iEnt || !is_user_connected(id)) {
		return FMRES_IGNORED;
	}

	if (player) {
		if (rg_get_user_team(id) != TEAM_SPECTATOR) {
			set_es(es, ES_Effects, EF_NODRAW);
		}
		return FMRES_IGNORED;
	}
	return FMRES_IGNORED;
}


PreparePlayer(id, bool:freeze) {
	if (!is_battle_context()) return;
	if (TeamName:get_member(id, m_iTeam) == TEAM_SPECTATOR || !is_user_alive(id)) return;

	new arena_id = g_eBattleData[BATTLE_ARENA];
	if (arena_id < 0 || arena_id >= GetArenaCount()) return;

	// гарантируем наличие entid
	if (!GetArenaEnt(arena_id)) FindArenas();

	new ent = GetArenaEnt(arena_id);
	if (!ent) return;

	new Float:flOrigin[3], Float:flAngles[3];
	get_entvar(ent, var_origin, flOrigin);
	get_entvar(ent, var_angles, flAngles);

	flOrigin[2] += 20.0;

	if (freeze) {
		set_entvar(id, var_velocity, { 0.0, 0.0, 0.0 });
		set_entvar(id, var_origin, flOrigin);
		set_entvar(id, var_angles, flAngles);
		set_entvar(id, var_v_angle, flAngles);
		set_entvar(id, var_fixangle, true);
		set_entvar(id, var_flags, get_entvar(id, var_flags) | FL_FROZEN);
	} else {
		set_entvar(id, var_flags, get_entvar(id, var_flags) & ~FL_FROZEN);
		set_entvar(id, var_angles, flAngles);
		RequestFrame("SetVelocity", id);
	}
}

public SetVelocity(id) {
	new Float:flVelocity[3];
	velocity_by_aim(id, 300, flVelocity);
	flVelocity[2] = 250.0;
	set_entvar(id, var_velocity, flVelocity);
}

stock FindBlock(id, block) {
	new iSize = ArraySize(g_aColide[id]);
	new TempCollide[CollideData_s];

	for (new i; i < iSize; i++) {
		ArrayGetArray(g_aColide[id], i, TempCollide);
		if (TempCollide[block_id] == block) return i;
	}
	return -1;
}

stock GetBlockId(szTargetName[]) {
	enum _: ArenaData_s { arena_id, block_id };

	new szArenaData[ArenaData_s][6], iArenaData[ArenaData_s];

	new szBlock[32];
	copy(szBlock, charsmax(szBlock), szTargetName);
	replace(szBlock, charsmax(szBlock), "_", " ");

	if (parse(szBlock, szArenaData[arena_id], charsmax(szArenaData[]), szArenaData[block_id], charsmax(szArenaData[]))) {
		iArenaData[block_id] = str_to_num(szArenaData[block_id]);
		return iArenaData[block_id];
	}
	return -1;
}
