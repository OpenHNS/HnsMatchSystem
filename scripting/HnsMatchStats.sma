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
#define SPOT_START_DELAY 5.0
#define SPOT_CONFIRM_TIME 3.0
#define SPOT_HEIGHT_LIMIT 100.0

enum _:TYPE_STATS
{
	STATS_ROUND = 0,
	STATS_ALL = 1
}

new g_szPrefix[24];

enum _: PLAYER_STATS {
	PLR_STATS_KILLS_CT,
	PLR_STATS_DEATHS_CT,
	PLR_STATS_ASSISTS_CT,
	PLR_STATS_STABS_CT,
	PLR_STATS_DAMAGE_CT,
	PLR_STATS_FALLDMG_CT,
	PLR_STATS_FALLDMG_TT,
	PLR_STATS_FLASHCOUNT,
	PLR_STATS_FLASH,
	PLR_STATS_FLASHFAIL,
	Float:PLR_STATS_FLASHTIME,
	Float:PLR_STATS_LAST_TT_TIME,
	PLR_STATS_FK_CT,
	PLR_STATS_FD_TT,
	PLR_STATS_MK1_CT,
	PLR_STATS_MK2_CT,
	PLR_STATS_MK3_CT,
	PLR_STATS_MK4_CT,
	PLR_STATS_MK5_CT,
	Float:PLR_STATS_SURVTIME,
	Float:PLR_STATS_PLAYTIME,
	PLR_STATS_SPOTTED_ROUNDS,
	Float:PLR_STATS_SPOTTED_SURV_TIME,
	PLR_STATS_TT_ROUNDS,
	PLR_STATS_CT_ROUNDS,
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

new bool:g_bFirstKillCt;
new bool:g_bFirstDeathTt;

new Float:g_flLastPosition[MAX_PLAYERS + 1][3];
new Float:g_flSpottedVisibleTime[MAX_PLAYERS + 1];
new bool:g_bSpottedConfirmed[MAX_PLAYERS + 1];
new Float:g_flSpottedTrackStart;

new Trie:g_tSaveData;
new Trie:g_tSaveRoundData;

new g_hApplyStatsForward;
new g_hSaveLeaveForward;

public plugin_init() {
	register_plugin("Match: Stats", "2.0", "OpenHNS"); // Garey

	RegisterHookChain(RG_CBasePlayer_Killed, "rgPlayerKilled", false);
	RegisterHookChain(RG_CBasePlayer_Killed, "rgPlayerKilledPost", true);
	RegisterHookChain(RG_CBasePlayer_TakeDamage, "rgPlayerTakeDamage", false);
	RegisterHookChain(RG_CBasePlayer_PreThink, "rgPlayerPreThink", true);
	RegisterHookChain(RG_CSGameRules_RestartRound, "rgRoundStart", true);
	RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "rgPlayerFallDamage", true);
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "rgRoundFreezeEnd", true);
	RegisterHookChain(RG_PlayerBlind, "rgPlayerBlind");
	RegisterHookChain(RG_ThrowFlashbang, "rgThrowFlashbang", true);
	RegisterHookChain(RG_CGrenade_ExplodeFlashbang, "rgExplodeFlashbang", true);

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
	register_native("hns_get_stats_damage", "native_get_stats_damage");
	
	register_native("hns_get_stats_falldmg_ct", "native_get_stats_falldmg_ct");
	register_native("hns_get_stats_falldmg_tt", "native_get_stats_falldmg_tt");
	
	register_native("hns_get_stats_flashcount", "native_get_stats_flashcount");
	register_native("hns_get_stats_flash", "native_get_stats_flash");
	register_native("hns_get_stats_flashfail", "native_get_stats_flashfail");
	register_native("hns_get_stats_flashtime", "native_get_stats_flashtime");
		
	register_native("hns_get_stats_fk", "native_get_stats_fk");
	register_native("hns_get_stats_fd", "native_get_stats_fd");
	register_native("hns_get_stats_mk1", "native_get_stats_mk1");
	register_native("hns_get_stats_mk2", "native_get_stats_mk2");
	register_native("hns_get_stats_mk3", "native_get_stats_mk3");
	register_native("hns_get_stats_mk4", "native_get_stats_mk4");
	register_native("hns_get_stats_mk5", "native_get_stats_mk5");

	register_native("hns_get_stats_surv", "native_get_stats_surv");
	register_native("hns_get_stats_playtime", "native_get_playtime");
	register_native("hns_get_stats_last_tt_time", "native_get_stats_last_tt_time");

	register_native("hns_get_stats_spotted_rounds", "native_get_spotted_rounds");
	register_native("hns_get_stats_spotted_survived_time", "native_get_spotted_survived_time");

	register_native("hns_get_stats_tt_rounds", "native_get_tt_rounds");
	register_native("hns_get_stats_ct_rounds", "native_get_ct_rounds");

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
		return g_StatsRound[get_param(id)][PLR_STATS_KILLS_CT];
	}
	return iStats[get_param(id)][PLR_STATS_KILLS_CT] + g_StatsRound[get_param(id)][PLR_STATS_KILLS_CT];
}

