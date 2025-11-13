#include <amxmodx>
#include <reapi>
#include <hns_matchsystem>

#define TASK_MAP 12344
#define SECTION_CHOICE_ALL -1
#define SECTION_CHOICE_NOMINATED -2

#define SECTION_NAME_KNIFE "knife"
#define SECTION_NAME_BOOST "boost"
#define SECTION_NAME_SKILL "skill"
#define SECTION_NAME_ALL "__all__"
#define SECTION_NAME_NOMINATED "nominated"
#define MAPS_MENU_SLOTS 7

new bool:g_bDebugMode;

new g_szLogPath[64];

new g_szPrefix[24];

new g_szCurrentMap[32];

enum _:SectionData {
	SectionName[32],
	SectionMaps
};

new Array:g_ArrSections;
new Array:g_ArrAllMaps;

new bool:g_bHasSettings;
new bool:g_bBoost;
new Float:g_fRoundTime;
new g_iFreezeTime;
new g_iFlash;
new g_iSmoke;

new g_PlayerMenuArray[MAX_PLAYERS + 1];
new g_MapMenuOffset[MAX_PLAYERS + 1];
new g_MapMenuChoice[MAX_PLAYERS + 1][MAPS_MENU_SLOTS];
new g_PlayerNomination[MAX_PLAYERS + 1][32];

new g_SelectedMap[MAX_PLAYERS + 1][32];
new g_SelectedSection[MAX_PLAYERS + 1][32];
new Array:g_ArrNominatedMaps;
new Array:g_ArrNominatedCounts;

