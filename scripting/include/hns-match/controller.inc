#if defined _controller_included
  #endinput
#endif

#define _controller_included

public ControllerReset() {
	Controller_EnsureStorage();

	ArrayClear(g_aController);
	TrieClear(g_tControllerByAuth);

	g_bControllerInitialized = false;
}

public ControllerInit() {
	if (g_bControllerInitialized) {
		return;
	}

	Controller_EnsureStorage();

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];

		new szSteamId[MAX_AUTHID_LENGTH];
		get_user_authid(id, szSteamId, charsmax(szSteamId));
		if (!szSteamId[0] || equal(szSteamId, "STEAM_ID_PENDING") || equal(szSteamId, "VALVE_ID_PENDING")) {
			continue;
		}

		if (getUserTeam(id) != TEAM_TERRORIST && getUserTeam(id) != TEAM_CT) {
			continue;
		}

		new ePlayer[PLAYERS_MATCH];
		new iIndex = Controller_FindIndexBySteam(szSteamId);
		if (iIndex >= 0) {
			ArrayGetArray(g_aController, iIndex, ePlayer);
		}

		// Стим айди
		copy(ePlayer[PM_STEAMID], charsmax(ePlayer[PM_STEAMID]), szSteamId);

		// Роль
		if (getUserTeam(id) == TEAM_TERRORIST) {
			ePlayer[PM_ROLE] = ROLE_TEAM_A;
		} else {
			ePlayer[PM_ROLE] = ROLE_TEAM_B;
		}

		if (getUserTeam(id) == TEAM_TERRORIST) {
			ePlayer[TEAM_MATCH] = HNS_TEAM_A;
		} else {
			ePlayer[TEAM_MATCH] = HNS_TEAM_B;
		}
		
		// Статус игрока
		ePlayer[PM_STATUS] = STATUS_ACTIVE;

		// Команда игрока в игре
		ePlayer[TEAM_GAME] = getUserTeam(id);

		if (iIndex >= 0) {
			ArraySetArray(g_aController, iIndex, ePlayer);
		} else {
			ArrayPushArray(g_aController, ePlayer);
			TrieSetCell(g_tControllerByAuth, szSteamId, ArraySize(g_aController) - 1);
		}
	}

	g_bControllerInitialized = true;
}

public ControllerCheck() {
	if (!g_bControllerInitialized) {
		return;
	}

	Controller_EnsureStorage();

	// Ставим всем активным статус лив
	new iSize = ArraySize(g_aController);

	for (new i = 0; i < iSize; i++) {
		new ePlayer[PLAYERS_MATCH];
		ArrayGetArray(g_aController, i, ePlayer);

		if (ePlayer[PM_STATUS] == STATUS_ACTIVE) {
			ePlayer[PM_STATUS] = STATUS_LEFT;
			ArraySetArray(g_aController, i, ePlayer);
		}
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];

		new szSteamId[MAX_AUTHID_LENGTH];
		get_user_authid(id, szSteamId, charsmax(szSteamId));
		if (!szSteamId[0] || equal(szSteamId, "STEAM_ID_PENDING") || equal(szSteamId, "VALVE_ID_PENDING")) {
			continue;
		}

		if (getUserTeam(id) != TEAM_TERRORIST && getUserTeam(id) != TEAM_CT) {
			continue;
		}

		new ePlayer[PLAYERS_MATCH];
		new iIndex = Controller_FindIndexBySteam(szSteamId);
		if (iIndex >= 0) {
			ArrayGetArray(g_aController, iIndex, ePlayer);
		}

		// Стим айди
		copy(ePlayer[PM_STEAMID], charsmax(ePlayer[PM_STEAMID]), szSteamId);

		// Роль
		if (g_isTeamTT == HNS_TEAM_A) {
			if (getUserTeam(id) == TEAM_TERRORIST) {
				ePlayer[PM_ROLE] = ROLE_TEAM_A;
			} else {
				ePlayer[PM_ROLE] = ROLE_TEAM_B;
			}
		} else {
			if (getUserTeam(id) == TEAM_TERRORIST) {
				ePlayer[PM_ROLE] = ROLE_TEAM_B;
			} else {
				ePlayer[PM_ROLE] = ROLE_TEAM_A;
			}
		}

		if (g_isTeamTT == HNS_TEAM_A) {
			if (getUserTeam(id) == TEAM_TERRORIST) {
				ePlayer[TEAM_MATCH] = HNS_TEAM_A;
			} else {
				ePlayer[TEAM_MATCH] = HNS_TEAM_B;
			}
		} else {
			if (getUserTeam(id) == TEAM_TERRORIST) {
				ePlayer[TEAM_MATCH] = HNS_TEAM_B;
			} else {
				ePlayer[TEAM_MATCH] = HNS_TEAM_A;
			}
		}

		ePlayer[PM_STATUS] = STATUS_ACTIVE;

		ePlayer[TEAM_GAME] = getUserTeam(id);

		if (iIndex >= 0) {
			ArraySetArray(g_aController, iIndex, ePlayer);
		} else {
			ArrayPushArray(g_aController, ePlayer);
			TrieSetCell(g_tControllerByAuth, szSteamId, ArraySize(g_aController) - 1);
		}
	}

	ExecuteForward(g_hForwards[CONTROLLER_APPLY]);
}

public ControllerDestroy() {
	if (g_aController != Invalid_Array) {
		ArrayDestroy(g_aController);
		g_aController = Invalid_Array;
	}

	if (g_tControllerByAuth != Invalid_Trie) {
		TrieDestroy(g_tControllerByAuth);
		g_tControllerByAuth = Invalid_Trie;
	}

	g_bControllerInitialized = false;
}


/* ----- UTILS -----*/

stock Controller_EnsureStorage() {
	if (g_aController == Invalid_Array) {
		g_aController = ArrayCreate(PLAYERS_MATCH, 32);
	}

	if (g_tControllerByAuth == Invalid_Trie) {
		g_tControllerByAuth = TrieCreate();
	}
}

stock Controller_FindIndexBySteam(const szSteamId[]) {
	if (g_tControllerByAuth == Invalid_Trie) {
		return -1;
	}

	new iIndex;
	if (TrieGetCell(g_tControllerByAuth, szSteamId, iIndex)) {
		return iIndex;
	}

	return -1;
}

/* ----- UTILS -----*/
