#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <hns_matchsystem>
#include <hns_matchsystem_maps>
#include <PersistentDataStorage>

#define TEAM_NAME_LEN 32
#define MAP_NAME_LEN 32
#define PLAYER_AUTH_LEN 36
#define PLAYER_NAME_LEN 64

#define CUP_CONFIG_FILE "hns-cup-teams.ini"
#define CUP_MAPS_FILE "hns-cup-maps.ini"
#define CUP_MAX_MAPS 64
#define TASK_VETO_HUD 91212

enum {
	CUP_TEAM_FIRST,
	CUP_TEAM_SECOND,
	CUP_TEAM_TOTAL
};

enum _:CupPlayerData {
	PlayerAuth[PLAYER_AUTH_LEN],
	PlayerNick[PLAYER_NAME_LEN]
};

enum _:CupTeamData {
	CupTeamName[TEAM_NAME_LEN],
	Array:TeamPlayers
};

new Array:g_aCupTeams;
new Trie:g_tActiveAuths;
new g_iSelectedTeams[CUP_TEAM_TOTAL];
new g_iMenuSelectSlot[MAX_PLAYERS + 1];
new const szPdsTeamFirst[] = "hns_cup_team_first";
new const szPdsTeamSecond[] = "hns_cup_team_second";

new Array:g_aCupMaps;
new g_iVetoFormat = 1;
new bool:g_bMapBanned[CUP_MAX_MAPS];
new bool:g_bMapPicked[CUP_MAX_MAPS];
new g_iMapCount;
new bool:g_bVetoActive;
new g_iVetoCaptains[CUP_TEAM_TOTAL];
new g_iVetoTurn;
new g_iVetoStep;

new g_pCvarCup;
new g_szPrefix[24];
new bool:g_bConfigLoaded;

public plugin_init() {
	register_plugin("Match: Cup", "0.1", "OpenHNS");

	g_pCvarCup = register_cvar("hns_cup", "0");
	hook_cvar_change(g_pCvarCup, "onCupCvarChange");

	RegisterSayCmd("cup", "cup", "cmdCupMenu", ADMIN_LEVEL_E, "Open tournament cup menu");
	RegisterSayCmd("cupmenu", "cupm", "cmdCupMenu", ADMIN_LEVEL_E, "Open tournament cup menu");
	register_concmd("cupmenu", "cmdCupMenu", ADMIN_LEVEL_E, "Open tournament cup menu");

	g_tActiveAuths = TrieCreate();
	resetSelections(false, false);

}

public plugin_natives() {
	register_native("hns_cup_enabled", "native_cup_enabled");
}

public plugin_cfg() {
	hns_get_prefix(g_szPrefix, charsmax(g_szPrefix));
	loadCupConfig();
	loadCupMapsConfig();
	loadSavedSelections();
}

public plugin_end() {
	saveSelectedTeams();
	clearTeams(false);
	clearMaps();

	if (g_tActiveAuths)
		TrieDestroy(g_tActiveAuths);
}

public PDS_Save() {
	log_amx("HNS-CUP | PDS_Save forward fired");
	saveSelectedTeams();
}

public client_authorized(id, const authid[]) {
	enforcePlayer(id, true);
}

public client_putinserver(id) {
	enforcePlayer(id, true);
}

public client_disconnected(id) {
	if (g_bVetoActive && (id == g_iVetoCaptains[CUP_TEAM_FIRST] || id == g_iVetoCaptains[CUP_TEAM_SECOND])) {
		stopMapVeto();
		client_print_color(0, print_team_blue, "%s Капитан вышел. Pick/Ban карт остановлено.", g_szPrefix);
	}
}

public cmdCupMenu(id) {
	if (!isCupAdmin(id))
		return PLUGIN_HANDLED;

	if (!isCupEnabled()) {
		client_print_color(id, print_team_blue, "%s hns_cup выключен.", g_szPrefix);
		return PLUGIN_HANDLED;
	}

	showCupMenu(id);
	return PLUGIN_HANDLED;
}

public cmdCupMaps(id) {
	return cmdCupMenu(id);
}

public native_cup_enabled(amxx, params) {
	return isCupEnabled();
}

public onCupCvarChange(pcvar, const oldValue[], const newValue[]) {
	if (str_to_num(newValue) > 0)
		enforceAll();
	else
		stopMapVeto();
}

stock bool:isCupEnabled() {
	return get_pcvar_num(g_pCvarCup) > 0;
}

stock bool:isCupAdmin(id) {
	return bool:(get_user_flags(id) & ADMIN_LEVEL_E);
}

stock loadCupConfig() {
	clearTeams(true);

	new szPath[128], szFile[160];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	formatex(szFile, charsmax(szFile), "%s/mixsystem/%s", szPath, CUP_CONFIG_FILE);

	new fp = fopen(szFile, "rt");
	if (!fp) {
		log_amx("HNS-CUP | Config file %s not found.", szFile);
		resetSelections(true, false);
		return;
	}

	g_aCupTeams = ArrayCreate(CupTeamData);

	new szLine[192], szSection[TEAM_NAME_LEN], currentTeam = -1;

	while (!feof(fp)) {
		fgets(fp, szLine, charsmax(szLine));
		trim(szLine);

		if (!szLine[0] || szLine[0] == ';' || szLine[0] == '#')
			continue;

		if (szLine[0] == '[') {
			if (extractSectionName(szLine, szSection, charsmax(szSection))) {
				new eTeam[CupTeamData];
				copy(eTeam[CupTeamName], charsmax(eTeam[CupTeamName]), szSection);
				eTeam[TeamPlayers] = ArrayCreate(CupPlayerData);
				currentTeam = ArrayPushArray(g_aCupTeams, eTeam);
			} else {
				currentTeam = -1;
			}
			continue;
		}

		if (currentTeam == -1)
			continue;

		new szAuth[PLAYER_AUTH_LEN], szNick[PLAYER_NAME_LEN];
		if (!parsePlayerLine(szLine, szAuth, charsmax(szAuth), szNick, charsmax(szNick)))
			continue;

		new ePlayer[CupPlayerData];
		copy(ePlayer[PlayerAuth], charsmax(ePlayer[PlayerAuth]), szAuth);
		copy(ePlayer[PlayerNick], charsmax(ePlayer[PlayerNick]), szNick);

		new eTeam[CupTeamData];
		ArrayGetArray(g_aCupTeams, currentTeam, eTeam);
		ArrayPushArray(Array:eTeam[TeamPlayers], ePlayer);
	}
	fclose(fp);

	g_bConfigLoaded = (g_aCupTeams != Invalid_Array && ArraySize(g_aCupTeams) > 0);

	resetSelections(true, false);

	if (!g_bConfigLoaded) {
		log_amx("HNS-CUP | %s loaded but no teams were found.", szFile);
	} else {
		log_amx("HNS-CUP | Loaded %d teams from %s", ArraySize(g_aCupTeams), szFile);
	}

	debugSelectedTeams("After loadCupConfig");
}

