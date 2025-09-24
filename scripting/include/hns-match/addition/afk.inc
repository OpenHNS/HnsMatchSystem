#if defined _afk_included
  #endinput
#endif

#define _afk_included

const TASK_AFK = 77832;

enum _:AfkData_s {
	bool:is_afk,
	afk_timer
};

new eAfkData[MAX_PLAYERS + 1][AfkData_s];
new iPlayersAfk;

new Float:flAfkOrigin[MAX_PLAYERS + 1][3];

public taskCheckAfk() {
	if(task_exists(TASK_AFK)) {
		return;
	}

	if (g_eMatchState != STATE_ENABLED) {
		ResetAfkData();
		return;
	}

	if (g_iCurrentMode != MODE_MIX && g_iMatchStatus != MATCH_TEAMKNIFE) {
		ResetAfkData();
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ach");

	for(new i; i < iNum; i++) {
		new id = iPlayers[i];

		if (PlayerIsAfk(id)) {
			eAfkData[id][is_afk] = true;
			iPlayersAfk++;
		}
	}

	if (iPlayersAfk) {
		if(task_exists(TASK_AFK))
			remove_task(TASK_AFK);

		switch (g_iCurrentMode){
			case MODE_KNIFE: {
				kniferound_pause()
			}
			case MODE_MIX:{
				mix_pause();
			}
		}
		
		chat_print(0, "%L", LANG_PLAYER, "AFK_PAUSE", iPlayersAfk);
		set_task(1.0, "taskAfk", .id = TASK_AFK, .flags = "b");
	}
}

public taskAfk() {
	if (g_eMatchState != STATE_PAUSED) {
		ResetAfkData();
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum, szBuffer[512];
	get_players(iPlayers, iNum, "ch");

	add(szBuffer, charsmax(szBuffer), "AFK Players [wait time]:^n");

	for(new i; i < iNum; i++) {
		new id = iPlayers[i];
		new szTime[16];

		if (eAfkData[id][is_afk]) {
			if (getUserTeam(id) == TEAM_SPECTATOR || !is_user_alive(id)) {
				arrayset(eAfkData[id], 0, AfkData_s);
				arrayset(flAfkOrigin[id], 0.0, sizeof(flAfkOrigin[]));
				iPlayersAfk--;
				continue;
			}

			if (!PlayerIsAfk(id)) {
				arrayset(eAfkData[id], 0, AfkData_s);
				arrayset(flAfkOrigin[id], 0.0, sizeof(flAfkOrigin[]));
				iPlayersAfk--;
			} else {
				eAfkData[id][afk_timer]++;
				fnConvertTime(eAfkData[id][afk_timer] * 1.0, szTime, 23, false);
				add(szBuffer, charsmax(szBuffer), fmt("%n (%s)^n", id, szTime));
			}
		}
	}

	if (!iPlayersAfk) {
		if (g_ModFuncs[g_iCurrentMode][MODEFUNC_UNPAUSE])
			ExecuteForward(g_ModFuncs[g_iCurrentMode][MODEFUNC_UNPAUSE], _);
			
		chat_print(0, "%L", LANG_PLAYER, "AFK_UNPAUSE");

		if(task_exists(TASK_AFK))
			remove_task(TASK_AFK);
	} else {
		set_hudmessage(.red = 100, .green = 100, .blue = 100, .x = 0.01, .y = 0.23, .holdtime = 1.0);
		show_hudmessage(0, "%s", szBuffer);
	}
}

ResetAfkData() {
	if(task_exists(TASK_AFK)) {
		remove_task(TASK_AFK);
	}
		
	iPlayersAfk = 0;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for(new i; i < iNum; i++) {
		new id = iPlayers[i];
		arrayset(eAfkData[id], 0, AfkData_s);
		arrayset(flAfkOrigin[id], 0.0, sizeof(flAfkOrigin[]));
	}
}

stock bool:PlayerIsAfk(id) {
	new Float:origin[3]; get_entvar(id, var_origin, origin);

	if (getUserTeam(id) == TEAM_CT && get_member_game(m_bFreezePeriod)) {
		return false;
	}

	if (get_distance_f(flAfkOrigin[id], origin) <= 1.0)
		return true;

	return false;
}

public taskSaveAfk() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ach");

	for(new i; i < iNum; i++) {
		new id = iPlayers[i];
		get_entvar(id, var_origin, flAfkOrigin[id]);
	}
}
