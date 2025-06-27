#include <amxmodx>
#include <amxmisc>
#include <reapi>

#include <hns_matchsystem>
#include <hns_matchsystem_filter>
#include <hns_matchsystem_dbmysql>
#include <hns_matchsystem_api>
#include <hns_matchsystem_stats>
#include <hns_matchsystem_bans>

#define TASK_SHOWBEST 1328

new g_szPrefix[24];

new bool:g_HudOnOff[MAX_PLAYERS + 1];
new bool:g_HudRoundOnOff[MAX_PLAYERS + 1];

new bool:g_bDmgThisRound[MAX_PLAYERS + 1];
new Float:g_flHealthBefore[MAX_PLAYERS + 1];
new Float:g_flDmg[MAX_PLAYERS + 1];
new Float:g_flDmgTime[MAX_PLAYERS + 1];
new Float:g_flCmdNextUseTime[MAX_PLAYERS + 1];

new g_MsgSync;
new g_RoundSync;

new best_auth[10][MAX_AUTHID_LENGTH];

new Float:g_flShowRoundStats = 0.0;

new g_szMess[1024];

enum _: SHOW_STATS {
	PLR_STATS_STABS,
	PLR_STATS_DMG_CT,
	PLR_STATS_DMG_TT,
	Float:PLR_STATS_FLASHTIME,
	PLR_STATS_OWNAGES,
}

new g_eRoundBests[MAX_PLAYERS + 1][SHOW_STATS];

new g_eBestIndex[SHOW_STATS];
new g_eBestStats[SHOW_STATS];

enum _: SPEC_DATA {
	bool:SHOW_SPEC,
	bool:SPEC_HIDE,
	bool:IS_SPEC,
	SPEC_TARGET,
	bool:IS_POV
}

new g_eSpecPlayers[MAX_PLAYERS + 1][SPEC_DATA];

public plugin_natives() {
	set_native_filter("match_system_additons");
}

public plugin_init() {
	register_plugin("Match: Player info", "1.1", "OpenHNS");

	register_clcmd("say", "sayHandle");

	RegisterSayCmd("hud", "hudinfo", "cmdHudInfo", 0, "Show hud info");
	RegisterSayCmd("ri", "roundinfo", "cmdRoundInfo", 0, "Show hud info");
	RegisterSayCmd("top", "tops", "ShowTop", 0, "Show top");
	RegisterSayCmd("showspec", "speclist", "cmdShowSpec", 0, "On/Off speclist");
	RegisterSayCmd("spechide", "hidespec", "cmdSpecHide", 0, "Spec hide");

	RegisterHookChain(RG_CBasePlayer_TakeDamage, "rgTakeDamage", true);

	set_task(1.0, "task_ShowPlayerInfo", .flags = "b");

	RegisterHookChain(RG_CBasePlayer_Spawn, "rgPlayerSpawn", false);
	RegisterHookChain(RG_CBasePlayer_Observer_SetMode,"RG_CBasePlayerObserverSetMode_Pre", .post = true);
	RegisterHookChain(RG_CBasePlayer_Observer_FindNextPlayer,"RG_CBasePlayerObserverFindNextPlayer_Post", .post = true);
	
	g_MsgSync = CreateHudSyncObj();
	g_RoundSync = CreateHudSyncObj();
}

public client_disconnected(id) {
	if (g_eSpecPlayers[id][IS_SPEC]) {
		arrayset(g_eSpecPlayers[id], 0, SPEC_DATA);
	}

	g_HudOnOff[id] = false;
	g_HudRoundOnOff[id] = false;

	g_bDmgThisRound[id] = false;
	g_flHealthBefore[id] = 0.0;
	g_flDmg[id] = 0.0;
	g_flDmgTime[id] = 0.0;
	g_flCmdNextUseTime[id] = 0.0;

	arrayset(g_eRoundBests[id], 0, SHOW_STATS);
}