public plugin_precache() {
	debug_init("/hnsmatch-maps");

	g_ArrSections = ArrayCreate(SectionData);
	g_ArrAllMaps = ArrayCreate(32);
	g_ArrNominatedMaps = ArrayCreate(32);
	g_ArrNominatedCounts = ArrayCreate(1);
	g_bHasSettings = false;
	g_bBoost = false;

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
	new currentSection = -1;

	rh_get_mapname(g_szCurrentMap, charsmax(g_szCurrentMap));

	while (!feof(fp)) {
		fgets(fp, szLine, charsmax(szLine));
		trim(szLine);

		if (!szLine[0] || szLine[0] == ';')
			continue;

		if (szLine[0] == '[') {
			new szSectionName[32];
			if (extract_section_name(szLine, szSectionName, charsmax(szSectionName))) {
				currentSection = get_or_create_section(szSectionName);
			} else {
				currentSection = -1;
			}
			continue;
		}

		if (currentSection == -1) {
			continue;
		}

		new sectionData[SectionData];
		ArrayGetArray(g_ArrSections, currentSection, sectionData);
		new Array:sectionArray = Array:sectionData[SectionMaps];

		parse(szLine, szMap, charsmax(szMap), rt, charsmax(rt), ft, charsmax(ft), flash, charsmax(flash), smoke, charsmax(smoke));

		if (!isMapExist(szMap)) {
			server_print("HNS-MAPS | Карта %s не найдена в cstrike/maps.", szMap);
			continue;
		}

		ArrayPushString(sectionArray, szMap);
		add_map_to_all(szMap);

		if (equali(szMap, g_szCurrentMap)) {
			g_bBoost = bool:equali(sectionData[SectionName], SECTION_NAME_BOOST);

			if (rt[0] && ft[0] && flash[0] && smoke[0]) {
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
	register_plugin("Match: Maps", "1.5", "OpenHNS");

	RegisterSayCmd("map", "maps", "cmdMapsMenu", 0, "Open mapmenu");
	RegisterSayCmd("amx_mapmenu", "amx_mapsmenu", "cmdMapsMenu", 0, "Open mapmenu");
	register_menucmd(register_menuid("MapsMenu"), 1023, "maps_menu_handler");

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
	new Array:arrKnife = get_section_array_by_name(SECTION_NAME_KNIFE);
	if (!arrKnife) {
		return false;
	}

	new szMap[32];
	rh_get_mapname(szMap, charsmax(szMap));

	strtolower(szMap);

	for (new i = 0, iSize = ArraySize(arrKnife); i < iSize; i++) {
		new szKnifeMap[32];
		ArrayGetString(arrKnife, i, szKnifeMap, charsmax(szKnifeMap));
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
	new szMsg[192];
	formatex(szMsg, charsmax(szMsg), "\r%L", id, "MAPS_MENU_TITLE");

	new szDescription[192];
	formatex(szDescription, charsmax(szDescription), "^n\d%L", id, "MAPS_MENU_DESC_TYPE");
	
	add(szMsg, charsmax(szMsg), szDescription);

	new hMenu = menu_create(szMsg, "cmdMapsRootHandler");

	new sectionData[SectionData];
	new szInfo[6];
	new szSectionLabel[64];
	new bool:bHasItems;

	for (new i = 0, iSize = ArraySize(g_ArrSections); i < iSize; i++) {
		ArrayGetArray(g_ArrSections, i, sectionData);
		num_to_str(i, szInfo, charsmax(szInfo));
		if (!get_section_label(id, sectionData[SectionName], szSectionLabel, charsmax(szSectionLabel), false)) {
			copy(szSectionLabel, charsmax(szSectionLabel), sectionData[SectionName]);
		}
		menu_additem(hMenu, szSectionLabel, szInfo);
		bHasItems = true;
	}


	if (ArraySize(g_ArrAllMaps)) {
		num_to_str(SECTION_CHOICE_ALL, szInfo, charsmax(szInfo));
		formatex(szSectionLabel, charsmax(szSectionLabel), "%L", id, "MAPS_MENU_ALL");
		menu_additem(hMenu, szSectionLabel, szInfo);
		bHasItems = true;
	}

	num_to_str(SECTION_CHOICE_NOMINATED, szInfo, charsmax(szInfo));
	if (ArraySize(g_ArrNominatedMaps)) {
		formatex(szSectionLabel, charsmax(szSectionLabel), "%L", id, "MAPS_MENU_NOMINATED");
	} else {
		formatex(szSectionLabel, charsmax(szSectionLabel), "\d%L", id, "MAPS_MENU_NOMINATED");
	}
	menu_additem(hMenu, szSectionLabel, szInfo);
	bHasItems = true;

	if (!bHasItems) {
		menu_destroy(hMenu);
		client_print_color(id, print_team_red, "%s Нет доступных карт.", g_szPrefix);
		return PLUGIN_CONTINUE;
	}

	

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

	if (choice == SECTION_CHOICE_ALL) {
		if (!ArraySize(g_ArrAllMaps)) {
			return PLUGIN_HANDLED;
		}

		copy(g_SelectedSection[id], charsmax(g_SelectedSection[]), SECTION_NAME_ALL);
		g_MapMenuOffset[id] = 0;

		showMapsMenu(id, g_ArrAllMaps);
		return PLUGIN_HANDLED;
	}
	else if (choice == SECTION_CHOICE_NOMINATED) {
		if (!ArraySize(g_ArrNominatedMaps)) {
			cmdMapsMenu(id);
			return PLUGIN_HANDLED;
		}

		copy(g_SelectedSection[id], charsmax(g_SelectedSection[]), SECTION_NAME_NOMINATED);
		g_MapMenuOffset[id] = 0;

		showMapsMenu(id, g_ArrNominatedMaps);
		return PLUGIN_HANDLED;
	}

	if (choice < 0 || choice >= ArraySize(g_ArrSections)) {
		return PLUGIN_HANDLED;
	}

	new sectionData[SectionData];
	ArrayGetArray(g_ArrSections, choice, sectionData);

	copy(g_SelectedSection[id], charsmax(g_SelectedSection[]), sectionData[SectionName]);
	g_MapMenuOffset[id] = 0;

	showMapsMenu(id, Array:sectionData[SectionMaps]);

	return PLUGIN_HANDLED;
}

showMapsMenu(id, Array:arr) {
	if (!is_user_connected(id)) {
		return;
	}

	if (!arr) {
		return;
	}

	new bool:bIsNominated = (arr == g_ArrNominatedMaps);

	g_PlayerMenuArray[id] = _:arr;

	new iTotal = ArraySize(arr);
	if (!iTotal) {
		client_print_color(id, print_team_red, "%L", id, "MAPS_MENU_NO_MAPS", g_szPrefix);
		cmdMapsMenu(id);
		return;
	}

	new offset = g_MapMenuOffset[id];
	if (offset >= iTotal) {
		offset = 0;
		g_MapMenuOffset[id] = 0;
	}

	new totalPages = (iTotal + MAPS_MENU_SLOTS - 1) / MAPS_MENU_SLOTS;
	if (totalPages < 1) {
		totalPages = 1;
	}

	new currentPage = offset / MAPS_MENU_SLOTS + 1;

	new szBuffer[512], iLen, iKeys;

	formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "\r%L \y%d/%d^n", id, "MAPS_MENU_TITLE", currentPage, totalPages);
	iLen += strlen(szBuffer[iLen]);

	new szSelectedSection[64];
	if (!get_section_label(id, g_SelectedSection[id], szSelectedSection, charsmax(szSelectedSection), false)) {
		formatex(szSelectedSection, charsmax(szSelectedSection), "%L", id, "MAPS_MENU_DESC_NONE");
	}

	formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "\d%L^n", id, "MAPS_MENU_DESC_SELECTED", szSelectedSection);
	iLen += strlen(szBuffer[iLen]);

	formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "\d%L^n^n", id, "MAPS_MENU_DESC_MAP");
	iLen += strlen(szBuffer[iLen]);

	for (new i = 0; i < MAPS_MENU_SLOTS; i++) {
		g_MapMenuChoice[id][i] = -1;
	}

	new shown = 0;
	for (new i = 0; i < MAPS_MENU_SLOTS && offset + i < iTotal; i++) {
		new szMap[32];
		ArrayGetString(arr, offset + i, szMap, charsmax(szMap));

		if (bIsNominated) {
			new count = ArrayGetCell(g_ArrNominatedCounts, offset + i);
			formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "\r%d.\w %s \y[%d]^n", i + 1, szMap, count);
		} else {
			formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "\r%d.\w %s^n", i + 1, szMap);
		}
		iLen += strlen(szBuffer[iLen]);

		iKeys |= (1 << i);
		g_MapMenuChoice[id][i] = offset + i;
		shown++;
	}

	if (currentPage > 1) {
		formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "^n\r8.\w %L^n", id, "MAPS_MENU_PREV");
		iLen += strlen(szBuffer[iLen]);
		iKeys |= MENU_KEY_8;
	} else {
		formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "^n\r8.\w %L^n", id, "MAPS_MENU_BACK");
		iLen += strlen(szBuffer[iLen]);
		iKeys |= MENU_KEY_8;
	}

	if (offset + shown < iTotal) {
		formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "\r9.\w %L^n", id, "MAPS_MENU_NEXT");
		iLen += strlen(szBuffer[iLen]);
		iKeys |= MENU_KEY_9;
	} else {
		formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "\r9.\d %L^n", id, "MAPS_MENU_NEXT");
		iLen += strlen(szBuffer[iLen]);
	}

	formatex(szBuffer[iLen], charsmax(szBuffer) - iLen, "\r0.\w %L", id, "MAPS_MENU_EXIT");
	iLen += strlen(szBuffer[iLen]);
	iKeys |= MENU_KEY_0;

	show_menu(id, iKeys, szBuffer, -1, "MapsMenu");
}

