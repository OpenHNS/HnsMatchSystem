#include <amxmodx>
#include <reapi>
#include <sqlx>
#include <hns_matchsystem>

#define PTS_WIN 15
#define PTS_LOSS 10

new const g_szLinkPts[] = "https://SITENAME/pts/pts.php";

new g_szTablePlayers[] = "hns_players";
new g_szTablePts[] = "hns_pts";
new g_szTableOwnage[] = "hns_ownage";

#define SQL_CREATE_PLAYERS \
"CREATE TABLE IF NOT EXISTS `%s` \
( \
	`id`		INT(11) NOT NULL auto_increment PRIMARY KEY, \
	`name`		VARCHAR(32) NULL DEFAULT NULL, \
	`steamid`	VARCHAR(24) NULL DEFAULT NULL, \
	`ip`		VARCHAR(22) NULL DEFAULT NULL, \
	`playtime`		INT NOT NULL DEFAULT 1, \
	`lastconnect`	INT NOT NULL DEFAULT 0 \
);"

#define SQL_CREATE_PTS \
"CREATE TABLE IF NOT EXISTS `%s` ( \
	`id`	INT(11) NOT NULL PRIMARY KEY, \
	`wins`	INT(11) NOT NULL DEFAULT 0, \
	`loss`	INT(11) NOT NULL DEFAULT 0, \
	`pts`	INT(11) NOT NULL DEFAULT 1000 \
);"

#define SQL_CREATE_OWNAGE \
"CREATE TABLE IF NOT EXISTS `%s` ( \
	`id`	INT(11) NOT NULL PRIMARY KEY, \
	`ownage`	INT(11) NOT NULL DEFAULT 0 \
);"

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

enum _:SKILL_INFO
{
	SKILL_PTS,
	SKILL_LVL[10]
};

new const g_eSkillData[][SKILL_INFO] = {
	// pts	 skill
	{ 0,	"L-" },
	{ 650,	"L" },
	{ 750,	"L+" },
	{ 850,	"M-" },
	{ 950,	"M" },
	{ 1050,	"M+" },
	{ 1150,	"H-" },
	{ 1250,	"H" },
	{ 1350,	"H+" },
	{ 1450,	"P-" },
	{ 1550,	"P" },
	{ 1650,	"P+" },
	{ 1750,	"G-" },
	{ 1850,	"G" },
	{ 1950,	"G+" },
};

enum _:CVARS {
	HOST[48],
	USER[32],
	PASS[32],
	DB[32]
};

new g_eCvars[CVARS];

enum _:SQL {
	SQL_PLAYERS_CREATE,
	SQL_PLAYERS_SELECT,
	SQL_PLAYERS_INSERT,
	SQL_PLAYERS_NAME,
	SQL_PLAYERS_IP,
	SQL_PLAYERS_SAVE,
	SQL_PLAYERS_SAVECON,
	SQP_PTS_CREATE,
	SQL_PTS_SELECT,
	SQL_PTS_INSERT,
	SQL_PTS_TOP,
	SQL_PTS_SET_WIN,
	SQL_PTS_SET_LOSE,
	SQL_OWNAGE_CREATE,
	SQL_OWNAGE_SELECT,
	SQL_OWNAGE_INSERT,
	SQL_OWNAGE_SET
};

new Handle:g_hSqlTuple;

new g_iPlayerSQLID[MAX_PLAYERS + 1];

enum _:PTS_DATA {
	e_iPts,
    e_iWins,
    e_iLoss,
    e_iTop
};

new g_ePointsData[MAX_PLAYERS + 1][PTS_DATA];

new g_iOwnageData[MAX_PLAYERS + 1];

new g_sPrefix[24];

new Float:g_flMatchDelay;

