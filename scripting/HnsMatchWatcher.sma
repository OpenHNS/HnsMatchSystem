#include <amxmodx>
#include <amxmisc>
#include <hns_matchsystem>

#include <hns_matchsystem_filter>
#include <hns_matchsystem_cup>

#define RATIO 0.66

new const g_szFileName[] = "watcher.ini";

new g_sPrefix[24];

enum _:WATCHER {
	w_iId,
	w_szSteamId[64]
}

new g_eWatcher[WATCHER];

enum _:RNW {
	bool:r_bIsVote,
	bool:r_bPlayerVote[MAX_PLAYERS + 1],
	r_iNeedVote,
	r_iVotes[MAX_PLAYERS + 1]
}

new g_eRnw[RNW];

public plugin_natives() {
	set_native_filter("match_system_additons");
}

public plugin_init() {
	register_plugin("Match: Watcher", "1.2", "OpenHNS"); // Garey

	RegisterSayCmd("rnw", "rocknewwatcher", "cmdRnw", 0, "Rock new watchers");
	RegisterSayCmd("unrnw", "nornw", "cmdUnRnw", 0, "Cancel vote new watchers");
	RegisterSayCmd("watcher", "wt", "WatcherMenu", hns_get_flag_watcher(), "Watcher menu");

	register_dictionary("match_additons.txt");

	LoadWatcher();
}

public plugin_cfg() {
	hns_get_prefix(g_sPrefix, charsmax(g_sPrefix));
}

public client_putinserver(id) {
	g_eRnw[r_iVotes][id] = 0;
	g_eRnw[r_bPlayerVote][id] = false;

	new szAuthID[64]; get_user_authid(id, szAuthID, charsmax(szAuthID));
	if(equal(g_eWatcher[w_szSteamId], szAuthID)) {
		ActivateWatcher(id);
	}
}

public client_disconnected(id) {
	if(g_eRnw[r_bPlayerVote][id]) {
		g_eRnw[r_bPlayerVote][id] = false;
		g_eRnw[r_iNeedVote]--;
	}

	if(id == g_eWatcher[w_iId]) {
		g_eWatcher[w_iId] = 0;
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER , "WTR_LEAVE", g_sPrefix, id);
	}
}

public WatcherMenu(id) {
	if (!is_user_connected(id) || !isUserWatcher(id))
		return;

	static szMsg[128];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_MANAGMENT");
	new hMenu = menu_create(szMsg, "codeWatcherMenu");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU");
	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_TRANSFER");
	menu_additem(hMenu, szMsg, "2");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_CHANGEMAP");
	menu_additem(hMenu, szMsg, "3");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_KILLPLAYERS");
	menu_additem(hMenu, szMsg, "4");

	if (isUserFullWatcher(id)) {
		formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_KICKMENU");
	} else {
		formatex(szMsg, charsmax(szMsg), "\d%L", LANG_PLAYER, "WTR_MENU_KICKMENU");
	}

	menu_additem(hMenu, szMsg, "5");

	if (isUserFullWatcher(id)) {
		formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_MIXBANMENUS");
	} else {
		formatex(szMsg, charsmax(szMsg), "\d%L", LANG_PLAYER, "WTR_MENU_NOT_MIXBANMENUS");
	}

	menu_additem(hMenu, szMsg, "6");

	// if (isUserFullWatcher(id)) {
	// 	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_BLACKLIST");
	// } else {
	// 	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_NOT_BLACKLIST");
	// }
	// menu_additem(hMenu, szMsg, "5");

	menu_display(id, hMenu, 0);
}

public codeWatcherMenu(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}
	
	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);
	
	new iKey = str_to_num(szData);

	switch(iKey) {
		case 1: {
			ManagementWatcherMenu(id);
		}
		case 2: {
			client_cmd(id, "amx_teammenu");
		}
		case 3: {
			client_cmd(id, "amx_mapmenu");
		}
		case 4: {
			client_cmd(id, "amx_slapmenu");
		}
		case 5: {
			if (isUserFullWatcher(id)) {
				client_cmd(id, "amx_kickmenu");
			} else {
				WatcherMenu(id);
			}
		}
		case 6: {
			if (isUserFullWatcher(id)) {
				client_cmd(id, "hns_bans_menu");
			} else {
				WatcherMenu(id);
			}
		}
		// case 5: {
		// 	if (get_user_flags(id) & FULL_ACCESS) {
		// 		//client_cmd(id, ""); // Вызов блэклист меню
		// 	} else {
		// 		WatcherMenu(id);
		// 	}
		// }
	}
	
	return PLUGIN_HANDLED;
}

