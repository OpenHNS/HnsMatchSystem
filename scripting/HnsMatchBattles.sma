#include <amxmodx>
#include <fakemeta_util>
#include <reapi>
#include <hns_matchsystem>
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
	bool:battle_enabled,
	current_arena,
	start_player_id,
	num_players,
	prepare_time,
	bool:chance_for_players
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

public plugin_init() {
	register_plugin("Match: Battles (cfg)", "dev", "OpenHNS");

	get_mapname(g_szMap, charsmax(g_szMap));

	// инициализация массивов
	for (new i = 1; i <= MaxClients; i++)
		g_aColide[i] = ArrayCreate(CollideData_s);

		g_aArenas = ArrayCreate(ArenaInfo_s);

	RegisterSayCmd("race", "racemenu",		"CmdStartRace", hns_get_flag_watcher(), "Battles race menu");
	RegisterSayCmd("stoprace", "racestop",	"CmdStopRace", hns_get_flag_watcher(), "Battles stop race menu");
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
			sectionMatched = equali(curSection, g_szMap);
			continue;
		}

		if (!sectionMatched) continue;

		// ищем '='
		new posEq = contain(line, "=");
		if (posEq == -1) continue;

		// левая часть (название арены)
		new left[64];
		copyc(left, charsmax(left), line, '=');
		trim(left);

		// правая часть (targetname)
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