stock loadCupMapsConfig() {
	clearMaps();

	new szPath[128], szFile[160];
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	formatex(szFile, charsmax(szFile), "%s/mixsystem/%s", szPath, CUP_MAPS_FILE);

	new fp = fopen(szFile, "rt");
	if (!fp) {
		log_amx("HNS-CUP | Map config file %s not found.", szFile);
		return;
	}

	g_aCupMaps = ArrayCreate(MAP_NAME_LEN);

	new szLine[64];

	while (!feof(fp) && g_iMapCount < CUP_MAX_MAPS) {
		fgets(fp, szLine, charsmax(szLine));
		trim(szLine);

		if (!szLine[0] || szLine[0] == ';' || szLine[0] == '#')
			continue;

		strtolower(szLine);
		ArrayPushString(g_aCupMaps, szLine);
		g_iMapCount++;
	}
	fclose(fp);

	if (g_iMapCount > 0) {
		log_amx("HNS-CUP | Loaded %d maps from %s", g_iMapCount, szFile);
	} else {
		log_amx("HNS-CUP | %s loaded but no maps found.", szFile);
	}
}

stock clearTeams(bool:bResetSelections = true) {
	if (g_aCupTeams != Invalid_Array) {
		for (new i = 0, iSize = ArraySize(g_aCupTeams); i < iSize; i++) {
			new eTeam[CupTeamData];
			ArrayGetArray(g_aCupTeams, i, eTeam);
			if (eTeam[TeamPlayers])
				ArrayDestroy(Array:eTeam[TeamPlayers]);
		}
		ArrayDestroy(g_aCupTeams);
	}

	g_aCupTeams = Invalid_Array;
	g_bConfigLoaded = false;
	if (bResetSelections)
		resetSelections(false, false);
}

stock clearMaps() {
	if (g_aCupMaps != Invalid_Array) {
		ArrayDestroy(g_aCupMaps);
	}

	g_aCupMaps = Invalid_Array;
	g_iMapCount = 0;
	g_bVetoActive = false;
	g_iVetoStep = 0;
	arrayset(g_bMapBanned, false, sizeof g_bMapBanned);
	arrayset(g_bMapPicked, false, sizeof g_bMapPicked);
	g_iVetoCaptains[CUP_TEAM_FIRST] = g_iVetoCaptains[CUP_TEAM_SECOND] = -1;
	g_iVetoTurn = CUP_TEAM_FIRST;
	remove_task(TASK_VETO_HUD);
}

stock resetSelections(bool:bEnforce, bool:bSave = true) {
	if (g_bVetoActive)
		stopMapVeto();

	for (new i = CUP_TEAM_FIRST; i < CUP_TEAM_TOTAL; i++) {
		g_iSelectedTeams[i] = -1;
	}

	arrayset(g_iMenuSelectSlot, -1, sizeof g_iMenuSelectSlot);
	g_iVetoCaptains[CUP_TEAM_FIRST] = g_iVetoCaptains[CUP_TEAM_SECOND] = -1;

	rebuildActiveAuths();

	if (bSave)
		saveSelectedTeams();

	if (bEnforce && isCupEnabled())
		enforceAll();
}

stock rebuildActiveAuths() {
	if (g_tActiveAuths)
		TrieDestroy(g_tActiveAuths);

	g_tActiveAuths = TrieCreate();

	for (new slot = CUP_TEAM_FIRST; slot < CUP_TEAM_TOTAL; slot++) {
		if (!isValidTeamIndex(g_iSelectedTeams[slot]))
			continue;

		new eTeam[CupTeamData];
		ArrayGetArray(g_aCupTeams, g_iSelectedTeams[slot], eTeam);

		new Array:aPlayers = Array:eTeam[TeamPlayers];
		for (new i = 0, iSize = ArraySize(aPlayers); i < iSize; i++) {
			new ePlayer[CupPlayerData];
			ArrayGetArray(aPlayers, i, ePlayer);
			new szAuth[PLAYER_AUTH_LEN];
			copy(szAuth, charsmax(szAuth), ePlayer[PlayerAuth]);
			strtolower(szAuth);
			TrieSetCell(g_tActiveAuths, szAuth, 1);
		}
	}
}

stock enforceAll() {
	for (new id = 1; id <= MaxClients; id++) {
		if (is_user_connected(id))
			enforcePlayer(id, true);
	}
}