public plugin_natives() {
	register_native("hns_mysql_stats_init", "native_db_init");

	register_native("hns_mysql_stats_data", "native_get_pts_data");
	register_native("hns_set_pts_win", "native_set_pts_win");
	register_native("hns_set_pts_lose", "native_set_pts_lose");

	register_native("hns_mysql_stats_get_ownage", "native_hns_mysql_stats_get_ownage");
	register_native("hns_mysql_stats_set_ownage", "native_hns_mysql_stats_set_ownage");
}

public native_db_init(amxx, params) {
	return 1;
}

public native_get_pts_data(amxx, params) {
	enum { getId = 1, getData = 2 };

	new id = get_param(getId);
	new _:data = get_param(getData);

	return g_ePointsData[id][data]
}

public native_set_pts_win(amxx, params) {
	enum { getId = 1, getPtsNum = 2 };

	new id = get_param(getId);
	new iPtsNum = get_param(getPtsNum);

	SQLPtsSetWin(id, iPtsNum);
}

public native_set_pts_lose(amxx, params) {
	enum { getId = 1, getPtsNum = 2 };

	new id = get_param(getId);
	new iPtsNum = get_param(getPtsNum);

	SQLPtsSetLose(id, iPtsNum);
}

public native_hns_mysql_stats_get_ownage(amxx, params) {
	enum { getId = 1 };

	new id = get_param(getId);

	return g_iOwnageData[id];
}

public native_hns_mysql_stats_set_ownage(amxx, params) {
	enum { getId = 1 };

	new id = get_param(getId);

	SQLOwnageSet(id);
}

public plugin_cfg() {
	hns_get_prefix(g_sPrefix, charsmax(g_sPrefix));
}

public plugin_init() {
	register_plugin("Match: Database MySQL", "1.0", "OpenHNS"); // Garey

	new pCvar;
	pCvar = create_cvar("hns_host", "127.0.0.1", FCVAR_PROTECTED, "Host");
	bind_pcvar_string(pCvar, g_eCvars[HOST], charsmax(g_eCvars[HOST]));

	pCvar = create_cvar("hns_user", "root", FCVAR_PROTECTED, "User");
	bind_pcvar_string(pCvar, g_eCvars[USER], charsmax(g_eCvars[USER]));

	pCvar = create_cvar("hns_pass", "root", FCVAR_PROTECTED, "Password");
	bind_pcvar_string(pCvar, g_eCvars[PASS], charsmax(g_eCvars[PASS]));

	pCvar = create_cvar("hns_db", "hns", FCVAR_PROTECTED, "db");
	bind_pcvar_string(pCvar, g_eCvars[DB], charsmax(g_eCvars[DB]));

	new szPath[PLATFORM_MAX_PATH]; 
	get_localinfo("amxx_configsdir", szPath, charsmax(szPath));
	
	server_cmd("exec %s/mixsystem/hnsmatch-sql.cfg", szPath);
	server_exec();

	RegisterSayCmd("rank", "me", "CmdRank", 0, "Show rank");
	RegisterSayCmd("pts", "ptstop", "CmdPts", 0, "Show top pts players");

	RegisterHookChain(RG_CBasePlayer_SetClientUserInfoName, "rgSetClientUserInfoName", true);

	init_tables();

	register_dictionary("match_additons.txt");
}

public init_tables() {
	g_hSqlTuple = SQL_MakeDbTuple(g_eCvars[HOST], g_eCvars[USER], g_eCvars[PASS], g_eCvars[DB]);
	SQL_SetCharset(g_hSqlTuple, "utf-8");

	new szQuery[512];
	new cData[1];

	cData[0] = SQL_PLAYERS_CREATE;
	formatex(szQuery, charsmax(szQuery), SQL_CREATE_PLAYERS, g_szTablePlayers);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	cData[0] = SQP_PTS_CREATE;
	formatex(szQuery, charsmax(szQuery), SQL_CREATE_PTS, g_szTablePts);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	cData[0] = SQL_OWNAGE_CREATE;
	formatex(szQuery, charsmax(szQuery), SQL_CREATE_OWNAGE, g_szTableOwnage);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
	// CREATE
}