public maps_menu_handler(id, iKey) {
	if (!is_user_connected(id)) {
		return PLUGIN_HANDLED;
	}

	if (!g_PlayerMenuArray[id]) {
		return PLUGIN_HANDLED;
	}

	new Array:arr = Array:g_PlayerMenuArray[id];
	new iTotal = ArraySize(arr);

	if (!iTotal) {
		g_PlayerMenuArray[id] = 0;
		return PLUGIN_HANDLED;
	}

	switch (iKey) {
		case 0 .. (MAPS_MENU_SLOTS - 1): {
			new mapIndex = g_MapMenuChoice[id][iKey];

			if (mapIndex < 0 || mapIndex >= iTotal) {
				showMapsMenu(id, arr);
				return PLUGIN_HANDLED;
			}

			new szMap[32];
			ArrayGetString(arr, mapIndex, szMap, charsmax(szMap));

			cmdMapActionMenu(id, szMap);
		}
		case 7: {
			if (g_MapMenuOffset[id] >= MAPS_MENU_SLOTS) {
				g_MapMenuOffset[id] -= MAPS_MENU_SLOTS;
				if (g_MapMenuOffset[id] < 0) {
					g_MapMenuOffset[id] = 0;
				}
				showMapsMenu(id, arr);
			} else {
				g_MapMenuOffset[id] = 0;
				g_PlayerMenuArray[id] = 0;
				cmdMapsMenu(id);
			}
		}
		case 8: {
			if (g_MapMenuOffset[id] + MAPS_MENU_SLOTS < iTotal) {
				g_MapMenuOffset[id] += MAPS_MENU_SLOTS;
			}
			showMapsMenu(id, arr);
		}
		case 9: {
			g_MapMenuOffset[id] = 0;
			g_PlayerMenuArray[id] = 0;
		}
	}

	return PLUGIN_HANDLED;
}