stock enforcePlayer(id, bool:bApplyPlacement = false) {
	if (!isCupEnabled())
		return;

	if (!is_user_connected(id))
		return;

	if (is_user_bot(id) || is_user_hltv(id))
		return;

	new bool:bKnifeMap = hns_is_knife_map();
	new bool:bAdmin = isCupAdmin(id);
	new slot = getPlayerCupSlot(id);

	if (bKnifeMap && slot == -1 && !bAdmin) {
		kickNotAllowed(id, "Cup mode enabled. Only admins or selected teams can join.");
		return;
	}

	if (!bApplyPlacement)
		return;

	applyCupPlacement(id, slot, bAdmin, bKnifeMap);

	if (bAdmin || slot != -1)
		return;

	if (g_tActiveAuths == Invalid_Trie || TrieGetSize(g_tActiveAuths) == 0)
		return;

	new szAuth[PLAYER_AUTH_LEN];
	get_user_authid(id, szAuth, charsmax(szAuth));
	strtolower(szAuth);

	if (!TrieKeyExists(g_tActiveAuths, szAuth) && bKnifeMap)
		kickNotAllowed(id, "Cup mode enabled. You are not on the lineup list.");
}

stock kickNotAllowed(id, const reason[]) {
	if (!is_user_connected(id))
		return;

	new name[32], auth[PLAYER_AUTH_LEN];
	get_user_name(id, name, charsmax(name));
	get_user_authid(id, auth, charsmax(auth));
	server_print("[HNS-CUP] Kick %s (%s) reason: %s", name, auth, reason);

	server_cmd("kick #%d ^"%s^"", get_user_userid(id), reason);
}

stock applyCupPlacement(id, slot, bool:bAdmin, bool:bKnifeMap) {
	new bool:bSetTeam;
	new TeamName:targetTeam;
	new name[32];
	get_user_name(id, name, charsmax(name));

	switch (slot) {
		case CUP_TEAM_FIRST: {
			targetTeam = TEAM_TERRORIST;
			bSetTeam = true;
		}
		case CUP_TEAM_SECOND: {
			targetTeam = TEAM_CT;
			bSetTeam = true;
		}
	}

	if (bAdmin && slot == -1) {
		targetTeam = TEAM_SPECTATOR;
		bSetTeam = true;
	}

	if (bKnifeMap && !bSetTeam) {
		targetTeam = TEAM_SPECTATOR;
		bSetTeam = true;
	} else if (!bKnifeMap && bAdmin && !bSetTeam) {
		targetTeam = TEAM_SPECTATOR;
		bSetTeam = true;
	}

	if (!bKnifeMap && !bSetTeam)
		return;

	if (bSetTeam && rg_get_user_team(id) != targetTeam) {
		rg_set_user_team(id, targetTeam);
		server_print("[HNS-CUP] Assign %s (%d) to %s (admin=%d slot=%d knife=%d)", name, id,
			targetTeam == TEAM_TERRORIST ? "TT" : (targetTeam == TEAM_CT ? "CT" : "SPEC"),
			bAdmin, slot, bKnifeMap);
	}
}

stock getPlayerCupSlot(id) {
	if (!is_user_connected(id))
		return -1;

	if (isPlayerFromTeam(id, g_iSelectedTeams[_:CUP_TEAM_FIRST]))
		return CUP_TEAM_FIRST;

	if (isPlayerFromTeam(id, g_iSelectedTeams[_:CUP_TEAM_SECOND]))
		return CUP_TEAM_SECOND;

	return -1;
}

stock saveSelectedTeams() {
	PDS_SetCell(szPdsTeamFirst, g_iSelectedTeams[_:CUP_TEAM_FIRST]);
	PDS_SetCell(szPdsTeamSecond, g_iSelectedTeams[_:CUP_TEAM_SECOND]);

	debugSelectedTeams("PDS_Save");
}

stock loadSavedSelections() {
	new iFirst = -1, iSecond = -1;
	new bool:bGotFirst = PDS_GetCell(szPdsTeamFirst, iFirst);
	new bool:bGotSecond = PDS_GetCell(szPdsTeamSecond, iSecond);
	log_amx("HNS-CUP | PDS_GetCell first=%d (got=%d) second=%d (got=%d)", iFirst, bGotFirst, iSecond, bGotSecond);

	if (!isValidTeamIndex(iFirst))
		iFirst = -1;
	if (!isValidTeamIndex(iSecond))
		iSecond = -1;

	g_iSelectedTeams[_:CUP_TEAM_FIRST] = iFirst;
	g_iSelectedTeams[_:CUP_TEAM_SECOND] = iSecond;

	assignDefaultCaptainForSlot(CUP_TEAM_FIRST);
	assignDefaultCaptainForSlot(CUP_TEAM_SECOND);

	rebuildActiveAuths();
	enforceAll();

	debugSelectedTeams("PDS_Load");
}

stock debugSelectedTeams(const szTag[]) {
	new szFirst[TEAM_NAME_LEN], szSecond[TEAM_NAME_LEN];
	getTeamName(g_iSelectedTeams[_:CUP_TEAM_FIRST], szFirst, charsmax(szFirst));
	getTeamName(g_iSelectedTeams[_:CUP_TEAM_SECOND], szSecond, charsmax(szSecond));

	log_amx("HNS-CUP | %s first_idx=%d (%s) second_idx=%d (%s)",
		szTag,
		g_iSelectedTeams[_:CUP_TEAM_FIRST], szFirst,
		g_iSelectedTeams[_:CUP_TEAM_SECOND], szSecond);
	server_print("[HNS-CUP] %s first_idx=%d (%s) second_idx=%d (%s)",
		szTag,
		g_iSelectedTeams[_:CUP_TEAM_FIRST], szFirst,
		g_iSelectedTeams[_:CUP_TEAM_SECOND], szSecond);
}

