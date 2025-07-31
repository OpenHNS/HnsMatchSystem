#if defined _globals_included
  #endinput
#endif

#define _globals_included

#define TASK_TIMER 54345
#define HUD_PAUSE 23931

#define TASK_WAIT 12319
#define TASK_STARTED 13339

#define TASK_WAITCAP 13131

#define TASK_SURRENDER 55566

new bool:g_bDebugMode;

new g_PluginId;

enum NATCH_RULES {
	RULES_MR,
	RULES_TIMER,
	RULES_DUEL
}

new NATCH_RULES:g_iCurrentRules;

enum MATCH_STATUS {
	MATCH_NONE,
	MATCH_CAPTAINPICK,
	MATCH_CAPTAINKNIFE,
	MATCH_TEAMPICK,
	MATCH_TEAMKNIFE,
	MATCH_MAPPICK,
	MATCH_WAITCONNECT,
	MATCH_STARTED
}
new MATCH_STATUS:g_iMatchStatus;

enum MODE_STATES {
	STATE_DISABLED,
	STATE_PREPARE,
	STATE_PAUSED,
	STATE_ENABLED
}
new MODE_STATES:g_eMatchState;

enum HNS_TEAM {
	HNS_TEAM_B,
	HNS_TEAM_A
}

new HNS_TEAM:g_isTeamTT;

enum _:MATCH_INFO {
	e_mTeamSize,
	e_mTeamSizeTT,
	Float:e_mWintime,
	Float:e_flSidesTime[HNS_TEAM],
	e_iSidesRounds[HNS_TEAM],
	Trie:e_tLeaveData,
	bool:e_mLeaved
};

new g_eMatchInfo[MATCH_INFO];

enum _:SurrenderData_s {
	bool:e_sStarted,
	e_sInitiator,
	Float:e_sFlDelay,
	Float:e_sFlTime
};
new g_eSurrenderData[SurrenderData_s];

new bool:g_bNoplay[MAX_PLAYERS + 1];

new Float:g_flRoundTime;

new g_szMapName[32]
new g_iHostageEnt;

// const
new const sndDenySelect[] = "common/wpn_denyselect.wav";
new const sndUseSound[] = "buttons/blip1.wav";

enum _: Forwards {
	TEAM_BATTLE,
	MATCH_START,
	MATCH_RESET_ROUND,
	MATCH_FINISH,
	MATCH_FINISH_POST,
	MATCH_CANCEL,
	MATCH_LEAVE_PLAYER,
	MATCH_JOIN_PLAYER,
	HNS_ROUND_START,
	HNS_ROUND_END,
	HNS_ROUND_FREEZEEND
};

new g_hForwards[Forwards];

enum PLAYER_ROLES { 
	ROLE_SPEC = 0, 
	ROLE_CAP_A, 
	ROLE_TEAM_A, 
	ROLE_CAP_B, 
	ROLE_TEAM_B
};

enum _: PLAYER_INFO {
	PLAYER_ROLES:PLAYER_ROLE,
	bool:PLAYER_MATCH,
	PLAYER_TEAM[16],
	LEAVE_IN_ROUND
};

new g_ePlayerInfo[MAX_PLAYERS + 1][PLAYER_INFO];

new Array:g_aPlayersLoadData;

new TeamName:g_eSpecBack[MAX_PLAYERS + 1];

new g_msgMoney;