#include <amxmodx>
#include <reapi>
#include <hns_matchsystem>

#define TASK_MAP 12344

new bool:g_bDebugMode;

new g_szLogPath[64];

new g_szPrefix[24];

new g_szCurrentMap[32];

new Array:g_ArrBoost;
new Array:g_ArrSkill;
new Array:g_ArrKnife;

new bool:g_bHasSettings;
new bool:g_bBoost;
new Float:g_fRoundTime;
new g_iFreezeTime;
new g_iFlash;
new g_iSmoke;

new Array:g_CurrentMenuArray;

new g_SelectedMap[MAX_PLAYERS + 1][32];

public plugin_precache() {
	debug_init("/hnsmatch-maps");

	g_ArrKnife = ArrayCreate(32);
	g_ArrBoost = ArrayCreate(32);
	g_ArrSkill = ArrayCreate(32);

	new szPath[128], szFile[160];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	formatex(szFile, charsmax(szFile), "%s/mixsystem/hns-maps.ini", szPath);

	new fp = fopen(szFile, "rt");
	if (!fp) {
		log_amx("Не найден файл %s!", szFile);
		return;
	}

	new szLine[128], szMap[32];
	new rt[8], ft[8], flash[8], smoke[8];
	new section;

	rh_get_mapname(g_szCurrentMap, charsmax(g_szCurrentMap));

	while (!feof(fp)) {
		fgets(fp, szLine, charsmax(szLine));
		trim(szLine);

		if (!szLine[0] || szLine[0] == ';')
			continue;

		if (szLine[0] == '[') {
			if (equali(szLine, "[knife]")) section = 1;
			else if (equali(szLine, "[boost]")) section = 2;
			else if (equali(szLine, "[skill]")) section = 3;
			else section = 0;
			continue;
		}

		if (section == 1) {
			parse(szLine, szMap, charsmax(szMap));
			strtolower(szMap);
			if (!isMapExist(szMap)) {
				server_print("HNS-MAPS | Карта %s не найдена в cstrike/maps.", szMap);
				continue;
			}

			ArrayPushString(g_ArrKnife, szMap);
		}
		else if (section == 2 || section == 3) {
			parse(szLine, szMap, charsmax(szMap), rt, charsmax(rt), ft, charsmax(ft), flash, charsmax(flash), smoke, charsmax(smoke));
			strtolower(szMap);

			if (!isMapExist(szMap)) {
				server_print("HNS-MAPS | Карта %s не найдена в cstrike/maps.", szMap);
				continue;
			}

			if (section == 2) ArrayPushString(g_ArrBoost, szMap);
			else if (section == 3) ArrayPushString(g_ArrSkill, szMap);

			if (equali(szMap, g_szCurrentMap)) {
				if (section == 2) {
					g_bBoost = true;
				}
				g_fRoundTime = str_to_float(rt);
				g_iFreezeTime = str_to_num(ft);
				g_iFlash = str_to_num(flash);
				g_iSmoke = str_to_num(smoke);

				g_bHasSettings = true;

				LogSendMessage("HNS-MAPS | Найдены настройки для %s: round=%.1f, freeze=%d, flash=%d, smoke=%d boost=%d",
					g_szCurrentMap, g_fRoundTime, g_iFreezeTime, g_iFlash, g_iSmoke, g_bBoost);
			}
		}
	}
	fclose(fp);
}

public plugin_init() {
	register_plugin("Match: Maps", "1.3", "OpenHNS");

	RegisterSayCmd("map", "maps", "cmdMapsMenu", 0, "Open mapmenu");

	register_dictionary("match_additons.txt");
}

public plugin_natives() {
	register_native("hnsmatch_maps_init", "native_maps_init");
	register_native("hnsmatch_maps_is_knife", "native_maps_is_knife");
	register_native("hnsmatch_maps_load_settings", "native_maps_load_settings");
}

public native_maps_init(amxx, params) {
	return 1;
}

public bool:native_maps_is_knife(amxx, params) {
	new szMap[32];
	rh_get_mapname(szMap, charsmax(szMap));

	strtolower(szMap);

	for (new i = 0, iSize = ArraySize(g_ArrKnife); i < iSize; i++) {
		new szKnifeMap[32];
		ArrayGetString(g_ArrKnife, i, szKnifeMap, charsmax(szKnifeMap));
		if (strcmp(szMap, szKnifeMap, false) == 0)
			return true;
	}
	return false;
}

public bool:native_maps_load_settings(amxx, params) {
	if (applyCurrentMapSettings()) {
		return true;
	} else {
		return false;
	}
}

public plugin_cfg() {
	hns_get_prefix(g_szPrefix, charsmax(g_szPrefix));
}

public cmdMapsMenu(id) {
	new szMsg[64];
	formatex(szMsg, charsmax(szMsg), "\r%L", id, "MAPS_MENU_TITLE");

	new hMenu = menu_create(szMsg, "cmdMapsRootHandler");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MAPS_MENU_KNIFE");
	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MAPS_MENU_BOOST");
	menu_additem(hMenu, szMsg, "2");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MAPS_MENU_SKILL");
	menu_additem(hMenu, szMsg, "3");

	menu_display(id, hMenu, 0);
	return PLUGIN_CONTINUE;
}

public cmdMapsRootHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	new choice = str_to_num(szData);
	menu_destroy(hMenu);

	new szMsg[64];

	if (choice == 1) {
		formatex(szMsg, charsmax(szMsg), "%L:", id, "MAPS_MENU_KNIFE");
		showMapsMenu(id, g_ArrKnife, szMsg);
	} else if (choice == 2) {
		formatex(szMsg, charsmax(szMsg), "%L:", id, "MAPS_MENU_BOOST");
		showMapsMenu(id, g_ArrBoost, szMsg);
	} else if (choice == 3) {
		formatex(szMsg, charsmax(szMsg), "%L:", id, "MAPS_MENU_SKILL");
		showMapsMenu(id, g_ArrSkill, szMsg);
	}

	return PLUGIN_HANDLED;
}

showMapsMenu(id, Array:arr, const title[]) {
	new szMapId[10];
	new hMenu = menu_create(title, "cmdMapsMenuHandler");

	g_CurrentMenuArray = arr;

	for (new i = 0, iSize = ArraySize(arr), szMap[32]; i < iSize; i++) {
		ArrayGetString(arr, i, szMap, charsmax(szMap));
		num_to_str(i, szMapId, charsmax(szMapId));
		menu_additem(hMenu, szMap, szMapId);
	}

	menu_display(id, hMenu, 0);
}

public cmdMapsMenuHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);

	menu_destroy(hMenu);

	new mapid = str_to_num(szData);
	new szMap[32];
	ArrayGetString(g_CurrentMenuArray, mapid, szMap, charsmax(szMap));

	cmdMapActionMenu(id, szMap);

	return PLUGIN_HANDLED;
}

public cmdMapActionMenu(id, szMap[]) {
	new szMsg[64];
	formatex(szMsg, charsmax(szMsg), "%L:", id, "MAPS_ACTION_TITLE", szMap);

	copy(g_SelectedMap[id], charsmax(g_SelectedMap[]), szMap);

	new hMenu = menu_create(szMsg, "cmdMapActionHandler");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MAPS_ACTION_NOM");
	menu_additem(hMenu, szMsg, "1");

	if (isUserWatcher(id)) {
		formatex(szMsg, charsmax(szMsg), "%L", id, "MAPS_ACTION_CHANGE");
	} else {
		formatex(szMsg, charsmax(szMsg), "\d%L", id, "MAPS_ACTION_CHANGE");
	}

	menu_additem(hMenu, szMsg, "2");

	menu_display(id, hMenu, 0);
}

public cmdMapActionHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new choice = str_to_num(szData);

	if (choice == 1) {
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "MAPS_NOM", g_szPrefix, id, g_SelectedMap[id]);
	}
	else if (choice == 2) {
		if (isUserWatcher(id)) {
			client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "MAPS_CHAGE", g_szPrefix, id, g_SelectedMap[id]);
			set_task(1.0, "change_map", id + TASK_MAP);
		} else {
			cmdMapActionMenu(id, g_SelectedMap[id]);
		}
	}

	return PLUGIN_HANDLED;
}

public change_map(idtask) {
	new id = idtask - TASK_MAP;

	engine_changelevel(g_SelectedMap[id]);
}

stock bool:applyCurrentMapSettings() {
	if (!g_bHasSettings) {
		return false;
	}

	set_cvar_float("mp_roundtime", g_fRoundTime);
	set_cvar_num("mp_freezetime", g_iFreezeTime);
	set_cvar_num("hns_flash", g_iFlash);
	set_cvar_num("hns_smoke", g_iSmoke);

	if (g_bBoost) {
		set_cvar_num("hns_boost", 1);
	} else {
		set_cvar_num("hns_boost", 0);
	}

	LogSendMessage("HNS-MAPS | applyCurrentMapSettings() Загружены настройки для %s: round=%.1f, freeze=%d, flash=%d, smoke=%d boost=%d",
		g_szCurrentMap, g_fRoundTime, g_iFreezeTime, g_iFlash, g_iSmoke, g_bBoost);

	return true;
}

stock debug_init(const dir[]) {
	g_bDebugMode = bool:(plugin_flags() & AMX_FLAG_DEBUG);

	if (g_bDebugMode) {
		get_localinfo("amxx_logs", g_szLogPath, charsmax(g_szLogPath));
		add(g_szLogPath, charsmax(g_szLogPath), dir);

		if (!dir_exists(g_szLogPath))
			mkdir(g_szLogPath);
	}
}

stock LogSendMessage(szData[1024], any:...) {
	if (!g_bDebugMode) {
		return;
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

stock isMapExist(const szMap[]) {
	new szPath[128];
	formatex(szPath, charsmax(szPath), "maps/%s.bsp", szMap);
	return file_exists(szPath);
}