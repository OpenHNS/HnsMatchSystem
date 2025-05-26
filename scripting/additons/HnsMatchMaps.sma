#include <amxmodx>
#include <hns_matchsystem>

new g_szPrefix[24];

new Trie:g_Trie;
new Array:g_ArrMaps;

public plugin_init() {
	register_plugin("Match: Maps", "1.0", "OpenHNS"); // Garey

	RegisterSayCmd("map", "maps", "cmdMapsMenu", 0, "Open mapmenu");
}

public plugin_cfg() {
	hns_get_prefix(g_szPrefix, charsmax(g_szPrefix));
}

public plugin_precache() {
	new mapName[32]
	g_ArrMaps = ArrayCreate(32);
	g_Trie = TrieCreate();

	new szPath[64], szFile[75];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	formatex(szFile, charsmax(szFile), "%s/maps.ini", szPath);

	new fp = fopen(szFile, "rt");

	while (!feof(fp)) {
		fgets(fp, mapName, charsmax(mapName));
		trim(mapName);
		strtolower(mapName);	  	
		if (!mapName[0] || mapName[0] == ';')
		{
			continue;
		}
		
		ArrayPushArray(g_ArrMaps, mapName);
	}
	fclose(fp);

	TrieDestroy(g_Trie);
}

public cmdMapsMenu(id) { // TODO: 2 Пункта: 1 номинировать карты, 2 Выбрать карту (для капитанов)
	new szMapId[10];

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "\rMap list:");

	new hMenu = menu_create(szMsg, "cmdMapsMenuHandler");

	for (new i = 0, iSize = ArraySize(g_ArrMaps), szMap[32]; i < iSize; i++) {
		ArrayGetArray(g_ArrMaps, i, szMap);
		num_to_str(i, szMapId, charsmax(szMapId));
		menu_additem(hMenu, szMap, szMapId);
	}

	menu_display(id, hMenu, 0);
	return PLUGIN_CONTINUE;
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
	ArrayGetArray(g_ArrMaps, mapid, szMap);

	if (hns_get_status() == MATCH_MAPPICK)
	{
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "MAPS_NOM", g_szPrefix, id, szMap);
	}

	return PLUGIN_HANDLED;
}