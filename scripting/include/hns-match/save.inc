#if defined _save_included
  #endinput
#endif

#define _save_included

#define NAME_DATA_AUTH "plr_auth"
#define NAME_DATA_TEAM "plr_team"

enum _:SAVE_PLAYER_DATA {
	SAVE_AUTH[24],
	TeamName:SAVE_TEAM
};

new bool:g_bPlayersListLoaded;

new g_szBuffer[2048];

public Save_d(index) {
	Save_players(TEAM_TERRORIST);

	PDS_SetString("playerslist", g_szBuffer);
}

public Load_d(index) {
	loadPlayers();
}

stock bool:checkPlayer(id) {
	new eTmpPlayer[SAVE_PLAYER_DATA], iSize = ArraySize(g_aPlayersLoadData);
	new szAuth[24]; get_user_authid(id, szAuth, charsmax(szAuth));
	for (new i; i < iSize; i++) {
		ArrayGetArray(g_aPlayersLoadData, i, eTmpPlayer);
		if (equal(szAuth, eTmpPlayer[SAVE_AUTH])) {
			rg_set_user_team(id, eTmpPlayer[SAVE_TEAM]);
			return true;
		}
	}
	return false;
}

/* SAVE DATA */

public PDS_Save() {
	if (hns_is_knife_map()) {
		if (g_szBuffer[0])
			PDS_SetString("playerslist", g_szBuffer);
	}
	PDS_SetCell("match_status",		g_iMatchStatus);
	PDS_SetCell("match_mode",		g_iCurrentMode);
	PDS_SetCell("match_gameplay",   g_iCurrentGameplay);
	PDS_SetCell("match_rules",	 	g_iCurrentRules);
}


stock arrayAppendValue(JSON:array, JSON:node) {
	json_array_append_value(array, node);
	json_free(node);
}

public Save_players(TeamName:team_winners) {
	new JSON:JSArray = json_init_array();

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];

		if (getUserTeam(id) == TEAM_SPECTATOR) 
		    continue;

		new szIndexName[16];
		formatex(szIndexName, charsmax(szIndexName), "player_%i", i + 1);

		new JSON:JSIndex = json_init_string(szIndexName)
		json_array_append_value(JSArray, JSIndex);
		json_free(JSIndex);

		new eTmpPlayer[SAVE_PLAYER_DATA];

		get_user_authid(id, eTmpPlayer[SAVE_AUTH], charsmax(eTmpPlayer[SAVE_AUTH]));
		eTmpPlayer[SAVE_TEAM] = TeamName:getUserTeam(id) == team_winners ? TEAM_TERRORIST : TEAM_CT;

		new JSON:JSData = json_init_object();
		json_object_set_string(JSData, NAME_DATA_AUTH, eTmpPlayer[SAVE_AUTH]);
		json_object_set_number(JSData, NAME_DATA_TEAM, _:eTmpPlayer[SAVE_TEAM]);
		json_array_append_value(JSArray, JSData);
		json_free(JSData);

		if (g_bDebugMode) server_print("[MATCH] PLR SAVE | %n (%s %s %d)", id, szIndexName, eTmpPlayer[SAVE_AUTH], _:eTmpPlayer[SAVE_TEAM])
	}

	json_serial_to_string(JSArray, g_szBuffer, charsmax(g_szBuffer), true);

	if (g_bDebugMode) server_print("[MATCH] PLR SAVE | g_szBuffer (%s)", g_szBuffer)

	json_free(JSArray);
}

/* hedqi
	Save_players собирает JSON в строку g_szBuffer
	PDS_Save Этот g_szBuffer сохраняет с именем playerslist.
	([ `JSArray`
    	"player_1", `JSIndex`
    	{
    	    "plr_auth": "STEAM_0:1:88325890", `JSData`
    	    "plr_team": 1 `JSData`
    	}
	])
	
	На каждый json_init нужно делать json_free, чтобы память не утикала.

	TODO: Нужно протестить 15х15 сейв, посомтреть не выдет ли ничего ошибку.
		Я попробую за коммит сделать дебаг, надо будет проверить всех ли сохраняет и загружает.

*/

/* SAVE DATA */

/* LOAD DATA */

loadPlayers() {
	if (!hns_is_knife_map())
		g_bPlayersListLoaded = PDS_GetString("playerslist", g_szBuffer, charsmax(g_szBuffer));

	if (g_bPlayersListLoaded) {
		new JSON:JSArray = json_parse(g_szBuffer);

		if (!json_is_array(JSArray)) {
			if (JSArray != Invalid_JSON)
				json_free(JSArray);

			server_print("[HNS-Match] ERROR! g_szBuffer value is not json array!");
			return;
		}

		if (g_bDebugMode) server_print("[MATCH] PLR LOAD | g_szBuffer (%s)", g_szBuffer)

		for (new i = 0; i < json_array_get_count(JSArray); i++) {
			new JSON:JSValue = json_array_get_value(JSArray, i);

			switch (json_get_type(JSValue)) {
				case JSONString: {
					if (g_bDebugMode) {
						new szIndexName[16];
						json_array_get_string(JSArray, i, szIndexName, charsmax(szIndexName))
						server_print("[MATCH] PLR LOAD | szIndexName (%s)", szIndexName);
					}
				}
				case JSONObject: {
					if (!g_aPlayersLoadData) {
						server_print("FAIL")
						return;
					}

					new eTmpPlayer[SAVE_PLAYER_DATA], iNumGet;

					for (new j = 0; j < json_object_get_count(JSValue); j++) {

						new JSON:JSData = json_object_get_value_at(JSValue, j);

						new szDataName[32];
						json_object_get_name(JSValue, j, szDataName, charsmax(szDataName));
						//if (g_bDebugMode) server_print("[MATCH] PLR LOAD | szDataName (%s)", szDataName)

						if(equal(szDataName, NAME_DATA_AUTH)) { // plr_auth
							json_get_string(JSData, eTmpPlayer[SAVE_AUTH], charsmax(eTmpPlayer[SAVE_AUTH]));
							iNumGet++;
							//if (g_bDebugMode) server_print("[MATCH] PLR LOAD | json_get_string (%s)", eTmpPlayer[SAVE_AUTH])
						} else if (equal(szDataName, NAME_DATA_TEAM)) { // plr_team
							eTmpPlayer[SAVE_TEAM] = _:json_get_number(JSData);
							//if (g_bDebugMode) server_print("[MATCH] PLR LOAD | json_get_number (%d)", eTmpPlayer[SAVE_TEAM])
							iNumGet++;
						} else {
							if (g_bDebugMode) server_print("[MATCH] PLR LOAD | А? )")
						}

						if (iNumGet == 2) {
							if (g_bDebugMode) server_print("[MATCH] PLR LOAD | eTmpPlayer (%s %d)", eTmpPlayer[SAVE_AUTH], _:eTmpPlayer[SAVE_TEAM])

							ArrayPushArray(g_aPlayersLoadData, eTmpPlayer);

							arrayset(eTmpPlayer, 0, SAVE_PLAYER_DATA);
							iNumGet = 0;
						}

						json_free(JSData);
					}
				}
			}

			json_free(JSValue);
		}

		json_free(JSArray);
	}
}

/* LOAD DATA */

stock save_reset_data() {
	g_bPlayersListLoaded = false;
	g_szBuffer = "";
}