stock showCupMenu(id) {
	new szMsg[128];
	formatex(szMsg, charsmax(szMsg), "\rCup меню");

	new hMenu = menu_create(szMsg, "CupMenuHandler");

	formatex(szMsg, charsmax(szMsg), "Команда 1: \y%s", getTeamLabel(g_iSelectedTeams[_:CUP_TEAM_FIRST]));
	menu_additem(hMenu, szMsg, "1");
	formatex(szMsg, charsmax(szMsg), "Команда 2: \y%s", getTeamLabel(g_iSelectedTeams[_:CUP_TEAM_SECOND]));
	menu_additem(hMenu, szMsg, "2");
	formatex(szMsg, charsmax(szMsg), "Капитан \d%s\w: \y%s", getTeamLabel(g_iSelectedTeams[_:CUP_TEAM_FIRST]), getCaptainNameLabel(CUP_TEAM_FIRST));
	menu_additem(hMenu, szMsg, "3");
	formatex(szMsg, charsmax(szMsg), "Капитан \d%s\w: \y%s", getTeamLabel(g_iSelectedTeams[_:CUP_TEAM_SECOND]), getCaptainNameLabel(CUP_TEAM_SECOND));
	menu_additem(hMenu, szMsg, "4");

	formatex(szMsg, charsmax(szMsg), "Формат бана/пика: \r%s", getVetoFormatLabel());
	menu_additem(hMenu, szMsg, "5");
	formatex(szMsg, charsmax(szMsg), "Очистить значения (команды, капитаны)");
	menu_additem(hMenu, szMsg, "6");
	formatex(szMsg, charsmax(szMsg), "Обновить конфиги (карты, команды)");
	menu_additem(hMenu, szMsg, "7");
	formatex(szMsg, charsmax(szMsg), g_bVetoActive ? "\rОстановить pick/ban" : "Старт pick/ban");
	menu_additem(hMenu, szMsg, "8");
	formatex(szMsg, charsmax(szMsg), "Кикнуть всех, кроме админов");
	menu_additem(hMenu, szMsg, "9");

	menu_setprop(hMenu, MPROP_EXITNAME, "Выход");

	menu_display(id, hMenu);
}

public CupMenuHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new bool:bReopenMenu = true;

	new szInfo[8], szTmp[2], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), szTmp, charsmax(szTmp), callback);

	switch (str_to_num(szInfo)) {
		case 1: {
			showSelectMenu(id, CUP_TEAM_FIRST);
			bReopenMenu = false;
		}
		case 2: {
			showSelectMenu(id, CUP_TEAM_SECOND);
			bReopenMenu = false;
		}
		case 3: {
			showCaptainPickMenu(id, CUP_TEAM_FIRST);
			bReopenMenu = false;
		}
		case 4: {
			showCaptainPickMenu(id, CUP_TEAM_SECOND);
			bReopenMenu = false;
		}
	case 5: {
		if (g_bVetoActive) {
			client_print_color(id, print_team_blue, "%s Формат нельзя менять во время пик/бан.", g_szPrefix);
		} else {
			cycleVetoFormat();
			client_print_color(id, print_team_blue, "%s Формат бана/пика: ^3%s^1", g_szPrefix, getVetoFormatLabel());
		}
	}
		case 6: {
			resetSelections(true);
		}
		case 7: {
			loadCupConfig();
			loadCupMapsConfig();
			client_print_color(id, print_team_blue, "%s Конфиги перезагружены.", g_szPrefix);
		}
		case 8: {
			if (g_bVetoActive) {
				stopMapVeto();
				client_print_color(id, print_team_blue, "%s Пик/бан остановлен.", g_szPrefix);
			} else {
				showStartVetoMenu(id);
				bReopenMenu = false;
			}
		}
		case 9: {
			kickNonCupAdmins(id);
		}
	}

	menu_destroy(menu);

	// For selection we open a new menu, for other actions re-open main menu.
	if (bReopenMenu && isCupAdmin(id) && isCupEnabled())
		showCupMenu(id);

	return PLUGIN_HANDLED;
}

stock cycleVetoFormat() {
	g_iVetoFormat++;

	if (g_iVetoFormat < 1 || g_iVetoFormat > 3)
		g_iVetoFormat = 1;
}

stock getVetoFormatLabel() {
	static szLabel[8];

	switch (g_iVetoFormat) {
		case 2: formatex(szLabel, charsmax(szLabel), "BO3");
		case 3: formatex(szLabel, charsmax(szLabel), "BO5");
		default: {
			g_iVetoFormat = 1;
			formatex(szLabel, charsmax(szLabel), "BO1");
		}
	}

	return szLabel;
}

stock bool:isPickStep() {
	switch (g_iVetoFormat) {
		case 2: return (g_iVetoStep == 2 || g_iVetoStep == 3); // BO3 pick phase after 2 bans
		case 3: return (g_iVetoStep == 2 || g_iVetoStep == 3 || g_iVetoStep == 6 || g_iVetoStep == 7); // BO5 two pick phases
	}

	return false;
}

stock getMinMapsForFormat() {
	switch (g_iVetoFormat) {
		case 2: return 5; // 2 bans + 2 picks + decider
		case 3: return 7; // 2 bans + 2 picks + 2 bans + 2 picks + decider
	}

	return 2; // at least 2 maps for BO1
}

stock kickNonCupAdmins(id) {
	new players[MAX_PLAYERS], num;
	get_players(players, num, "ch");

	new kicked;
	for (new i; i < num; i++) {
		new pid = players[i];
		if (isCupAdmin(pid))
			continue;

		kicked++;
		server_cmd("kick #%d ^"Only admins^"", get_user_userid(pid));
	}

	if (kicked > 0)
		client_print_color(0, print_team_blue, "%s ^3%d^1 игроков кикнуто. Остались только админы.", g_szPrefix, kicked);
	else
		client_print_color(id, print_team_blue, "%s Некого кикать, на сервере только админы.", g_szPrefix);
}

