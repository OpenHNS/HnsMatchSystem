#include <amxmodx>
#include <fakemeta_util>
#include <reapi>
#include <hns_matchsystem>
#include <hns_matchsystem_filter>
#include <hns_matchsystem_maps>

const TASK_START_BATTLE = 78291;
const TASK_PLAYER_RETURN = 13901;

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
	BATTLE_PREPARE
};

enum _: CollideData_s {
	block_id,
	Float:dont_collide_after
};

enum _: ArenaInfo_s {
	a_name[32],
	a_target[32],
	a_type,
	a_entid
};

const ARENA_TYPE_RACE = (1 << 0);
const ARENA_TYPE_TELEPORT = (1 << 1);
const ARENA_TYPE_ALL = ARENA_TYPE_RACE | ARENA_TYPE_TELEPORT;

new g_sPrefix[24], g_szMap[32];
new g_eBattleData[BattleData_s];
new bool:g_bBattleMenuCaptain[MAX_PLAYERS + 1];
new bool:g_bRaceLoadoutGiven[MAX_PLAYERS + 1];
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
	if (!is_knife_map_safe()) {
		g_bArenasLoaded = false;
		return 0;
	}

	if (!g_aArenas) {
		g_aArenas = ArrayCreate(ArenaInfo_s);
		get_mapname(g_szMap, charsmax(g_szMap));
	}

	if (!g_bArenasLoaded || !GetArenaCountByType(ARENA_TYPE_RACE)) {
		LoadArenasFromIni();
	}

	if (g_bArenasLoaded) {
		FindArenas();
	}

	return g_bArenasLoaded && GetArenaCountByType(ARENA_TYPE_RACE) > 0;
}

public bool:native_battle_start(amxx, params) {
	new iArena = 0;

	if (params >= 1) {
		iArena = get_param(1);
	}

	if (hns_get_mode() == MODE_KNIFE && g_eBattleData[BATTLE_ENABLED]) {
		return true;
	}

	if (!can_start_battle_now()) {
		return false;
	}

	g_eBattleData[BATTLE_INITIATOR] = 0;
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
	new bool:bCaptainMenu = false;

	if (params >= 2) {
		bCaptainMenu = get_param(2) != 0;
	}

	if (!is_user_connected(id) || !isUserWatcher(id)) {
		return false;
	}

	return OpenBattleMenu(id, bCaptainMenu);
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
	RegisterSayCmd("arenas", "arenasmenu",	"CmdArenas", 0, "Battles arenas menu");

	// На не-ножевой карте батлы отключены: не читаем arenas config.
	if (is_knife_map_safe()) {
		LoadArenasFromIni();
		FindArenas();
	} else {
		g_bArenasLoaded = false;
		log_amx("[HNS] Battles disabled on non-knife map '%s'.", g_szMap);
	}

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
	g_bBattleMenuCaptain[id] = false;
	g_bRaceLoadoutGiven[id] = false;
	g_flTouchDelay[id] = 0.0;
	remove_task(id + TASK_PLAYER_RETURN);
	ResetColideData(id, false);
}

public CmdStartRace(id) {
	OpenBattleMenu(id, false);
	return PLUGIN_HANDLED;
}

