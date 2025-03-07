#include <amxmodx>
#include <reapi>
#include <sqlx>
#include <hns_matchsystem>
#include <hns_matchsystem_sql>

#define SQL_CREATE_TABLE \
"CREATE TABLE IF NOT EXISTS `%s` \
( \
	`id`				INT(11) NOT NULL auto_increment PRIMARY KEY, \
	`player_name`		VARCHAR(32) NULL DEFAULT NULL, \
	`player_steamid`	VARCHAR(24) NOT NULL, \
	`player_ip`			VARCHAR(16) NULL DEFAULT NULL, \
	`admin_name`		VARCHAR(32) NULL DEFAULT NULL, \
	`admin_steamid`		VARCHAR(24) NOT NULL, \
	`admin_ip`			VARCHAR(16) NULL DEFAULT NULL, \
	`expired`			TIMESTAMP NULL DEFAULT NULL \
);"

#define SQL_ADD_SEC \
"NOW() + INTERVAL %d SECOND"

#define SQL_SET_BAN_PLAYER \
"INSERT INTO `%s` \
( \
	player_name, \
	player_steamid, \
	player_ip, \
	admin_name, \
	admin_steamid, \
	admin_ip, \
	expired \
) \
VALUES \
( \
	'%s', \
	'%s', \
	'%s', \
	'%s', \
	'%s', \
	'%s', \
	%s \
);"

#define SQL_SET_OFFBAN_PLAYER \
"INSERT INTO `%s` \
( \
	player_name, \
	player_steamid, \
	player_ip, \
	admin_name, \
	admin_steamid, \
	admin_ip, \
	expired \
) \
VALUES \
( \
	'%s', \
	'%s', \
	'%s', \
	'%s', \
	'%s', \
	'%s', \
	%s \
);"

#define SQL_SET_UNBAN_PLAYER \
"DELETE FROM `%s` \
	WHERE `player_steamid` = '%s';"

#define SQL_LOAD_PLAYER \
"SELECT `admin_name`, \
		`admin_steamid`, \
		`expired`, \
		Unix_timestamp(expired) AS expired_date_unix \
FROM `%s` \
WHERE `player_steamid` = '%s' AND (`expired` > now() OR `expired` IS NULL);"

#define SQL_GET_BANNED \
"SELECT	`player_name`, \
		`player_steamid`, \
		`player_ip`, \
		`admin_name`, \
		`admin_steamid`, \
		`expired` \
FROM `%s` \
WHERE `expired` > now() OR `expired` IS NULL"

#define BAN_TASK 22100

new bool:g_bDebugMode;

new const g_szTable[] = "hns_bans";

enum _: BAN_TIME_DATA {
	TIME_NAME[24], TIME_SECONDS
};

new const g_eBanTime[][BAN_TIME_DATA] = {
	{"5 minutes", 300},
	{"3 hours", 10800},
	{"1 day", 86400},
	{"3 days", 259200},
	{"5 days", 432000}
};

enum _: SQL {
	SQL_TABLE,
	SQL_BAN_PLAYER,
	SQL_OFFBAN_PLAYER,
	SQL_UNBAN_PLAYER,
	SQL_LOAD,
	SQL_BANNED_PLAYERS
};

new Handle:g_hSqlTuple;

enum _: BAN_DATA {
	bool:IS_OFFBAN,
	BAN_PAYER,
	BAN_TIME
};

new g_eBanData[MAX_PLAYERS + 1][BAN_DATA];

enum _: PLAYER_DATA{
	bool:IS_BANNED,
	PLAYER_NAME[MAX_NAME_LENGTH],
	PLAYER_STEAM[24],
	PLAYER_IP[16],
	ADMIN_NAME[MAX_NAME_LENGTH],
	ADMIN_STEAM[24],
	DATE_EXPIRED[32],
	TIME_EXPIRED
};
new g_ePlayerInfo[MAX_PLAYERS + 1][PLAYER_DATA];
new g_eBanPlayer[MAX_PLAYERS + 1][PLAYER_DATA];

enum _: DISC_PLAYERS {
	DISC_PLAYERS_NAME[MAX_NAME_LENGTH],
	DISC_PLAYERS_STEAM[24],
	DISC_PLAYERS_IP[16]
};

new Array:g_aDisconnectedPlayers;
new Array:g_aBannedPlayers;

