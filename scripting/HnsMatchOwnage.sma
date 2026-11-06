#include <amxmodx>
#include <engine>
#include <reapi>
#include <sqlx>
#include <hns_matchsystem>
#include <hns_matchsystem_filter>
#include <hns_matchsystem_dbmysql>
#include <hns_matchsystem_api>

#define DELAY 5.0

new Float:g_flLastHeadTouch[MAX_PLAYERS + 1];
new g_iHeadTarget[MAX_PLAYERS + 1];
new g_iOwnageCheckMode = 1;

new g_hForwardOwnage;
new HookChain:g_hPostThink;

new const g_szSound[][] = {
	"openhns/mario.wav",
	"openhns/ownage.wav"
};

public plugin_precache() {
	for(new i; i < sizeof(g_szSound); i++)
		precache_sound(g_szSound[i]);
}

public plugin_natives() {
	set_native_filter("match_system_additons");
}

public plugin_init() {
	register_plugin("Match: Ownage", "1.1", "OpenHNS");
	
	register_touch("player", "player", "touchPlayer");
	g_hPostThink = RegisterHookChain(RG_CBasePlayer_PostThink, "CBasePlayer_PostThink_Post", true);

	new pCvar = create_cvar(
		"hns_ownage_check_mode",
		"1",
		FCVAR_NONE,
		"Ownage detection: 0 - Engine Touch, 1 - ReAPI PostThink",
		true,
		0.0,
		true,
		1.0
	);
	bind_pcvar_num(pCvar, g_iOwnageCheckMode);
	hook_cvar_change(pCvar, "CvarOwnageCheckModeChanged");

	if (g_iOwnageCheckMode == 0) {
		DisableHookChain(g_hPostThink);
	}

	register_dictionary("match_additons.txt");

	g_hForwardOwnage = CreateMultiForward("hns_ownage", ET_CONTINUE, FP_CELL, FP_CELL);
}

public touchPlayer(iToucher, iTouched) {
	if (g_iOwnageCheckMode != 0) {
		return;
	}

	if(entity_get_int(iToucher, EV_INT_flags) & FL_ONGROUND && entity_get_edict(iToucher, EV_ENT_groundentity) == iTouched && rg_get_user_team(iToucher) == TEAM_TERRORIST && rg_get_user_team(iTouched) == TEAM_CT) {
		HandleOwnage(iToucher, iTouched);
	}
}

public CBasePlayer_PostThink_Post(id) {
	if (!is_user_alive(id) || rg_get_user_team(id) != TEAM_TERRORIST) {
		g_iHeadTarget[id] = 0;
		return;
	}

	new iTouched = get_entvar(id, var_groundentity);

	if (!(get_entvar(id, var_flags) & FL_ONGROUND)
		|| iTouched < 1
		|| iTouched > MaxClients
		|| !is_user_alive(iTouched)
		|| rg_get_user_team(iTouched) != TEAM_CT)
	{
		g_iHeadTarget[id] = 0;
		return;
	}

	if (g_iHeadTarget[id] == iTouched) {
		return;
	}

	g_iHeadTarget[id] = iTouched;
	HandleOwnage(id, iTouched);
}

public CvarOwnageCheckModeChanged(pCvar, const szOldValue[], const szNewValue[]) {
	new iOldMode = clamp(str_to_num(szOldValue), 0, 1);
	new iNewMode = clamp(str_to_num(szNewValue), 0, 1);

	g_iOwnageCheckMode = iNewMode;

	if (iOldMode == iNewMode) {
		return;
	}

	arrayset(g_iHeadTarget, 0, sizeof(g_iHeadTarget));

	if (iNewMode == 1) {
		EnableHookChain(g_hPostThink);
	} else {
		DisableHookChain(g_hPostThink);
	}
}

stock HandleOwnage(iToucher, iTouched) {
	new Float:flGametime = get_gametime();

	if (g_flLastHeadTouch[iToucher] > 0.0 && flGametime <= g_flLastHeadTouch[iToucher] + DELAY) {
		return;
	}

	new HNS_MODES:iMode = hns_get_mode();
	new bool:bOwnageHandled = false;

	if (hns_mysql_stats_init() && iMode == MODE_MIX && hns_get_state() == STATE_ENABLED) {
		ClearDHUDMessages();
		set_dhudmessage(250, 255, 0, -1.0, 0.15, 0, 0.0, 5.0, 0.1, 0.1);
		show_dhudmessage(0, "%L", LANG_PLAYER, "HNS_OWNAGE_MIX", iToucher, iTouched, hns_mysql_stats_get_ownage(iToucher));
		hns_mysql_stats_set_ownage(iToucher);
		bOwnageHandled = true;
	} else if (iMode == MODE_PUB || iMode == MODE_DM || iMode == MODE_DM_1TT || iMode == MODE_ZM) {
		ClearDHUDMessages();
		set_dhudmessage(250, 255, 0, -1.0, 0.15, 0, 0.0, 5.0, 0.1, 0.1);
		show_dhudmessage(0, "%L", LANG_PLAYER, "HNS_OWNAGE", iToucher, iTouched);
		bOwnageHandled = true;
	}

	if (!bOwnageHandled) {
		return;
	}

	g_flLastHeadTouch[iToucher] = flGametime;
	rg_send_audio(0, g_szSound[random(sizeof(g_szSound))]);
	ExecuteForward(g_hForwardOwnage, _, iToucher, iTouched);
}

public client_disconnected(id) {
	g_flLastHeadTouch[id] = 0.0;
	g_iHeadTarget[id] = 0;
}

stock ClearDHUDMessages(iClear = 8) {
	for (new iDHUD = 0; iDHUD < iClear; iDHUD++)
		show_dhudmessage(0, ""); 
}
