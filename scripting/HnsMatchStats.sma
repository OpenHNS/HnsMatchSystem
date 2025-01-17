#include <amxmodx>
#include <reapi>
#include <xs>

#include <hns_matchsystem>
#include <hns_matchsystem_pts>

forward hns_ownage(iToucher, iTouched);

#define TASK_TIMER_STATS 61237

enum _:TYPE_STATS
{
	STATS_ROUND = 0,
	STATS_ALL = 1
}

new g_szPrefix[24];

enum _: PLAYER_STATS {
	PLR_STATS_KILLS,
	PLR_STATS_DEATHS,
	PLR_STATS_ASSISTS,
	PLR_STATS_STABS,
	PLR_STATS_DMG_CT,
	PLR_STATS_DMG_TT,
	Float:PLR_STATS_RUNNED,
	Float:PLR_STATS_FLASHTIME,
	Float:PLR_STATS_SURVTIME,
	PLR_STATS_OWNAGES,
	PLR_STATS_STOPS,
	bool:PLR_MATCH,
	TeamName:PLR_TEAM
}

new iStats[MAX_PLAYERS + 1][PLAYER_STATS];
new g_StatsRound[MAX_PLAYERS + 1][PLAYER_STATS];

new g_iGameStops;

new g_iLastAttacker[MAX_PLAYERS + 1];

new Float:g_flLastPosition[MAX_PLAYERS + 1][3];

new Trie:g_tSaveData;
new Trie:g_tSaveRoundData;

public plugin_init() {
	register_plugin("Match: Stats", "1.1.1", "OpenHNS"); // Garey

	RegisterHookChain(RG_CBasePlayer_Killed, "rgPlayerKilled", true);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "rgPlayerTakeDamage", false);
	RegisterHookChain(RG_CBasePlayer_PreThink, "rgPlayerPreThink", true);
	RegisterHookChain(RG_CSGameRules_RestartRound, "rgRoundStart", true);
	RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "rgPlayerFallDamage", true);
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "rgRoundFreezeEnd", true);
	RegisterHookChain(RG_RoundEnd, "rgRoundEnd", false);
	RegisterHookChain(RG_PlayerBlind, "rgPlayerBlind");

	g_tSaveData = TrieCreate();
	g_tSaveRoundData = TrieCreate();
}

public plugin_cfg() {
	hns_get_prefix(g_szPrefix, charsmax(g_szPrefix));
}

public plugin_natives() {
	register_native("hns_get_stats_kills", "native_get_stats_kills");
	register_native("hns_get_stats_deaths", "native_get_stats_deaths");
	register_native("hns_get_stats_assists", "native_get_stats_assists");
	register_native("hns_get_stats_stabs", "native_get_stats_stabs");
	register_native("hns_get_stats_dmg_ct", "native_get_stats_dmg_ct");
	register_native("hns_get_stats_dmg_tt", "native_get_stats_dmg_tt");
	register_native("hns_get_stats_runned", "native_get_stats_runned");
	register_native("hns_get_stats_flashtime", "native_get_stats_flashtime");
	register_native("hns_get_stats_surv", "native_get_stats_surv");
	register_native("hns_get_stats_ownages", "native_get_stats_ownages");
}

public native_get_stats_kills(amxx, params) {
	enum { type = 1, id = 2 };

	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_KILLS];
	}

	return iStats[get_param(id)][PLR_STATS_KILLS];
}

public native_get_stats_deaths(amxx, params) {
	enum { type = 1, id = 2 };

	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_DEATHS];
	}

	return iStats[get_param(id)][PLR_STATS_DEATHS];
}

public native_get_stats_assists(amxx, params) {
	enum { type = 1, id = 2 };

	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_ASSISTS];
	}

	return iStats[get_param(id)][PLR_STATS_ASSISTS];
}

public native_get_stats_stabs(amxx, params) {
	enum { type = 1, id = 2 };

	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_STABS];
	}

	return iStats[get_param(id)][PLR_STATS_STABS];
}

public native_get_stats_dmg_ct(amxx, params) {
	enum { type = 1, id = 2 };

	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_DMG_CT];
	}

	return iStats[get_param(id)][PLR_STATS_DMG_CT];
}

public native_get_stats_dmg_tt(amxx, params) {
	enum { type = 1, id = 2 };

	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_DMG_TT];
	}

	return iStats[get_param(id)][PLR_STATS_DMG_TT];
}

public Float:native_get_stats_runned(amxx, params) {
	enum { type = 1, id = 2 };

	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_RUNNED];
	}

	return iStats[get_param(id)][PLR_STATS_RUNNED];
}

public Float:native_get_stats_flashtime(amxx, params) {
	enum { type = 1, id = 2 };

	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_FLASHTIME];
	}

	return iStats[get_param(id)][PLR_STATS_FLASHTIME];
}

public Float:native_get_stats_surv(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_SURVTIME];
	}
	return iStats[get_param(id)][PLR_STATS_SURVTIME];
}

