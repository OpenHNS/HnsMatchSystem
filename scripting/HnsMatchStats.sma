#include <amxmodx>
#include <reapi>
#include <xs>
#include <fakemeta_util>
#include <hns_matchsystem>

forward hns_players_replaced(requested_id, id);

forward hns_ownage(iToucher, iTouched);

forward ms_session_bhop(id, iCount, Float:flPercent, Float:flAVGSpeed);
forward ms_session_sgs(id, iCount, Float:flPercent, Float:flAVGSpeed);
forward ms_session_ddrun(id, iCount, Float:flPercent, Float:flAVGSpeed);

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
	Float:PLR_STATS_RUNNEDTIME,
	Float:PLR_STATS_FLASHTIME,
	Float:PLR_STATS_SURVTIME,
	Float:PLR_STATS_HIDETIME,
	Float:PLR_STATS_PLAYTIME,
	PLR_STATS_OWNAGES,
	PLR_STATS_STOPS,
	PLR_STATS_BHOP_COUNT,
	Float:PLR_STATS_BHOP_PERCENT_SUM,
	PLR_STATS_SGS_COUNT,
	Float:PLR_STATS_SGS_PERCENT_SUM,
	PLR_STATS_DDRUN_COUNT,
	Float:PLR_STATS_DDRUN_PERCENT_SUM,
	bool:PLR_MATCH,
	TeamName:PLR_TEAM,
}

new iStats[MAX_PLAYERS + 1][PLAYER_STATS];
new g_StatsRound[MAX_PLAYERS + 1][PLAYER_STATS];

new g_iGameStops;

new g_iLastAttacker[MAX_PLAYERS + 1];

new Float:g_flLastPosition[MAX_PLAYERS + 1][3];

new Trie:g_tSaveData;
new Trie:g_tSaveRoundData;

new g_hApplyStatsForward;
new g_hSaveLeaveForward;

public plugin_init() {
	register_plugin("Match: Stats", "1.2", "OpenHNS"); // Garey

	RegisterHookChain(RG_CBasePlayer_Killed, "rgPlayerKilled", false);
	RegisterHookChain(RG_CBasePlayer_Killed, "rgPlayerKilledPost", true);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "rgPlayerTakeDamage", false);
	RegisterHookChain(RG_CBasePlayer_PreThink, "rgPlayerPreThink", true);
	RegisterHookChain(RG_CSGameRules_RestartRound, "rgRoundStart", true);
	RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "rgPlayerFallDamage", true);
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "rgRoundFreezeEnd", true);
	RegisterHookChain(RG_PlayerBlind, "rgPlayerBlind");

	g_hApplyStatsForward = CreateMultiForward("hns_apply_stats", ET_CONTINUE, FP_CELL);
	g_hSaveLeaveForward = CreateMultiForward("hns_save_leave_stats", ET_CONTINUE, FP_CELL, FP_CELL);

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
	register_native("hns_get_stats_runnedtime", "native_get_stats_runnedtime");
	register_native("hns_get_stats_avg_speed", "native_get_stats_avg_speed");
	register_native("hns_get_stats_flashtime", "native_get_stats_flashtime");
	register_native("hns_get_stats_surv", "native_get_stats_surv");
	register_native("hns_get_stats_hidetime", "native_get_hidetime");
	register_native("hns_get_stats_playtime", "native_get_playtime");
	register_native("hns_get_stats_ownages", "native_get_stats_ownages");
	register_native("hns_get_stats_bhop_count", "native_get_stats_bhop_count");
	register_native("hns_get_stats_bhop_percent", "native_get_stats_bhop_percent");
	register_native("hns_get_stats_sgs_count", "native_get_stats_sgs_count");
	register_native("hns_get_stats_sgs_percent", "native_get_stats_sgs_percent");
	register_native("hns_get_stats_ddrun_count", "native_get_stats_ddrun_count");
	register_native("hns_get_stats_ddrun_percent", "native_get_stats_ddrun_percent");
}

public native_get_stats_kills(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_KILLS];
	}
	return iStats[get_param(id)][PLR_STATS_KILLS] + g_StatsRound[get_param(id)][PLR_STATS_KILLS];
}

public native_get_stats_deaths(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_DEATHS];
	}
	return iStats[get_param(id)][PLR_STATS_DEATHS] + g_StatsRound[get_param(id)][PLR_STATS_DEATHS];
}

public native_get_stats_assists(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_ASSISTS];
	}
	return iStats[get_param(id)][PLR_STATS_ASSISTS] + g_StatsRound[get_param(id)][PLR_STATS_ASSISTS];
}