stock showSelectMenu(id, slot) {
	if (!g_bConfigLoaded || g_aCupTeams == Invalid_Array || ArraySize(g_aCupTeams) == 0) {
		client_print_color(id, print_team_blue, "%s Cup teams are not loaded.", g_szPrefix);
		return;
	}

	g_iMenuSelectSlot[id] = slot;

	new szTitle[96];
	formatex(szTitle, charsmax(szTitle), "\rSelect team for %s", slot == CUP_TEAM_FIRST ? "A" : "B");

	new menu = menu_create(szTitle, "CupTeamSelectHandler");

	new eTeam[CupTeamData], szInfo[8], szItem[64];
	for (new i = 0, iSize = ArraySize(g_aCupTeams); i < iSize; i++) {
		ArrayGetArray(g_aCupTeams, i, eTeam);
		num_to_str(i, szInfo, charsmax(szInfo));

		new Array:aPlayers = Array:eTeam[TeamPlayers];
		formatex(szItem, charsmax(szItem), "%s \y(%d)", eTeam[CupTeamName], aPlayers ? ArraySize(aPlayers) : 0);
		menu_additem(menu, szItem, szInfo);
	}

	menu_display(id, menu);
}

public CupTeamSelectHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		if (isCupAdmin(id))
			showCupMenu(id);
		return PLUGIN_HANDLED;
	}

	new szInfo[8], szName[2], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), szName, charsmax(szName), callback);

	new teamIndex = str_to_num(szInfo);
	new slot = g_iMenuSelectSlot[id];

	menu_destroy(menu);
	g_iMenuSelectSlot[id] = -1;

	if (slot != CUP_TEAM_FIRST && slot != CUP_TEAM_SECOND) {
		if (isCupAdmin(id))
			showCupMenu(id);
		return PLUGIN_HANDLED;
	}

	if (!isValidTeamIndex(teamIndex)) {
		if (isCupAdmin(id))
			showCupMenu(id);
		return PLUGIN_HANDLED;
	}

	new otherSlot = (slot == CUP_TEAM_FIRST) ? CUP_TEAM_SECOND : CUP_TEAM_FIRST;
	if (g_iSelectedTeams[otherSlot] == teamIndex) {
		client_print_color(id, print_team_blue, "%s Team already selected in another slot.", g_szPrefix);
		showSelectMenu(id, slot);
		return PLUGIN_HANDLED;
	}

	g_iSelectedTeams[slot] = teamIndex;

	new szTeamName[TEAM_NAME_LEN];
	getTeamName(teamIndex, szTeamName, charsmax(szTeamName));
	client_print_color(id, print_team_blue, "%s ^3%s^1 set for slot ^3%s^1.", g_szPrefix, szTeamName, slot == CUP_TEAM_FIRST ? "A" : "B");

	assignDefaultCaptainForSlot(slot);

	rebuildActiveAuths();
	saveSelectedTeams();

	if (isCupEnabled())
		enforceAll();

	if (isCupAdmin(id))
		showCupMenu(id);

	return PLUGIN_HANDLED;
}

stock assignDefaultCaptainForSlot(slot) {
	if (slot != CUP_TEAM_FIRST && slot != CUP_TEAM_SECOND) {
		return;
	}

	if (!isValidTeamIndex(g_iSelectedTeams[_:slot])) {
		g_iVetoCaptains[_:slot] = -1;
		return;
	}

	new captain = findFirstListedTeamMember(g_iSelectedTeams[_:slot]);
	g_iVetoCaptains[_:slot] = captain;
}

stock findFirstListedTeamMember(teamIndex) {
	if (!isValidTeamIndex(teamIndex))
		return -1;

	new eTeam[CupTeamData];
	ArrayGetArray(g_aCupTeams, teamIndex, eTeam);

	new Array:aPlayers = Array:eTeam[TeamPlayers];
	if (!aPlayers)
		return -1;

	if (ArraySize(aPlayers) <= 0)
		return -1;

	new ePlayer[CupPlayerData];
	ArrayGetArray(aPlayers, 0, ePlayer);

	new szAuth[PLAYER_AUTH_LEN], szLineAuth[PLAYER_AUTH_LEN];
	copy(szLineAuth, charsmax(szLineAuth), ePlayer[PlayerAuth]);

	new players[MAX_PLAYERS], num;
	get_players(players, num, "ch");

	for (new p; p < num; p++) {
		new pid = players[p];
		if (is_user_bot(pid) || is_user_hltv(pid))
			continue;

		get_user_authid(pid, szAuth, charsmax(szAuth));
		strtolower(szAuth);

		if (equal(szAuth, szLineAuth))
			return pid;
	}

	return -1;
}

stock bool:isPlayerFromTeam(id, teamIndex) {
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return false;

	if (!isValidTeamIndex(teamIndex))
		return false;

	new szAuth[PLAYER_AUTH_LEN];
	get_user_authid(id, szAuth, charsmax(szAuth));
	strtolower(szAuth);

	return isAuthInTeam(szAuth, teamIndex);
}

stock bool:isAuthInTeam(const szAuth[], teamIndex) {
	if (!isValidTeamIndex(teamIndex) || !szAuth[0])
		return false;

	new eTeam[CupTeamData];
	ArrayGetArray(g_aCupTeams, teamIndex, eTeam);

	new Array:aPlayers = Array:eTeam[TeamPlayers];
	if (!aPlayers)
		return false;

	new szAuthLower[PLAYER_AUTH_LEN];
	copy(szAuthLower, charsmax(szAuthLower), szAuth);
	strtolower(szAuthLower);

	for (new i = 0, iSize = ArraySize(aPlayers); i < iSize; i++) {
		new ePlayer[CupPlayerData];
		ArrayGetArray(aPlayers, i, ePlayer);

		new szLine[PLAYER_AUTH_LEN];
		copy(szLine, charsmax(szLine), ePlayer[PlayerAuth]);
		strtolower(szLine);

		if (equal(szLine, szAuthLower))
			return true;
	}

	return false;
}