public client_disconnected(id) {
	clear_player_nomination(id);

	g_PlayerMenuArray[id] = 0;
	g_MapMenuOffset[id] = 0;
	g_SelectedMap[id][0] = EOS;
	g_SelectedSection[id][0] = EOS;
}

public cmdMapActionMenu(id, szMap[]) {
	new szMsg[128];
	formatex(szMsg, charsmax(szMsg), "\r%L", id, "MAPS_MENU_TITLE");

	new szDescription[160];
	formatex(szDescription, charsmax(szDescription), "^n\d%L^n%L",
		id, "MAPS_MENU_ACTION_MAP", szMap,
		id, "MAPS_ACTION_DESC");
	add(szMsg, charsmax(szMsg), szDescription);

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

	menu_addblank2(hMenu); // 3
	menu_addblank2(hMenu); // 4
	menu_addblank2(hMenu); // 5
	menu_addblank2(hMenu); // 6
	menu_addblank2(hMenu); // 7

	formatex(szMsg, charsmax(szMsg), "%L", id, "MAPS_MENU_BACK");
	menu_additem(hMenu, szMsg, "8");
	
	formatex(szMsg, charsmax(szMsg), "\d%L", id, "MAPS_MENU_NX");
	menu_additem(hMenu, szMsg, "9");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MAPS_MENU_EXIT");
	menu_additem(hMenu, szMsg, "0");

	menu_setprop(hMenu, MPROP_PERPAGE, 0);

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
		set_player_nomination(id, g_SelectedMap[id]);
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
	else if (choice == 8) {
		if (g_PlayerMenuArray[id]) {
			showMapsMenu(id, Array:g_PlayerMenuArray[id]);
		} else {
			cmdMapsMenu(id);
		}
	}
	
	return PLUGIN_HANDLED;
}

public change_map(idtask) {
	new id = idtask - TASK_MAP;

	engine_changelevel(g_SelectedMap[id]);
}

stock bool:extract_section_name(const szLine[], szSection[], len) {
	if (szLine[0] != '[') {
		return false;
	}

	new i = 1, j = 0;
	while (szLine[i] && szLine[i] != ']' && j < len) {
		szSection[j++] = szLine[i++];
	}

	if (szLine[i] != ']') {
		return false;
	}

	szSection[j] = EOS;
	trim(szSection);

	return szSection[0] != EOS;
}

stock get_or_create_section(const name[]) {
	new index = get_section_index(name);
	if (index != -1) {
		return index;
	}

	new sectionData[SectionData];
	copy(sectionData[SectionName], charsmax(sectionData[SectionName]), name);
	sectionData[SectionMaps] = _:ArrayCreate(32);

	return ArrayPushArray(g_ArrSections, sectionData);
}

stock get_section_index(const name[]) {
	new sectionData[SectionData];
	for (new i = 0, iSize = ArraySize(g_ArrSections); i < iSize; i++) {
		ArrayGetArray(g_ArrSections, i, sectionData);
		if (equali(sectionData[SectionName], name)) {
			return i;
		}
	}

	return -1;
}