public QueryHandler(iFailState, Handle:hQuery, szError[], iErrnum, cData[], iSize, Float:fQueueTime) {
	if (iFailState != TQUERY_SUCCESS) {
		log_amx("SQL Error #%d - %s", iErrnum, szError);
		return PLUGIN_HANDLED;
	}

	switch(cData[0]) {
		case SQL_PLAYERS_SELECT: {
			new id = cData[1];

			if (!is_user_connected(id))
				return PLUGIN_HANDLED;

			if (SQL_NumResults(hQuery)) {
				SQLPlayersSelectHandler(hQuery, id);
			} else {
				SQLPlayersInsert(id);
			}
		}
		case SQL_PLAYERS_INSERT: {
			new id = cData[1];

			if (!is_user_connected(id))
				return PLUGIN_HANDLED;

			SQLPlayersInsertHandler(hQuery, id);
		}
		case SQL_PTS_SELECT: {
			new id = cData[1];

			if (!is_user_connected(id))
				return PLUGIN_HANDLED;

			if (SQL_NumResults(hQuery)) {
				SQLPtsSelectHandler(hQuery, id);
			} else {
				arrayset(g_ePointsData[id], 0, PTS_DATA);
				SQLPtsInsert(id);
			}
		}
		case SQL_PTS_INSERT: {
			new id = cData[1];

			if (!is_user_connected(id))
				return PLUGIN_HANDLED;

			SQLPtsInsertHandler(hQuery, id);
		}
		case SQL_PTS_TOP: {
			new id = cData[1];

			if (!is_user_connected(id))
				return PLUGIN_HANDLED;

			SQLPtsTopHandler(hQuery, id);
		}
		case SQL_OWNAGE_SELECT: {
			new id = cData[1];

			if (!is_user_connected(id))
				return PLUGIN_HANDLED;

			SQLOwnageSelectHandler(hQuery, id);
		}
	}

	return PLUGIN_HANDLED;
}

public SQLPlayersSelect(id) {
	new szQuery[512];

	new cData[2];
	cData[0] = SQL_PLAYERS_SELECT, 
	cData[1] = id;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szQuery, charsmax(szQuery),
	"SELECT * FROM \
		`%s` \
	WHERE \
		`steamid` = '%s'",
	g_szTablePlayers,
	szAuthId);

	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	return PLUGIN_HANDLED;
}

public SQLPlayersSelectHandler(Handle:hQuery, id) {
	new tempSQLID = SQL_FieldNameToNum(hQuery, "id");
	new tempName = SQL_FieldNameToNum(hQuery, "name");
	new tempIP = SQL_FieldNameToNum(hQuery, "ip");

	g_iPlayerSQLID[id] = SQL_ReadResult(hQuery, tempSQLID);

	new szNewName[MAX_NAME_LENGTH];
	new szNewNameSQL[MAX_NAME_LENGTH * 2]
	get_user_name(id, szNewName, charsmax(szNewName));
	SQL_QuoteString(Empty_Handle, szNewNameSQL, charsmax(szNewNameSQL), szNewName);

	new szOldName[MAX_NAME_LENGTH];
	SQL_ReadResult(hQuery, tempName, szOldName, charsmax(szOldName));

	if (!equal(szNewNameSQL, szOldName))
		SQLPlayersName(id, szNewNameSQL);
	
	new szNewIp[MAX_IP_LENGTH]; 
	get_user_ip(id, szNewIp, charsmax(szNewIp), true);

	new szOldIp[MAX_NAME_LENGTH]; 
	SQL_ReadResult(hQuery, tempIP, szOldIp, charsmax(szOldIp));

	if (!equal(szNewIp, szOldIp))
		SQLPlayersIP(id, szNewIp);

	SQLPtsSelect(id);

	SQLOwnageSelect(id);

	return PLUGIN_HANDLED;
}

