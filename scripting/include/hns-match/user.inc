#if defined _user_included
  #endinput
#endif

#define _user_included

// Присвоить игроку роль
stock hns_set_user_role(id, PLAYER_ROLES:eRole) {
	g_ePlayerInfo[id][PLAYER_ROLE] = eRole;
	g_ePlayerInfo[id][PLAYER_MATCH] = true;

	LogSendMessage("[MATCH] Player (%n) set role (%d)", id, g_ePlayerInfo[id][PLAYER_ROLE]);
}

// Если игрок имеет указаную роль
stock bool:hns_is_user_role(id, PLAYER_ROLES:eRole) {
	if (g_ePlayerInfo[id][PLAYER_ROLE] == eRole) {
		return true;
	}

	return false;
}

// Получить id капитана указанной роли
stock hns_get_captain_role(PLAYER_ROLES:eRole) {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];

		if (g_ePlayerInfo[id][PLAYER_ROLE] == eRole) {
			return id;
		}
	}

	return 0;
}

// На основе ролей проверяет и распределяет по командам
stock hns_distribute_roles_teams() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];

		switch (g_ePlayerInfo[id][PLAYER_ROLE]) {
			case ROLE_SPEC: {
				if (getUserTeam(id) != TEAM_SPECTATOR) {
					transferUserToSpec(id);
				}
			}
			case ROLE_CAP_A, ROLE_TEAM_A: {
				if (getUserTeam(id) != TEAM_TERRORIST) {
					rg_set_user_team(id, TEAM_TERRORIST);
					rg_round_respawn(id);
				}
			}
			case ROLE_CAP_B, ROLE_TEAM_B: {
				if (getUserTeam(id) != TEAM_CT) {
					rg_set_user_team(id, TEAM_CT);
					rg_round_respawn(id);
				}
			}
		}
	}
}

stock getUserKey(id) {
	new szAuth[24];
	get_user_authid(id, szAuth, charsmax(szAuth));
	return szAuth;
}

stock TeamName:getUserTeam(id) {
	return get_member(id, m_iTeam);
}

stock bool:getUserInMatch(id) {
	if (g_iCurrentMode != MODE_MIX)
		return false;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];

		if (getUserTeam(iPlayer) == TEAM_SPECTATOR)
			continue;

		if (id == iPlayer)
			return true;
	}
	return false;
}

stock bool:isUserWatcher(id) {
	if (get_user_flags(id) & read_flags(g_iSettings[WATCHER_FLAG]))
		return true;
	else
		return false;
}

stock bool:isUserFullWatcher(id) {
	if (get_user_flags(id) & read_flags(g_iSettings[FULL_WATCHER_FLAG]))
		return true;
	else
		return false;
}

stock bool:isUserAdmin(id) {
	if (get_user_flags(id) & read_flags(g_iSettings[ADMIN_FLAG]))
		return true;
	else
		return false;
}

stock setUserGodmode(index, godmode = 0) {
	set_entvar(index, var_takedamage, godmode == 1 ? DAMAGE_NO : DAMAGE_AIM);

	return 1;
}

stock transferUserToSpec(id) {
	setTeam(id, TEAM_SPECTATOR);
	set_entvar(id, var_solid, SOLID_NOT);
	set_entvar(id, var_movetype, MOVETYPE_FLY);
}

stock transferUsers(TeamName:iTeam) {
	new Float:flTime;
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		if (is_user_connected(id)) {
			switch (id) {
				case 1 ..8: flTime = 0.1;
				case 9 ..16: flTime = 0.2;
				case 17 ..24: flTime = 0.3;
				case 25 ..32: flTime = 0.4;
			}

			new taskParams[2];
			taskParams[0] = id;
			taskParams[1] = _:iTeam;

			set_task(flTime, "taskToTeam", id, taskParams, sizeof taskParams);
		}
	}
}

public taskToTeam(Params[]) {
	new id = Params[0];
	new team = Params[1];
	if (is_user_connected(id)) {
		if (is_user_alive(id))
			user_silentkill(id);

		if (getUserTeam(id) != TeamName:team)
			setTeam(id, TeamName:team);
	}
}

setTeam(id, TeamName:iTeam) {
	set_member(id, m_bTeamChanged, false);

	if (is_user_alive(id))
		user_silentkill(id);

	switch (iTeam) {
		case TEAM_TERRORIST: {
			rg_internal_cmd(id, "jointeam", "1");
			rg_internal_cmd(id, "joinclass", "5");
		}
		case TEAM_CT: {
			rg_internal_cmd(id, "jointeam", "2");
			rg_internal_cmd(id, "joinclass", "5");
		}
		case TEAM_SPECTATOR: {
			rg_internal_cmd(id, "jointeam", "6");
		}
	}
}


stock get_num_players_in_match(iIgnonePlayer = 0) {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	new numGameplr;
	for (new i; i < iNum; i++) {
		new tempid = iPlayers[i];

		if (iIgnonePlayer == tempid) {
			continue;
		}

		if (getUserTeam(tempid) != TEAM_TERRORIST && getUserTeam(tempid) != TEAM_CT) {
			continue;
		}

		numGameplr++;
	}
	return numGameplr;
}

stock bool:checkUserBan() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	new bool:foundPlayerBanned = false;

	for (new i; i < iNum; i++) {
		new tempid = iPlayers[i];
		if (getUserTeam(tempid) == TEAM_SPECTATOR) continue;

		if (!e_bBanned[tempid]) continue;

		chat_print(0, "%L", LANG_PLAYER, "BAN_PAUSE", tempid);
		transferUserToSpec(tempid);
		foundPlayerBanned = true;	
	}

	if (foundPlayerBanned && g_ModFuncs[g_iCurrentMode][MODEFUNC_PAUSE]) {
		ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_PAUSE], _);
	}

	return foundPlayerBanned;
}

stock bool:check_captain_role(TeamName:iTeam) {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		if (getUserTeam(id) == !iTeam) continue;

		if (g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_CAP_A || g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_CAP_B) {
		}
		
	}
}