public native_get_stats_deaths(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_DEATHS_CT];
	}
	return iStats[get_param(id)][PLR_STATS_DEATHS_CT] + g_StatsRound[get_param(id)][PLR_STATS_DEATHS_CT];
}

public native_get_stats_assists(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_ASSISTS_CT];
	}
	return iStats[get_param(id)][PLR_STATS_ASSISTS_CT] + g_StatsRound[get_param(id)][PLR_STATS_ASSISTS_CT];
}

public native_get_stats_stabs(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_STABS_CT];
	}
	return iStats[get_param(id)][PLR_STATS_STABS_CT] + g_StatsRound[get_param(id)][PLR_STATS_STABS_CT];
}

public native_get_stats_damage(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_DAMAGE_CT];
	}
	return iStats[get_param(id)][PLR_STATS_DAMAGE_CT] + g_StatsRound[get_param(id)][PLR_STATS_DAMAGE_CT];
}

public native_get_stats_falldmg_ct(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_FALLDMG_CT];
	}
	return iStats[get_param(id)][PLR_STATS_FALLDMG_CT] + g_StatsRound[get_param(id)][PLR_STATS_FALLDMG_CT];
}

public native_get_stats_falldmg_tt(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_FALLDMG_TT];
	}
	return iStats[get_param(id)][PLR_STATS_FALLDMG_TT] + g_StatsRound[get_param(id)][PLR_STATS_FALLDMG_TT];
}

public native_get_stats_flashcount(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_FLASHCOUNT];
	}
	return iStats[get_param(id)][PLR_STATS_FLASHCOUNT] + g_StatsRound[get_param(id)][PLR_STATS_FLASHCOUNT];
}

public native_get_stats_flash(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_FLASH];
	}
	return iStats[get_param(id)][PLR_STATS_FLASH] + g_StatsRound[get_param(id)][PLR_STATS_FLASH];
}

public native_get_stats_flashfail(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_FLASHFAIL];
	}
	return iStats[get_param(id)][PLR_STATS_FLASHFAIL] + g_StatsRound[get_param(id)][PLR_STATS_FLASHFAIL];
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

public Float:native_get_stats_last_tt_time(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_LAST_TT_TIME];
	}
	return iStats[get_param(id)][PLR_STATS_LAST_TT_TIME] + g_StatsRound[get_param(id)][PLR_STATS_LAST_TT_TIME];
}

public native_get_stats_fk(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_FK_CT];
	}
	return iStats[get_param(id)][PLR_STATS_FK_CT] + g_StatsRound[get_param(id)][PLR_STATS_FK_CT];
}

public native_get_stats_fd(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_FD_TT];
	}
	return iStats[get_param(id)][PLR_STATS_FD_TT] + g_StatsRound[get_param(id)][PLR_STATS_FD_TT];
}

