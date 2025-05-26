#include <amxmodx>
#include <reapi>

#include <hns_matchsystem>

new iWatcherAccess = ADMIN_BAN;

public plugin_init() {
	register_plugin("Match: Admin management", "1.0", "OpenHNS");

	// pCvar[WATCHER_FLAG] = create_cvar("hns_watcher_flag", "f", FCVAR_NONE, "Watcher access flag");
	// bind_pcvar_string(pCvar[WATCHER_FLAG], g_iSettings[WATCHER_FLAG], charsmax(g_iSettings[WATCHER_FLAG]));

	// pCvar[FULL_WATCHER_FLAG] = create_cvar("hns_fullwatcher_flag", "m", FCVAR_NONE, "Full watcher access flag");
	// bind_pcvar_string(pCvar[FULL_WATCHER_FLAG], g_iSettings[FULL_WATCHER_FLAG], charsmax(g_iSettings[FULL_WATCHER_FLAG]));

	// pCvar[ADMIN_FLAG] = create_cvar("hns_admin_flag", "b", FCVAR_NONE, "Admin access flag");
	// bind_pcvar_string(pCvar[ADMIN_FLAG], g_iSettings[ADMIN_FLAG], charsmax(g_iSettings[ADMIN_FLAG]));

	RegisterSayCmd("mr", 		"maxround", 	"cmdMrMode",		iWatcherAccess, "Choose MR mode");
	RegisterSayCmd("timer", 	"wintime", 		"cmdWintimeMode",	iWatcherAccess, "Choose Wintime mode");
	RegisterSayCmd("duel", 		"versus", 		"cmdDuelMode",		iWatcherAccess, "Choose 1x1 mode");
}

// public plugin_cfg()
// {
//     console_print(0, "[%i] plugin_cfg", g_iLine);   
//     g_iLine++;
// }

public cmdMrMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (hns_get_rules() == RULES_MR) {
		chat_print(0, "%l", "MODE_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (hns_get_mode() == MODE_MIX) {
		chat_print(0, "%l", "MODE_NOT_MIX");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "MODE_SET_MR", id);
	hns_set_rules(RULES_MR);

	return PLUGIN_HANDLED;
}

public cmdWintimeMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (hns_get_rules() == RULES_TIMER) {
		chat_print(0, "%l", "MODE_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (hns_get_mode() == MODE_MIX) {
		chat_print(0, "%l", "MODE_NOT_MIX");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "MODE_SET_WT", id);
	hns_set_rules(RULES_TIMER);

	return PLUGIN_HANDLED;
}

public cmdDuelMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (hns_get_rules() == RULES_DUEL) {
		chat_print(0, "%l", "MODE_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (hns_get_mode() == MODE_MIX) {
		chat_print(0, "%l", "MODE_NOT_MIX");
		return PLUGIN_HANDLED;
	}

	if (get_num_players_in_match() > 2) {
		chat_print(0, "%l", "MODE_NOT_SET_DUEL");
		return PLUGIN_HANDLED;
	}

	chat_print(0, "%l", "MODE_SET_DUEL", id);
	hns_set_rules(RULES_DUEL);

	return PLUGIN_HANDLED;
}

stock bool:isUserWatcher(id) {
	if (get_user_flags(id)) //& hns_get_flag_watcher())
		return true;
	else
		return false;
}

stock bool:isUserFullWatcher(id) {
	if (get_user_flags(id)) // & hns_get_flag_fullwatcher())
		return true;
	else
		return false;
}

stock bool:isUserAdmin(id) {
	if (get_user_flags(id)) // & hns_get_flag_admin())
		return true;
	else
		return false;
}