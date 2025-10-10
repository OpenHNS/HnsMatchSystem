//new hook_cmd;

#define TASK_HOOK 99912

new bool:isHook[MAX_PLAYERS + 1];

new ihookOrigin[MAX_PLAYERS + 1][3];

//new HookChain:fwdPlayerMove;

public training_init() {
	g_GPFuncs[GAMEPLAY_TRAINING][GP_ENABLE]	  = CreateOneForward(g_PluginId, "training_enable_rules");
	g_GPFuncs[GAMEPLAY_TRAINING][GP_DISABLE]  = CreateOneForward(g_PluginId, "training_disable_rules");
	g_GPFuncs[GAMEPLAY_TRAINING][GP_SETROLE]  = CreateOneForward(g_PluginId, "training_setrole", FP_CELL);
}

public training_enable_rules() {
	set_semiclip(SEMICLIP_OFF);

	register_clcmd("+hook", "hook_old_on");
	register_clcmd("-hook", "hook_old_off");

	// if(!hook_cmd)
	// {
	// 	hook_cmd = register_clcmd("+hook", "hook_on");
	// 	register_clcmd("-hook", "hook_off");
	// }

	// if(!fwdPlayerMove)
	// 	fwdPlayerMove = RegisterHookChain(RG_PM_Move, "PM_PlayerMove", true);

	// EnableHookChain(fwdPlayerMove);
}
// public hook_on(id) {
// 	hook[id] = true;
// }

// public hook_off(id) {
// 	hook[id] = false;
// }

// public PM_PlayerMove(const PlayerMove:ppmove, const server) {
// 	static Float:velocity[3];
// 	new const id = get_pmove(pm_player_index) + 1;

// 	if(hook[id]) {
// 		velocity_by_aim(id, 750, velocity);
// 		set_pmove(pm_velocity, velocity);

// 		set_entvar(id, var_sequence, 8);
// 		set_entvar(id, var_gaitsequence, 1);
// 	}
// }

public training_disable_rules() {
	// if (fwdPlayerMove)
	// 	DisableHookChain(fwdPlayerMove);
}

public training_setrole(id) {
	rg_remove_all_items(id);
	setUserGodmode(id, true);
	rg_give_item(id, "weapon_knife");
	rg_set_user_footsteps(id, false);
}


public hook_old_on(id) {
	if(!is_user_alive(id)) {
		return PLUGIN_HANDLED;
	}
	
	isHook[id] = true;

	get_user_origin(id, ihookOrigin[id], 3);

	set_task(0.1, "server_hook_task", id + TASK_HOOK, "", 0, "ab");

	server_hook_task(id + TASK_HOOK);


	return PLUGIN_HANDLED;
}

public hook_old_off(id) {
	remove_hook(id);
}


public server_hook_task(id) {
	id -= TASK_HOOK;

	if (g_iCurrentMode != MODE_TRAINING && g_eMatchState != STATE_PAUSED) {
		remove_hook(id);
		return PLUGIN_HANDLED;
	}

	if(!is_user_connected(id) || !is_user_alive(id)) {
		remove_hook(id);
		return PLUGIN_HANDLED;
	}

	if (!isHook[id]) {
		remove_hook(id);
		return PLUGIN_HANDLED;
	}

	remove_hook_beam(id);
	
	create_hook_beam(id);


	new iOrigin[3], Float:flVelocity[3];

	get_user_origin(id,iOrigin)
	
	new iDistance = get_distance(ihookOrigin[id],iOrigin)
	
	if(iDistance > 60) {
		flVelocity[0] = (ihookOrigin[id][0] - iOrigin[0]) * (2.0 * 400 / iDistance)
		flVelocity[1] = (ihookOrigin[id][1] - iOrigin[1]) * (2.0 * 400 / iDistance)
		flVelocity[2] = (ihookOrigin[id][2] - iOrigin[2]) * (2.0 * 400 / iDistance)
		set_entvar(id, var_velocity, flVelocity)
	} else {
		set_entvar(id, var_velocity, Float:{0.0,0.0,0.0})
		set_entvar(id, var_gravity, 0.00000001);
	}
	
	set_entvar(id, var_sequence, 8);
	set_entvar(id, var_gaitsequence, 1);
	set_entvar(id, var_frame, 0.0);

	return PLUGIN_HANDLED;
}

public remove_hook(id) {
	if(task_exists(id + TASK_HOOK)) {
		remove_task(id + TASK_HOOK)
	}

	set_pev(id, pev_gravity, 1.0);

	isHook[id] = false;

	remove_hook_beam(id);

}

public create_hook_beam(id) {
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(1)
	write_short(id)
	write_coord(ihookOrigin[id][0])
	write_coord(ihookOrigin[id][1])
	write_coord(ihookOrigin[id][2])
	write_short(iBeam)
	write_byte(0)
	write_byte(0)
	write_byte(100)
	write_byte(2)
	write_byte(0)
	write_byte(100)
	write_byte(100)
	write_byte(100)
	write_byte(100)
	write_byte(0)
	message_end()
}

public remove_hook_beam(id) {
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(99)
	write_short(id)
	message_end()
}