public SQLPlayersInsert(id) {
	new szQuery[512];

	new cData[2];
	cData[0] = SQL_PLAYERS_INSERT,
	cData[1] = id;

	new szName[MAX_NAME_LENGTH * 2];
	SQL_QuoteString(Empty_Handle, szName, charsmax(szName), fmt("%n", id));

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	new szIp[MAX_IP_LENGTH];
	get_user_ip(id, szIp, charsmax(szIp), true);

	formatex(szQuery, charsmax(szQuery), 
	"INSERT INTO `%s` ( \
		name, \
		steamid, \
		ip \
	) VALUES ( \
		'%s', \
		'%s', \
		'%s' \
	)", 
	g_szTablePlayers,
	szName,
	szAuthId,
	szIp);

	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	return PLUGIN_HANDLED;
}

public SQLPlayersInsertHandler(Handle:hQuery, id) {
	g_iPlayerSQLID[id] = SQL_GetInsertId(hQuery);

	SQLPtsSelect(id);

	return PLUGIN_HANDLED;
}

public SQLPlayersName(id, szNewname[]) {
	new szQuery[512]
	new cData[1] = SQL_PLAYERS_NAME;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	new szName[MAX_NAME_LENGTH * 2];
	SQL_QuoteString(Empty_Handle, szName, charsmax(szName), szNewname);

	formatex(szQuery, charsmax(szQuery),
	"UPDATE `%s` SET \
		`name` = '%s' \
	WHERE \
		`steamid` = '%s'",
	g_szTablePlayers,
	szName,
	szAuthId);
	
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQLPlayersIP(id, szNewip[]) {
	new szQuery[512]
	new cData[1] = SQL_PLAYERS_IP;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szQuery, charsmax(szQuery), 
	"UPDATE `%s` SET \
		`ip` = '%s' \
	WHERE \
		`steamid` = '%s'", 
	g_szTablePlayers, 
	szNewip, 
	szAuthId);

	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQLPlayersSave(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	
	new szQuery[512];
	new cData[1] = SQL_PLAYERS_SAVE;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));
	
	new iSaveOnline = get_user_time(id);
	
	formatex(szQuery, charsmax(szQuery), 
	"UPDATE `%s` SET \
		`playtime` = `playtime` + %d \
	WHERE \
		`steamid` = '%s'", 
		g_szTablePlayers, 
		iSaveOnline, 
		szAuthId);

	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	return PLUGIN_HANDLED;
}

public SQLPlayersSaveConn(id) {
	new szQuery[512];
	new cData[1] = SQL_PLAYERS_SAVECON;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));
	
	new iTime[32];
	get_time("%S", iTime, charsmax(iTime));
	
	formatex(szQuery, charsmax(szQuery), 
	"UPDATE `%s` SET \
		`lastconnect` = '%s' \
	WHERE \
		`steamid` = '%s'", 
	g_szTablePlayers, 
	iTime, 
	szAuthId);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

	return PLUGIN_HANDLED;
}

public SQLPtsSelect(id) {
	if (!is_user_connected(id))
		return;

	new szQuery[512];
	new cData[2]; 

	cData[0] = SQL_PTS_SELECT;
	cData[1] = id;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szQuery, charsmax(szQuery), 
	"SELECT * \
	FROM `%s` \
	WHERE `id` = \
	( \
		SELECT `id` \
		FROM   `hns_players` \
		WHERE  `steamid` = '%s' \
	);",
	g_szTablePts,
	szAuthId);
	
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQLPtsSelectHandler(Handle:hQuery, id) {
	new index_wins = SQL_FieldNameToNum(hQuery, "wins");
	new index_loss = SQL_FieldNameToNum(hQuery, "loss");
	new index_pts = SQL_FieldNameToNum(hQuery, "pts");

	g_ePointsData[id][e_iWins] = SQL_ReadResult(hQuery, index_wins);
	g_ePointsData[id][e_iLoss] = SQL_ReadResult(hQuery, index_loss);
	g_ePointsData[id][e_iPts] = SQL_ReadResult(hQuery, index_pts);

	SQLPtsTop(id);

	return PLUGIN_HANDLED;
}