public RaceHandler(id, hMenu, item) {
	if (!is_user_connected(id)) { 
		menu_destroy(hMenu); 
		return PLUGIN_HANDLED; 
	}

	if (item == MENU_EXIT) { 
		if (g_bBattleMenuCaptain[id] && hns_get_mode() == MODE_TRAINING && hns_get_status() == MATCH_CAPTAINPICK) {
			client_print_color(0, print_team_blue, "%s Battle menu canceled. Fallback to knife decide.", g_sPrefix);
			hns_set_status(MATCH_CAPTAINKNIFE);
			hns_set_mode(MODE_KNIFE);
		}

		g_bBattleMenuCaptain[id] = false;
		menu_destroy(hMenu); 
		return PLUGIN_HANDLED; 
	}

	if (!isUserWatcher(id)) {
		menu_destroy(hMenu); 
		return PLUGIN_HANDLED; 
	}

	if (!can_open_battle_menu_now(g_bBattleMenuCaptain[id])) {
		menu_destroy(hMenu); 
		return PLUGIN_HANDLED;
	}


	new iCount = GetArenaCountByType(ARENA_TYPE_RACE);

	if (!iCount) { 
		menu_destroy(hMenu); 
		return PLUGIN_HANDLED; 
	}

	new iArenaID;
	if (!GetArenaByItemIndex(item, ARENA_TYPE_RACE, iArenaID)) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	g_eBattleData[BATTLE_INITIATOR] = id;

	if (g_bBattleMenuCaptain[id]) {
		hns_set_status(MATCH_CAPTAINBATTLE);
	}

	StartBattle(iArenaID);
	if (g_bBattleMenuCaptain[id] && !g_eBattleData[BATTLE_ENABLED] && hns_get_mode() == MODE_TRAINING) {
		hns_set_status(MATCH_CAPTAINPICK);
	}
	g_bBattleMenuCaptain[id] = false;

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

	if (!g_bArenasLoaded || !GetArenaCountByType(ARENA_TYPE_ALL)) {
		client_print_color(id, print_team_red, "%s %L", g_sPrefix, id, "BATTLE_NO_TELEPORTS");
		return PLUGIN_HANDLED;
	}

	new hMenu = menu_create(fmt("%L", id, "BATTLE_MENU_TELEPORTS_TITLE"), "ArenasHandler");

	menu_additem(hMenu, fmt("%L", id, "BATTLE_MENU_TELEPORT_KNIFE"));

	new iCount = GetArenaCountByType(ARENA_TYPE_ALL), szName[48];
	for (new i = 0; i < iCount; i++) {
		new iArenaID;
		if (!GetArenaByItemIndex(i, ARENA_TYPE_ALL, iArenaID)) {
			continue;
		}

		GetArenaName(iArenaID, szName, charsmax(szName));
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
	flOrigin[2] += 60.0;

	set_entvar(id, var_origin, flOrigin);
	set_entvar(id, var_angles, flAngles);
	set_entvar(id, var_v_angle, flAngles);
	set_entvar(id, var_fixangle, true);
	set_entvar(id, var_velocity, { 0.0, 0.0, 0.0 });
	set_entvar(id, var_basevelocity, { 0.0, 0.0, 0.0 });

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
		hns_set_gameplay(GAMEPLAY_BATTLERACE);

		for (new id = 1; id <= MaxClients; id++) {
			g_bRaceLoadoutGiven[id] = false;
			remove_task(id + TASK_PLAYER_RETURN);
		}
	} else {
		hns_set_mode(MODE_KNIFE);
	}

	// Battle must always run in no-block style.
	SetBattleSemiclip(true);

	g_eBattleData[BATTLE_ARENA] = iArenaID;

	new szName[48];
	GetArenaName(iArenaID, szName, charsmax(szName));

	if (g_eBattleData[BATTLE_INITIATOR]) {
		client_print_color(0, print_team_blue, "%s %L", g_sPrefix, LANG_SERVER, "BATTLE_STARTED", g_eBattleData[BATTLE_INITIATOR], szName);
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		PreparePlayer(id, true);
	}

	g_eBattleData[BATTLE_PREPARE] = 0;
	remove_task(TASK_START_BATTLE);
	set_task(1.0, "task_StartBattle", .id = TASK_START_BATTLE);

	return PLUGIN_HANDLED;
}

public EndBattle(bool:set_training) {
	if (!g_eBattleData[BATTLE_ENABLED]) {
		return PLUGIN_HANDLED;
	}

	new bool:bRaceMode = hns_get_status() == MATCH_BATTLERACE;

	g_eBattleData[BATTLE_ENABLED] = false;
	remove_task(TASK_START_BATTLE);
	arrayset(g_eBattleData, 0, BattleData_s);
	SetBattleSemiclip(false);

	if (bRaceMode) {
		hns_set_status(MATCH_NONE);
		// For standalone race always return via training mode start
		// so round restart is executed by training_start().
		hns_set_mode(MODE_TRAINING);
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		remove_task(id + TASK_PLAYER_RETURN);
		g_bRaceLoadoutGiven[id] = false;
		ResetColideData(id, false);
	}

	if (!bRaceMode && set_training) {
		hns_set_mode(MODE_TRAINING);
	}

	return PLUGIN_HANDLED;
}

stock SetBattleSemiclip(bool:bEnable) {
	server_cmd("semiclip_option semiclip %d", bEnable ? 1 : 0);
	// ReSemiclip: team 0 -> semiclip for all players (including enemies).
	server_cmd("semiclip_option team 0");
	server_cmd("semiclip_option time 0");
	server_exec();
}