public native_get_stats_stabs(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_STABS];
	}
	return iStats[get_param(id)][PLR_STATS_STABS] + g_StatsRound[get_param(id)][PLR_STATS_STABS];
}

public native_get_stats_dmg_ct(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_DMG_CT];
	}
	return iStats[get_param(id)][PLR_STATS_DMG_CT] + g_StatsRound[get_param(id)][PLR_STATS_DMG_CT];
}

public native_get_stats_dmg_tt(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_DMG_TT];
	}
	return iStats[get_param(id)][PLR_STATS_DMG_TT] + g_StatsRound[get_param(id)][PLR_STATS_DMG_TT];
}

public Float:native_get_stats_runned(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_RUNNED];
	}
	return iStats[get_param(id)][PLR_STATS_RUNNED] + g_StatsRound[get_param(id)][PLR_STATS_RUNNED];
}

public Float:native_get_stats_runnedtime(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_RUNNEDTIME];
	}
	return iStats[get_param(id)][PLR_STATS_RUNNEDTIME] + g_StatsRound[get_param(id)][PLR_STATS_RUNNEDTIME];
}

public Float:native_get_stats_avg_speed(amxx, params) {
	enum { type = 1, id = 2 };
	new Float:runned_time = g_StatsRound[get_param(id)][PLR_STATS_RUNNEDTIME];
	new Float:run_distance = g_StatsRound[get_param(id)][PLR_STATS_RUNNED];

	if (get_param(type) != STATS_ROUND) {
		runned_time += iStats[get_param(id)][PLR_STATS_RUNNEDTIME];
		run_distance += iStats[get_param(id)][PLR_STATS_RUNNED];
	}

	if (runned_time == 0.0) {
		return 0.0; // Avoid division by zero
	}
	return floatdiv(run_distance, runned_time);
}

public Float:native_get_stats_flashtime(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_FLASHTIME];
	}
	return iStats[get_param(id)][PLR_STATS_FLASHTIME] + g_StatsRound[get_param(id)][PLR_STATS_FLASHTIME];
}

public Float:native_get_stats_surv(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_SURVTIME];
	}
	return iStats[get_param(id)][PLR_STATS_SURVTIME] + g_StatsRound[get_param(id)][PLR_STATS_SURVTIME];
}

public Float:native_get_playtime(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_PLAYTIME];
	}
	return iStats[get_param(id)][PLR_STATS_PLAYTIME] + g_StatsRound[get_param(id)][PLR_STATS_PLAYTIME];
}

public Float:native_get_hidetime(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_HIDETIME];
	}
	return iStats[get_param(id)][PLR_STATS_HIDETIME] + g_StatsRound[get_param(id)][PLR_STATS_HIDETIME];
}

public native_get_stats_ownages(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_OWNAGES];
	}
	return iStats[get_param(id)][PLR_STATS_OWNAGES] + g_StatsRound[get_param(id)][PLR_STATS_OWNAGES];
}

public native_get_stats_bhop_count(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_BHOP_COUNT];
	}
	return iStats[get_param(id)][PLR_STATS_BHOP_COUNT] + g_StatsRound[get_param(id)][PLR_STATS_BHOP_COUNT];
}

public Float:native_get_stats_bhop_percent(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return get_average_percent(g_StatsRound[get_param(id)][PLR_STATS_DDRUN_COUNT], g_StatsRound[get_param(id)][PLR_STATS_BHOP_PERCENT_SUM]);
	}
	return get_average_percent(iStats[get_param(id)][PLR_STATS_DDRUN_COUNT] + g_StatsRound[get_param(id)][PLR_STATS_DDRUN_COUNT], iStats[get_param(id)][PLR_STATS_BHOP_PERCENT_SUM] + g_StatsRound[get_param(id)][PLR_STATS_BHOP_PERCENT_SUM]);
}

public native_get_stats_sgs_count(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_SGS_COUNT];
	}
	return iStats[get_param(id)][PLR_STATS_SGS_COUNT] + g_StatsRound[get_param(id)][PLR_STATS_SGS_COUNT];
}

public Float:native_get_stats_sgs_percent(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return get_average_percent(g_StatsRound[get_param(id)][PLR_STATS_DDRUN_COUNT], g_StatsRound[get_param(id)][PLR_STATS_SGS_PERCENT_SUM]);
	}
	return get_average_percent(iStats[get_param(id)][PLR_STATS_DDRUN_COUNT] + g_StatsRound[get_param(id)][PLR_STATS_DDRUN_COUNT], iStats[get_param(id)][PLR_STATS_SGS_PERCENT_SUM] + g_StatsRound[get_param(id)][PLR_STATS_SGS_PERCENT_SUM]);
}

