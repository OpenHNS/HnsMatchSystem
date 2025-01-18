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


const ACCESS = ADMIN_LEVEL_A;

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

enum _: PlayerData_s {
	bool:banned,
	admin_name[MAX_NAME_LENGTH],
	admin_steamid[24],
	date_expired[32],
	time_expired
};

new g_ePlayerData[MAX_PLAYERS + 1][PlayerData_s];

enum _: BanData_s {
	bool:offban,
	ban_player,
	ban_time
};

new g_eBanData[MAX_PLAYERS + 1][BanData_s];

enum _: BanPlayer_s {
	ban_player_name[MAX_NAME_LENGTH],
	ban_player_steamid[24],
	ban_player_ip[16],
	ban_admin_name[MAX_NAME_LENGTH],
	ban_admin_steamid[24],
	ban_player_expired[32]
};

new g_eBanPlayer[MAX_PLAYERS + 1][BanPlayer_s];

enum _: DisconnectedPlayers_s {
	disconnected_player_name[MAX_NAME_LENGTH],
	disconnected_player_steamid[24],
	disconnected_player_ip[16]
};

new Array:g_aDisconnectedPlayers;

enum _: BannedPlayers_s {
	banned_player_name[MAX_NAME_LENGTH],
	banned_player_steamid[24],
	banned_player_ip[16],
	banned_admin_name[MAX_NAME_LENGTH],
	banned_admin_steamid[24],
	banned_player_expired[32]
};

new Array:g_aBannedPlayers;

new g_MsgSync;
new g_sPrefix[24];
new g_hBanForwards;
new g_hBanForwardsInit;

public plugin_init() {
	register_plugin("Mix: Bans", "DEV", "OpenHNS");
	RegisterForwards();
	RegisterCmds();

	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", true);
	RegisterHookChain(RH_SV_DropClient, "SV_DropClient_Pre", false);

	g_aDisconnectedPlayers = ArrayCreate(DisconnectedPlayers_s);
	g_aBannedPlayers = ArrayCreate(BannedPlayers_s);

	g_MsgSync = CreateHudSyncObj();
}

public plugin_cfg() {
	hns_get_prefix(g_sPrefix, charsmax(g_sPrefix));
}

public plugin_end() {
	ArrayDestroy(g_aDisconnectedPlayers);
	ArrayDestroy(g_aBannedPlayers);
}

public plugin_natives() {
	register_native("hns_get_player_banned", "native_get_player_banned");
	register_native("hns_get_player_expired_ban", "native_get_player_expired_ban");
}

public native_get_player_banned(amxx, params) {
	enum { id = 1 };
	return bool:g_ePlayerData[get_param(id)][banned];
}

public native_get_player_expired_ban(amxx, params) {
	enum { id = 1, expired, len };
	set_string(expired, g_ePlayerData[get_param(id)][date_expired], get_param(len));
	server_print(g_ePlayerData[get_param(id)][date_expired]);
}

public client_putinserver(id) {
	server_print("client_putinserver g_hBanForwardsInit")
	new deb = ExecuteForward(g_hBanForwardsInit, _);
	server_print("deb: %d", deb)
	SQL_Load(id);

	new szAuth[24];
	get_user_authid(id, szAuth, charsmax(szAuth));
	new index = FindDisconnectedAuthIndex(szAuth);

	if (index == -1)
		return;

	ArrayDeleteItem(g_aDisconnectedPlayers, index);
}

public SV_DropClient_Pre(const id, bool:crash) {
	if (g_ePlayerData[id][banned])
		return;

	new TempPlayer[DisconnectedPlayers_s];

	get_user_name(id, TempPlayer[disconnected_player_name], charsmax(TempPlayer[disconnected_player_name]));
	get_user_authid(id, TempPlayer[disconnected_player_steamid], charsmax(TempPlayer[disconnected_player_steamid]));
	get_user_ip(id, TempPlayer[disconnected_player_ip], charsmax(TempPlayer[disconnected_player_ip]), true);

	ArrayPushArray(g_aDisconnectedPlayers, TempPlayer);
}

