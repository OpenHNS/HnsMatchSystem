#include <amxmodx>
#include <reapi>
#include <sqlx>
#include <hns_matchsystem>
#include <hns_matchsystem_sql>

new const g_szTablePts[] = "hns_pts";

#define PTS_WIN 15
#define PTS_LOSS 10

#define SQL_CREATE_TABLE \
"CREATE TABLE IF NOT EXISTS `%s` ( \
	`id`	INT(11) NOT NULL PRIMARY KEY, \
	`wins`	INT(11) NOT NULL DEFAULT 0, \
	`loss`	INT(11) NOT NULL DEFAULT 0, \
	`pts`	INT(11) NOT NULL DEFAULT 1000 \
);"

#define SQL_CREATE_DATA \
"INSERT INTO `%s` ( \
	id \
) VALUES ( \
	%d \
)"

#define SQL_SELECT_DATA \
"SELECT * \
FROM `%s` \
WHERE `id` = \
( \
	SELECT `id` \
	FROM   `hns_players` \
	WHERE  `steamid` = '%s' \
);"

#define SQL_SET_WIN \
"UPDATE `%s` \
SET	`wins` = `wins` + 1, `pts` = `pts` + %d \
WHERE `id` IN \
( \
	SELECT `id` \
	FROM   `%s` \
	WHERE  `steamid` = '%s' \
);"

#define SQL_SET_LOSE \
"UPDATE `%s` SET \
	`loss` = `loss` + 1, `pts` = `pts` - %d \
WHERE `id` IN \
( \
	SELECT `id` \
	FROM   `%s` \
	WHERE  `steamid` = '%s' \
); "

#define SQL_GET_TOP \
"SELECT COUNT(*) \
FROM `%s` \
WHERE `pts` >= %d"

#define SQL_SET_RANK \
"UPDATE `%s` SET \
	`rank` = %d \
WHERE `id` IN \
( \
	SELECT `id` \
	FROM   `%s` \
	WHERE  `steamid` = '%s' \
);"

enum _:SQL {
	SQL_TABLE,
	SQL_INSERT,
	SQL_SELECT,
	SQL_TOP,
	SQL_WINNERS,
	SQL_LOOSERS
};

new Handle:g_hSqlTuple;
new g_sTablePlayers[32];

enum _:PTS_DATA {
	e_iPts,
    e_iWins,
    e_iLoss,
    e_iTop
};

new g_ePointsData[MAX_PLAYERS + 1][PTS_DATA];

new const g_szLinkPts[] = "https://SITENAME/pts/pts.php";

new g_sPrefix[24];
new Float:g_flMatchDelay;

new g_hFwdPlayerInit;

public plugin_init() {
	register_plugin("Match: Pts", "1.1", "OpenHNS"); // Garey

	RegisterSayCmd("rank", "me", "CmdRank", 0, "Show rank");
	RegisterSayCmd("pts", "ptstop", "CmdPts", 0, "Show top pts players");

	g_hFwdPlayerInit = CreateMultiForward("hns_pts_init_player", ET_CONTINUE, FP_CELL, FP_CELL, FP_CELL, FP_CELL, FP_CELL);

	register_dictionary("match_additons.txt");
}

public CmdRank(id) {
	client_print_color(id, print_team_blue, "%L", id, "PTS_RANK", g_sPrefix, g_ePointsData[id][e_iTop], g_ePointsData[id][e_iPts], g_ePointsData[id][e_iWins], g_ePointsData[id][e_iLoss], get_skill_player(g_ePointsData[id][e_iPts]));
}

public CmdPts(id) {
	new szMotd[MAX_MOTD_LENGTH];

	formatex(szMotd, sizeof(szMotd) - 1,\
	"<html><head><meta http-equiv=^"Refresh^" content=^"0;url=%s^"></head><body><p><center>LOADING...</center></p></body></html>",\
	g_szLinkPts);

	show_motd(id, szMotd);
}

public plugin_cfg() {
	hns_sql_get_table_name(g_sTablePlayers, charsmax(g_sTablePlayers));

	hns_get_prefix(g_sPrefix, charsmax(g_sPrefix));
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
			if (iWinTeam == 1)
				SQL_SetPts(TEAM_TERRORIST);
			else
				SQL_SetPts(TEAM_CT);
		}
	}
	g_flMatchDelay = 0.0;
}

public hns_sql_player_authorized(id) {
	SQL_Select(id);
}