public native_get_stats_ddrun_count(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_DDRUN_COUNT];
	}
	return iStats[get_param(id)][PLR_STATS_DDRUN_COUNT] + g_StatsRound[get_param(id)][PLR_STATS_DDRUN_COUNT];
}

public Float:native_get_stats_ddrun_percent(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return get_average_percent(g_StatsRound[get_param(id)][PLR_STATS_DDRUN_COUNT], g_StatsRound[get_param(id)][PLR_STATS_DDRUN_PERCENT_SUM]);
	}
	return get_average_percent(iStats[get_param(id)][PLR_STATS_DDRUN_COUNT] + g_StatsRound[get_param(id)][PLR_STATS_DDRUN_COUNT], iStats[get_param(id)][PLR_STATS_DDRUN_PERCENT_SUM] + g_StatsRound[get_param(id)][PLR_STATS_DDRUN_PERCENT_SUM]);
}

public hns_players_replaced(requested_id, id) {	
	for (new i = 0; i < PLAYER_STATS; i++) {
		if (i == PLR_STATS_KILLS || i == PLR_MATCH || i == PLR_STATS_DEATHS) {
			continue;
		}
		iStats[id][i] = iStats[requested_id][i];
	}
	
	if (rg_get_user_team(requested_id) == TEAM_SPECTATOR) {
		arrayset(iStats[requested_id], 0, PLAYER_STATS);
	}
}

public client_putinserver(id) {
	TrieGetArray(g_tSaveData, getUserKey(id), iStats[id], PLAYER_STATS);
	TrieGetArray(g_tSaveRoundData, getUserKey(id), g_StatsRound[id], PLAYER_STATS);

	if (hns_get_mode() == MODE_MIX || hns_get_state() == STATE_PAUSED) {
		SetScoreInfo(id, true);
	} else {
		arrayset(iStats[id], 0, PLAYER_STATS);
	}
}


public hns_player_leave_inmatch(id) {
	if ((iStats[id][PLR_TEAM] == TEAM_TERRORIST || iStats[id][PLR_TEAM] == TEAM_CT) && (hns_get_mode() == MODE_MIX || hns_get_state() == STATE_PAUSED)) {
		iStats[id][PLR_STATS_STOPS] = g_iGameStops;
	}

	ExecuteForward(g_hSaveLeaveForward, _, id, iStats[id][PLR_TEAM]);

	TrieSetArray(g_tSaveData, getUserKey(id), iStats[id], PLAYER_STATS);
	TrieSetArray(g_tSaveRoundData, getUserKey(id), g_StatsRound[id], PLAYER_STATS);

	arrayset(iStats[id], 0, PLAYER_STATS);
	arrayset(g_StatsRound[id], 0, PLAYER_STATS);
	arrayset(g_flLastPosition[id], 0, sizeof(g_flLastPosition[]));
	g_iLastAttacker[id] = 0;
}

public hns_match_reset_round() {
	g_iGameStops++;

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	for (new i; i < iNum; i++) {
		new iPlayer = iPlayers[i];

		if (rg_get_user_team(iPlayer) != TEAM_TERRORIST && rg_get_user_team(iPlayer) != TEAM_CT) {
			continue;
		}

		arrayset(g_StatsRound[iPlayer], 0, PLAYER_STATS);

		SetScoreInfo(iPlayer, false);
	}
}

public hns_match_started() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i; i < iNum; i++) {
		new id = iPlayers[i];
		arrayset(iStats[id], 0, PLAYER_STATS);
		arrayset(g_StatsRound[id], 0, PLAYER_STATS);
		SetScoreInfo(id, false);
	}
}

public hns_ownage(iToucher, iTouched) {
	g_StatsRound[iToucher][PLR_STATS_OWNAGES]++;
}

public ms_session_bhop(id, iCount, Float:flPercent, Float:flAVGSpeed) {
	g_StatsRound[id][PLR_STATS_BHOP_COUNT] += iCount;
	
	new Float:flWeighted = floatmul(float(iCount), flPercent);
	g_StatsRound[id][PLR_STATS_BHOP_PERCENT_SUM] = floatadd(g_StatsRound[id][PLR_STATS_BHOP_PERCENT_SUM], flWeighted);
}

public ms_session_sgs(id, iCount, Float:flPercent, Float:flAVGSpeed) {
	g_StatsRound[id][PLR_STATS_SGS_COUNT] += iCount;

	new Float:flWeighted = floatmul(float(iCount), flPercent);
	g_StatsRound[id][PLR_STATS_SGS_PERCENT_SUM] = floatadd(g_StatsRound[id][PLR_STATS_SGS_PERCENT_SUM], flWeighted);
}

