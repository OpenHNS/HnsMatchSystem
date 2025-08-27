#include <amxmodx>
#include <hns_matchsystem>

new g_szPrefix[24];

new Array:g_ArrBoost; // массив карт boost
new Array:g_ArrSkill; // массив карт skill

new Array:g_CurrentMenuArray;

public plugin_precache() {
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
            if (equali(mapName, "[boost]"))
                section = 1;
            else if (equali(mapName, "[skill]"))
                section = 2;
            else
                section = 0;
            continue;
        }

        strtolower(mapName);

        if (section == 1)
            ArrayPushString(g_ArrBoost, mapName);
        else if (section == 2)
            ArrayPushString(g_ArrSkill, mapName);
    }
    fclose(fp);
}

public plugin_init() {
    register_plugin("Match: Maps", "1.2", "OpenHNS");

    RegisterSayCmd("map", "maps", "cmdMapsMenu", 0, "Open mapmenu");
}

public plugin_cfg() {
    hns_get_prefix(g_szPrefix, charsmax(g_szPrefix));
}

public cmdMapsMenu(id) {
    new szMsg[64];
    formatex(szMsg, charsmax(szMsg), "\rВыбор меню карт:");

    new hMenu = menu_create(szMsg, "cmdMapsRootHandler");
    menu_additem(hMenu, "Boost карты", "1");
    menu_additem(hMenu, "Skill карты", "2");

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
        showMapsMenu(id, g_ArrBoost, "Boost карты:");
    else if (choice == 2)
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

    if (hns_get_status() == MATCH_MAPPICK) {
        client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "MAPS_NOM", g_szPrefix, id, szMap);
    }

	client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "MAPS_NOM", g_szPrefix, id, szMap);

    return PLUGIN_HANDLED;
}