public native_get_stats_mk1(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_MK1_CT];
	}
	return iStats[get_param(id)][PLR_STATS_MK1_CT] + g_StatsRound[get_param(id)][PLR_STATS_MK1_CT];
}

public native_get_stats_mk2(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_MK2_CT];
	}
	return iStats[get_param(id)][PLR_STATS_MK2_CT] + g_StatsRound[get_param(id)][PLR_STATS_MK2_CT];
}

public native_get_stats_mk3(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_MK3_CT];
	}
	return iStats[get_param(id)][PLR_STATS_MK3_CT] + g_StatsRound[get_param(id)][PLR_STATS_MK3_CT];
}

public native_get_stats_mk4(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_MK4_CT];
	}
	return iStats[get_param(id)][PLR_STATS_MK4_CT] + g_StatsRound[get_param(id)][PLR_STATS_MK4_CT];
}

public native_get_stats_mk5(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_MK5_CT];
	}
	return iStats[get_param(id)][PLR_STATS_MK5_CT] + g_StatsRound[get_param(id)][PLR_STATS_MK5_CT];
}

public native_get_spotted_rounds(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_SPOTTED_ROUNDS];
	}
	return iStats[get_param(id)][PLR_STATS_SPOTTED_ROUNDS] + g_StatsRound[get_param(id)][PLR_STATS_SPOTTED_ROUNDS];
}

public Float:native_get_spotted_survived_time(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_SPOTTED_SURV_TIME];
	}
	return iStats[get_param(id)][PLR_STATS_SPOTTED_SURV_TIME] + g_StatsRound[get_param(id)][PLR_STATS_SPOTTED_SURV_TIME];
}


public native_get_tt_rounds(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_TT_ROUNDS];
	}
	return iStats[get_param(id)][PLR_STATS_TT_ROUNDS] + g_StatsRound[get_param(id)][PLR_STATS_TT_ROUNDS];
}