public ms_session_ddrun(id, iCount, Float:flPercent, Float:flAVGSpeed) {
	g_StatsRound[id][PLR_STATS_DDRUN_COUNT] += iCount;

	new Float:flWeighted = floatmul(float(iCount), flPercent);
	g_StatsRound[id][PLR_STATS_DDRUN_PERCENT_SUM] = floatadd(g_StatsRound[id][PLR_STATS_DDRUN_PERCENT_SUM], flWeighted);
}

public rgPlayerKilled(victim, attacker) {
	if (hns_get_mode() != MODE_MIX) {
		return;
	}

	if (is_user_connected(attacker) && victim != attacker) {
		g_StatsRound[attacker][PLR_STATS_KILLS]++;
	}

	if (is_user_connected(victim)) {
		g_StatsRound[victim][PLR_STATS_DEATHS]++;
	}

	if (g_iLastAttacker[victim] && g_iLastAttacker[victim] != attacker) {
		g_StatsRound[g_iLastAttacker[victim]][PLR_STATS_ASSISTS]++;
		g_iLastAttacker[victim] = 0;
	}

}

public rgPlayerKilledPost(victim, attacker) {
	if (hns_get_mode() != MODE_MIX) {
		return;
	}

	if (is_user_connected(attacker) && victim != attacker) {
		SetScoreInfo(attacker, true);
	}

	if (is_user_connected(victim)) {
		SetScoreInfo(victim, true);
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
	}
}

public rgPlayerFallDamage(id) {
	if (hns_get_mode() != MODE_MIX || hns_get_state() != STATE_ENABLED) {
		return;
	}

	new dmg = floatround(Float:GetHookChainReturn(ATYPE_FLOAT));

	if (rg_get_user_team(id) == TEAM_TERRORIST) {
		g_StatsRound[id][PLR_STATS_DMG_TT] += dmg;
	} else {
		g_StatsRound[id][PLR_STATS_DMG_CT] += dmg;
	}
}

public rgPlayerBlind(const index, const inflictor, const attacker, const Float:fadeTime, const Float:fadeHold, const alpha) {
	if(rg_get_user_team(index) != TEAM_CT || rg_get_user_team(attacker) != TEAM_TERRORIST || index == attacker)
		return HC_CONTINUE;

	if (alpha != 255 || fadeHold < 1.0)
		return HC_CONTINUE;

	g_StatsRound[attacker][PLR_STATS_FLASHTIME] += fadeHold;

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
				if(is_player_running(id))
				{
					g_StatsRound[id][PLR_STATS_RUNNED] += vector_length(velocity) * frametime;
					g_StatsRound[id][PLR_STATS_RUNNEDTIME] += frametime;
				}
				if(is_player_hidding(id))
				{
					g_StatsRound[id][PLR_STATS_HIDETIME] += frametime;					
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
	if (hns_get_state() != STATE_ENABLED || hns_get_mode() != MODE_MIX) {
		remove_task(TASK_TIMER_STATS);
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++)
	{
		new id = iPlayers[i];
		if(!is_user_connected(id))
			continue;

		new TeamName:iTeam = rg_get_user_team(id);
		if(iTeam == TEAM_SPECTATOR)
			continue;
		
		if (iTeam == TEAM_TERRORIST && is_user_alive(id))
			g_StatsRound[id][PLR_STATS_SURVTIME] += 0.25;

		g_StatsRound[id][PLR_STATS_PLAYTIME] += 0.25;
	}
}

public hns_match_finished() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	collect_stats();

	ExecuteForward(g_hApplyStatsForward, _, 1);
}

public hns_match_finished_post() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		arrayset(iStats[id], 0, PLAYER_STATS);
		arrayset(g_StatsRound[id], 0, PLAYER_STATS);
	}
}