stock showCaptainPickMenu(id, slot) {
	new title[64];
	formatex(title, charsmax(title), "\rКапитан %s", getTeamLabel(g_iSelectedTeams[_:slot]));

	if (!isValidTeamIndex(g_iSelectedTeams[_:slot])) {
		client_print_color(id, print_team_blue, "%s Сначала выберите команду.", g_szPrefix);
		return;
	}

	new menu = menu_create(title, "CupCaptainPickHandler");
	g_iMenuSelectSlot[id] = slot;

	new players[MAX_PLAYERS], num, szId[6], szItem[64];
	get_players(players, num, "ch");

	for (new i; i < num; i++) {
		new pid = players[i];
		if (is_user_bot(pid) || is_user_hltv(pid))
			continue;

		if (g_iVetoCaptains[_:(slot == CUP_TEAM_FIRST ? CUP_TEAM_SECOND : CUP_TEAM_FIRST)] == pid)
			continue;

		if (!isPlayerFromTeam(pid, g_iSelectedTeams[_:slot]))
			continue;

		num_to_str(pid, szId, charsmax(szId));
		formatex(szItem, charsmax(szItem), "%n", pid);
		menu_additem(menu, szItem, szId);
	}

	menu_display(id, menu);
}

public CupCaptainPickHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		if (isCupAdmin(id))
			showCupMenu(id);
		return PLUGIN_HANDLED;
	}

	new szInfo[8], szTmp[2], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), szTmp, charsmax(szTmp), callback);

	new pid = str_to_num(szInfo);
	menu_destroy(menu);

	new slot = g_iMenuSelectSlot[id];
	g_iMenuSelectSlot[id] = -1;

	if (slot != CUP_TEAM_FIRST && slot != CUP_TEAM_SECOND) {
		if (isCupAdmin(id))
			showCupMenu(id);
		return PLUGIN_HANDLED;
	}

	if (!is_user_connected(pid)) {
		client_print_color(id, print_team_blue, "%s Игрок вышел.", g_szPrefix);
		if (isCupAdmin(id))
			showCupMenu(id);
		return PLUGIN_HANDLED;
	}

	if (!isPlayerFromTeam(pid, g_iSelectedTeams[_:slot])) {
		client_print_color(id, print_team_blue, "%s Игрок не из выбранной команды.", g_szPrefix);
		if (isCupAdmin(id))
			showCupMenu(id);
		return PLUGIN_HANDLED;
	}

	g_iVetoCaptains[_:slot] = pid;
	client_print_color(0, print_team_blue, "%s Капитан ^3%s^1: ^3%n^1", g_szPrefix, getTeamLabel(g_iSelectedTeams[_:slot]), pid);

	if (isCupAdmin(id))
		showCupMenu(id);

	return PLUGIN_HANDLED;
}

stock showStartVetoMenu(id) {
	if (!isCupEnabled()) {
		client_print_color(id, print_team_blue, "%s hns_cup выключен.", g_szPrefix);
		return;
	}

	if (g_bVetoActive) {
		client_print_color(id, print_team_blue, "%s Пик/бан уже идёт.", g_szPrefix);
		return;
	}

	if (!isValidTeamIndex(g_iSelectedTeams[_:CUP_TEAM_FIRST]) || !isValidTeamIndex(g_iSelectedTeams[_:CUP_TEAM_SECOND])) {
		client_print_color(id, print_team_blue, "%s Выберите обе команды перед стартом Pick/Ban.", g_szPrefix);
		return;
	}

	new menu = menu_create("\rКто начинает бан/пик?", "CupStartVetoHandler");

	new szInfo[4], szItem[96];
	for (new slot = CUP_TEAM_FIRST; slot < CUP_TEAM_TOTAL; slot++) {
		num_to_str(slot, szInfo, charsmax(szInfo));
		formatex(szItem, charsmax(szItem), "%s", getTeamLabel(g_iSelectedTeams[_:slot]));
		menu_additem(menu, szItem, szInfo);
	}

	menu_display(id, menu);
}

public CupStartVetoHandler(id, menu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(menu);
		if (isCupAdmin(id) && isCupEnabled())
			showCupMenu(id);
		return PLUGIN_HANDLED;
	}

	new szInfo[8], szTmp[2], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), szTmp, charsmax(szTmp), callback);
	menu_destroy(menu);

	new startSlot = str_to_num(szInfo);
	if (startSlot != CUP_TEAM_FIRST && startSlot != CUP_TEAM_SECOND) {
		client_print_color(id, print_team_blue, "%s Неизвестный выбор команды.", g_szPrefix);
		if (isCupAdmin(id) && isCupEnabled())
			showCupMenu(id);
		return PLUGIN_HANDLED;
	}

	startMapVeto(id, startSlot);

	if (!g_bVetoActive && isCupAdmin(id) && isCupEnabled())
		showCupMenu(id);

	return PLUGIN_HANDLED;
}