public CSGameRules_RestartRound_Post() {
	if (!is_battle_context()) {
		return;
	}

	if (!g_eBattleData[BATTLE_ENABLED]) {
		return
	}

	// Safety: knife mode/gameplay can toggle settings during round restart.
	// Re-apply no-block for active battle context.
	SetBattleSemiclip(true);

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

public task_StartBattle() {
	if (!is_battle_context()) {
		remove_task(TASK_START_BATTLE);
		return HC_CONTINUE;
	}

	// Keep battle no-block forced during whole countdown/restart cycle.
	// Some mode/config hooks can override semiclip options between ticks.
	SetBattleSemiclip(true);

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
		new szCounter[16];

		if (g_eBattleData[BATTLE_PREPARE] == 4) {
			formatex(szCounter, charsmax(szCounter), "%L", LANG_SERVER, "BATTLE_HUD_FIGHT");
		} else {
			formatex(szCounter, charsmax(szCounter), "%d", 4 - g_eBattleData[BATTLE_PREPARE]);
		}

		set_dhudmessage(100, 100, 100, -1.0, 0.75, .holdtime = 1.0);
		show_dhudmessage(0, "%L", LANG_SERVER, "BATTLE_HUD_TEXT", szCounter, "");
	}

	new iSoundIndex = g_eBattleData[BATTLE_PREPARE];
	if (g_eBattleData[BATTLE_PREPARE] >= 1 && g_eBattleData[BATTLE_PREPARE] <= 3) {
		iSoundIndex = 4 - g_eBattleData[BATTLE_PREPARE];
	}

	rg_send_audio(0, g_szSounds[iSoundIndex])
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

	new bool:bFreeze = g_eBattleData[BATTLE_PREPARE] < sizeof(g_szSounds);

	PreparePlayer(id, bFreeze);

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

stock bool:can_open_battle_menu_now(bool:bCaptainMenu) {
	if (!is_knife_map_safe()) {
		return false;
	}

	if (hns_get_mode() != MODE_TRAINING) {
		return false;
	}

	new MATCH_STATUS:iStatus = hns_get_status();

	if (bCaptainMenu) {
		return iStatus == MATCH_CAPTAINPICK;
	}

	return iStatus == MATCH_NONE;
}

stock bool:OpenBattleMenu(id, bool:bCaptainMenu = false) {
	if (!is_user_connected(id)) {
		return false;
	}

	if (!isUserWatcher(id)) {
		return false;
	}

	if (!can_open_battle_menu_now(bCaptainMenu)) {
		return false;
	}

	if (!g_bArenasLoaded || !GetArenaCountByType(ARENA_TYPE_RACE)) {
		client_print_color(id, print_team_red, "%s %L", g_sPrefix, id, "BATTLE_NO_ARENAS");
		return false;
	}

	g_bBattleMenuCaptain[id] = bCaptainMenu;

	new hMenu = menu_create(fmt("%L", id, "BATTLE_MENU_RACE_TITLE"), "RaceHandler");

	new iCount = GetArenaCountByType(ARENA_TYPE_RACE), name[48];
	for (new i = 0; i < iCount; i++) {
		new iArenaID;
		if (!GetArenaByItemIndex(i, ARENA_TYPE_RACE, iArenaID)) {
			continue;
		}

		GetArenaName(iArenaID, name, charsmax(name));
		menu_additem(hMenu, fmt("%s%s", name, i == iCount - 1 ? "^n" : ""));
	}

	menu_display(id, hMenu, 0);
	return true;
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
	if (!is_knife_map_safe()) {
		if (g_aArenas) {
			ArrayClear(g_aArenas);
		}
		g_bArenasLoaded = false;
		return;
	}

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

	new line[192], curSection[64], bool:sectionMatched, iSectionTypeMask;
	while (!feof(file)) {
		fgets(file, line, charsmax(line));
		trim(line);

		if (!line[0] || line[0] == ';' || (line[0] == '/' && line[1] == '/')) continue;

		if (line[0] == '[') {
			new close = contain(line, "]");
			if (close == -1) {
				sectionMatched = false;
				iSectionTypeMask = 0;
				continue;
			}

			copyc(curSection, charsmax(curSection), line[1], ']');
			trim(curSection);
			
			iSectionTypeMask = GetArenaSectionType(curSection);
			sectionMatched = iSectionTypeMask != 0;
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
		info[a_type] = iSectionTypeMask;
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

		info[a_entid] = FindArenaEntByType(info[a_type], info[a_target]);
		ArraySetArray(g_aArenas, i, info);

		if (!info[a_entid]) {
			log_amx("[HNS] target '%s' not found for type %d on map '%s' (arena '%s')",
				info[a_target], info[a_type], g_szMap, info[a_name]);
		}
	}
}

stock FindArenaEntByType(iArenaType, const szTargetName[]) {
	// :teleports -> info_target
	if (iArenaType == ARENA_TYPE_TELEPORT) {
		return FindEntByTargetName("info_target", szTargetName);
	}

	// :races -> info_teleport_destination
	if (iArenaType == ARENA_TYPE_RACE) {
		return FindEntByTargetName("info_teleport_destination", szTargetName);
	}

	return 0;
}

stock FindEntByTargetName(const szClassName[], const szTargetName[]) {
	new ent = -1, tn[32];

	while ((ent = rg_find_ent_by_class(ent, szClassName))) {
		get_entvar(ent, var_targetname, tn, charsmax(tn));
		if (equali(tn, szTargetName)) {
			return ent;
		}
	}

	return 0;
}

stock GetArenaCount() {
	return g_aArenas ? ArraySize(g_aArenas) : 0;
}

stock GetArenaCountByType(iTypeMask) {
	if (!g_aArenas) {
		return 0;
	}

	new info[ArenaInfo_s], iCount;
	new iTotal = ArraySize(g_aArenas);
	for (new i; i < iTotal; i++) {
		ArrayGetArray(g_aArenas, i, info);
		if (info[a_type] & iTypeMask) {
			iCount++;
		}
	}

	return iCount;
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

// Фильтрованный индекс для меню арен.
stock GetArenaByItemIndex(menu_item, iTypeMask, &iArenaID) {
	iArenaID = -1;

	if (menu_item < 0 || !g_aArenas) {
		return 0;
	}

	new info[ArenaInfo_s], iFilteredIndex;
	new iTotal = ArraySize(g_aArenas);
	for (new i; i < iTotal; i++) {
		ArrayGetArray(g_aArenas, i, info);
		if (!(info[a_type] & iTypeMask)) {
			continue;
		}

		if (iFilteredIndex == menu_item) {
			iArenaID = i;
			return 1;
		}

		iFilteredIndex++;
	}

	return 0;
}

// для меню /arenas: item 0 — "knife", дальше 1..count
stock GetTeleportByItemIndex(menu_item, &iArenaID) {
	iArenaID = -1;
	if (menu_item <= 0) {
		return 0;
	}

	return GetArenaByItemIndex(menu_item - 1, ARENA_TYPE_ALL, iArenaID);
}

stock GetArenaSectionType(const szSection[]) {
	new szMapSection[64], szCategory[32];
	copy(szMapSection, charsmax(szMapSection), szSection);

	new iColonPos = contain(szMapSection, ":");
	if (iColonPos < 0) {
		return 0;
	}

	copy(szCategory, charsmax(szCategory), szMapSection[iColonPos + 1]);
	szMapSection[iColonPos] = 0;
	trim(szMapSection);
	trim(szCategory);

	if (!equali(szMapSection, g_szMap)) {
		return 0;
	}

	if (equali(szCategory, "races")) {
		return ARENA_TYPE_RACE;
	}

	if (equali(szCategory, "teleports")) {
		return ARENA_TYPE_TELEPORT;
	}

	return 0;
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

	// Ignore finish/fail triggers while countdown is active.
	if (g_eBattleData[BATTLE_PREPARE] < sizeof(g_szSounds)) {
		return;
	}

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
		new MATCH_STATUS:iStatus = hns_get_status();
		new TeamName:iWinnerTeam = TeamName:get_member(id, m_iTeam);

		client_print_color(0, print_team_blue, "%s %L", g_sPrefix, LANG_SERVER, "BATTLE_WIN_PLAYER", id);
		EndBattle(false);

		// For captain/team battle in knife context finish round with winner team,
		// so knife flow continues without manual user_kill().
		if (iStatus == MATCH_CAPTAINBATTLE || iStatus == MATCH_TEAMBATTLE) {
			if (iWinnerTeam == TEAM_CT) {
				rg_round_end(0.1, WINSTATUS_CTS, ROUND_CTS_WIN);
			} else {
				rg_round_end(0.1, WINSTATUS_TERRORISTS, ROUND_TERRORISTS_WIN);
			}
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

ResetColideData(id, bool:return_to_start) {
	ArrayClear(g_aColide[id]);

	if (return_to_start) {
		ReturnPlayerToStart(id);
	}
}

ReturnPlayerToStart(id) {
	if (!g_eBattleData[BATTLE_ENABLED]) {
		return;
	}

	if (!is_user_connected(id) || !is_user_alive(id)) {
		return;
	}

	remove_task(id + TASK_PLAYER_RETURN);
	PreparePlayer(id, true);
	set_task(1.0, "task_PlayerReturn", .id = id + TASK_PLAYER_RETURN);
}

public task_PlayerReturn(id) {
	id -= TASK_PLAYER_RETURN;

	if (!g_eBattleData[BATTLE_ENABLED])
		return;

	if (!is_user_connected(id) || !is_user_alive(id))
		return;

	PreparePlayer(id, false);
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
	new TeamName:iTeam = TeamName:get_member(id, m_iTeam);
	if (iTeam == TEAM_SPECTATOR || !is_user_alive(id)) return;

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

	if (is_battle_race_context()) {
		PrepareRaceLoadout(id);
	}

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

stock PrepareRaceLoadout(id) {
	if (g_bRaceLoadoutGiven[id]) {
		return;
	}

	rg_remove_all_items(id);
	rg_give_item(id, "weapon_knife");
	rg_give_item(id, "weapon_usp");
	g_bRaceLoadoutGiven[id] = true;
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