public hns_sql_connection(Handle:hSqlTuple) {
	g_hSqlTuple = hSqlTuple;

	new szQuery[512];
	new cData[1] = SQL_TABLE;
	
	formatex(szQuery, charsmax(szQuery), SQL_CREATE_TABLE, g_szTablePts);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public QueryHandler(iFailState, Handle:hQuery, szError[], iErrnum, cData[], iSize, Float:fQueueTime) {
	if (iFailState != TQUERY_SUCCESS) {
		log_amx("SQL Error #%d - %s", iErrnum, szError);
		return;
	}

	switch(cData[0]) {
		case SQL_SELECT: {
			new id = cData[1];

			if (SQL_NumResults(hQuery)) {
				new index_wins = SQL_FieldNameToNum(hQuery, "wins");
				new index_loss = SQL_FieldNameToNum(hQuery, "loss");
				new index_pts = SQL_FieldNameToNum(hQuery, "pts");

				g_ePointsData[id][e_iWins] = SQL_ReadResult(hQuery, index_wins);
				g_ePointsData[id][e_iLoss] = SQL_ReadResult(hQuery, index_loss);
				g_ePointsData[id][e_iPts] = SQL_ReadResult(hQuery, index_pts);

				SQL_Top(id);
			} else {
				arrayset(g_ePointsData[id], 0, PTS_DATA);
				SQL_Insert(id);
			}
		}
		case SQL_INSERT: {
			new id = cData[1];

			if (!is_user_connected(id))
				return;

			SQL_Top(id);
		}
		case SQL_TOP: {
			new id = cData[1];

			if (!is_user_connected(id))
				return;

			if (SQL_NumResults(hQuery)) {
				g_ePointsData[id][e_iTop] = SQL_ReadResult(hQuery, 0);
			}

			ExecuteForward(g_hFwdPlayerInit, _, id, g_ePointsData[id][e_iPts], g_ePointsData[id][e_iWins], g_ePointsData[id][e_iLoss], g_ePointsData[id][e_iTop]);
		}
		case SQL_WINNERS, SQL_LOOSERS: {
			for(new i = 1; i <= MaxClients; i++) {
				if (!is_user_connected(i))
					continue;

				if (get_member(i, m_iTeam) == TEAM_SPECTATOR)
					continue;
				
				SQL_Top(i);
			}
		}
	}
}

SQL_SetPts(TeamName:team_winners) {
	if (team_winners == TEAM_TERRORIST) {
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "PTS_SET_TT", g_sPrefix);
	} else {
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "PTS_SET_CT", g_sPrefix);
	}

	new szQuery[1024], iLen;
	
	new cData[2]; 
	cData[0] = SQL_WINNERS;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ce", team_winners == TEAM_TERRORIST ? "TERRORIST" : "CT");

	if (iNum) {
		for(new i, szAuthId[MAX_AUTHID_LENGTH]; i < iNum; i++) {
			new iWinner = iPlayers[i];
			get_user_authid(iWinner, szAuthId, charsmax(szAuthId));

			g_ePointsData[iWinner][e_iWins]++;
			g_ePointsData[iWinner][e_iPts] += PTS_WIN;

			iLen += formatex(szQuery[iLen], charsmax(szQuery)-iLen, SQL_SET_WIN, g_szTablePts, PTS_WIN, g_sTablePlayers, szAuthId);
		}
		SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));

		szQuery = "";
		iLen = 0;
	}

	get_players(iPlayers, iNum, "ce", team_winners == TEAM_TERRORIST ? "CT" : "TERRORIST");

	if (iNum) {
		for(new i, szAuthId[MAX_AUTHID_LENGTH]; i < iNum; i++) {
			new iLooser = iPlayers[i];
			get_user_authid(iLooser, szAuthId, charsmax(szAuthId));

			g_ePointsData[iLooser][e_iLoss]++;
			g_ePointsData[iLooser][e_iPts] -= PTS_WIN;

			iLen += formatex(szQuery[iLen], charsmax(szQuery)-iLen, SQL_SET_LOSE, g_szTablePts, PTS_LOSS, g_sTablePlayers, szAuthId);
		}
		SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
	}
}

public SQL_Select(id) {
	if (!is_user_connected(id))
		return;

	new szQuery[512];
	new cData[2]; 

	cData[0] = SQL_SELECT;
	cData[1] = id;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szQuery, charsmax(szQuery), SQL_SELECT_DATA, g_szTablePts, szAuthId);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_Insert(id) {
	new szQuery[512];
	new cData[2];

	cData[0] = SQL_INSERT;
	cData[1] = id;

	g_ePointsData[id][e_iPts] = 1000;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szQuery, charsmax(szQuery), SQL_CREATE_DATA, g_szTablePts, hns_sql_get_player_id(id));
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public SQL_Top(id) {
	new szQuery[512];
	new cData[2]; 
	
	cData[0] = SQL_TOP
	cData[1] = id;
	
	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));
	
	formatex(szQuery, charsmax(szQuery), SQL_GET_TOP, g_szTablePts, g_ePointsData[id][e_iPts]);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

enum _:skill_info {
	skill_pts,
	skill_lvl[10]
};

new const g_eSkillData[][skill_info] = {
	// pts     skill
	{ 0,		"L-" },
	{ 650,		"L" },
	{ 750,		"L+" },
	{ 850,		"M-" },
	{ 950,		"M" },
	{ 1050,		"M+" },
	{ 1150,		"H-" },
	{ 1250,		"H" },
	{ 1350,		"H+" },
	{ 1450,		"P-" },
	{ 1550,		"P" },
	{ 1650,		"P+" },
	{ 1750,		"G-" },
	{ 1850,		"G" },
	{ 1950,		"G+" },
};

stock get_skill_player(iPts) {
	new iPtr[10];
	for(new i; i < sizeof(g_eSkillData); i++) {
		if (iPts >= g_eSkillData[i][skill_pts]) {
			formatex(iPtr, charsmax(iPtr), "%s", g_eSkillData[i][skill_lvl]);
		}
	}
	return iPtr;
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