stock startMapVeto(id, startSlot) {
	if (!isCupEnabled()) {
		client_print_color(id, print_team_blue, "%s hns_cup выключен.", g_szPrefix);
		return;
	}

	if (!isValidTeamIndex(g_iSelectedTeams[_:CUP_TEAM_FIRST]) || !isValidTeamIndex(g_iSelectedTeams[_:CUP_TEAM_SECOND])) {
		client_print_color(id, print_team_blue, "%s Выберите обе команды перед стартом Pick/Ban.", g_szPrefix);
		return;
	}

	if (!is_user_connected(g_iVetoCaptains[_:CUP_TEAM_FIRST]) || !isPlayerFromTeam(g_iVetoCaptains[_:CUP_TEAM_FIRST], g_iSelectedTeams[_:CUP_TEAM_FIRST]))
		assignDefaultCaptainForSlot(CUP_TEAM_FIRST);
	if (!is_user_connected(g_iVetoCaptains[_:CUP_TEAM_SECOND]) || !isPlayerFromTeam(g_iVetoCaptains[_:CUP_TEAM_SECOND], g_iSelectedTeams[_:CUP_TEAM_SECOND]))
		assignDefaultCaptainForSlot(CUP_TEAM_SECOND);

	if (g_bVetoActive) {
		client_print_color(id, print_team_blue, "%s Pick/Ban карт уже идёт.", g_szPrefix);
		return;
	}

	if (g_iMapCount < 2 || g_aCupMaps == Invalid_Array) {
		client_print_color(id, print_team_blue, "%s Недостаточно карт в ^3%s^1.", g_szPrefix, CUP_MAPS_FILE);
		return;
	}

	if (!is_user_connected(g_iVetoCaptains[_:CUP_TEAM_FIRST]) || !is_user_connected(g_iVetoCaptains[_:CUP_TEAM_SECOND])) {
		client_print_color(id, print_team_blue, "%s Укажите обоих капитанов перед стартом Pick/Ban.", g_szPrefix);
		return;
	}

	if (startSlot != CUP_TEAM_FIRST && startSlot != CUP_TEAM_SECOND)
		startSlot = CUP_TEAM_FIRST;

	new minMaps = getMinMapsForFormat();
	if (g_iMapCount < minMaps) {
		client_print_color(id, print_team_blue, "%s Недостаточно карт для формата ^3%s^1 (нужно минимум %d). Добавьте больше карт в ^3%s^1.", g_szPrefix, getVetoFormatLabel(), minMaps, CUP_MAPS_FILE);
		return;
	}

	arrayset(g_bMapBanned, false, sizeof g_bMapBanned);
	arrayset(g_bMapPicked, false, sizeof g_bMapPicked);
	g_bVetoActive = true;
	g_iVetoTurn = startSlot;
	g_iVetoStep = 0;

	remove_task(TASK_VETO_HUD);
	set_task(1.0, "taskShowVetoHud", TASK_VETO_HUD, .flags = "b");

	client_print_color(0, print_team_blue, "%s Старт pick/ban. Формат: ^3%s^1. Первым выбирает капитан ^3%s^1 (^3%n^1).", g_szPrefix, getVetoFormatLabel(), getTeamLabel(g_iSelectedTeams[_:startSlot]), g_iVetoCaptains[_:startSlot]);

	showMapVetoMenu(g_iVetoCaptains[_:g_iVetoTurn]);
}

stock stopMapVeto() {
	if (!g_bVetoActive)
		return;

	g_bVetoActive = false;
	g_iVetoStep = 0;
	remove_task(TASK_VETO_HUD);
	arrayset(g_bMapBanned, false, sizeof g_bMapBanned);
	arrayset(g_bMapPicked, false, sizeof g_bMapPicked);
	g_iVetoTurn = CUP_TEAM_FIRST;

	show_menu(g_iVetoCaptains[_:CUP_TEAM_FIRST], 0, "^n", 1);
	show_menu(g_iVetoCaptains[_:CUP_TEAM_SECOND], 0, "^n", 1);

	client_print_color(0, print_team_blue, "%s Pick/Ban карт остановлено.", g_szPrefix);
}

stock showMapVetoMenu(id) {
	if (!g_bVetoActive || !is_user_connected(id))
		return;

	new menu = menu_create("\rВыбор карты (бан)", "MapVetoHandler");

	new szInfo[8], szItem[64], szMap[MAP_NAME_LEN];
	for (new i; i < g_iMapCount; i++) {
		ArrayGetString(g_aCupMaps, i, szMap, charsmax(szMap));
		num_to_str(i, szInfo, charsmax(szInfo));

		if (g_bMapBanned[i]) {
			formatex(szItem, charsmax(szItem), "\r%s [BAN]", szMap);
		} else if (g_bMapPicked[i]) {
			formatex(szItem, charsmax(szItem), "\d%s [PICK]", szMap);
		} else {
			formatex(szItem, charsmax(szItem), "%s", szMap);
		}

		menu_additem(menu, szItem, szInfo);
	}

	// 7 слотов + 8/9 для навигации
	menu_setprop(menu, MPROP_PERPAGE, 7);
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, menu);
}