public native_get_stats_ownages(amxx, params) {
	enum { type = 1, id = 2 };

	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_OWNAGES];
	}

	return iStats[get_param(id)][PLR_STATS_OWNAGES];
}

public client_putinserver(id) {
	TrieGetArray(g_tSaveData, getUserKey(id), iStats[id], PLAYER_STATS);
	TrieGetArray(g_tSaveRoundData, getUserKey(id), g_StatsRound[id], PLAYER_STATS);

	if (hns_get_mode() == MODE_MIX || hns_get_state() == STATE_PAUSED) {
		if (iStats[id][PLR_STATS_STOPS] < g_iGameStops) {
			iStats[id][PLR_STATS_KILLS] -= g_StatsRound[id][PLR_STATS_KILLS]
			iStats[id][PLR_STATS_DEATHS] -= g_StatsRound[id][PLR_STATS_DEATHS]
			iStats[id][PLR_STATS_ASSISTS] -= g_StatsRound[id][PLR_STATS_ASSISTS]

			SetScoreInfo(id);
		} else {
			SetScoreInfo(id);
		}
	} else
		arrayset(iStats[id], 0, PLAYER_STATS);
}

public client_disconnected(id) {
	if ((iStats[id][PLR_TEAM] == TEAM_TERRORIST || iStats[id][PLR_TEAM] == TEAM_CT) && (hns_get_mode() == MODE_MIX || hns_get_state() == STATE_PAUSED)) {
		iStats[id][PLR_STATS_STOPS] = g_iGameStops;
	}
	TrieSetArray(g_tSaveData, getUserKey(id), iStats[id], PLAYER_STATS);
	TrieSetArray(g_tSaveRoundData, getUserKey(id), g_StatsRound[id], PLAYER_STATS);

	arrayset(iStats[id], 0, PLAYER_STATS);
	arrayset(g_StatsRound[id], 0, PLAYER_STATS);
	arrayset(g_flLastPosition[id], 0, sizeof(g_flLastPosition[]));
	g_iLastAttacker[id] = 0;
}

public hns_match_reset_round() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];
		ResetPlayerRoundStats(iPlayer);
	}
}

public hns_match_started() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		arrayset(iStats[id], 0, PLAYER_STATS);
		arrayset(g_StatsRound[id], 0, PLAYER_STATS);
		SetScoreInfo(id);
	}
}

public hns_ownage(iToucher, iTouched) {
	g_StatsRound[iToucher][PLR_STATS_OWNAGES]++;
	iStats[iToucher][PLR_STATS_OWNAGES]++;
}

public rgPlayerKilled(victim, attacker) {
	if (hns_get_mode() != MODE_MIX) {
		return;
	}
	
	if (is_user_connected(attacker) && victim != attacker) {
		g_StatsRound[attacker][PLR_STATS_KILLS]++;
		iStats[attacker][PLR_STATS_KILLS]++;
		g_StatsRound[victim][PLR_STATS_DEATHS]++;
		iStats[victim][PLR_STATS_DEATHS]++;
	}

	if (g_iLastAttacker[victim] && g_iLastAttacker[victim] != attacker) {
		g_StatsRound[g_iLastAttacker[victim]][PLR_STATS_ASSISTS]++;
		iStats[g_iLastAttacker[victim]][PLR_STATS_ASSISTS]++;
		g_iLastAttacker[victim] = 0;
	}
}

public rgPlayerTakeDamage(iVictim, iWeapon, iAttacker, Float:fDamage) { // Проверить не засчитывает ли урон по своим
	if (hns_get_mode() != MODE_MIX || hns_get_state() != STATE_ENABLED) {
		return;
	}

	if (is_user_alive(iAttacker) && iVictim != iAttacker) {
		new Float:fHealth; get_entvar(iVictim, var_health, fHealth);
		if (fDamage < fHealth) {
			g_iLastAttacker[iVictim] = iAttacker;
		}

		g_StatsRound[iAttacker][PLR_STATS_STABS]++;
		iStats[iAttacker][PLR_STATS_STABS]++;
	}
}

public rgPlayerFallDamage(id) {
	if (hns_get_mode() != MODE_MIX || hns_get_state() != STATE_ENABLED) {
		return;
	}

	new dmg = floatround(Float:GetHookChainReturn(ATYPE_FLOAT));

	if (rg_get_user_team(id) == TEAM_TERRORIST) {
		g_StatsRound[id][PLR_STATS_DMG_TT] += dmg;
		iStats[id][PLR_STATS_DMG_TT] += dmg;
	} else {
		g_StatsRound[id][PLR_STATS_DMG_CT] += dmg;
		iStats[id][PLR_STATS_DMG_CT] += dmg;
	}
}