public ManagementWatcherMenu(id) {
	if (!is_user_connected(id) || !isUserWatcher(id))
		return;

	static szMsg[128];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_MANAGMENT");
	new hMenu = menu_create(szMsg, "codeManagementWatcherMenu");

	if (isUserFullWatcher(id)) {
		formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_DEL");
	} else {
		formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_NOT_DEL");
	}

	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_ADD");
	menu_additem(hMenu, szMsg, "2");

	menu_display(id, hMenu, 0);
}

public codeManagementWatcherMenu(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);
	
	new iKey = str_to_num(szData);

	switch (iKey) {
		case 1: {
			if(is_user_connected(g_eWatcher[w_iId])) {
				remove_user_flags(g_eWatcher[w_iId], hns_get_flag_watcher());
				client_print_color(0, print_team_red, "%L", LANG_PLAYER, "WTR_DELETE", g_sPrefix, id, g_eWatcher[w_iId]);
				g_eWatcher[w_szSteamId] = "";
				g_eWatcher[w_iId] = 0;
			} else {
				if(strlen(g_eWatcher[w_szSteamId])) {
					client_print_color(0, print_team_red, "%L", LANG_PLAYER, "WTR_DELETE_STEAM", g_sPrefix, id, g_eWatcher[w_szSteamId]);
					g_eWatcher[w_szSteamId] = "";
				}
			}
		}
		case 2: {
			ChooseNewWatcherMenu(id);
		}
	}

	return PLUGIN_HANDLED;
}

public ChooseNewWatcherMenu(id) {
	static szMsg[128];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_NEW");
	new hMenu = menu_create(szMsg, "codeChooseNewWatcherMenu");
	
	new iPlayers[MAX_PLAYERS], iNum, iTempID;
	
	new szName[MAX_PLAYERS], szUserId[MAX_PLAYERS];
	get_players(iPlayers, iNum);
	
	for (new i; i < iNum; i++) {
		iTempID = iPlayers[i];
		
		get_user_name(iTempID, szName, charsmax(szName));
		formatex(szUserId, charsmax(szUserId), "%d", get_user_userid(iTempID));
		
		if(!(get_user_flags(iTempID) & hns_get_flag_fullwatcher()))
			menu_additem(hMenu, szName, szUserId, 0);
	}
	
	menu_display(id, hMenu, 0);
}

public codeChooseNewWatcherMenu(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}
	
	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);
	
	new iUserID = str_to_num(szData);
	
	new iPlayer = find_player("k", iUserID);
	
	if (iPlayer) {
		MakeWatcher(id,  iPlayer);
	}

	return PLUGIN_HANDLED;
}

public MakeWatcher(maker, id) {
	if(!is_user_connected(id)) {
		client_print_color(maker, print_team_blue, "%L", maker, "WTR_PLR_DISC", g_sPrefix)
		
		return PLUGIN_HANDLED;
	}
	
	if(is_user_connected(g_eWatcher[w_iId]))
		remove_user_flags(g_eWatcher[w_iId], hns_get_flag_watcher());
	
	ActivateWatcher(id);
	client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "WTR_CHOOSE_NEW", g_sPrefix, maker, id);
	
	return PLUGIN_HANDLED;
}

public ActivateWatcher(id) {
	get_user_authid(id, g_eWatcher[w_szSteamId], charsmax(g_eWatcher[w_szSteamId]));
	g_eWatcher[w_iId] = id;
	
	set_user_flags(id, hns_get_flag_watcher());
	
	return PLUGIN_CONTINUE;
}

public cmdRnw(id) {
	if (hns_cup_enabled()) {
		client_print_color(id, print_team_blue, "%L", LANG_PLAYER, "CUP_NOT", g_sPrefix);
		return PLUGIN_CONTINUE;
	}

	new iPlayers = get_playersnum();
	
	if(iPlayers <= 1) {
		client_print_color(id, print_team_blue, "%L", id, "WTR_NOT_NEED", g_sPrefix);
		
		return PLUGIN_CONTINUE;
	}

	new iNeedVote;

	if(g_eRnw[r_bPlayerVote][id]) {
		iNeedVote = floatround((iPlayers * RATIO) - g_eRnw[r_iNeedVote]);
		client_print_color(id, print_team_blue, "%L", id, "WTR_ALR_VOTE", g_sPrefix, iNeedVote);
		
		return PLUGIN_CONTINUE
	}
	
	g_eRnw[r_bPlayerVote][id] = true;
	g_eRnw[r_iNeedVote]++;
	
	iNeedVote = floatround((iPlayers * RATIO) - g_eRnw[r_iNeedVote])
	if(iNeedVote > 0) {
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "WTR_VOTE", g_sPrefix, id, iNeedVote);
	} else {	
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "WTR_START", g_sPrefix);
		StartVote();
	}
	
	return PLUGIN_CONTINUE;
}