stock Array:get_section_array_by_name(const name[]) {
	new index = get_section_index(name);
	if (index == -1) {
		return Array:0;
	}

	new sectionData[SectionData];
	ArrayGetArray(g_ArrSections, index, sectionData);

	return Array:sectionData[SectionMaps];
}

stock add_map_to_all(const szMap[]) {
	if (!array_contains_string(g_ArrAllMaps, szMap)) {
		ArrayPushString(g_ArrAllMaps, szMap);
	}
}

stock bool:array_contains_string(Array:arr, const value[]) {
	if (!arr || !value[0]) {
		return false;
	}

	new szTemp[32];

	for (new i = 0, iSize = ArraySize(arr); i < iSize; i++) {
		ArrayGetString(arr, i, szTemp, charsmax(szTemp));
		if (equali(szTemp, value)) {
			return true;
		}
	}

	return false;
}

stock set_player_nomination(id, const szMap[]) {
	if (!szMap[0]) {
		return;
	}

	if (equali(g_PlayerNomination[id], szMap)) {
		return;
	}

	if (g_PlayerNomination[id][0]) {
		adjust_nomination_count(g_PlayerNomination[id], -1);
	}

	copy(g_PlayerNomination[id], charsmax(g_PlayerNomination[]), szMap);
	adjust_nomination_count(szMap, 1);
}

stock clear_player_nomination(id) {
	if (!g_PlayerNomination[id][0]) {
		return;
	}

	adjust_nomination_count(g_PlayerNomination[id], -1);
	g_PlayerNomination[id][0] = EOS;
}

stock adjust_nomination_count(const szMap[], delta) {
	if (!szMap[0] || !delta) {
		return;
	}

	new idx = get_nomination_index(szMap);
	if (idx == -1) {
		if (delta > 0) {
			ArrayPushString(g_ArrNominatedMaps, szMap);
			ArrayPushCell(g_ArrNominatedCounts, delta);
		}
		return;
	}

	new count = ArrayGetCell(g_ArrNominatedCounts, idx);
	count += delta;

	if (count <= 0) {
		ArrayDeleteItem(g_ArrNominatedMaps, idx);
		ArrayDeleteItem(g_ArrNominatedCounts, idx);
	} else {
		ArraySetCell(g_ArrNominatedCounts, idx, count);
	}
}

stock get_nomination_index(const szMap[]) {
	new szTemp[32];
	for (new i = 0, iSize = ArraySize(g_ArrNominatedMaps); i < iSize; i++) {
		ArrayGetString(g_ArrNominatedMaps, i, szTemp, charsmax(szTemp));
		if (equali(szTemp, szMap)) {
			return i;
		}
	}
	return -1;
}

stock bool:get_section_label(id, const sectionName[], szBuffer[], len, bool:bWithColon) {
	if (len <= 0) {
		return false;
	}

	if (!sectionName[0]) {
		szBuffer[0] = EOS;
		return false;
	}

	if (equali(sectionName, SECTION_NAME_ALL)) {
		formatex(szBuffer, len, bWithColon ? "%L:" : "%L", id, "MAPS_MENU_ALL");
		return true;
	}

	if (equali(sectionName, SECTION_NAME_NOMINATED)) {
		formatex(szBuffer, len, bWithColon ? "%L:" : "%L", id, "MAPS_MENU_NOMINATED");
		return true;
	}

	if (equali(sectionName, SECTION_NAME_KNIFE)) {
		formatex(szBuffer, len, bWithColon ? "%L:" : "%L", id, "MAPS_MENU_KNIFE");
		return true;
	}

	if (equali(sectionName, SECTION_NAME_BOOST)) {
		formatex(szBuffer, len, bWithColon ? "%L:" : "%L", id, "MAPS_MENU_BOOST");
		return true;
	}

	if (equali(sectionName, SECTION_NAME_SKILL)) {
		formatex(szBuffer, len, bWithColon ? "%L:" : "%L", id, "MAPS_MENU_SKILL");
		return true;
	}

	formatex(szBuffer, len, bWithColon ? 
	"%s:" : "%s", sectionName);
	return true;
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