public hns_round_end() {
	if (hns_get_mode() == MODE_MIX && hns_get_state() == STATE_ENABLED) {
		if(task_exists(TASK_TIMER_STATS)) {
			remove_task(TASK_TIMER_STATS);
		}		
		collect_stats();
		ExecuteForward(g_hApplyStatsForward, _, 0);		
	}
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

stock SetScoreInfo(id, bool:bRound = false) {
	new Float:flKills, iDeaths;
	if (bRound) {
		flKills = float(iStats[id][PLR_STATS_KILLS] + g_StatsRound[id][PLR_STATS_KILLS]);
		iDeaths = iStats[id][PLR_STATS_DEATHS] + g_StatsRound[id][PLR_STATS_DEATHS];
	} else {
		flKills = float(iStats[id][PLR_STATS_KILLS]);
		iDeaths = iStats[id][PLR_STATS_DEATHS];
	}

	set_entvar(id, var_frags, flKills);
	set_member(id, m_iDeaths, iDeaths);
	Msg_Update_ScoreInfo(id, flKills, iDeaths);
}

stock Msg_Update_ScoreInfo(id, Float:flKills, iDeaths) {
	const iMsg_ScoreInfo = 85;

	message_begin(MSG_BROADCAST, iMsg_ScoreInfo);
	write_byte(id);
	write_short(floatround(flKills));
	write_short(iDeaths);
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

stock bool:is_player_running(id) {
	if(!is_user_alive(id))
	{
		return false;
	}
	new Float:velocity[3];
	get_entvar(id, var_velocity, velocity);

	// Don't reset the Z velocity, because it can be used for jumps/ladders
	//velocity[2] = 0.0;

	if(vector_length(velocity) > 200.0)
		return true;

	return false;
}

stock is_player_hidding(id) {
	if(!is_user_alive(id))
	{
		return false;
	}
	
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ache", "CT");
	new Float:origin[3];
	get_entvar(id, var_origin, origin);
	new bool:hided = true;
	for (new i = 0; i < iNum; i++)
	{
		new player = iPlayers[i];
		if (fm_is_in_viewcone(player, origin) && fm_is_ent_visible(player, id))
		{
			hided = false;
			break;
		}
	}

	return hided;
}
public Float:get_average_percent(iCount, Float:flPercentSum) {
    if (iCount == 0) {
        return 0.0;
    }
    return floatdiv(flPercentSum, float(iCount));
}

collect_stats()
{
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];

		iStats[id][PLR_STATS_OWNAGES] += g_StatsRound[id][PLR_STATS_OWNAGES];
		iStats[id][PLR_STATS_BHOP_COUNT] += g_StatsRound[id][PLR_STATS_BHOP_COUNT];
		iStats[id][PLR_STATS_BHOP_PERCENT_SUM] = floatadd(iStats[id][PLR_STATS_BHOP_PERCENT_SUM], g_StatsRound[id][PLR_STATS_BHOP_PERCENT_SUM]);
		iStats[id][PLR_STATS_SGS_COUNT] += g_StatsRound[id][PLR_STATS_SGS_COUNT];
		iStats[id][PLR_STATS_SGS_PERCENT_SUM] = floatadd(iStats[id][PLR_STATS_SGS_PERCENT_SUM], g_StatsRound[id][PLR_STATS_SGS_PERCENT_SUM]);
		iStats[id][PLR_STATS_DDRUN_COUNT] += g_StatsRound[id][PLR_STATS_DDRUN_COUNT];
		iStats[id][PLR_STATS_DDRUN_PERCENT_SUM] = floatadd(iStats[id][PLR_STATS_DDRUN_PERCENT_SUM], g_StatsRound[id][PLR_STATS_DDRUN_PERCENT_SUM]);
		iStats[id][PLR_STATS_KILLS] += g_StatsRound[id][PLR_STATS_KILLS];
		iStats[id][PLR_STATS_DEATHS] += g_StatsRound[id][PLR_STATS_DEATHS];
		iStats[id][PLR_STATS_ASSISTS] += g_StatsRound[id][PLR_STATS_ASSISTS];
		iStats[id][PLR_STATS_STABS] += g_StatsRound[id][PLR_STATS_STABS];
		iStats[id][PLR_STATS_DMG_TT] += g_StatsRound[id][PLR_STATS_DMG_TT];
		iStats[id][PLR_STATS_DMG_CT] += g_StatsRound[id][PLR_STATS_DMG_CT];
		iStats[id][PLR_STATS_RUNNED] += g_StatsRound[id][PLR_STATS_RUNNED];
		iStats[id][PLR_STATS_RUNNEDTIME] += g_StatsRound[id][PLR_STATS_RUNNEDTIME];
		iStats[id][PLR_STATS_PLAYTIME] += g_StatsRound[id][PLR_STATS_PLAYTIME];
		iStats[id][PLR_STATS_HIDETIME] += g_StatsRound[id][PLR_STATS_HIDETIME];
		iStats[id][PLR_STATS_FLASHTIME] += g_StatsRound[id][PLR_STATS_FLASHTIME];
		iStats[id][PLR_STATS_SURVTIME] += g_StatsRound[id][PLR_STATS_SURVTIME];

		arrayset(g_StatsRound[id], 0, PLAYER_STATS);

		SetScoreInfo(id, false);
	}
}