public native_get_ct_rounds(amxx, params) {
	enum { type = 1, id = 2 };
	if (get_param(type) == STATS_ROUND) {
		return g_StatsRound[get_param(id)][PLR_STATS_CT_ROUNDS];
	}
	return iStats[get_param(id)][PLR_STATS_CT_ROUNDS] + g_StatsRound[get_param(id)][PLR_STATS_CT_ROUNDS];
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
		return get_average_percent(g_StatsRound[get_param(id)][PLR_STATS_BHOP_COUNT], g_StatsRound[get_param(id)][PLR_STATS_BHOP_PERCENT_SUM]);
	}
	return get_average_percent(iStats[get_param(id)][PLR_STATS_BHOP_COUNT] + g_StatsRound[get_param(id)][PLR_STATS_BHOP_COUNT], iStats[get_param(id)][PLR_STATS_BHOP_PERCENT_SUM] + g_StatsRound[get_param(id)][PLR_STATS_BHOP_PERCENT_SUM]);
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
		return get_average_percent(g_StatsRound[get_param(id)][PLR_STATS_SGS_COUNT], g_StatsRound[get_param(id)][PLR_STATS_SGS_PERCENT_SUM]);
	}
	return get_average_percent(iStats[get_param(id)][PLR_STATS_SGS_COUNT] + g_StatsRound[get_param(id)][PLR_STATS_SGS_COUNT], iStats[get_param(id)][PLR_STATS_SGS_PERCENT_SUM] + g_StatsRound[get_param(id)][PLR_STATS_SGS_PERCENT_SUM]);
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
		if (i == PLR_STATS_KILLS_CT || i == PLR_MATCH || i == PLR_STATS_DEATHS_CT) {
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
	g_flSpottedVisibleTime[id] = 0.0;
	g_bSpottedConfirmed[id] = false;
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
		g_flSpottedVisibleTime[iPlayer] = 0.0;
		g_bSpottedConfirmed[iPlayer] = false;

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
		g_flSpottedVisibleTime[id] = 0.0;
		g_bSpottedConfirmed[id] = false;
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

	if (!g_bFirstDeathTt && is_user_connected(victim) && rg_get_user_team(victim) == TEAM_TERRORIST) {
		g_StatsRound[victim][PLR_STATS_FD_TT]++;
		g_bFirstDeathTt = true;
	}

	if (!g_bFirstKillCt && is_user_connected(attacker) && victim != attacker && rg_get_user_team(attacker) == TEAM_CT && rg_get_user_team(victim) == TEAM_TERRORIST) {
		g_StatsRound[attacker][PLR_STATS_FK_CT]++;
		g_bFirstKillCt = true;
	}

	if (is_user_connected(attacker) && victim != attacker && rg_get_user_team(attacker) == TEAM_CT) {
		g_StatsRound[attacker][PLR_STATS_KILLS_CT]++;
	}

	if (is_user_connected(victim) && rg_get_user_team(victim) == TEAM_CT) {
		g_StatsRound[victim][PLR_STATS_DEATHS_CT]++;
	}

	if (g_iLastAttacker[victim] && g_iLastAttacker[victim] != attacker && rg_get_user_team(g_iLastAttacker[victim]) == TEAM_CT) {
		g_StatsRound[g_iLastAttacker[victim]][PLR_STATS_ASSISTS_CT]++;
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

	if (!is_user_alive(iAttacker) || iVictim == iAttacker || !is_user_alive(iVictim)) {
		return;
	}

	new TeamName:iAttackerTeam = rg_get_user_team(iAttacker);
	new TeamName:iVictimTeam = rg_get_user_team(iVictim);
	if (iAttackerTeam == iVictimTeam || iAttackerTeam == TEAM_SPECTATOR || iVictimTeam == TEAM_SPECTATOR) {
		return;
	}

	new Float:fHealth; get_entvar(iVictim, var_health, fHealth);
	if (fDamage < fHealth) {
		g_iLastAttacker[iVictim] = iAttacker;
	}

	new iDamage = floatround(fDamage);
	if (iDamage <= 0) {
		return;
	}
	iDamage = min(iDamage, 100);

	if (iAttackerTeam == TEAM_CT && iVictimTeam == TEAM_TERRORIST) {
		if (is_attacker_knife(iAttacker)) {
			g_StatsRound[iAttacker][PLR_STATS_DAMAGE_CT] += iDamage;
		}
		g_StatsRound[iAttacker][PLR_STATS_STABS_CT]++;
	}
}

public rgPlayerFallDamage(id) {
	if (hns_get_mode() != MODE_MIX || hns_get_state() != STATE_ENABLED) {
		return;
	}

	new dmg = floatround(Float:GetHookChainReturn(ATYPE_FLOAT));
	if (dmg <= 0) {
		return;
	}
	dmg = min(dmg, 100);

	new TeamName:iTeam = rg_get_user_team(id);
	if (iTeam == TEAM_TERRORIST) {
		g_StatsRound[id][PLR_STATS_FALLDMG_TT] += dmg;
	} else if (iTeam == TEAM_CT) {
		g_StatsRound[id][PLR_STATS_FALLDMG_CT] += dmg;
	}
}

public rgPlayerBlind(const index, const inflictor, const attacker, const Float:fadeTime, const Float:fadeHold, const alpha) {
	if (hns_get_mode() != MODE_MIX || hns_get_state() != STATE_ENABLED) {
		return HC_CONTINUE;
	}

	if(rg_get_user_team(index) != TEAM_CT || rg_get_user_team(attacker) != TEAM_TERRORIST || index == attacker)
		return HC_CONTINUE;

	if (alpha != 255 || fadeHold < 1.0)
		return HC_CONTINUE;

	g_StatsRound[attacker][PLR_STATS_FLASHTIME] += fadeHold;
	g_StatsRound[attacker][PLR_STATS_FLASHCOUNT]++;

	if (!is_nullent(inflictor)) {
		set_entvar(inflictor, var_iuser1, 1);
	}

	return HC_CONTINUE;
}

public rgThrowFlashbang(const index, Float:vecStart[3], Float:vecVelocity[3], Float:time) {
	if (hns_get_mode() != MODE_MIX || hns_get_state() != STATE_ENABLED) {
		return HC_CONTINUE;
	}

	if (rg_get_user_team(index) != TEAM_TERRORIST) {
		return HC_CONTINUE;
	}

	new iEnt = GetHookChainReturn(ATYPE_INTEGER);
	if (!is_nullent(iEnt)) {
		set_entvar(iEnt, var_iuser1, 0);
		set_entvar(iEnt, var_iuser2, index);
	}

	g_StatsRound[index][PLR_STATS_FLASH]++;

	return HC_CONTINUE;
}

public rgExplodeFlashbang(const ent) {
	if (hns_get_mode() != MODE_MIX || hns_get_state() != STATE_ENABLED) {
		return HC_CONTINUE;
	}

	if (is_nullent(ent)) {
		return HC_CONTINUE;
	}

	if (get_entvar(ent, var_iuser1) != 0) {
		return HC_CONTINUE;
	}

	new owner = get_entvar(ent, var_iuser2);
	if (owner <= 0 || owner > MaxClients) {
		return HC_CONTINUE;
	}

	if (rg_get_user_team(owner) != TEAM_TERRORIST) {
		return HC_CONTINUE;
	}

	g_StatsRound[owner][PLR_STATS_FLASHFAIL]++;

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
				if (get_gametime() >= g_flSpottedTrackStart && !g_bSpottedConfirmed[id]) {
					if (is_player_spotted_by_ct(id)) {
						g_flSpottedVisibleTime[id] += frametime;
						if (g_flSpottedVisibleTime[id] >= SPOT_CONFIRM_TIME) {
							g_bSpottedConfirmed[id] = true;
							g_StatsRound[id][PLR_STATS_SPOTTED_ROUNDS] = 1;
						}
					} else {
						g_flSpottedVisibleTime[id] = 0.0;
					}
				}
			}
		}
	}

	last_updated[id] = get_gametime();
	xs_vec_copy(origin, g_flLastPosition[id]);
}