public cmdUnRnw(id) {
	if (hns_cup_enabled()) {
		client_print_color(id, print_team_blue, "%L", LANG_PLAYER, "CUP_NOT", g_sPrefix);
		return PLUGIN_CONTINUE;
	}

	if(g_eRnw[r_bPlayerVote][id])
	{
		client_print_color(id, print_team_blue, "%L", id, "WTR_VOTE_CANCL", g_sPrefix);
		g_eRnw[r_bPlayerVote][id] = false;
		g_eRnw[r_iNeedVote]--;
	}

	return PLUGIN_CONTINUE;
}

public StartVote() {
	g_eRnw[r_bIsVote] = true;
	arrayset(g_eRnw[r_bPlayerVote], false, sizeof(g_eRnw[r_bPlayerVote]));
	g_eRnw[r_iNeedVote] = 0;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	
	for(new i = 1; i <= MaxClients; i++) {
		new id = iPlayers[i];

		if (!is_user_connected(id)) {
			continue;
		}

		voteWatcherMenu(id);
	}
	
	set_task(15.0, "check_votes");
}

public voteWatcherMenu(id) {
	static szMsg[128];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "WTR_MENU_CHOSE");
	new hMenu = menu_create(szMsg, "codeVoteWatcherMenu");
	
	new iPlayers[MAX_PLAYERS], iNum, iTempID;
	get_players(iPlayers, iNum, "ch");

	new szName[64], szUserId[MAX_PLAYERS];
	
	for (new i; i < iNum; i++) {
		iTempID = iPlayers[i];
		
		format(szName, charsmax(szName), "%n [%d]", iTempID, g_eRnw[r_iVotes][iTempID]);
		formatex(szUserId, charsmax(szUserId), "%d", get_user_userid(iTempID));
		
		menu_additem(hMenu, szName, szUserId, 0);
	}
	
	menu_display(id, hMenu, 0);
}

public codeVoteWatcherMenu(id, hMenu, item) {
	if(!g_eRnw[r_bIsVote]) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}
	
	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);
	
	new iUserID = str_to_num(szData);
	
	new iPlayer = find_player("k", iUserID);
	
	if (iPlayer) {
		g_eRnw[r_iVotes][iPlayer]++;
		
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "WTR_VOTE_CHOOSE", g_sPrefix, id, iPlayer, g_eRnw[r_iVotes][iPlayer]);
	} else {
		client_print_color(id, print_team_blue, "%L", id, "WTR_VOTE_DISC", g_sPrefix);	
		voteWatcherMenu(id);
	}

	return PLUGIN_HANDLED;
}

public check_votes() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum);

	new iCandiates[MAX_PLAYERS], cnum;
	
	new iMaxVotes = g_eRnw[r_iVotes][iPlayers[0]];
	new iNewWatcher = iPlayers[0];

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if(g_eRnw[r_iVotes][id] > iMaxVotes) {
			iNewWatcher = id;
			iMaxVotes = g_eRnw[r_iVotes][id];
		}
	}
	
	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if(g_eRnw[r_iVotes][id] == iMaxVotes) {
			iCandiates[cnum++] = id;
		}
	}

	if(cnum > 1) {
		iNewWatcher = iCandiates[random_num(1, cnum)];
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "WTR_NEW_RANDOM", g_sPrefix, iNewWatcher, cnum);
	} else {	
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "WTR_NEW", g_sPrefix, iNewWatcher, iMaxVotes);
	}
	
	ActivateWatcher(iNewWatcher);
	g_eRnw[r_bIsVote] = false;
	arrayset(g_eRnw[r_iVotes], 0, sizeof(g_eRnw[r_iVotes]));
}

public plugin_end() {
	SaveWatcher();
}

public LoadWatcher() {
	new szDatadDr[128];
	get_datadir(szDatadDr, charsmax(szDatadDr));

	format(szDatadDr, charsmax(szDatadDr), "%s/%s",szDatadDr, g_szFileName);
	
	if(file_exists(szDatadDr)) {
		new iFile = fopen(szDatadDr, "r");

		fgets(iFile, g_eWatcher[w_szSteamId], charsmax(g_eWatcher[w_szSteamId]));

		fclose(iFile);
	}
}

public SaveWatcher() {
	new szDatadDr[128];
	get_datadir(szDatadDr, charsmax(szDatadDr));

	format(szDatadDr, charsmax(szDatadDr), "%s/%s",szDatadDr, g_szFileName);
	
	if(file_exists(szDatadDr)) {
		delete_file(szDatadDr);
	}

	new iFile = fopen(szDatadDr, "w");
	
	if(strlen(g_eWatcher[w_szSteamId])) {
		fputs(iFile, g_eWatcher[w_szSteamId]);
	}

	fclose(iFile);	
}