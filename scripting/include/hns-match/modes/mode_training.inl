public trainingmode_init() {
	g_ModFuncs[MODE_TRAINING][MODEFUNC_START]			= CreateOneForward(g_PluginId, "training_start");
	g_ModFuncs[MODE_TRAINING][MODEFUNC_PLAYER_LEAVE]	= CreateOneForward(g_PluginId, "training_player_leave", FP_CELL);
	g_ModFuncs[MODE_TRAINING][MODEFUNC_PLAYER_JOIN]		= CreateOneForward(g_PluginId, "training_player_join", FP_CELL);
}

public training_start() {
	g_iCurrentMode = MODE_TRAINING;
	ChangeGameplay(GAMEPLAY_TRAINING);
	hns_restart_round(1.0);
	set_cvars_mode(MODE_TRAINING);
}

public training_player_leave(id) {
  switch (g_iMatchStatus) {
    case MATCH_CAPTAINPICK: {
      if (g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_CAP_A || g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_CAP_B) {
        chat_print(0, "[^3HNSRU^1] Captain ^3%n^1 leave, stop captain mode.", id);
        captain_stop();
      }
    }
    case MATCH_TEAMPICK: {
      if (g_ePlayerInfo[id][PLAYER_ROLE] != ROLE_SPEC) {
        TrieSetArray(g_eMatchInfo[e_tLeaveData], getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);
      }
    }
  }
  
  arrayset(g_ePlayerInfo[id], 0, PLAYER_INFO);
}


public training_player_join(id) {
	TrieGetArray(g_eMatchInfo[e_tLeaveData], getUserKey(id), g_ePlayerInfo[id], PLAYER_INFO);

	if (g_iMatchStatus == MATCH_CAPTAINPICK || g_iMatchStatus == MATCH_TEAMPICK || g_iMatchStatus == MATCH_MAPPICK) {
		if (!hns_is_user_role(id, ROLE_SPEC)) {
			if (g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_TEAM_A || g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_CAP_A) {
				rg_set_user_team(id, TEAM_TERRORIST);
				rg_round_respawn(id);
			} else {
				rg_set_user_team(id, TEAM_CT);
				rg_round_respawn(id);
			}

			if (g_iMatchStatus == MATCH_TEAMPICK && (g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_CAP_A || g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_CAP_B)) {
				if (g_iCaptainPick == -1) {
					LogSendMessage("[MATCH] (g_iCaptainPick == -1) (%n)", id);
					if (g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_CAP_A) {
						g_iCaptainFirst = id;
						g_iCaptainPick = g_iCaptainFirst;
						get_user_authid(g_iCaptainPick, g_iCaptainPickSteam, charsmax(g_iCaptainPickSteam))
					} else {
						g_iCaptainSecond = id;
						g_iCaptainPick = g_iCaptainSecond;
						get_user_authid(g_iCaptainPick, g_iCaptainPickSteam, charsmax(g_iCaptainPickSteam))
					}

					if (task_exists(TASK_WAITLEAVECAP)) {
						remove_task(TASK_WAITLEAVECAP);
					}
					
					pickMenu(g_iCaptainPick, true);
				} else if (g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_CAP_A) {
					if (hns_get_role_num(ROLE_CAP_A) > 1) {
						g_ePlayerInfo[id][PLAYER_ROLE] = ROLE_TEAM_A;
					} else {
						new szTmpAuth[MAX_AUTHID_LENGTH]
						get_user_authid(g_iCaptainPick, szTmpAuth, charsmax(szTmpAuth))
						if (equal(g_iCaptainPickSteam, szTmpAuth)) {
							g_iCaptainFirst = id;
							g_iCaptainPick = g_iCaptainFirst;
						}
					}
				} else if (g_ePlayerInfo[id][PLAYER_ROLE] == ROLE_CAP_B) {
					if (hns_get_role_num(ROLE_CAP_B) > 1) {
						g_ePlayerInfo[id][PLAYER_ROLE] = ROLE_TEAM_B;
					} else {
						new szTmpAuth[MAX_AUTHID_LENGTH]
						get_user_authid(g_iCaptainPick, szTmpAuth, charsmax(szTmpAuth))
						if (equal(g_iCaptainPickSteam, szTmpAuth)) {
							g_iCaptainSecond = id;
							g_iCaptainPick = g_iCaptainSecond;
						}
					}
				}
			}

		} else {
			transferUserToSpec(id);
		}
		return;
	}
	
	if (equali(g_szMapName, g_iSettings[KNIFEMAP])) {
		rg_round_respawn(id);
		return;
	}

	if (g_bPlayersListLoaded) {
		if (!checkPlayer(id))
			transferUserToSpec(id);
		else
			rg_round_respawn(id);
	}
	else
		rg_round_respawn(id);
}