public CSGameRules_RestartRound_Post() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];

		if (!g_ePlayerData[id][banned])
			return;

		if (g_ePlayerData[id][time_expired] && get_systime() >= g_ePlayerData[id][time_expired]) {
			new szAuth[24];
			get_user_authid(id, szAuth, charsmax(szAuth));
			new index = FindBannedAuthIndex(szAuth);

			if (index != -1)
				ArrayDeleteItem(g_aBannedPlayers, index);

			arrayset(g_ePlayerData[id], 0, PlayerData_s);
			client_print_color(0, print_team_blue, "%s Player ^3%n^1 has expired mix ban..", g_sPrefix, id);
		}
	}
}

public hns_sql_connection(Handle:hSqlTuple) {
	g_hSqlTuple = hSqlTuple;

	new szQuery[1024];
	new cData[1];
	cData[0] = SQL_TABLE;
	
	formatex(szQuery, charsmax(szQuery), SQL_CREATE_TABLE, g_szTable);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
	SQL_BannedPlayers();
}

public QueryHandler(iFailState, Handle:hQuery, szError[], iErrnum, cData[], iSize, Float:fQueueTime) {
	if (iFailState != TQUERY_SUCCESS) {
		log_amx("SQL Error #%d - %s", iErrnum, szError);
		return;
	}

	switch (cData[0]) {
		case SQL_TABLE: {}
		case SQL_BAN_PLAYER: {
			new admin_id = cData[1], player_id = cData[2];

			if (!is_user_connected(admin_id) || !is_user_connected(player_id))
				return;

			SQL_Load(player_id);

			if (g_eBanData[admin_id][ban_time])
				client_print_color(0, print_team_blue, "%s ^3%n^1 banned a player ^3%n^1 on mix. Expired: ^3%s", g_sPrefix, admin_id, player_id, secondsToDHM(g_eBanData[admin_id][ban_time]));
			else
				client_print_color(0, print_team_blue, "%s ^3%n^1 banned a player ^3%n^1 on mix. Expired: ^3Permanent", g_sPrefix, admin_id, player_id);

			ArrayClear(g_aBannedPlayers);
			SQL_BannedPlayers();

			arrayset(g_eBanData[admin_id], 0, BanData_s);
			arrayset(g_eBanPlayer[admin_id], 0, BanData_s);
		}
		case SQL_OFFBAN_PLAYER: {
			new admin_id = cData[1];

			if (!is_user_connected(admin_id))
				return;

			new index = FindDisconnectedAuthIndex(g_eBanPlayer[admin_id][ban_player_steamid]);

			if (index != -1)
				ArrayDeleteItem(g_aDisconnectedPlayers, index);

			new found_id = find_player("c", g_eBanPlayer[admin_id][ban_player_steamid]);

			if (found_id)
				SQL_Load(found_id);

			if (g_eBanData[admin_id][ban_time])
				client_print_color(0, print_team_blue, "%s ^3%n^1 banned a player ^3%s^1 on mix. Expired: ^3%s", g_sPrefix, admin_id, g_eBanPlayer[admin_id][ban_player_name], secondsToDHM(g_eBanData[admin_id][ban_time]));
			else
				client_print_color(0, print_team_blue, "%s ^3%n^1 banned a player ^3%s^1 on mix. Expired: ^3Permanent", g_sPrefix, admin_id, g_eBanPlayer[admin_id][ban_player_name]);

			ArrayClear(g_aBannedPlayers);
			SQL_BannedPlayers();

			arrayset(g_eBanData[admin_id], 0, BanData_s);
			arrayset(g_eBanPlayer[admin_id], 0, BanData_s);
		}
		case SQL_UNBAN_PLAYER: {
			new admin_id = cData[1];

			if (!is_user_connected(admin_id))
				return;

			new index = FindBannedAuthIndex(g_eBanPlayer[admin_id][ban_player_steamid]);

			if (index != -1)
				ArrayDeleteItem(g_aBannedPlayers, index);

			new found_id = find_player("c", g_eBanPlayer[admin_id][ban_player_steamid]);

			if (found_id)
				SQL_Load(found_id);
			else {
				new TempPlayer[DisconnectedPlayers_s];
				copy(TempPlayer[disconnected_player_name], charsmax(TempPlayer[disconnected_player_name]), g_eBanPlayer[admin_id][ban_player_name]);
				copy(TempPlayer[disconnected_player_steamid], charsmax(TempPlayer[disconnected_player_steamid]), g_eBanPlayer[admin_id][ban_player_steamid]);
				copy(TempPlayer[disconnected_player_ip], charsmax(TempPlayer[disconnected_player_ip]), g_eBanPlayer[admin_id][ban_player_ip]);

				ArrayPushArray(g_aDisconnectedPlayers, TempPlayer);
			}

			client_print_color(0, print_team_blue, "%s ^3%n^1 unbanned a player ^3%s^1 on mix.", g_sPrefix, admin_id, g_eBanPlayer[admin_id][ban_player_name]);
			arrayset(g_eBanPlayer[admin_id], 0, BanData_s);
		}
		case SQL_LOAD: {
			new id = cData[1];

			if (!is_user_connected(id))
				return;

			if (SQL_NumResults(hQuery)) {
				g_ePlayerData[id][banned] = true;
				SQL_ReadResult(hQuery, 0, g_ePlayerData[id][admin_name], charsmax(g_ePlayerData[][admin_name]));
				SQL_ReadResult(hQuery, 1, g_ePlayerData[id][admin_steamid], charsmax(g_ePlayerData[][admin_steamid]));
				new ban_expired = SQL_ReadResult(hQuery, 2);

				if (!ban_expired)
					copy(g_ePlayerData[id][date_expired], charsmax(g_ePlayerData[][date_expired]), "Permanent");
				else
					SQL_ReadResult(hQuery, 2, g_ePlayerData[id][date_expired], charsmax(g_ePlayerData[][date_expired]));

				g_ePlayerData[id][time_expired] = SQL_ReadResult(hQuery, 3);


				server_print("(ExecuteForward) %n %d", id, g_ePlayerData[id][banned])
				ExecuteForward(g_hBanForwards, _, id, g_ePlayerData[id][banned]);

				set_task(5.0, "Task_ShowHud", id);
			} else {
				new szAuth[24];
				get_user_authid(id, szAuth, charsmax(szAuth));
				new index = FindBannedAuthIndex(szAuth);

				if (index != -1)
					ArrayDeleteItem(g_aBannedPlayers, index);

				arrayset(g_ePlayerData[id], 0, PlayerData_s);
			}
		}
		case SQL_BANNED_PLAYERS: {
			new TempPlayer[BannedPlayers_s];
			while (SQL_MoreResults(hQuery)) {
				SQL_ReadResult(hQuery, 0, TempPlayer[banned_player_name], charsmax(TempPlayer[banned_player_name]));
				SQL_ReadResult(hQuery, 1, TempPlayer[banned_player_steamid], charsmax(TempPlayer[banned_player_steamid]));
				SQL_ReadResult(hQuery, 2, TempPlayer[banned_player_ip], charsmax(TempPlayer[banned_player_ip]));
				SQL_ReadResult(hQuery, 3, TempPlayer[banned_admin_name], charsmax(TempPlayer[banned_admin_name]));
				SQL_ReadResult(hQuery, 4, TempPlayer[banned_admin_steamid], charsmax(TempPlayer[banned_admin_steamid]));
				SQL_ReadResult(hQuery, 5, TempPlayer[banned_player_expired], charsmax(TempPlayer[banned_player_expired]));

				ArrayPushArray(g_aBannedPlayers, TempPlayer);
				SQL_NextRow(hQuery);
			}
		}
	}
}