public rgRoundFreezeEnd() {
	g_flSpottedTrackStart = get_gametime() + SPOT_START_DELAY;
	set_task(0.25, "taskRoundEvent", .id = TASK_TIMER_STATS, .flags = "b");
}

public taskRoundEvent() {
	if (hns_get_state() != STATE_ENABLED || hns_get_mode() != MODE_MIX) {
		remove_task(TASK_TIMER_STATS);
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	new lastTT = 0;
	new aliveTT = 0;
	for (new i = 0; i < iNum; i++) {
		new pid = iPlayers[i];
		if (!is_user_connected(pid)) {
			continue;
		}
		if (rg_get_user_team(pid) != TEAM_TERRORIST) {
			continue;
		}
		if (!is_user_alive(pid)) {
			continue;
		}
		aliveTT++;
		lastTT = pid;
	}

	for (new i = 0; i < iNum; i++)
	{
		new id = iPlayers[i];
		if(!is_user_connected(id))
			continue;

		new TeamName:iTeam = rg_get_user_team(id);
		if(iTeam == TEAM_SPECTATOR)
			continue;
		
		if (iTeam == TEAM_TERRORIST) {
			g_StatsRound[id][PLR_STATS_TT_ROUNDS] = 1;
			if (is_user_alive(id))
				g_StatsRound[id][PLR_STATS_SURVTIME] += 0.25;

			g_StatsRound[id][PLR_STATS_PLAYTIME] += 0.25;
			if (aliveTT == 1 && id == lastTT && is_user_alive(id)) {
				g_StatsRound[id][PLR_STATS_LAST_TT_TIME] += 0.25;
			}
		} else if (iTeam == TEAM_CT) {
			g_StatsRound[id][PLR_STATS_CT_ROUNDS] = 1;
		}
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
		g_flSpottedVisibleTime[id] = 0.0;
		g_bSpottedConfirmed[id] = false;
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

	g_bFirstKillCt = false;
	g_bFirstDeathTt = false;
	
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	for (new i = 0; i < iNum; i++) {
		new id = iPlayers[i];
		arrayset(g_StatsRound[id], 0, PLAYER_STATS);
		arrayset(g_flLastPosition[id], 0, sizeof(g_flLastPosition[]));
		g_flSpottedVisibleTime[id] = 0.0;
		g_bSpottedConfirmed[id] = false;
	
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
		flKills = float(iStats[id][PLR_STATS_KILLS_CT] + g_StatsRound[id][PLR_STATS_KILLS_CT]);
		iDeaths = iStats[id][PLR_STATS_DEATHS_CT] + g_StatsRound[id][PLR_STATS_DEATHS_CT];
	} else {
		flKills = float(iStats[id][PLR_STATS_KILLS_CT]);
		iDeaths = iStats[id][PLR_STATS_DEATHS_CT];
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

stock bool:is_attacker_knife(id) {
	new iWeapon = get_member(id, m_pActiveItem);
	if (iWeapon <= 0) {
		return false;
	}
	static szClassname[32];
	get_entvar(iWeapon, var_classname, szClassname, charsmax(szClassname));
	return (equal(szClassname, "weapon_knife") != 0);
}

stock bool:is_player_spotted_by_ct(id) {
	if (!is_user_alive(id) || rg_get_user_team(id) != TEAM_TERRORIST) {
		return false;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ache", "CT");

	new Float:ttEye[3], Float:ttViewOfs[3];
	get_entvar(id, var_origin, ttEye);
	get_entvar(id, var_view_ofs, ttViewOfs);
	ttEye[2] += ttViewOfs[2];

	new Float:ctEye[3], Float:ctViewOfs[3];
	for (new i = 0; i < iNum; i++) {
		new iCT = iPlayers[i];

		get_entvar(iCT, var_origin, ctEye);
		get_entvar(iCT, var_view_ofs, ctViewOfs);
		ctEye[2] += ctViewOfs[2];

		if (floatabs(ttEye[2] - ctEye[2]) > SPOT_HEIGHT_LIMIT) {
			continue;
		}

		if (fm_is_in_viewcone(iCT, ttEye) && fm_is_ent_visible(iCT, id)) {
			return true;
		}
	}

	return false;
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

		if (g_StatsRound[id][PLR_STATS_SPOTTED_ROUNDS]) {
			g_StatsRound[id][PLR_STATS_SPOTTED_SURV_TIME] += g_StatsRound[id][PLR_STATS_SURVTIME];
		}

		new mkKills = g_StatsRound[id][PLR_STATS_KILLS_CT];
		if (mkKills > 0) {
			if (mkKills > 5) {
				mkKills = 5;
			}
			switch (mkKills) {
				case 1: g_StatsRound[id][PLR_STATS_MK1_CT] = 1;
				case 2: g_StatsRound[id][PLR_STATS_MK2_CT] = 1;
				case 3: g_StatsRound[id][PLR_STATS_MK3_CT] = 1;
				case 4: g_StatsRound[id][PLR_STATS_MK4_CT] = 1;
				case 5: g_StatsRound[id][PLR_STATS_MK5_CT] = 1;
			}
		}

		iStats[id][PLR_STATS_OWNAGES] += g_StatsRound[id][PLR_STATS_OWNAGES];
		iStats[id][PLR_STATS_BHOP_COUNT] += g_StatsRound[id][PLR_STATS_BHOP_COUNT];
		iStats[id][PLR_STATS_BHOP_PERCENT_SUM] = floatadd(iStats[id][PLR_STATS_BHOP_PERCENT_SUM], g_StatsRound[id][PLR_STATS_BHOP_PERCENT_SUM]);
		iStats[id][PLR_STATS_SGS_COUNT] += g_StatsRound[id][PLR_STATS_SGS_COUNT];
		iStats[id][PLR_STATS_SGS_PERCENT_SUM] = floatadd(iStats[id][PLR_STATS_SGS_PERCENT_SUM], g_StatsRound[id][PLR_STATS_SGS_PERCENT_SUM]);
		iStats[id][PLR_STATS_DDRUN_COUNT] += g_StatsRound[id][PLR_STATS_DDRUN_COUNT];
		iStats[id][PLR_STATS_DDRUN_PERCENT_SUM] = floatadd(iStats[id][PLR_STATS_DDRUN_PERCENT_SUM], g_StatsRound[id][PLR_STATS_DDRUN_PERCENT_SUM]);
		iStats[id][PLR_STATS_KILLS_CT] += g_StatsRound[id][PLR_STATS_KILLS_CT];
		iStats[id][PLR_STATS_DEATHS_CT] += g_StatsRound[id][PLR_STATS_DEATHS_CT];
		iStats[id][PLR_STATS_ASSISTS_CT] += g_StatsRound[id][PLR_STATS_ASSISTS_CT];
		iStats[id][PLR_STATS_STABS_CT] += g_StatsRound[id][PLR_STATS_STABS_CT];
		iStats[id][PLR_STATS_FALLDMG_TT] += g_StatsRound[id][PLR_STATS_FALLDMG_TT];
		iStats[id][PLR_STATS_FALLDMG_CT] += g_StatsRound[id][PLR_STATS_FALLDMG_CT];
		iStats[id][PLR_STATS_DAMAGE_CT] += g_StatsRound[id][PLR_STATS_DAMAGE_CT];
		iStats[id][PLR_STATS_FLASHCOUNT] += g_StatsRound[id][PLR_STATS_FLASHCOUNT];
		iStats[id][PLR_STATS_FLASH] += g_StatsRound[id][PLR_STATS_FLASH];
		iStats[id][PLR_STATS_FLASHFAIL] += g_StatsRound[id][PLR_STATS_FLASHFAIL];
		iStats[id][PLR_STATS_LAST_TT_TIME] += g_StatsRound[id][PLR_STATS_LAST_TT_TIME];
		iStats[id][PLR_STATS_FK_CT] += g_StatsRound[id][PLR_STATS_FK_CT];
		iStats[id][PLR_STATS_FD_TT] += g_StatsRound[id][PLR_STATS_FD_TT];
		iStats[id][PLR_STATS_MK1_CT] += g_StatsRound[id][PLR_STATS_MK1_CT];
		iStats[id][PLR_STATS_MK2_CT] += g_StatsRound[id][PLR_STATS_MK2_CT];
		iStats[id][PLR_STATS_MK3_CT] += g_StatsRound[id][PLR_STATS_MK3_CT];
		iStats[id][PLR_STATS_MK4_CT] += g_StatsRound[id][PLR_STATS_MK4_CT];
		iStats[id][PLR_STATS_MK5_CT] += g_StatsRound[id][PLR_STATS_MK5_CT];
		iStats[id][PLR_STATS_PLAYTIME] += g_StatsRound[id][PLR_STATS_PLAYTIME];
		iStats[id][PLR_STATS_TT_ROUNDS] += g_StatsRound[id][PLR_STATS_TT_ROUNDS];
		iStats[id][PLR_STATS_CT_ROUNDS] += g_StatsRound[id][PLR_STATS_CT_ROUNDS];
		iStats[id][PLR_STATS_SPOTTED_ROUNDS] += g_StatsRound[id][PLR_STATS_SPOTTED_ROUNDS];
		iStats[id][PLR_STATS_SPOTTED_SURV_TIME] = floatadd(iStats[id][PLR_STATS_SPOTTED_SURV_TIME], g_StatsRound[id][PLR_STATS_SPOTTED_SURV_TIME]);
		iStats[id][PLR_STATS_FLASHTIME] += g_StatsRound[id][PLR_STATS_FLASHTIME];
		iStats[id][PLR_STATS_SURVTIME] += g_StatsRound[id][PLR_STATS_SURVTIME];

		arrayset(g_StatsRound[id], 0, PLAYER_STATS);

		SetScoreInfo(id, false);
	}
}
