public battle_init() {
	g_GPFuncs[GAMEPLAY_BATTLERACE][GP_ENABLE] = CreateOneForward(g_PluginId, "battle_enable_rules");
	g_GPFuncs[GAMEPLAY_BATTLERACE][GP_DISABLE] = CreateOneForward(g_PluginId, "battle_disable_rules");
	g_GPFuncs[GAMEPLAY_BATTLERACE][GP_SETROLE] = CreateOneForward(g_PluginId, "battle_setrole", FP_CELL);
}

public battle_enable_rules() {
	// ReSemiclip: team 0 -> semiclip for all players (including enemies).
	set_semiclip(SEMICLIP_ON);
	g_iCurrentGameplay = GAMEPLAY_BATTLERACE;

	// Battle gameplay intentionally has no +hook logic.
	for (new id = 1; id <= MaxClients; id++) {
		if (is_user_connected(id)) {
			remove_hook(id);
		}
	}
}

public battle_disable_rules() {
}

public battle_setrole(id) {
	if (!is_user_connected(id)) {
		return;
	}

	rg_remove_all_items(id);
	setUserGodmode(id, true);
	rg_give_item(id, "weapon_knife");
	rg_set_user_footsteps(id, false);
}
