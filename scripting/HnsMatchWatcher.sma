#include <amxmodx>
#include <reapi>

#include <hns_matchsystem>

new iWatcherAccess = ADMIN_BAN;

public plugin_init() {
	register_plugin("Match: Watcher management", "1.0.1", "OpenHNS");

	RegisterSayCmd("mr", 		"maxround", 	"cmdMrMode",		iWatcherAccess, "Choose MR mode");
	RegisterSayCmd("timer", 	"wintime", 		"cmdWintimeMode",	iWatcherAccess, "Choose Wintime mode");
	RegisterSayCmd("duel", 		"versus", 		"cmdDuelMode",		iWatcherAccess, "Choose 1x1 mode");
}

public cmdMrMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (hns_get_rules() == RULES_MR) {
		client_print_color(0, print_team_blue, "%l", "MODE_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (hns_get_mode() == MODE_MIX) {
		client_print_color(0, print_team_blue, "%l", "MODE_NOT_MIX");
		return PLUGIN_HANDLED;
	}

	client_print_color(0, print_team_blue, "%l", "MODE_SET_MR", id);
	hns_set_rules(RULES_MR);

	return PLUGIN_HANDLED;
}

public cmdWintimeMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (hns_get_rules() == RULES_TIMER) {
		client_print_color(0, print_team_blue, "%l", "MODE_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (hns_get_mode() == MODE_MIX) {
		client_print_color(0, print_team_blue, "%l", "MODE_NOT_MIX");
		return PLUGIN_HANDLED;
	}

	client_print_color(0, print_team_blue, "%l", "MODE_SET_WT", id);
	hns_set_rules(RULES_TIMER);

	return PLUGIN_HANDLED;
}

public cmdDuelMode(id) {
	if (!isUserWatcher(id)) {
		return PLUGIN_HANDLED;
	}

	if (hns_get_rules() == RULES_DUEL) {
		client_print_color(0, print_team_blue, "%l", "MODE_ALREADY");
		return PLUGIN_HANDLED;
	}

	if (hns_get_mode() == MODE_MIX) {
		client_print_color(0, print_team_blue, "%l", "MODE_NOT_MIX");
		return PLUGIN_HANDLED;
	}

	if (get_num_players_in_match() > 2) {
		client_print_color(0, print_team_blue, "%l", "MODE_NOT_SET_DUEL");
		return PLUGIN_HANDLED;
	}

	client_print_color(0, print_team_blue, "%l", "MODE_SET_DUEL", id);
	hns_set_rules(RULES_DUEL);

	return PLUGIN_HANDLED;
}

stock get_num_players_in_match() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	new numGameplr;
	for (new i; i < iNum; i++) {
		new tempid = iPlayers[i];
		if (rg_get_user_team(tempid) == TEAM_SPECTATOR) continue;
		numGameplr++;
	}
	return numGameplr;
}