public SQLPtsInsert(id) {
	new szQuery[512];
	new cData[2];

	cData[0] = SQL_PTS_INSERT;
	cData[1] = id;

	g_ePointsData[id][e_iPts] = 1000;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szQuery, charsmax(szQuery),
	"INSERT INTO `%s` ( \
		id \
	) VALUES ( \
		%d \
	)", 
	g_szTablePts,
	g_iPlayerSQLID[id]);
	
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQLPtsInsertHandler(Handle:hQuery, id) {
	SQLPtsTop(id);

	return PLUGIN_HANDLED;
}

public SQLPtsTop(id) {
	new szQuery[512];
	new cData[2]; 
	
	cData[0] = SQL_PTS_TOP
	cData[1] = id;
	
	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));
	
	formatex(szQuery, charsmax(szQuery), 
	"SELECT COUNT(*) \
	FROM `%s` \
	WHERE `pts` >= %d", 
	g_szTablePts, 
	g_ePointsData[id][e_iPts]);

	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQLPtsTopHandler(Handle:hQuery, id) {
	if (SQL_NumResults(hQuery)) {
		g_ePointsData[id][e_iTop] = SQL_ReadResult(hQuery, 0);
	}


	return PLUGIN_HANDLED;
}

public SQLPtsSetWin(id, iPtsNum) {
	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	new szQuery[512];
	new cData[2]; 
	
	cData[0] = SQL_PTS_SET_WIN;
	cData[1] = id;

	g_ePointsData[id][e_iWins]++;
	g_ePointsData[id][e_iPts] += iPtsNum;

	formatex(szQuery, charsmax(szQuery),
	"UPDATE `%s` \
	SET	`wins` = `wins` + 1, `pts` = `pts` + %d \
	WHERE `id` IN \
	( \
		SELECT `id` \
		FROM   `%s` \
		WHERE  `steamid` = '%s' \
	);", 
	g_szTablePts, 
	iPtsNum, 
	g_szTablePlayers, 
	szAuthId);

	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQLPtsSetLose(id, iPtsNum) {
	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	new szQuery[512];
	new cData[2]; 
	
	cData[0] = SQL_PTS_SET_LOSE;
	cData[1] = id;

	g_ePointsData[id][e_iLoss]++;
	g_ePointsData[id][e_iPts] -= iPtsNum;

	formatex(szQuery, charsmax(szQuery),
	"UPDATE `%s` SET \
		`loss` = `loss` + 1, `pts` = `pts` - %d \
	WHERE `id` IN \
	( \
		SELECT `id` \
		FROM   `%s` \
		WHERE  `steamid` = '%s' \
	);", 
	g_szTablePts, 
	iPtsNum, 
	g_szTablePlayers, 
	szAuthId);

	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQLOwnageSelect(id) {
	if (!is_user_connected(id))
		return;

	new szQuery[512];
	new cData[2]; 

	cData[0] = SQL_OWNAGE_SELECT;
	cData[1] = id;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szQuery, charsmax(szQuery), 
	"SELECT * \
	FROM `%s` \
	WHERE `id` = \
	( \
		SELECT `id` \
		FROM   `hns_players` \
		WHERE  `steamid` = '%s' \
	);", 
	g_szTableOwnage, 
	szAuthId);
	
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQLOwnageSelectHandler(Handle:hQuery, id) {
	if (SQL_NumResults(hQuery)) {
		new index_ownage = SQL_FieldNameToNum(hQuery, "ownage");
		g_iOwnageData[id] = SQL_ReadResult(hQuery, index_ownage);
	} else {
		g_iOwnageData[id] = 0;
		SQLOwnageInsert(id);
	}
}

public SQLOwnageInsert(id) {
	new szQuery[512];
	new cData[2];

	cData[0] = SQL_OWNAGE_INSERT;
	cData[1] = id;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szQuery, charsmax(szQuery), 
	"INSERT INTO `%s` ( \
		id \
	) VALUES ( \
		%d \
	)", 
	g_szTableOwnage, 
	g_iPlayerSQLID[id]);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQLOwnageSet(id) {
	g_iOwnageData[id]++;

	new szQuery[512];
	new cData[1] = SQL_OWNAGE_SET;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));
	
	formatex(szQuery, charsmax(szQuery), 
	"UPDATE `%s` \
	SET	`ownage` = `ownage` + 1 \
	WHERE `id` = \
	( \
		SELECT `id` \
		FROM   `hns_players` \
		WHERE  `steamid` = '%s' \
	);", 
	g_szTableOwnage, 
	szAuthId);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public client_putinserver(id) {
	SQLPlayersSelect(id);
}

public client_disconnected(id) {
	SQLPlayersSave(id);
	SQLPlayersSaveConn(id);
}

public CmdRank(id) {
	client_print_color(id, print_team_blue, "%L", id, "PTS_RANK", g_sPrefix, g_ePointsData[id][e_iTop], g_ePointsData[id][e_iPts], g_ePointsData[id][e_iWins], g_ePointsData[id][e_iLoss], hns_mysql_stats_skill(id));
}

public CmdPts(id) {
	new szMotd[MAX_MOTD_LENGTH];

	formatex(szMotd, sizeof(szMotd) - 1,\
	"<html><head><meta http-equiv=^"Refresh^" content=^"0;url=%s^"></head><body><p><center>LOADING...</center></p></body></html>",\
	g_szLinkPts);

	show_motd(id, szMotd);
}

public rgSetClientUserInfoName(id, infobuffer[], szNewName[]) {
	if (!is_user_connected(id))
		return;

	SQLPlayersName(id, szNewName);
}

public hns_match_started() {
	g_flMatchDelay = get_gametime() + 600;
}

public hns_match_canceled() {
	g_flMatchDelay = 0.0;
}

public hns_match_finished(iWinTeam) {
	if (g_flMatchDelay > get_gametime()) {
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "PTS_NOT_TIME", g_sPrefix);
	} else {
		if (get_num_players_in_match() < 5) {
			client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "PTS_NOT_PLR", g_sPrefix);
		} else {
			new iPlayers[MAX_PLAYERS], iNum;
			if (iWinTeam == 1) {
				get_players(iPlayers, iNum, "che", "TERRORIST");
				for (new i; i < iNum; i++) {
					SQLPtsSetWin(iPlayers[i], PTS_WIN);
				}

				get_players(iPlayers, iNum, "che", "CT");
				for (new i; i < iNum; i++) {
					SQLPtsSetLose(iPlayers[i], PTS_LOSS);
				}
			} else if (iWinTeam == 2) {
				get_players(iPlayers, iNum, "che", "CT");
				for (new i; i < iNum; i++) {
					SQLPtsSetWin(iPlayers[i], PTS_WIN);
				}

				get_players(iPlayers, iNum, "che", "TERRORIST");
				for (new i; i < iNum; i++) {
					SQLPtsSetLose(iPlayers[i], PTS_LOSS);
				}
			}
		}
	}
	g_flMatchDelay = 0.0;
}


public plugin_end() {
	SQL_FreeHandle(g_hSqlTuple);
}

stock get_num_players_in_match() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	new numGameplr;
	for (new i; i < iNum; i++) {
		new tempid = iPlayers[i];
		if (rg_get_user_team(tempid) == TEAM_SPECTATOR) continue;
		numGameplr++;
	}
	return numGameplr;
}

stock hns_mysql_stats_skill(id) {
	new iPts = g_ePointsData[id][e_iPts];
	new szSkill[10];
	for (new i; i < sizeof(g_eSkillData); i++) {
		if (iPts >= g_eSkillData[i][SKILL_PTS]) {
			formatex(szSkill, charsmax(szSkill), "%s", g_eSkillData[i][SKILL_LVL]);
		}
	}
	return szSkill;
}
