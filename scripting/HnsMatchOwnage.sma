#include <amxmodx>
#include <engine>
#include <reapi>
#include <sqlx>
#include <hns_matchsystem>
#include <hns_matchsystem_dbmysql>

#define DELAY 5.0

new Float:g_flLastHeadTouch[MAX_PLAYERS + 1];

new g_hForwardOwnage;

new const g_szSound[][] = {
	"openhns/mario.wav",
	"openhns/ownage.wav"
};

public plugin_precache() {
	for(new i; i < sizeof(g_szSound); i++)
		precache_sound(g_szSound[i]);
}

public plugin_natives() {
	set_native_filter("hns_dbmysql_filter");
}

public plugin_init() {
	register_plugin("Match: Ownage", "1.1", "OpenHNS");
	
	register_touch("player", "player", "touchPlayer");

	register_dictionary("match_additons.txt");

	g_hForwardOwnage = CreateMultiForward("hns_ownage", ET_CONTINUE, FP_CELL, FP_CELL);
}

public touchPlayer(iToucher, iTouched) {
	if(entity_get_int(iToucher, EV_INT_flags) & FL_ONGROUND && entity_get_edict(iToucher, EV_ENT_groundentity) == iTouched && rg_get_user_team(iToucher) == TEAM_TERRORIST && rg_get_user_team(iTouched) == TEAM_CT) {
		static Float:flGametime;
		flGametime = get_gametime();
		
		if(flGametime > g_flLastHeadTouch[iToucher] + DELAY) {
			ClearDHUDMessages();
			set_dhudmessage(250, 255, 0, -1.0, 0.15, 0, 0.0, 5.0, 0.1, 0.1);
			if (hns_db_init() && hns_get_mode() == MODE_MIX && hns_get_state() == STATE_ENABLED) {
				show_dhudmessage(0, "%L", LANG_PLAYER, "HNS_OWNAGE_MIX", iToucher, iTouched, hns_get_ownage(iToucher));
				hns_set_ownage(iToucher);
			} else if (hns_get_mode() == MODE_PUB || hns_get_mode() == MODE_DM || hns_get_mode() == MODE_ZM) {
				show_dhudmessage(0, "%L", LANG_PLAYER, "HNS_OWNAGE", iToucher, iTouched);
			}
			
			if (hns_get_mode() == MODE_MIX || hns_get_mode() == MODE_PUB || hns_get_mode() == MODE_DM || hns_get_mode() == MODE_ZM) {
				g_flLastHeadTouch[iToucher] = flGametime;
				rg_send_audio(0, g_szSound[random(sizeof(g_szSound))]);
			}

			ExecuteForward(g_hForwardOwnage, _, iToucher, iTouched);
		}
	}
}

public client_disconnected(id) {
	g_flLastHeadTouch[id] = 0.0;
}

stock ClearDHUDMessages(iClear = 8) {
	for (new iDHUD = 0; iDHUD < iClear; iDHUD++)
		show_dhudmessage(0, ""); 
}