new g_sPrefix[24];
new g_hBanForwards;
new g_hBanForwardsInit;

public plugin_init() {
	register_plugin("Match: Bans", "1.1", "OpenHNS");

	register_clcmd("hns_banmenu", "HnsBanMenu");
	register_clcmd("hns_bans_menu", "HnsBansMenu");
	register_clcmd("hns_offbanmenu", "HnsOffBanMenu");
	register_clcmd("hns_unbanmenu", "HnsUnbanMenu");

	RegisterHookChain(RH_SV_DropClient, "rgDropClient", false);

	g_aDisconnectedPlayers = ArrayCreate(DISC_PLAYERS);
	g_aBannedPlayers = ArrayCreate(PLAYER_DATA);

	g_hBanForwards = CreateMultiForward("hns_player_banned", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL);
	g_hBanForwardsInit = CreateMultiForward("hns_banned_init", ET_CONTINUE);

	set_task(1.0, "BanCheckSecond", BAN_TASK, .flags="b");

	g_bDebugMode = bool:(plugin_flags() & AMX_FLAG_DEBUG);
}

public plugin_cfg() {
	hns_get_prefix(g_sPrefix, charsmax(g_sPrefix));
}

public plugin_end() {
	ArrayDestroy(g_aDisconnectedPlayers);
	ArrayDestroy(g_aBannedPlayers);
}

public client_putinserver(id) {
	ExecuteForward(g_hBanForwardsInit);
	
	SQL_Load(id);

	new szAuth[24];
	get_user_authid(id, szAuth, charsmax(szAuth));
	new index = FindDisconnectedAuthIndex(szAuth);

	if (index == -1) {
		return;
	}

	ArrayDeleteItem(g_aDisconnectedPlayers, index);
}

public rgDropClient(const id, bool:crash) {
	if (g_ePlayerInfo[id][IS_BANNED]) {
		return;
	}

	new TempPlayer[DISC_PLAYERS];

	get_user_name(id, TempPlayer[DISC_PLAYERS_NAME], charsmax(TempPlayer[DISC_PLAYERS_NAME]));
	get_user_authid(id, TempPlayer[DISC_PLAYERS_STEAM], charsmax(TempPlayer[DISC_PLAYERS_STEAM]));
	get_user_ip(id, TempPlayer[DISC_PLAYERS_IP], charsmax(TempPlayer[DISC_PLAYERS_IP]), true);

	ArrayPushArray(g_aDisconnectedPlayers, TempPlayer);
}

/* SQL queries */

public hns_sql_connection(Handle:hSqlTuple) {
	g_hSqlTuple = hSqlTuple;

	new cData[1];
	cData[0] = SQL_TABLE;
	
	new szQuery[1024];
	formatex(szQuery, charsmax(szQuery), SQL_CREATE_TABLE, g_szTable);

	if (g_bDebugMode) server_print("MATCHBAN [SQL 1] %s", szQuery)
	
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
	SQL_BannedPlayers();
}