public MapVetoHandler(id, menu, item) {
	if (!g_bVetoActive) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (!is_user_connected(id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (id != g_iVetoCaptains[_:g_iVetoTurn]) {
		menu_destroy(menu);
		showMapVetoMenu(g_iVetoCaptains[_:g_iVetoTurn]);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(menu);
		showMapVetoMenu(id);
		return PLUGIN_HANDLED;
	}

	new szInfo[8], szTmp[2], access, callback;
	menu_item_getinfo(menu, item, access, szInfo, charsmax(szInfo), szTmp, charsmax(szTmp), callback);
	menu_destroy(menu);

	new mapIndex = str_to_num(szInfo);

	if (mapIndex < 0 || mapIndex >= g_iMapCount || g_bMapBanned[mapIndex] || g_bMapPicked[mapIndex]) {
		showMapVetoMenu(id);
		return PLUGIN_HANDLED;
	}

	new szMap[MAP_NAME_LEN];
	ArrayGetString(g_aCupMaps, mapIndex, szMap, charsmax(szMap));

	new bool:bPick = isPickStep();
	if (bPick) {
		g_bMapPicked[mapIndex] = true;
	} else {
		g_bMapBanned[mapIndex] = true;
	}

	new slotTurn = g_iVetoTurn;
	if (slotTurn < CUP_TEAM_FIRST || slotTurn >= CUP_TEAM_TOTAL)
		client_print_color(0, print_team_blue, "%s ^3%n^1 %s карту ^3%s^1.", g_szPrefix, id, bPick ? "выбрал" : "забанил", szMap);
	else
		client_print_color(0, print_team_blue, "%s ^3%s^1 (^3%n^1) %s карту ^3%s^1.", g_szPrefix, getTeamLabel(g_iSelectedTeams[_:slotTurn]), id, bPick ? "выбрали" : "забанили", szMap);
	server_print("[HNS-CUP] Map %s by %s (%d): %s (slot=%d)", bPick ? "pick" : "ban", getTeamLabel(g_iSelectedTeams[_:slotTurn]), id, szMap, slotTurn);

	g_iVetoStep++;

	g_iVetoTurn = (g_iVetoTurn == CUP_TEAM_FIRST) ? CUP_TEAM_SECOND : CUP_TEAM_FIRST;

	if (getRemainingMaps() <= 1) {
		announceRemainingMaps();
		stopMapVeto();
		return PLUGIN_HANDLED;
	}

	new nextCap = g_iVetoCaptains[_:g_iVetoTurn];
	if (!is_user_connected(nextCap)) {
		client_print_color(0, print_team_blue, "%s Капитан отсоединился. Pick/Ban остановлено.", g_szPrefix);
		stopMapVeto();
		return PLUGIN_HANDLED;
	}

	showMapVetoMenu(nextCap);
	return PLUGIN_HANDLED;
}

public taskShowVetoHud() {
	if (!g_bVetoActive) {
		remove_task(TASK_VETO_HUD);
		return;
	}

	new remaining = getRemainingMaps();
	new hud[1024], pos;

	if (remaining <= 1) {
		new idx = getLastRemainingMap();
		if (idx != -1) {
			new szMap[MAP_NAME_LEN];
			ArrayGetString(g_aCupMaps, idx, szMap, charsmax(szMap));
			formatex(hud, charsmax(hud), "Карта: %s", szMap);
		}
	} else {
		for (new i; i < g_iMapCount; i++) {
			if (g_bMapBanned[i])
				continue;

			new szMap[MAP_NAME_LEN];
			ArrayGetString(g_aCupMaps, i, szMap, charsmax(szMap));
			pos += formatex(hud[pos], charsmax(hud) - pos, "%s^n", szMap);
		}
	}

	set_hudmessage(255, 255, 255, 0.8, 0.2, 0, 1.0, 1.0, 0.1, 1.0, 4);
	show_hudmessage(0, "%s", hud);
}

stock bool:isValidTeamIndex(index) {
	return (g_aCupTeams != Invalid_Array && index >= 0 && index < ArraySize(g_aCupTeams));
}

stock getTeamName(index, buffer[], len) {
	if (!isValidTeamIndex(index)) {
		formatex(buffer, len, "не выбрана");
		return;
	}

	new eTeam[CupTeamData];
	ArrayGetArray(g_aCupTeams, index, eTeam);
	formatex(buffer, len, "%s", eTeam[CupTeamName]);
}

stock getTeamLabel(index) {
	static szLabel[64];
	getTeamName(index, szLabel, charsmax(szLabel));
	return szLabel;
}

stock getCaptainNameLabel(slot) {
	static szLabel[64];
	if (g_iVetoCaptains[slot] <= 0 || !is_user_connected(g_iVetoCaptains[slot])) {
		formatex(szLabel, charsmax(szLabel), "не выбран");
	} else {
		formatex(szLabel, charsmax(szLabel), "%n", g_iVetoCaptains[slot]);
	}
	return szLabel;
}

stock getRemainingMaps() {
	new count;
	for (new i; i < g_iMapCount; i++) {
		if (!g_bMapBanned[i] && !g_bMapPicked[i])
			count++;
	}
	return count;
}

stock announceRemainingMaps() {
	new remaining = getRemainingMaps();
	if (remaining <= 0)
		return;

	new szBuffer[256], pos;
	new szConsole[256], posConsole;
	for (new i; i < g_iMapCount; i++) {
		if (g_bMapBanned[i] || g_bMapPicked[i])
			continue;

		new szMap[MAP_NAME_LEN];
		ArrayGetString(g_aCupMaps, i, szMap, charsmax(szMap));

		if (pos > 0)
			pos += formatex(szBuffer[pos], charsmax(szBuffer) - pos, ", ");

		pos += formatex(szBuffer[pos], charsmax(szBuffer) - pos, "%s", szMap);

		if (posConsole > 0)
			posConsole += formatex(szConsole[posConsole], charsmax(szConsole) - posConsole, ", ");
		posConsole += formatex(szConsole[posConsole], charsmax(szConsole) - posConsole, "%s", szMap);
	}

	client_print_color(0, print_team_blue, "%s Осталось карт: ^3%s^1", g_szPrefix, szBuffer);
	server_print("[HNS-CUP] Remaining maps: %s", szConsole);
}

stock getLastRemainingMap() {
	for (new i; i < g_iMapCount; i++) {
		if (!g_bMapBanned[i] && !g_bMapPicked[i])
			return i;
	}
	return -1;
}

stock bool:extractSectionName(const szLine[], szOut[], len) {
	if (szLine[0] != '[')
		return false;

	new iClose = contain(szLine, "]");
	if (iClose == -1 || iClose <= 1)
		return false;

	new iCopy = iClose - 1;
	if (iCopy < 0)
		iCopy = 0;
	else if (iCopy > len - 1)
		iCopy = len - 1;

	copy(szOut, len, szLine[1]);
	szOut[iCopy] = EOS;
	trim(szOut);

	return true;
}

stock bool:parsePlayerLine(const szLine[], szAuth[], authLen, szNick[], nickLen) {
	new szLocal[192];
	copy(szLocal, charsmax(szLocal), szLine);

	new iPos = contain(szLocal, " ");
	if (iPos == -1)
		return false;

	copy(szAuth, authLen, szLocal);
	szAuth[iPos] = EOS;
	trim(szAuth);

	if (!szAuth[0])
		return false;

	copy(szNick, nickLen, szLocal[iPos + 1]);
	trim(szNick);

	if (!szNick[0])
		formatex(szNick, nickLen, "player");

	strtolower(szAuth);
	return true;
}

stock bool:hns_is_knife_map() {
	if (hnsmatch_maps_init()) {
		return hnsmatch_maps_is_knife();
	}

	return false;
}
