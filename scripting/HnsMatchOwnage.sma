#include <amxmodx>
#include <engine>
#include <reapi>
#include <sqlx>
#include <hns_matchsystem>
#include <hns_matchsystem_sql>

new const g_szTablePts[] = "hns_ownage";

#define DELAY 5.0

#define SQL_CREATE_TABLE \
"CREATE TABLE IF NOT EXISTS `%s` ( \
	`id`	INT(11) NOT NULL PRIMARY KEY, \
	`ownage`	INT(11) NOT NULL DEFAULT 0 \
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

#define SQL_SET \
"UPDATE `%s` \
SET	`ownage` = `ownage` + 1 \
WHERE `id` = \
( \
	SELECT `id` \
	FROM   `hns_players` \
	WHERE  `steamid` = '%s' \
);"

enum _:SQL {
	SQL_TABLE,
	SQL_INSERT,
	SQL_SELECT,
    SQL_OWNAGE
};

new Handle:g_hSqlTuple;

new g_iDataOwnage[MAX_PLAYERS + 1];

new Float:g_flLastHeadTouch[MAX_PLAYERS + 1];

new g_hForwardOwnage;

new const g_szSound[][] = {
	"openhns/mario.wav",
	"openhns/ownage.wav"
};

public plugin_precache() {
	for(new i; i < sizeof(g_szSound); i++)
		precache_sound(g_szSound[i]);
}

public plugin_init() {
	register_plugin("Match: Ownage", "1.0.1", "OpenHNS");
	
	register_touch("player", "player", "touchPlayer");

	register_dictionary("match_additons.txt");

	g_hForwardOwnage = CreateMultiForward("hns_ownage", ET_CONTINUE, FP_CELL, FP_CELL);
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
				new index_ownage = SQL_FieldNameToNum(hQuery, "ownage");
				g_iDataOwnage[id] = SQL_ReadResult(hQuery, index_ownage);
			} else {
				g_iDataOwnage[id] = 0;
				SQL_Insert(id);
			}
		}
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

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));

	formatex(szQuery, charsmax(szQuery), SQL_CREATE_DATA, g_szTablePts, hns_sql_get_player_id(id));
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public touchPlayer(iToucher, iTouched) {
	if(entity_get_int(iToucher, EV_INT_flags) & FL_ONGROUND && entity_get_edict(iToucher, EV_ENT_groundentity) == iTouched && rg_get_user_team(iToucher) == TEAM_TERRORIST && rg_get_user_team(iTouched) == TEAM_CT) {
		static Float:flGametime;
		flGametime = get_gametime();
		
		if(flGametime > g_flLastHeadTouch[iToucher] + DELAY) {
			ClearDHUDMessages();
			set_dhudmessage(250, 255, 0, -1.0, 0.15, 0, 0.0, 5.0, 0.1, 0.1);
			if (hns_get_mode() == MODE_MIX && hns_get_state() == STATE_ENABLED) {
				g_iDataOwnage[iToucher]++;
				show_dhudmessage(0, "%L", LANG_PLAYER, "HNS_OWNAGE_MIX", iToucher, iTouched, g_iDataOwnage[iToucher]);
				SQL_SetOwnage(iToucher);
			} else if (hns_get_mode() == MODE_PUB || hns_get_mode() == MODE_DM || hns_get_mode() == MODE_ZM) {
				show_dhudmessage(0, "%L", LANG_PLAYER, "HNS_OWNAGE", iToucher, iTouched);
			}
			
			if (hns_get_mode() == MODE_MIX || hns_get_mode() == MODE_PUB || hns_get_mode() == MODE_DM || hns_get_mode() == MODE_ZM) {
				g_flLastHeadTouch[iToucher] = flGametime;
				rg_send_audio(0, g_szSound[random(sizeof(g_szSound))]);
			}

			ExecuteForward(g_hForwardOwnage, _, iToucher, iTouched);
		}
	}
}

public SQL_SetOwnage(id) {
	new szQuery[512];
	new cData[1] = SQL_OWNAGE;

	new szAuthId[MAX_AUTHID_LENGTH];
	get_user_authid(id, szAuthId, charsmax(szAuthId));
	
	formatex(szQuery, charsmax(szQuery), SQL_SET, g_szTablePts, szAuthId);
	SQL_ThreadQuery(g_hSqlTuple, "QueryHandler", szQuery, cData, sizeof(cData));
}

public client_disconnected(id) {
	g_iDataOwnage[id] = 0;
	g_flLastHeadTouch[id] = 0.0;
}

stock ClearDHUDMessages(iClear = 8) {
	for (new iDHUD = 0; iDHUD < iClear; iDHUD++)
		show_dhudmessage(0, ""); 
}
