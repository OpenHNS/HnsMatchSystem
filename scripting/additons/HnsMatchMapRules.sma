#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <hns_matchsystem>

new g_szMapName[32];
new g_sPrefix[24];

public plugin_init() {
    register_plugin("Kill Piranesi", "0.0.1", "OpenHNS") // hedqi

    rh_get_mapname(g_szMapName, charsmax(g_szMapName));

    if(equali(g_szMapName, "de_piranesi")) {
		register_forward(FM_PlayerPreThink, "fwdPreThink");
	}
}

public plugin_cfg() {
	hns_get_prefix(g_sPrefix, charsmax(g_sPrefix));
}

public fwdPreThink(id) {
	if(!is_user_alive(id))
		return FMRES_IGNORED;

	if(hns_get_mode() != MODE_TRAINING) {
		if(pev(id, pev_waterlevel)) {
			client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "KILL_WATER", g_sPrefix, id);
			user_kill(id, 1);
		}
	}
	return FMRES_IGNORED;
}