public SQL_BanPlayer(admin_id, player_id) {
	new szAdminName[MAX_NAME_LENGTH];
	SQL_QuoteString(Empty_Handle, szAdminName, charsmax(szAdminName), fmt("%n", admin_id));
	SQL_QuoteString(Empty_Handle, g_eBanPlayer[admin_id][PLAYER_NAME], charsmax(g_eBanPlayer[][PLAYER_NAME]), fmt("%n", player_id));
	
	new szAdminAuth[24];
	get_user_authid(admin_id, szAdminAuth, charsmax(szAdminAuth));
	get_user_authid(player_id, g_eBanPlayer[admin_id][PLAYER_STEAM], charsmax(g_eBanPlayer[][PLAYER_STEAM]));

	new szAdminIp[16];
	get_user_ip(admin_id, szAdminIp, charsmax(szAdminIp), true);
	get_user_ip(player_id, g_eBanPlayer[admin_id][PLAYER_IP], charsmax(g_eBanPlayer[][PLAYER_IP]), true);

	new szTime[64];
	if (g_eBanData[admin_id][BAN_TIME]) {
		formatex(szTime, charsmax(szTime), SQL_ADD_SEC, g_eBanData[admin_id][BAN_TIME]);
	}

	new cData[3];
	cData[0] = SQL_BAN_PLAYER,
	cData[1] = admin_id, 
	cData[2] = player_id;
	
	new szQuery[512];
	formatex(szQuery, charsmax(szQuery), SQL_SET_BAN_PLAYER, g_szTable, 
	g_eBanPlayer[admin_id][PLAYER_NAME], 
	g_eBanPlayer[admin_id][PLAYER_STEAM], 
	g_eBanPlayer[admin_id][PLAYER_IP], 
	szAdminName, 
	szAdminAuth, 
	szAdminIp, 
	g_eBanData[admin_id][BAN_TIME] ? szTime : "NULL");

	if (g_bDebugMode) server_print("MATCHBAN [SQL 2]")
	if (g_bDebugMode) server_print("%s", szQuery)
	
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_Offban(admin_id, player_name[], player_steamid[], player_ip[]) {
	new szPlayerName[MAX_NAME_LENGTH];
	SQL_QuoteString(Empty_Handle, szPlayerName, charsmax(szPlayerName), fmt("%s", player_name));

	new szAdminName[MAX_NAME_LENGTH];
	SQL_QuoteString(Empty_Handle, szAdminName, charsmax(szAdminName), fmt("%n", admin_id));

	new szAdminAuth[24];
	get_user_authid(admin_id, szAdminAuth, charsmax(szAdminAuth));

	new szAdminIp[16];
	get_user_ip(admin_id, szAdminIp, charsmax(szAdminIp), true);

	new szTime[64];
	if (g_eBanData[admin_id][BAN_TIME])
		formatex(szTime, charsmax(szTime), SQL_ADD_SEC, g_eBanData[admin_id][BAN_TIME]);

	new szQuery[512];
	formatex(szQuery, charsmax(szQuery), SQL_SET_OFFBAN_PLAYER, g_szTable, 
	szPlayerName, 
	player_steamid, 
	player_ip, 
	szAdminName, 
	szAdminAuth, 
	szAdminIp, 
	g_eBanData[admin_id][BAN_TIME] ? szTime : "NULL");

	new cData[2];
	cData[0] = SQL_OFFBAN_PLAYER;
	cData[1] = admin_id;

	if (g_bDebugMode) server_print("MATCHBAN [SQL 3] %s", szQuery)
	
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_UnbanPlayer(admin_id, player_steamid[]) {
	new szQuery[256];
	formatex(szQuery, charsmax(szQuery), SQL_SET_UNBAN_PLAYER, g_szTable, player_steamid);
	
	new cData[2];
	cData[0] = SQL_UNBAN_PLAYER, 
	cData[1] = admin_id;

	if (g_bDebugMode) server_print("MATCHBAN [SQL 4] %s", szQuery)

	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_Load(id) {
	new szAuth[24];
	get_user_authid(id, szAuth, charsmax(szAuth));

	new szQuery[512];
	formatex(szQuery, charsmax(szQuery), SQL_LOAD_PLAYER, g_szTable, szAuth);

	new cData[2];
	cData[0] = SQL_LOAD;
	cData[1] = id;

	if (g_bDebugMode) server_print("MATCHBAN [SQL 5] %s", szQuery)

	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_BannedPlayers() {
	new szQuery[512];
	formatex(szQuery, charsmax(szQuery), SQL_GET_BANNED, g_szTable);

	new cData[1] = SQL_BANNED_PLAYERS;

	if (g_bDebugMode) server_print("MATCHBAN [SQL 6] %s", szQuery)

	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public QueryHandler(iFailState, Handle:hQuery, szError[], iErrnum, cData[], iSize, Float:fQueueTime) {
	if (iFailState != TQUERY_SUCCESS) {
		log_amx("SQL Error #%d - %s", iErrnum, szError);
		return;
	}

	switch (cData[0]) {
		case SQL_TABLE: {}
		case SQL_BAN_PLAYER: {
			new admin_id = cData[1];
			new player_id = cData[2];

			if (!is_user_connected(admin_id) || !is_user_connected(player_id))
				return;

			SQL_Load(player_id);

			if (g_eBanData[admin_id][BAN_TIME])
				client_print_color(0, print_team_blue, "%L", LANG_PLAYER , "BAN_PLAYER", g_sPrefix, admin_id, player_id, secondsToDHM(g_eBanData[admin_id][BAN_TIME]));
			else
				client_print_color(0, print_team_blue, "%L", LANG_PLAYER , "BAN_PLAYER_PERM", g_sPrefix, admin_id, player_id);

			ArrayClear(g_aBannedPlayers);

			SQL_BannedPlayers();

			if (g_bDebugMode) server_print("QueryHandler [SQL_BAN_PLAYER] %n", admin_id)
			if (g_bDebugMode) server_print("QueryHandler [SQL_BAN_PLAYER] %n", player_id)

			arrayset(g_eBanData[admin_id], 0, BAN_DATA);
			arrayset(g_eBanPlayer[admin_id], 0, BAN_DATA);
		}
		case SQL_OFFBAN_PLAYER: {
			new admin_id = cData[1];

			if (!is_user_connected(admin_id))
				return;

			new index = FindDisconnectedAuthIndex(g_eBanPlayer[admin_id][PLAYER_STEAM]);

			if (index != -1)
				ArrayDeleteItem(g_aDisconnectedPlayers, index);

			new found_id = find_player("c", g_eBanPlayer[admin_id][PLAYER_STEAM]);

			if (found_id)
				SQL_Load(found_id);

			if (g_eBanData[admin_id][BAN_TIME])
				client_print_color(0, print_team_blue, "%L", LANG_PLAYER , "BAN_PLAYER_OFF", g_sPrefix, admin_id, g_eBanPlayer[admin_id][PLAYER_NAME], secondsToDHM(g_eBanData[admin_id][BAN_TIME]));
			else
				client_print_color(0, print_team_blue, "%L", LANG_PLAYER , "BAN_PLAYER_PERM_OFF", g_sPrefix, admin_id, g_eBanPlayer[admin_id][PLAYER_NAME]);

			ArrayClear(g_aBannedPlayers);

			SQL_BannedPlayers();

			arrayset(g_eBanData[admin_id], 0, BAN_DATA);
			arrayset(g_eBanPlayer[admin_id], 0, BAN_DATA);
		}
		case SQL_UNBAN_PLAYER: {
			new admin_id = cData[1];

			if (!is_user_connected(admin_id))
				return;

			new index = FindBannedAuthIndex(g_eBanPlayer[admin_id][PLAYER_STEAM]);

			if (index != -1)
				ArrayDeleteItem(g_aBannedPlayers, index);

			new found_id = find_player("c", g_eBanPlayer[admin_id][PLAYER_STEAM]);

			if (found_id)
				SQL_Load(found_id);
			else {
				new TempPlayer[DISC_PLAYERS];
				copy(TempPlayer[DISC_PLAYERS_NAME], charsmax(TempPlayer[DISC_PLAYERS_NAME]), g_eBanPlayer[admin_id][PLAYER_NAME]);
				copy(TempPlayer[DISC_PLAYERS_STEAM], charsmax(TempPlayer[DISC_PLAYERS_STEAM]), g_eBanPlayer[admin_id][PLAYER_STEAM]);
				copy(TempPlayer[DISC_PLAYERS_IP], charsmax(TempPlayer[DISC_PLAYERS_IP]), g_eBanPlayer[admin_id][PLAYER_IP]);

				ArrayPushArray(g_aDisconnectedPlayers, TempPlayer);
			}

			client_print_color(0, print_team_blue, "%L", LANG_PLAYER , "UNBAN_PLAYER", g_sPrefix, admin_id, g_eBanPlayer[admin_id][PLAYER_NAME]);

			arrayset(g_eBanPlayer[admin_id], 0, BAN_DATA);
		}
		case SQL_LOAD: {
			new id = cData[1];

			if (!is_user_connected(id))
				return;

			if (SQL_NumResults(hQuery)) {
				g_ePlayerInfo[id][IS_BANNED] = true;
				SQL_ReadResult(hQuery, 0, g_ePlayerInfo[id][ADMIN_NAME], charsmax(g_ePlayerInfo[][ADMIN_NAME]));
				SQL_ReadResult(hQuery, 1, g_ePlayerInfo[id][ADMIN_STEAM], charsmax(g_ePlayerInfo[][ADMIN_STEAM]));

				new ban_expired = SQL_ReadResult(hQuery, 2);

				static szMsg[128];
				formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_DATE_EXPIRED_P");

				if (!ban_expired)
					copy(g_ePlayerInfo[id][DATE_EXPIRED], charsmax(g_ePlayerInfo[][DATE_EXPIRED]), szMsg);
				else
					SQL_ReadResult(hQuery, 2, g_ePlayerInfo[id][DATE_EXPIRED], charsmax(g_ePlayerInfo[][DATE_EXPIRED]));

				g_ePlayerInfo[id][TIME_EXPIRED] = SQL_ReadResult(hQuery, 3);

				Task_ShowHud(id)

				ExecuteForward(g_hBanForwards, _, id, g_ePlayerInfo[id][IS_BANNED], g_ePlayerInfo[id][TIME_EXPIRED]);
			} else {
				new szAuth[24];
				get_user_authid(id, szAuth, charsmax(szAuth));
				new index = FindBannedAuthIndex(szAuth);

				if (index != -1)
					ArrayDeleteItem(g_aBannedPlayers, index);

				arrayset(g_ePlayerInfo[id], 0, PLAYER_DATA);
			}
		}
		case SQL_BANNED_PLAYERS: {
			new TempPlayer[PLAYER_DATA];
			while (SQL_MoreResults(hQuery)) {
				SQL_ReadResult(hQuery, 0, TempPlayer[PLAYER_NAME], charsmax(TempPlayer[PLAYER_NAME]));
				SQL_ReadResult(hQuery, 1, TempPlayer[PLAYER_STEAM], charsmax(TempPlayer[PLAYER_STEAM]));
				SQL_ReadResult(hQuery, 2, TempPlayer[PLAYER_IP], charsmax(TempPlayer[PLAYER_IP]));
				SQL_ReadResult(hQuery, 3, TempPlayer[ADMIN_NAME], charsmax(TempPlayer[ADMIN_NAME]));
				SQL_ReadResult(hQuery, 4, TempPlayer[ADMIN_STEAM], charsmax(TempPlayer[ADMIN_STEAM]));
				SQL_ReadResult(hQuery, 5, TempPlayer[DATE_EXPIRED], charsmax(TempPlayer[DATE_EXPIRED]));

				ArrayPushArray(g_aBannedPlayers, TempPlayer);
				SQL_NextRow(hQuery);
			}
		}
	}
}

public BanCheckSecond() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		
		if (!g_ePlayerInfo[id][IS_BANNED]) {
			continue;
		}

		if (g_ePlayerInfo[id][TIME_EXPIRED] && get_systime() >= g_ePlayerInfo[id][TIME_EXPIRED]) {
			new szAuth[24];
			get_user_authid(id, szAuth, charsmax(szAuth));
			new index = FindBannedAuthIndex(szAuth);

			if (index != -1) {
				ArrayDeleteItem(g_aBannedPlayers, index);
			}

			arrayset(g_ePlayerInfo[id], 0, PLAYER_DATA);

			ExecuteForward(g_hBanForwards, _, id, false, 0);
			
			client_print_color(0, print_team_blue, "%L", LANG_PLAYER , "BAN_EXPIRED", g_sPrefix, id);
		}
	}
}

public Task_ShowHud(id) {
	if (!g_ePlayerInfo[id][IS_BANNED]) {
		return;
	}

	static szMsg[128];
	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_INFO", g_ePlayerInfo[id][ADMIN_NAME], g_ePlayerInfo[id][ADMIN_STEAM], g_ePlayerInfo[id][DATE_EXPIRED]);

	set_dhudmessage(250, 255, 255, -1.0, 0.3, 0, 0.0, 5.0, 0.1, 0.1);
	show_dhudmessage(id, szMsg);
}

/* SQL queries */

/* Menus */


public HnsBansMenu(id) {
	if (!is_user_connected(id) || !isUserFullWatcher(id))
		return;

	static szMsg[128];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_MAIN_MENU");
	new hMenu = menu_create(szMsg, "codeHnsBansMenu");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_MAIN_BAN");
	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_MAIN_OFFBAN");
	menu_additem(hMenu, szMsg, "2");

	new iSize = ArraySize(g_aBannedPlayers);

	if (!iSize || !g_aBannedPlayers) {
		formatex(szMsg, charsmax(szMsg), "\d%L", LANG_PLAYER, "BAN_MAIN_UNBAN");
	} else {
		formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_MAIN_UNBAN");
	}

	menu_additem(hMenu, szMsg, "3");

	menu_display(id, hMenu, 0);
}

public codeHnsBansMenu(id, hMenu, item) {
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
			HnsBanMenu(id, 0);
		}
		case 2: {
			HnsOffBanMenu(id, 0);
		}
		case 3: {
			new iSize = ArraySize(g_aBannedPlayers);

			if (!iSize || !g_aBannedPlayers) {
				HnsBansMenu(id);
			} else {
				HnsUnbanMenu(id, 0);
			}
		}
	}

	return PLUGIN_HANDLED;
}

public HnsBanMenu(id, page) {
	if (!is_user_connected(id) || !isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	static szMsg[128];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_BAN_MENU");
	
	new hMenu = menu_create(szMsg, "HnsBanHandler");

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];

		if (id == iPlayer && g_ePlayerInfo[id][IS_BANNED])
			continue;

		if (g_ePlayerInfo[iPlayer][IS_BANNED]) {
			continue;
		}

		new szPlayer[10]
		num_to_str(iPlayer, szPlayer, charsmax(szPlayer));
		
		menu_additem(hMenu, fmt("%n", iPlayer), szPlayer);
	}

	menu_display(id, hMenu, page);
	
	return PLUGIN_HANDLED;
}

public HnsBanHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);

	menu_destroy(hMenu);
	
	new iPlayer = str_to_num(szData);

	if (!is_user_connected(iPlayer)) {
		HnsBanMenu(id, item / 7);
		return PLUGIN_HANDLED;
	}

	if (g_ePlayerInfo[iPlayer][IS_BANNED]) {
		HnsBanMenu(id, item / 7);
		return PLUGIN_HANDLED;
	}

	g_eBanData[id][BAN_PAYER] = iPlayer;
	g_eBanData[id][IS_OFFBAN] = false;

	HnsTimeMenu(id);

	return PLUGIN_HANDLED;
}

public HnsOffBanMenu(id, page) {
	if (!is_user_connected(id) || !isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (!g_aDisconnectedPlayers) {
		return PLUGIN_HANDLED;
	}

	new TempPlayer[DISC_PLAYERS];
	new iSize = ArraySize(g_aDisconnectedPlayers);

	if (!iSize) {
		return PLUGIN_HANDLED;
	}

	static szMsg[128];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_OFFBAN_MENU");
	
	new hMenu = menu_create(szMsg, "HnsOffBanHandler");

	for (new i; i < iSize; i++) {
		ArrayGetArray(g_aDisconnectedPlayers, i, TempPlayer);

		menu_additem(hMenu, fmt("%s", TempPlayer[DISC_PLAYERS_NAME]));
	}

	menu_display(id, hMenu, page);

	return PLUGIN_HANDLED;
}

public HnsOffBanHandler(id, hMenu, item) {
	if (!g_aDisconnectedPlayers) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	menu_destroy(hMenu);

	ArrayGetArray(g_aDisconnectedPlayers, item, g_eBanPlayer[id]);

	g_eBanData[id][IS_OFFBAN] = true;

	HnsTimeMenu(id);

	return PLUGIN_HANDLED;
}

public HnsTimeMenu(id) {
	if (!is_user_connected(id) || !isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	static szMsg[128];

	if (g_eBanData[id][IS_OFFBAN]) {
		formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_TIME_MENU_S", g_eBanPlayer[id][PLAYER_NAME]);
	} else {
		formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_TIME_MENU_N", g_eBanData[id][BAN_PAYER]);
	}

	new hMenu = menu_create(szMsg, "HnsTimeHandler");

	for (new i; i < sizeof(g_eBanTime); i++)
		menu_additem(hMenu, fmt("%s", g_eBanTime[i][TIME_NAME]));

	menu_display(id, hMenu, 0);

	return PLUGIN_HANDLED;
}

public HnsTimeHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	menu_destroy(hMenu);

	g_eBanData[id][BAN_TIME] = g_eBanTime[item][TIME_SECONDS];

	if (g_eBanData[id][IS_OFFBAN]) {
		SQL_Offban(id, g_eBanPlayer[id][PLAYER_NAME], g_eBanPlayer[id][PLAYER_STEAM], g_eBanPlayer[id][PLAYER_IP]);
	} else {
		SQL_BanPlayer(id, g_eBanData[id][BAN_PAYER]);
	}

	return PLUGIN_HANDLED;
}

public HnsUnbanMenu(id, page) {
	if (!is_user_connected(id) || !isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (!g_aBannedPlayers) {
		return PLUGIN_HANDLED;
	}

	new iSize = ArraySize(g_aBannedPlayers);

	if (!iSize) {
		return PLUGIN_HANDLED;
	}

	static szMsg[128];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_UNBAN_MENU");
	
	new hMenu = menu_create(szMsg, "HnsUnbanHandler");

	new TempPlayer[PLAYER_DATA];
	for (new i; i < iSize; i++) {
		ArrayGetArray(g_aBannedPlayers, i, TempPlayer);
		menu_additem(hMenu, fmt("%s", TempPlayer[PLAYER_NAME]));
	}

	menu_display(id, hMenu, page);
	
	return PLUGIN_HANDLED;
}

public HnsUnbanHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	menu_destroy(hMenu);

	ArrayGetArray(g_aBannedPlayers, item, g_eBanPlayer[id]);

	HnsInfoBanMenu(id);

	return PLUGIN_HANDLED;
}

public HnsInfoBanMenu(id) {
	if (!is_user_connected(id) || !isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	new szExpired[32];
	
	if (g_eBanPlayer[id][DATE_EXPIRED]) {
		formatex(szExpired, charsmax(szExpired), "%s", g_eBanPlayer[id][DATE_EXPIRED]);
	} else {
		formatex(szExpired, charsmax(szExpired), "%L", LANG_PLAYER, "BAN_DATE_EXPIRED_P");
	}

	static szMsg[512];
	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "BAN_FULLINFO", g_eBanPlayer[id][PLAYER_NAME], g_eBanPlayer[id][PLAYER_STEAM], g_eBanPlayer[id][ADMIN_NAME], g_eBanPlayer[id][ADMIN_STEAM], szExpired);

	new hMenu = menu_create(szMsg, "HnsInfoBanHandler");

	menu_additem(hMenu, "Unban");

	menu_display(id, hMenu, 0);

	return PLUGIN_HANDLED;
}

public HnsInfoBanHandler(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	menu_destroy(hMenu);

	SQL_UnbanPlayer(id, g_eBanPlayer[id][PLAYER_STEAM]);

	new findID = find_player_by_steam(g_eBanPlayer[id][PLAYER_STEAM]);

	if (findID) {
		arrayset(g_ePlayerInfo[findID], 0, PLAYER_DATA);
		ExecuteForward(g_hBanForwards, _, findID, false, 0);
	}

	return PLUGIN_HANDLED;
}

/* Menus */

/* Stocks */

stock FindDisconnectedAuthIndex(szAuth[]) {
	new iSize = ArraySize(g_aDisconnectedPlayers);
	new TempPlayer[DISC_PLAYERS];

	for (new i; i < iSize; i++) {
		ArrayGetArray(g_aDisconnectedPlayers, i, TempPlayer);
		if (equal(szAuth, TempPlayer[DISC_PLAYERS_STEAM])) {
			return i;
		}
	}
	return -1;
}

stock FindBannedAuthIndex(szAuth[]) {
	new iSize = ArraySize(g_aBannedPlayers);
	new TempPlayer[PLAYER_DATA];

	for (new i; i < iSize; i++) {
		ArrayGetArray(g_aBannedPlayers, i, TempPlayer);
		if (equal(szAuth, TempPlayer[PLAYER_STEAM])) {
			return i;
		}
	}
	return -1;
}

public find_player_by_steam(const steam_id[]) {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum);

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];

		new szAuth[24];
		get_user_authid(id, szAuth, charsmax(szAuth));

		if (equal(szAuth, steam_id)) {
			return id;
		}
	}

	return 0;
}

stock secondsToDHM(time) {
	new szTime[32]
	if (time < 60) {
		formatex(szTime, charsmax(szTime), "%ds.", time)
	} else {
		new days = time / 86400
		new hours = (time - days * 86400) / 3600
		new minutes = ((time - days * 86400) - 3600 * hours) / 60
		new seconds = time % 60

		if (days) formatex(szTime, charsmax(szTime), "%dd.", days)
		if (hours) formatex(szTime, charsmax(szTime), "%s %dh.", szTime, hours)
		if (minutes) formatex(szTime, charsmax(szTime), "%s %dm.", szTime, minutes)
		if (seconds) formatex(szTime, charsmax(szTime), "%s %ds.", szTime, seconds)

		trim(szTime)
	}
	return szTime
}

/* Stocks */