public rgPlayerBlind(const index, const inflictor, const attacker, const Float:fadeTime, const Float:fadeHold, const alpha) {
	if(rg_get_user_team(index) != TEAM_CT || rg_get_user_team(attacker) != TEAM_TERRORIST || index == attacker)
		return HC_CONTINUE;

	if (alpha != 255 || fadeHold < 1.0)
		return HC_CONTINUE;

	g_StatsRound[attacker][PLR_STATS_FLASHTIME] += fadeHold;
	iStats[attacker][PLR_STATS_FLASHTIME] += fadeHold;

	return HC_CONTINUE;
}

public rgPlayerPreThink(id) {
	static Float:origin[3];
	static Float:velocity[3];
	static Float:last_updated[MAX_PLAYERS + 1];
	static Float:frametime;
	get_entvar(id, var_origin, origin);
	get_entvar(id, var_velocity, velocity);

	frametime = get_gametime() - last_updated[id];
	if (frametime > 1.0) {
		frametime = 1.0;
	}

	if (hns_get_state() == STATE_ENABLED) {
		if (is_user_alive(id)) {
			if (rg_get_user_team(id) == TEAM_TERRORIST) {
				if (vector_length(velocity) * frametime >= get_distance_f(origin, g_flLastPosition[id])) {
					velocity[2] = 0.0;
					if (vector_length(velocity) > 125.0) {
						g_StatsRound[id][PLR_STATS_RUNNED] += vector_length(velocity) * frametime;
						iStats[id][PLR_STATS_RUNNED] += vector_length(velocity) * frametime;
					}
				}

			}
		}
	}

	last_updated[id] = get_gametime();
	xs_vec_copy(origin, g_flLastPosition[id]);
}

public rgRoundFreezeEnd() {
	set_task(0.25, "taskRoundEvent", .id = TASK_TIMER_STATS, .flags = "b");
}

public taskRoundEvent() {
	if (hns_get_state() != STATE_ENABLED || hns_get_mode() != MODE_MIX)
	{
		remove_task(TASK_TIMER_STATS);
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "aech", "TERRORIST");

	for (new i = 0; i < iNum; i++)
	{
		new id = iPlayers[i];
		g_StatsRound[id][PLR_STATS_SURVTIME] += 0.25;
		iStats[id][PLR_STATS_SURVTIME] += 0.25;
	}
}

public rgRoundEnd(WinStatus: status, ScenarioEventEndRound: event, Float:tmDelay) {
	remove_task(TASK_TIMER_STATS);
}

public rgRoundStart() {
	remove_task(TASK_TIMER_STATS);
	if (hns_get_mode() != MODE_MIX) {
		return;
	}
	
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		arrayset(g_StatsRound[id], 0, PLAYER_STATS);
		arrayset(g_flLastPosition[id], 0, sizeof(g_flLastPosition[]));
	
		g_iLastAttacker[id] = 0;
	}

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		iStats[id][PLR_TEAM] = rg_get_user_team(id);
	}

}

stock ResetPlayerRoundStats(id) {
	if (rg_get_user_team(id) == TEAM_TERRORIST)
		iStats[id][PLR_STATS_SURVTIME] -= g_StatsRound[id][PLR_STATS_SURVTIME];

	if (rg_get_user_team(id) == TEAM_TERRORIST || rg_get_user_team(id) == TEAM_CT) {
		iStats[id][PLR_STATS_STABS] -= g_StatsRound[id][PLR_STATS_STABS];
		iStats[id][PLR_STATS_DMG_CT] -= g_StatsRound[id][PLR_STATS_DMG_CT];
		iStats[id][PLR_STATS_RUNNED] -= g_StatsRound[id][PLR_STATS_RUNNED];
		iStats[id][PLR_STATS_FLASHTIME] -= g_StatsRound[id][PLR_STATS_FLASHTIME];

		iStats[id][PLR_STATS_KILLS] -= g_StatsRound[id][PLR_STATS_KILLS];
		iStats[id][PLR_STATS_DEATHS] -= g_StatsRound[id][PLR_STATS_DEATHS];
		iStats[id][PLR_STATS_ASSISTS] -= g_StatsRound[id][PLR_STATS_ASSISTS];
		SetScoreInfo(id);
	}
	g_iGameStops++;

	arrayset(g_StatsRound[id], 0, PLAYER_STATS);
}

stock SetScoreInfo(id) {
	set_entvar(id, var_frags, float(iStats[id][PLR_STATS_KILLS]));
	set_member(id, m_iDeaths, iStats[id][PLR_STATS_DEATHS]);
	Msg_Update_ScoreInfo(id);
}

stock Msg_Update_ScoreInfo(id) {
	const iMsg_ScoreInfo = 85;

	message_begin(MSG_BROADCAST, iMsg_ScoreInfo);
	write_byte(id);
	write_short(0);
	write_short(0);
	write_short(0);
	write_short(0);
	message_end();
}

public plugin_end() {
	TrieDestroy(g_tSaveData);
	TrieDestroy(g_tSaveRoundData);
}

stock getUserKey(id) {
	new szAuth[24];
	get_user_authid(id, szAuth, charsmax(szAuth));
	return szAuth;
}