public Task_ShowHud(id) {
	if (!g_ePlayerData[id][banned])
		return;

	set_hudmessage(.red = 255, .green = 255, .blue = 255, .x = -1.00, .y = 0.3, .holdtime = 10.0);
	ShowSyncHudMsg(id, g_MsgSync, "You were banned on mix!^n\
									Admin: %s | Steamid: %s^n\
									Expired: %s", g_ePlayerData[id][admin_name], g_ePlayerData[id][admin_steamid], g_ePlayerData[id][date_expired]);
}

public SQL_BanPlayer(admin_id, player_id) {
	new szQuery[512];
	new cData[3];
	cData[0] = SQL_BAN_PLAYER, cData[1] = admin_id, cData[2] = player_id;

	new szAdminName[MAX_NAME_LENGTH];
	SQL_QuoteString(Empty_Handle, g_eBanPlayer[admin_id][ban_player_name], charsmax(g_eBanPlayer[][ban_player_name]), fmt("%n", player_id));
	SQL_QuoteString(Empty_Handle, szAdminName, charsmax(szAdminName), fmt("%n", admin_id));

	get_user_authid(player_id, g_eBanPlayer[admin_id][ban_player_steamid], charsmax(g_eBanPlayer[][ban_player_steamid]));
	new szAdminAuth[24];
	get_user_authid(admin_id, szAdminAuth, charsmax(szAdminAuth));

	get_user_ip(player_id, g_eBanPlayer[admin_id][ban_player_ip], charsmax(g_eBanPlayer[][ban_player_ip]), true);
	new szAdminIp[16];
	get_user_ip(admin_id, szAdminIp, charsmax(szAdminIp), true);

	new szTime[64];
	if (g_eBanData[admin_id][ban_time])
		formatex(szTime, charsmax(szTime), "now() + interval %d SECOND", g_eBanData[admin_id][ban_time]);

	formatex(szQuery, charsmax(szQuery), "\
		INSERT INTO `%s` \
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
		);", g_szTable, g_eBanPlayer[admin_id][ban_player_name], g_eBanPlayer[admin_id][ban_player_steamid], g_eBanPlayer[admin_id][ban_player_ip], szAdminName, szAdminAuth, szAdminIp, g_eBanData[admin_id][ban_time] ? szTime : "NULL");
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_Offban(admin_id, player_name[], player_steamid[], player_ip[]) {
	new szQuery[512];
	new cData[2];
	cData[0] = SQL_OFFBAN_PLAYER, cData[1] = admin_id;

	new szPlayerName[MAX_NAME_LENGTH], szAdminName[MAX_NAME_LENGTH];
	SQL_QuoteString(Empty_Handle, szPlayerName, charsmax(szPlayerName), fmt("%s", player_name));
	SQL_QuoteString(Empty_Handle, szAdminName, charsmax(szAdminName), fmt("%n", admin_id));

	new szAdminAuth[24];
	get_user_authid(admin_id, szAdminAuth, charsmax(szAdminAuth));
	new szAdminIp[16];
	get_user_ip(admin_id, szAdminIp, charsmax(szAdminIp), true);

	new szTime[64];
	if (g_eBanData[admin_id][ban_time])
		formatex(szTime, charsmax(szTime), "now() + interval %d SECOND", g_eBanData[admin_id][ban_time]);

	formatex(szQuery, charsmax(szQuery), "\
		INSERT INTO `%s` \
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
		);", g_szTable, szPlayerName, player_steamid, player_ip, szAdminName, szAdminAuth, szAdminIp, g_eBanData[admin_id][ban_time] ? szTime : "NULL");
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_UnbanPlayer(admin_id, player_steamid[]) {
	new szQuery[256];
	new cData[2];
	cData[0] = SQL_UNBAN_PLAYER, cData[1] = admin_id;

	formatex(szQuery, charsmax(szQuery), "\
		DELETE FROM `%s` \
		WHERE	`player_steamid` = '%s'", g_szTable, player_steamid);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_Load(id) {
	new szQuery[512];
	new cData[2];
	cData[0] = SQL_LOAD, cData[1] = id;
	new szAuth[24];
	get_user_authid(id, szAuth, charsmax(szAuth));

	formatex(szQuery, charsmax(szQuery), "\
		SELECT `admin_name`, \
			`admin_steamid`, \
			`expired`, \
			Unix_timestamp(expired) AS expired_date_unix \
		FROM	 `%s` \
		WHERE	`player_steamid` = '%s' \
			AND (`expired` > now() \
					OR `expired` IS NULL)", g_szTable, szAuth);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_BannedPlayers() {
	new szQuery[512];
	new cData[1] = SQL_BANNED_PLAYERS;

	formatex(szQuery, charsmax(szQuery), "\
		SELECT	`player_name`, \
				`player_steamid`, \
				`player_ip`, \
				`admin_name`, \
				`admin_steamid`, \
				`expired` \
		FROM	 `%s` \
		WHERE	`expired` > now() \
				OR `expired` IS NULL", g_szTable);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

RegisterForwards() {
	g_hBanForwards = CreateMultiForward("hns_player_banned", ET_CONTINUE, FP_CELL, FP_CELL);
	g_hBanForwardsInit = CreateMultiForward("hns_banned_init", ET_CONTINUE);
}

RegisterCmds() {
	register_clcmd("hns_banmenu", "CmdBan");
	register_clcmd("hns_offbanmenu", "CmdOffban");
	register_clcmd("hns_unbanmenu", "CmdUnban");
}

public CmdBan(id) {
	if (~get_user_flags(id) & ACCESS)
		return PLUGIN_HANDLED;

	MenuBan(id);
	return PLUGIN_HANDLED;
}

public CmdOffban(id) {
	if (~get_user_flags(id) & ACCESS)
		return PLUGIN_HANDLED;

	MenuOffban(id);
	return PLUGIN_HANDLED;
}

public CmdUnban(id) {
	if (~get_user_flags(id) & ADMIN_BAN)
		return PLUGIN_HANDLED;

	MenuUnban(id);
	return PLUGIN_HANDLED;
}

MenuBan(id, page = 0) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (~get_user_flags(id) & ACCESS)
		return PLUGIN_HANDLED;

	new iPlayers[MAX_PLAYERS], iNum, szPlayer[10], iPlayer;
	new menu = menu_create("\rBan player on mix", "BanHandler");

	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		iPlayer = iPlayers[i];

		if (id == iPlayer)
			continue;

		if (g_ePlayerData[iPlayer][banned])
			continue;

		num_to_str(iPlayer, szPlayer, charsmax(szPlayer));
		menu_additem(menu, fmt("%n", iPlayer), szPlayer);
	}
	menu_display(id, menu, page);
	return PLUGIN_HANDLED;
}

public BanHandler(id, menu, item) {
	if (!is_user_connected(id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (~get_user_flags(id) & ACCESS) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new s_Data[6], s_Name[64], i_Access, i_Callback;
	menu_item_getinfo(menu, item, i_Access, s_Data, charsmax(s_Data), s_Name, charsmax(s_Name), i_Callback);
	new iPlayer = str_to_num(s_Data);

	if (!is_user_connected(iPlayer)) {
		MenuBan(id, item / 7);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (g_ePlayerData[iPlayer][banned]) {
		MenuBan(id, item / 7);
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	g_eBanData[id][ban_player] = iPlayer;
	g_eBanData[id][offban] = false;
	MenuTime(id);

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

MenuOffban(id, page = 0) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (~get_user_flags(id) & ACCESS)
		return PLUGIN_HANDLED;

	if (!g_aDisconnectedPlayers)
		return PLUGIN_HANDLED;

	new TempPlayer[DisconnectedPlayers_s];
	new iSize = ArraySize(g_aDisconnectedPlayers);

	if (!iSize)
		return PLUGIN_HANDLED;

	new menu = menu_create("\rBan disconnected player on mix", "OffbanHandler");

	for (new i; i < iSize; i++) {
		ArrayGetArray(g_aDisconnectedPlayers, i, TempPlayer);
		menu_additem(menu, fmt("%s", TempPlayer[disconnected_player_name]));
	}
	menu_display(id, menu, page);
	return PLUGIN_HANDLED;
}

public OffbanHandler(id, menu, item) {
	if (!is_user_connected(id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (~get_user_flags(id) & ACCESS) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (!g_aDisconnectedPlayers) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	ArrayGetArray(g_aDisconnectedPlayers, item, g_eBanPlayer[id]);

	g_eBanData[id][offban] = true;
	MenuTime(id);

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public MenuTime(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (~get_user_flags(id) & ACCESS)
		return PLUGIN_HANDLED;

	new menu;
	if (g_eBanData[id][offban]) {
		menu = menu_create(fmt("\rSelect ban time^n\
						\dTarget: %s", g_eBanPlayer[id][ban_player_name]), "TimeHandler");
	} else {
		menu = menu_create(fmt("\rSelect ban time^n\
							\dTarget: %n", g_eBanData[id][ban_player]), "TimeHandler");
	}

	for (new i; i < sizeof(g_eBanTime); i++)
		menu_additem(menu, fmt("%s", g_eBanTime[i][TIME_NAME]));

	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public TimeHandler(id, menu, item) {
	if (!is_user_connected(id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (~get_user_flags(id) & ACCESS) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	g_eBanData[id][ban_time] = g_eBanTime[item][TIME_SECONDS];

	if (g_eBanData[id][offban])
		SQL_Offban(id, g_eBanPlayer[id][ban_player_name], g_eBanPlayer[id][ban_player_steamid], g_eBanPlayer[id][ban_player_ip]);
	else
		SQL_BanPlayer(id, g_eBanData[id][ban_player]);

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

MenuUnban(id, page = 0) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (~get_user_flags(id) & ADMIN_BAN)
		return PLUGIN_HANDLED;

	if (!g_aBannedPlayers)
		return PLUGIN_HANDLED;

	new TempPlayer[BannedPlayers_s];
	new iSize = ArraySize(g_aBannedPlayers);

	if (!iSize)
		return PLUGIN_HANDLED;

	new menu = menu_create("\rUnban player on mix", "UnbanHandler");

	for (new i; i < iSize; i++) {
		ArrayGetArray(g_aBannedPlayers, i, TempPlayer);
		menu_additem(menu, fmt("%s", TempPlayer[banned_player_name]));
	}
	menu_display(id, menu, page);
	return PLUGIN_HANDLED;
}

public UnbanHandler(id, menu, item) {
	if (!is_user_connected(id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (~get_user_flags(id) & ADMIN_LEVEL_B) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	ArrayGetArray(g_aBannedPlayers, item, g_eBanPlayer[id]);
	MenuInfo(id);

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public MenuInfo(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;

	if (~get_user_flags(id) & ADMIN_LEVEL_B)
		return PLUGIN_HANDLED;

	new szExpired[32];
	if (g_eBanPlayer[id][ban_player_expired])
		formatex(szExpired, charsmax(szExpired), "%s", g_eBanPlayer[id][ban_player_expired]);
	else
		formatex(szExpired, charsmax(szExpired), "Permanent");

	new menu = menu_create(fmt("\rUnban player^n\
								\dPlayer name: %s^n\
								Player steamid: %s^n\
								Admin name: %s^n\
								Admin steamid: %s^n\
								Expired: %s", g_eBanPlayer[id][ban_player_name], g_eBanPlayer[id][ban_player_steamid], g_eBanPlayer[id][ban_admin_name], g_eBanPlayer[id][ban_admin_steamid], szExpired), "InfoHandler");

	menu_additem(menu, "Unban");
	menu_display(id, menu, 0);
	return PLUGIN_HANDLED;
}

public InfoHandler(id, menu, item) {
	if (!is_user_connected(id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (~get_user_flags(id) & ADMIN_LEVEL_B) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	SQL_UnbanPlayer(id, g_eBanPlayer[id][ban_player_steamid]);

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

stock FindDisconnectedAuthIndex(szAuth[]) {
	new iSize = ArraySize(g_aDisconnectedPlayers);
	new TempPlayer[DisconnectedPlayers_s];

	for (new i; i < iSize; i++) {
		ArrayGetArray(g_aDisconnectedPlayers, i, TempPlayer);
		if (equal(szAuth, TempPlayer[disconnected_player_steamid])) {
			return i;
		}
	}
	return -1;
}

stock FindBannedAuthIndex(szAuth[]) {
	new iSize = ArraySize(g_aBannedPlayers);
	new TempPlayer[BannedPlayers_s];

	for (new i; i < iSize; i++) {
		ArrayGetArray(g_aBannedPlayers, i, TempPlayer);
		if (equal(szAuth, TempPlayer[banned_player_steamid])) {
			return i;
		}
	}
	return -1;
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