// ======== Вспомогалки арен ========
stock GetArenaCount() {
	return g_aArenas ? ArraySize(g_aArenas) : 0;
}
stock GetArenaName(index, out[], len) {
	out[0] = 0;
	if (index < 0 || index >= GetArenaCount()) return 0;

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
stock GetArenaByItemIndex(menu_item, &arena_index) {
	arena_index = -1;
	new cnt = GetArenaCount();
	if (menu_item < 0) return 0;
	if (menu_item < cnt) {
		arena_index = menu_item;
		return 1;
	}
	return 0;
}

// для меню /arenas: item 0 — "knife", дальше 1..count
stock GetTeleportByItemIndex(menu_item, &arena_index) {
	arena_index = -1;
	if (menu_item <= 0) return 0;
	new idx = menu_item - 1;
	if (idx < 0 || idx >= GetArenaCount()) return 0;
	arena_index = idx;
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

	if (!g_eBattleData[battle_enabled])
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

	if (g_eBattleData[current_arena] != -1 /* FASTRUN раньше */) {
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

		client_print_color(0, print_team_blue, "%s %n win battle!", g_sPrefix, id);
		EndBattle();

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
		if (g_eBattleData[chance_for_players]) {
			PlayerChance(id);
		} else {
			new iPlayers[MAX_PLAYERS], iNum;
			get_players(iPlayers, iNum, "ache", TeamName:get_member(id, m_iTeam) == TEAM_TERRORIST ? "TERRORIST" : "CT");

			if (!(iNum - 1)) {
				client_print_color(0, print_team_blue, "%s Team ^3%s^1 win battle!", g_sPrefix, TeamName:get_member(id, m_iTeam) == TEAM_TERRORIST ? "CTS" : "TERRORISTS");
				EndBattle();
			}
			user_kill(id);
		}
	}
}

PlayerChance(id) {
	PreparePlayer(id, true);
	set_task(1.0, "task_PlayerChance", id + TASK_PLAYER_CHANCE);
}

public task_PlayerChance(id) {
	id -= TASK_PLAYER_CHANCE;

	if (!g_eBattleData[battle_enabled])
		return;

	if (!is_user_connected(id))
		return;

	PreparePlayer(id, false);
	rg_send_audio(id, g_szSounds[charsmax(g_szSounds)]);
}

public AddToFullPack_Post(es, e, iEnt, id, hostflags, player, pSet) {
	new iCurrentMode = hns_get_mode();

	if (iCurrentMode != MODE_KNIFE)
		return FMRES_IGNORED;

	if (id == iEnt || !is_user_connected(id)) return FMRES_IGNORED;

	if (player) {
		if (TeamName:get_member(id, m_iTeam) != TEAM_SPECTATOR) {
			set_es(es, ES_Effects, EF_NODRAW);
		}
		return FMRES_IGNORED;
	}
	return FMRES_IGNORED;
}

public CmdStartRace(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	if (!hnsmatch_maps_is_knife()) return PLUGIN_HANDLED;
	if (~get_user_flags(id) & hns_get_flag_admin()) return PLUGIN_HANDLED;
	if (hns_get_mode() == MODE_KNIFE) return PLUGIN_HANDLED;

	if (!g_bArenasLoaded || !GetArenaCount()) {
		client_print_color(id, print_team_red, "%s На этой карте нет сконфигурированных арен.", g_sPrefix);
		return PLUGIN_HANDLED;
	}

	new menu = menu_create("\rSelect arena for battle", "RaceHandler");

	// динамический список арен
	new count = GetArenaCount(), name[48];
	for (new i = 0; i < count; i++) {
		GetArenaName(i, name, charsmax(name));
		menu_additem(menu, fmt("%s%s", name, i == count - 1 ? "^n" : ""));
	}

	// элемент-переключатель шанса
	menu_additem(menu, fmt("Chance for players: %s", g_bChanceForPlayers[id] ? "\ryes" : "\dno"));

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public RaceHandler(id, menu, item) {
	if (!is_user_connected(id)) { menu_destroy(menu); return PLUGIN_HANDLED; }
	if (item == MENU_EXIT) { menu_destroy(menu); return PLUGIN_HANDLED; }
	if (!hnsmatch_maps_is_knife()) { menu_destroy(menu); return PLUGIN_HANDLED; }
	if (~get_user_flags(id) & hns_get_flag_admin()) { menu_destroy(menu); return PLUGIN_HANDLED; }
	if (hns_get_mode() == MODE_KNIFE) { menu_destroy(menu); return PLUGIN_HANDLED; }

	new count = GetArenaCount();
	if (!count) { menu_destroy(menu); return PLUGIN_HANDLED; }

	// последний пункт = переключатель шанса
	if (item == count) {
		g_bChanceForPlayers[id] = !g_bChanceForPlayers[id];
		CmdStartRace(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new arena_index;
	if (!GetArenaByItemIndex(item, arena_index)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	g_eBattleData[start_player_id] = id;
	g_eBattleData[chance_for_players] = g_bChanceForPlayers[id];
	StartBattle(arena_index);

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public CmdStopRace(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	if (!hnsmatch_maps_is_knife()) return PLUGIN_HANDLED;
	if (~get_user_flags(id) & hns_get_flag_admin()) return PLUGIN_HANDLED;
	if (hns_get_mode() != MODE_KNIFE) return PLUGIN_HANDLED;

	EndBattle(true);
	client_print_color(0, print_team_blue, "%s ^3%n^1 stopped battle!", g_sPrefix, id);
	return PLUGIN_HANDLED;
}

public CmdArenas(id) {
	if (!is_user_connected(id)) return PLUGIN_HANDLED;
	if (!hnsmatch_maps_is_knife()) return PLUGIN_HANDLED;

	new iCurrentMode = hns_get_mode();
	if (iCurrentMode != MODE_TRAINING && iCurrentMode != MATCH_CAPTAINPICK) return PLUGIN_HANDLED;
	if (TeamName:get_member(id, m_iTeam) == TEAM_SPECTATOR) return PLUGIN_HANDLED;

	if (!g_bArenasLoaded || !GetArenaCount()) {
		client_print_color(id, print_team_red, "%s На этой карте нет телепортов из конфига.", g_sPrefix);
		return PLUGIN_HANDLED;
	}

	new menu = menu_create("\rTeleports:", "ArenasHandler");
	menu_additem(menu, "knife");

	new count = GetArenaCount(), name[48];
	for (new i = 0; i < count; i++) {
		GetArenaName(i, name, charsmax(name));
		menu_additem(menu, name);
	}

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public ArenasHandler(id, menu, item) {
	if (!is_user_connected(id)) { menu_destroy(menu); return PLUGIN_HANDLED; }
	if (item == MENU_EXIT) { menu_destroy(menu); return PLUGIN_HANDLED; }
	if (!hnsmatch_maps_is_knife()) { menu_destroy(menu); return PLUGIN_HANDLED; }

	new iCurrentMode = hns_get_mode();
	if (iCurrentMode != MODE_TRAINING && iCurrentMode != MATCH_CAPTAINPICK) { menu_destroy(menu); return PLUGIN_HANDLED; }
	if (TeamName:get_member(id, m_iTeam) == TEAM_SPECTATOR) { menu_destroy(menu); return PLUGIN_HANDLED; }

	if (!item) {
		rg_round_respawn(id);
		CmdArenas(id);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new arena_index;
	if (!GetTeleportByItemIndex(item, arena_index)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	// гарантируем что entid актуален
	if (!GetArenaEnt(arena_index)) FindArenas();

	new ent = GetArenaEnt(arena_index);
	if (!ent) {
		client_print_color(id, print_team_red, "%s Телепорт не найден (проверь targetname в ini).", g_sPrefix);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new Float:flOrigin[3], Float:flAngles[3];
	get_entvar(ent, var_origin, flOrigin);
	get_entvar(ent, var_angles, flAngles);

	set_entvar(id, var_origin, flOrigin);
	set_entvar(id, var_angles, flAngles);
	set_entvar(id, var_v_angle, flAngles);
	set_entvar(id, var_fixangle, true);

	CmdArenas(id);
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

StartBattle(arena_index) {
	if (!hnsmatch_maps_is_knife()) return;
	if (hns_get_mode() == MODE_KNIFE) return;
	if (!g_bArenasLoaded || arena_index < 0 || arena_index >= GetArenaCount()) return;

	hns_set_mode(MODE_KNIFE);
	g_eBattleData[current_arena] = arena_index;

	new name[48];
	GetArenaName(arena_index, name, charsmax(name));

	if (g_eBattleData[start_player_id]) {
		client_print_color(0, print_team_blue, "%s ^3%n^1 started battle! (^3%s^1)",
			g_sPrefix, g_eBattleData[start_player_id], name);
	}
}

public task_StartBattle() {
	if (hns_get_mode() != MODE_KNIFE) {
		remove_task(TASK_START_BATTLE);
		return;
	}

	if (g_eBattleData[prepare_time] >= sizeof(g_szSounds)) {
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");

		for (new i; i < iNum; i++) {
			new id = iPlayers[i];
			if (TeamName:get_member(id, m_iTeam) == TEAM_SPECTATOR || !is_user_alive(id))
				continue;
			PreparePlayer(id, false);
		}
		remove_task(TASK_START_BATTLE);
		return;
	}

	if (g_eBattleData[prepare_time]) {
		new szBuff[16];
		formatex(szBuff, charsmax(szBuff), "%d", g_eBattleData[prepare_time]);
		set_dhudmessage(100, 100, 100, -1.0, 0.75, .holdtime = 1.0);
		show_dhudmessage(0, "Батл^nНе нажимайте на клавиши заранее!^n%s^n%s",
			g_eBattleData[prepare_time] == 4 ? "В БОЙ!" : szBuff,
			g_eBattleData[chance_for_players] ? "CHANCE FOR PLAYERS" : "");
	}

	rg_send_audio(0, g_szSounds[g_eBattleData[prepare_time]])
	g_eBattleData[prepare_time]++;

	if (g_eBattleData[prepare_time] == 1)
		set_task(2.0, "task_StartBattle", TASK_START_BATTLE);
	else
		set_task(1.0, "task_StartBattle", TASK_START_BATTLE);
}

EndBattle(bool:set_training = false) {
	if (hns_get_mode() != MODE_KNIFE) return;

	g_eBattleData[battle_enabled] = false;
	remove_task(TASK_START_BATTLE);
	arrayset(g_eBattleData, 0, BattleData_s);

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		ResetColideData(id, false);
	}

	if (set_training) {
		hns_set_mode(MODE_TRAINING);
	}
}

public CSGameRules_RestartRound_Post() {
	if (hns_get_mode() != MODE_KNIFE) return;

	g_eBattleData[battle_enabled] = true;
	g_eBattleData[prepare_time] = 0;
	remove_task(TASK_START_BATTLE);
	set_task(1.0, "task_StartBattle", TASK_START_BATTLE);
}

public CBasePlayer_Spawn_Post(id) {
	if (!is_user_alive(id)) return;
	if (hns_get_mode() != MODE_KNIFE) return;

	PreparePlayer(id, true);
}

PreparePlayer(id, bool:freeze) {
	if (hns_get_mode() != MODE_KNIFE) return;
	if (TeamName:get_member(id, m_iTeam) == TEAM_SPECTATOR || !is_user_alive(id)) return;

	new arena_id = g_eBattleData[current_arena];
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

// ======== Служебные из исходника ========

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
