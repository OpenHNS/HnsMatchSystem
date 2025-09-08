#include <amxmodx>
#include <reapi>
#include <hns_matchsystem>

new g_szPrefix[24];

new Array:g_ArrBoost;
new Array:g_ArrSkill;
new Array:g_ArrKnife;

new Array:g_CurrentMenuArray;

new g_SelectedMap[MAX_PLAYERS + 1][32];

public plugin_precache() {
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

	new mapName[64], section;

	while (!feof(fp)) {
		fgets(fp, mapName, charsmax(mapName));
		trim(mapName);

		if (!mapName[0] || mapName[0] == ';')
			continue;

		if (mapName[0] == '[') {
			if (equali(mapName, "[knife]"))
				section = 1;
			else if (equali(mapName, "[boost]"))
				section = 2;
			else if (equali(mapName, "[skill]"))
				section = 3;
			else
				section = 0;
			continue;
		}

		strtolower(mapName);

		if (section == 1)
			ArrayPushString(g_ArrKnife, mapName);
		else if (section == 2)
			ArrayPushString(g_ArrBoost, mapName);
		else if (section == 3)
			ArrayPushString(g_ArrSkill, mapName);
	}
	fclose(fp);
}

public plugin_init() {
	register_plugin("Match: Maps", "1.2", "OpenHNS");

	RegisterSayCmd("map", "maps", "cmdMapsMenu", 0, "Open mapmenu");
}

public plugin_natives() {
	register_native("hnsmatch_maps_init", "native_maps_init");
	register_native("hnsmatch_maps_is_knife", "native_maps_is_knife");
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

public plugin_cfg() {
	hns_get_prefix(g_szPrefix, charsmax(g_szPrefix));
}

public cmdMapsMenu(id) {
	new szMsg[64];
	formatex(szMsg, charsmax(szMsg), "\rВыбор меню карт:");

	new hMenu = menu_create(szMsg, "cmdMapsRootHandler");
	menu_additem(hMenu, "Knife карты", "1");
	menu_additem(hMenu, "Boost карты", "2");
	menu_additem(hMenu, "Skill карты", "3");

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

	if (choice == 1)
		showMapsMenu(id, g_ArrKnife, "Knife карты:");
	else if (choice == 2)
		showMapsMenu(id, g_ArrBoost, "Boost карты:");
	else if (choice == 3)
		showMapsMenu(id, g_ArrSkill, "Skill карты:");

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
	formatex(szMsg, charsmax(szMsg), "Карта: %s", szMap);

	copy(g_SelectedMap[id], charsmax(g_SelectedMap[]), szMap);

	new hMenu = menu_create(szMsg, "cmdMapActionHandler");

	menu_additem(hMenu, "Номинировать карту", "1");

	if (isUserWatcher(id)) {
		menu_additem(hMenu, "Сменить карту", "2");
	} else {
		menu_additem(hMenu, "\dСменить карту", "2");
	}

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
			engine_changelevel(g_SelectedMap[id]);
		} else {
			cmdMapActionMenu(id, g_SelectedMap[id]);
		}
	}

	return PLUGIN_HANDLED;
}