public rgPlayerSpawn(id) {
	if (g_eSpecPlayers[id][IS_SPEC]) {
		arrayset(g_eSpecPlayers[id][IS_SPEC], 0, SPEC_DATA);
	}
}

public RG_CBasePlayerObserverSetMode_Pre(const id, iMode) {
	new iLastMode = get_member(id, m_iObserverLastMode);
	if (iLastMode != OBS_CHASE_FREE && iLastMode != OBS_IN_EYE) {
		g_eSpecPlayers[id][SPEC_TARGET] = 0;
		return HC_CONTINUE;
	}

	new iTarget = get_member(id, m_hObserverTarget);

	g_eSpecPlayers[id][IS_SPEC] = true;
	g_eSpecPlayers[id][SPEC_TARGET] = iTarget;
	g_eSpecPlayers[id][IS_POV] = bool:(iLastMode == OBS_IN_EYE);
	
	return HC_CONTINUE;
}

public RG_CBasePlayerObserverFindNextPlayer_Post(const id) {
	new iTarget = get_member(id, m_hObserverTarget);

	g_eSpecPlayers[id][IS_SPEC] = true;
	g_eSpecPlayers[id][SPEC_TARGET] = iTarget;
}

public plugin_cfg() {
	hns_get_prefix(g_szPrefix, charsmax(g_szPrefix));
}

public client_putinserver(id) {
	g_HudOnOff[id] = true;
	g_HudRoundOnOff[id] = true;
	g_eSpecPlayers[id][SHOW_SPEC] = true;
	g_eSpecPlayers[id][SPEC_HIDE] = false;
}

public sayHandle(id) {
	new szArgs[64];
	read_args(szArgs, charsmax(szArgs));
	remove_quotes(szArgs);
	trim(szArgs);

	if (szArgs[0] != '/') {
		return PLUGIN_CONTINUE;
	}

	new pattern[32];
	strtok2(szArgs, szArgs, charsmax(szArgs), pattern, charsmax(pattern), ' ');

	if(!equali(szArgs, "/dmg")) {
		return PLUGIN_CONTINUE;
	}

	trim(pattern);

	new Float:flGameTime = get_gametime();

	if(g_flCmdNextUseTime[id] > flGameTime) {
		client_print_color(id, print_team_blue, "%L", id, "DMG_SPAM", g_szPrefix, g_flCmdNextUseTime[id] - flGameTime);
		return PLUGIN_CONTINUE;
	}

	g_flCmdNextUseTime[id] = flGameTime + 5.0; // 5 sec

	new iTarget = pattern[0] ? cmd_target(id, pattern, CMDTARGET_ALLOW_SELF) : id;

	if (!iTarget) {
		client_print_color(id, print_team_blue, "%L", id, "DMG_ERR", g_szPrefix, pattern);
		return PLUGIN_CONTINUE;
	}

	if (g_flDmg[iTarget]) {
		if (g_bDmgThisRound[iTarget]) {
			client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "DMG_SHOW_ROUND", g_szPrefix, iTarget, g_flDmg[iTarget], g_flHealthBefore[iTarget], get_gametime() - g_flDmgTime[iTarget]);
		} else {
			client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "DMG_SHOW", g_szPrefix, iTarget, g_flDmg[iTarget], g_flHealthBefore[iTarget], get_gametime() - g_flDmgTime[iTarget]);
		}
	} else {
		client_print_color(id, print_team_blue, "%L", id, "DMG_ERR", g_szPrefix, pattern);
		return PLUGIN_CONTINUE;
	}

	return PLUGIN_CONTINUE;
}

public cmdHudInfo(id) {
	g_HudOnOff[id] = !g_HudOnOff[id];

	if (g_HudOnOff[id]) {
		client_print_color(id, print_team_blue, "%L", id, "HUD_ON", g_szPrefix);
	} else {
		client_print_color(id, print_team_blue, "%L", id, "HUD_OFF", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}

public cmdRoundInfo(id) {
	g_HudRoundOnOff[id] = !g_HudRoundOnOff[id];

	if (g_HudRoundOnOff[id]) {
		client_print_color(id, print_team_blue, "%L", id, "ROUNDINFO_ON", g_szPrefix);
	} else {
		client_print_color(id, print_team_blue, "%L", id, "ROUNDINFO_OFF", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}

public cmdShowSpec(id) {
	g_eSpecPlayers[id][SHOW_SPEC] = !g_eSpecPlayers[id][SHOW_SPEC];

	if (g_eSpecPlayers[id][SHOW_SPEC]) {
		client_print_color(id, print_team_blue, "%L", id, "SPECLIST_ON", g_szPrefix);
	} else {
		client_print_color(id, print_team_blue, "%L", id, "SPECLIST_OFF", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}

public cmdSpecHide(id) {
	g_eSpecPlayers[id][SPEC_HIDE] = !g_eSpecPlayers[id][SPEC_HIDE];

	if (g_eSpecPlayers[id][SPEC_HIDE]) {
		client_print_color(id, print_team_blue, "%L", id, "SPECHIDE_ON", g_szPrefix);
	} else {
		client_print_color(id, print_team_blue, "%L", id, "SPECHIDE_OFF", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}

public hns_round_end() {
	if (hns_get_mode() != MODE_MIX || hns_get_state() == STATE_PAUSED || hns_get_status() != MATCH_STARTED) {
		reset_best_players();
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	new bool:bShowBest;

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];

		g_eRoundBests[id][PLR_STATS_OWNAGES] = hns_get_stats_ownages(STATS_ROUND, id);
		g_eRoundBests[id][PLR_STATS_STABS] = hns_get_stats_stabs(STATS_ROUND, id);
		g_eRoundBests[id][PLR_STATS_DMG_CT] = hns_get_stats_dmg_ct(STATS_ROUND, id);
		g_eRoundBests[id][PLR_STATS_DMG_TT] =  hns_get_stats_dmg_tt(STATS_ROUND, id);
		g_eRoundBests[id][PLR_STATS_FLASHTIME] = hns_get_stats_flashtime(STATS_ROUND, id);
				
		for (new j = 0; j < SHOW_STATS; j++) {
			if (g_eRoundBests[id][j] > g_eBestStats[j])
			{
				g_eBestStats[j] = g_eRoundBests[id][j];
				g_eBestIndex[j] = id;
				bShowBest = true;
			}
		}
	}

	if (!bShowBest) {
		return;
	}

	new iLen = format(g_szMess, sizeof g_szMess - 1, "Best players of the round:^n^n");
	if (g_eBestIndex[PLR_STATS_OWNAGES])	iLen += format(g_szMess[iLen], sizeof g_szMess - iLen, "Ownages: %n - %d^n", g_eBestIndex[PLR_STATS_OWNAGES], g_eBestStats[PLR_STATS_OWNAGES])
	if (g_eBestIndex[PLR_STATS_STABS])		iLen += format(g_szMess[iLen], sizeof g_szMess - iLen, "Stabs: %n - %d^n", g_eBestIndex[PLR_STATS_STABS], g_eBestStats[PLR_STATS_STABS])
	if (g_eBestIndex[PLR_STATS_DMG_CT])		iLen += format(g_szMess[iLen], sizeof g_szMess - iLen, "CT Dmg: %n - %d^n", g_eBestIndex[PLR_STATS_DMG_CT], g_eBestStats[PLR_STATS_DMG_CT])
	if (g_eBestIndex[PLR_STATS_DMG_TT])		iLen += format(g_szMess[iLen], sizeof g_szMess - iLen, "TT Dmg: %n - %d^n", g_eBestIndex[PLR_STATS_DMG_TT], g_eBestStats[PLR_STATS_DMG_TT])
	if (g_eBestIndex[PLR_STATS_FLASHTIME]) 	iLen += format(g_szMess[iLen], sizeof g_szMess - iLen, "Flashed: %n - %.2f^n", g_eBestIndex[PLR_STATS_FLASHTIME], g_eBestStats[PLR_STATS_FLASHTIME])

	g_flShowRoundStats = get_gametime() + 10.0;
	set_task(1.0, "taskShowBestRound", TASK_SHOWBEST, .flags = "b");
}

public taskShowBestRound() {
	if (g_flShowRoundStats < get_gametime()) {
		reset_best_players();
		remove_task(TASK_SHOWBEST);
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
	
		if (!is_user_connected(id) || !g_HudRoundOnOff[id]) {
			continue;
		}

		set_hudmessage(.red = 100, .green = 100, .blue = 100, .x = 0.1, .y = -1.0, .fxtime = 0.0, .holdtime = 1.0);
		ShowSyncHudMsg(id, g_RoundSync, g_szMess);
	}
}

public hns_round_start() {
	if (g_flShowRoundStats < get_gametime() && hns_get_mode() == MODE_MIX) {
		reset_best_players();
	}
	arrayset(g_bDmgThisRound, false, sizeof(g_bDmgThisRound));
}

public hns_round_freezeend() {
	if (hns_get_mode() == MODE_MIX) {
		reset_best_players();
	}
}

public hns_match_started() {
	reset_best_players();
	for (new i; i < 10; i++) {
		best_auth[i] = "";
	}
}

public hns_match_stopped_post() {
	client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "STATS_TOP", g_szPrefix);
	ShowTop(0);
	reset_best_players();
}

public hns_match_surrendered() {
	client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "STATS_TOP", g_szPrefix);
	ShowTop(0);
	reset_best_players();
}

public hns_match_finished() {
	client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "STATS_TOP", g_szPrefix);
	ShowTop(0);
	reset_best_players();
}

public ShowTop(player) {
	if (!player) {
		new Float:best_time[10];
		new iPlayers[MAX_PLAYERS], iNum;
		get_players(iPlayers, iNum, "ch");
		new bid = 0;
		for (new i; i < iNum; i++) {
			new id = iPlayers[i];

			if (rg_get_user_team(id) == TEAM_SPECTATOR)
				continue;

			if (bid >= 10)
				break;

			get_user_authid(id, best_auth[bid], charsmax(best_auth[]));
			best_time[bid] = hns_get_stats_surv(STATS_ALL, id);
			bid++;
		}

		for (new i = 0; i < 10; i++) {
			for (new j = 0; j < 10; j++) {
				if (best_time[j] < best_time[i]) {
					new Float:tmp = best_time[i];
					new tmpauth[MAX_AUTHID_LENGTH];
					copy(tmpauth, charsmax(tmpauth), best_auth[i]);
					best_time[i] = best_time[j];
					best_time[j] = tmp;
					copy(best_auth[i], charsmax(best_auth[]), best_auth[j]);
					copy(best_auth[j], charsmax(best_auth[]), tmpauth);
				}
			}
		}
	}
	new szMotd[MAX_MOTD_LENGTH], iLen; // TODO: Добавить овнеджи, сделать столько стабы
	iLen = formatex(szMotd, charsmax(szMotd), "<html><head><meta charset=UTF-8>\
					<link rel=^"stylesheet^" href=^"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css^">\
					</head>\
						<body>\
							<div id=^"wrapper^">\
								<table id=^"keywords^" cellspacing=^"0^" cellpadding=^"0^" class=^"table^">\
									<thead>\
										<tr>\
										<th>Player</th>\
										<th>SDA</th>\
										<th>Survive time</th>\
										<th>DMG</th>\
										<th>RUN</th>\
										<th>Flash time</th>\
										<th>Stabs</th>\
										</tr>\
									</thead>\
									<tbody>");
	new surv_time[24]; new flash_time[24];
	for (new i = 0; i < 10; i++) {
		new id = find_player_ex(FindPlayer_MatchAuthId, best_auth[i]);

		if (!is_user_connected(id))
			continue;

		new Float:fS, Float:fD, Float:fA;
		fS = float(hns_get_stats_stabs(STATS_ALL, id));
		fD = float(hns_get_stats_deaths(STATS_ALL, id));
		fA = float(hns_get_stats_assists(STATS_ALL, id));

		fnConvertTime(hns_get_stats_surv(STATS_ALL, id), surv_time, 23);
		fnConvertTime(hns_get_stats_flashtime(STATS_ALL, id), flash_time, 23);
		iLen += formatex(szMotd[iLen], charsmax(szMotd) - iLen, "<tr> \
		<td>%n</td> \
		<td>%.1f</td> \
		<td>%s</td> \
		<td>%d</td> \
		<td>%.1fK</td> \
		<td>%s</td> \
		<td>%d</td> \
		</tr>",
			id,
			floatdiv(floatadd(fS, fA), fD),
			surv_time,
			hns_get_stats_dmg_tt(STATS_ALL, id) + hns_get_stats_dmg_ct(STATS_ALL, id),
			hns_get_stats_runned(STATS_ALL, id) / 1000.0,
			flash_time,
			hns_get_stats_stabs(STATS_ALL, id));
	}
	iLen += formatex(szMotd[iLen], charsmax(szMotd) - iLen, "</tbody>\
								</table>\
							</div>\
						</body>\
						</html>");
	show_motd(player, szMotd);
	//log_to_file("motd.txt", szMotd);
}

public rgTakeDamage(victim, inflictor, attacker, Float:damage, damagebits) {
	if (~damagebits & DMG_FALL || damage < 1.0) {
		return;
	}

	g_flDmg[victim] = damage;
	g_flDmgTime[victim] = get_gametime();
	get_entvar(victim, var_health, g_flHealthBefore[victim]);
	g_flHealthBefore[victim] += damage;
	g_bDmgThisRound[victim] = true;
}

public task_ShowPlayerInfo() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for(new i; i < iNum; i++) {
		new id = iPlayers[i];

		if(!is_user_connected(id)) {
			continue;
		}

		new show_id = is_user_alive(id) ? id : get_entvar(id, var_iuser2);

		if (!show_id) {
			continue;
		}

		if (g_HudOnOff[id]) {
			set_hudmessage(.red = 100, .green = 100, .blue = 100, .x = 0.01, .y = 0.25, .holdtime = 1.0);
			new szHudMess[1024], iLen;
			//if (show_id != id) {
				if (hns_mysql_stats_init()) {
					iLen += format(szHudMess[iLen], sizeof szHudMess - iLen, "\
					Player: %n (#%d)^n\
					PTS: %d [%s]^n^n", 
					show_id, hns_mysql_stats_data(show_id, e_iTop),
					hns_mysql_stats_data(show_id, e_iPts), hns_mysql_stats_skill(show_id));
				} else if (hns_api_stats_init()) {
					new szSkill[10];
					hns_api_stats_rank(show_id, GET_GOOD, szSkill, charsmax(szSkill))

					iLen += format(szHudMess[iLen], sizeof szHudMess - iLen, "\
					Player: %n (#%d)^n\
					PTS: %d [%s]^n^n", 
					show_id, hns_api_stats_place(show_id, GET_GOOD),
					hns_api_stats_rating(show_id, GET_GOOD), szSkill);
				} else {
					iLen += format(szHudMess[iLen], sizeof szHudMess - iLen, "\
					Player: %n^n^n", 
					show_id);	
				}
			//}

			if (hns_get_mode() == MODE_MIX && hns_get_state() != STATE_PAUSED && hns_get_rules() != RULES_DUEL) {
				new szTime[24];
				fnConvertTime(hns_get_stats_surv(STATS_ALL, show_id), szTime, charsmax(szTime), false);
				iLen += format(szHudMess[iLen], sizeof szHudMess - iLen, "\
				Survive time: %s^n\
				Stabs: %d^n",
				szTime,
				hns_get_stats_stabs(STATS_ALL, show_id));
			}
			else  if (hns_get_mode() == MODE_MIX && hns_get_state() != STATE_PAUSED && hns_get_rules() == RULES_DUEL) {
				iLen += format(szHudMess[iLen], sizeof szHudMess - iLen, "\
				Stabs: %d^n",
				hns_get_stats_stabs(STATS_ALL, show_id));
			}

			if (g_bHnsBannedInit) {
				if (e_bBanned[id]) {
					iLen += format(szHudMess[iLen], sizeof szHudMess - iLen, "You are banned from matches: %s^n", secondsToDHM(g_iBanExpired[id] - get_systime()));
				}
			}


			if (hns_get_status() != MATCH_NONE && hns_get_status() != MATCH_STARTED && hns_get_state() != STATE_PAUSED) {
				iLen += format(szHudMess[iLen], sizeof szHudMess - iLen, "%s", get_matchstats_str(hns_get_status()));
			}

			new szSpecMess[512], iSpecLen;
			new iSpecNum;
			for (new j = 0; j < MAX_PLAYERS; j++) {
				if (!g_eSpecPlayers[id][SHOW_SPEC]) {
					break;
				}

				if (!g_eSpecPlayers[j][IS_SPEC]) {
					continue;
				}

				if (g_eSpecPlayers[j][SPEC_HIDE]) {
					continue;
				}

				if (!is_user_connected(j)) {
					continue;
				}

				if (g_eSpecPlayers[j][SPEC_TARGET] == show_id) {
					iSpecNum++;
					iSpecLen += format(szSpecMess[iSpecLen], sizeof szSpecMess - iSpecLen, "%n%s^n", j, g_eSpecPlayers[j][IS_POV] ? "" : " [3rd Person]");
				}
			}

			if (iSpecNum) {
				iLen += format(szHudMess[iLen], sizeof szHudMess - iLen, "^nWatching [%d]^n%s", iSpecNum, szSpecMess);
			}

			ShowSyncHudMsg(id, g_MsgSync, "%s", szHudMess);
		}
	}
}

public get_matchstats_str(MATCH_STATUS:iStatus) {
	new szOut[32];
	switch (iStatus) {
		case MATCH_CAPTAINPICK .. MATCH_CAPTAINKNIFE: {
			formatex(szOut, charsmax(szOut), "Captain mode");
		}
		case MATCH_TEAMPICK: {
			formatex(szOut, charsmax(szOut), "Team pick");
		}
		case MATCH_TEAMKNIFE: {
			formatex(szOut, charsmax(szOut), "Knife round");
		}
		case MATCH_MAPPICK: {
			formatex(szOut, charsmax(szOut), "Map pick");
		}
		case MATCH_WAITCONNECT: {
			formatex(szOut, charsmax(szOut), "Wait players");
		}
	}
	return szOut;
}

public reset_best_players() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		arrayset(g_eRoundBests[id], 0, SHOW_STATS);

	}

	remove_task(TASK_SHOWBEST);
	arrayset(g_eBestIndex, 0, SHOW_STATS);
	arrayset(g_eBestStats, 0, SHOW_STATS);
	arrayset(g_szMess, 0, 0);
	g_szMess[0] = 0;
}

stock fnConvertTime(Float:time, convert_time[], len, bool:with_intpart = true) {
	new szTemp[24];
	new Float:flSeconds = time, iMinutes;

	iMinutes = floatround(flSeconds / 60.0, floatround_floor);
	flSeconds -= iMinutes * 60.0;
	new intpart = floatround(flSeconds, floatround_floor);
	new Float:decpart = (flSeconds - intpart) * 100.0;

	if (with_intpart) {
		intpart = floatround(decpart);
		formatex(szTemp, charsmax(szTemp), "%02i:%02.0f.%d", iMinutes, flSeconds, intpart);
	} else {
		formatex(szTemp, charsmax(szTemp), "%02i:%02.0f", iMinutes, flSeconds);
	}

	formatex(convert_time, len, "%s", szTemp);

	return PLUGIN_HANDLED;
}