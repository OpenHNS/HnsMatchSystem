#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <hns_matchsystem>

new g_szPrefix[24];

new bool:g_bDamage[MAX_PLAYERS + 1];
new bool:g_bSaveAngles[MAX_PLAYERS + 1];

new Float:g_fCheckpointAngles[MAX_PLAYERS + 1][3];
new Float:g_fCheckpoints[MAX_PLAYERS + 1][2][3];
new bool:g_fCheckpointAlternate[MAX_PLAYERS + 1];

new bool:g_bInvisPlayers[MAX_PLAYERS + 1];

new g_hResetBugForward;

public plugin_init() {
	register_plugin("Match: Training", "1.0", "OpenHNS");

	RegisterSayCmd("training", "tr", "hns_training_menu");
	
	RegisterSayCmd("checkpoint", "cp", "CmdCheckpoint");
	RegisterSayCmd("teleport", "tp", "CmdGoCheck");
	RegisterSayCmd("gocheck", "gc", "CmdGoCheck");
	RegisterSayCmd("stuck", "st", "CmdStuck");
	RegisterSayCmd("respawn", "rp", "CmdRespawn");
	RegisterSayCmd("noclip", "clip", "CmdClipMode");
	RegisterSayCmd("showdamage", "showdmg", "CmdShowDamage");
	RegisterSayCmd("angles", "ang", "CmdSaveAngles");
	RegisterSayCmd("invis", "inv", "cmdInvis");

	RegisterSayCmd("weapons", "weap", "cmdWeapons");
	RegisterSayCmd("scout", "sc", "cmdScout");
	RegisterSayCmd("usp", "pistol", "cmdUsp");
	RegisterSayCmd("awp", "sniper", "cmdAWP");
	RegisterSayCmd("m4a1", "m4", "cmdM4A1");
	
	RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "rgFlPlayerFallDamage", true);
	RegisterHookChain(RG_CBasePlayer_Spawn, "rgPlayerSpawn", false);

	register_forward(FM_AddToFullPack, "fmAddToFullPack", 1);
	
	g_hResetBugForward = CreateMultiForward("fwResetBug", ET_IGNORE, FP_CELL);

	register_dictionary("match_additons.txt");
}

public client_putinserver(id) {
	g_bDamage[id] = true;
	g_bSaveAngles[id] = true;
	g_bInvisPlayers[id] = false;
}

public plugin_cfg() {
	hns_get_prefix(g_szPrefix, charsmax(g_szPrefix));
}

public CmdClipMode(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if(!is_user_alive(id))  {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_NOT_ALIVE", g_szPrefix);
		return PLUGIN_HANDLED;
	}

	new iClip = get_entvar(id, var_movetype) != MOVETYPE_NOCLIP ? MOVETYPE_NOCLIP : MOVETYPE_WALK;

	set_entvar(id, var_movetype, iClip);

	if (iClip == MOVETYPE_NOCLIP) {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_CLIP_ON", g_szPrefix);
	} else {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_CLIP_OFF", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}


public CmdCheckpoint(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if(!is_user_alive(id)) {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_NOT_ALIVE", g_szPrefix);
		return PLUGIN_HANDLED;
	}

	get_entvar(id, var_origin, g_fCheckpoints[id][g_fCheckpointAlternate[id] ? 1 : 0]);
	get_entvar(id, var_v_angle, g_fCheckpointAngles[id]);

	g_fCheckpointAlternate[id] = !g_fCheckpointAlternate[id];

	client_print_color(id, print_team_blue, "%L", id, "TRNING_CPNT_SAVE", g_szPrefix);

	return PLUGIN_HANDLED;
}

public CmdRespawn(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if (rg_get_user_team(id) != TEAM_SPECTATOR) {
		rg_round_respawn(id);
	}

	return PLUGIN_HANDLED;
}

public CmdGoCheck(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if(!is_user_alive(id)) {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_NOT_ALIVE", g_szPrefix);
		return PLUGIN_HANDLED;
	}

	if(!g_fCheckpoints[id][0][0]) {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_TLPRT_NOT", g_szPrefix);
		return PLUGIN_HANDLED;
	}
	
	set_entvar(id, var_velocity, Float:{0.0, 0.0, 0.0});
	set_entvar(id, var_flags, get_entvar(id, var_flags) | FL_DUCKING);
	set_entvar(id, var_origin, g_fCheckpoints[id][!g_fCheckpointAlternate[id]]);

	if(g_bSaveAngles[id]) {
		set_entvar(id, var_angles, g_fCheckpointAngles[id]);
		set_entvar(id, var_v_angle, g_fCheckpointAngles[id]);
		set_entvar(id, var_fixangle, 1);
	}

	new iReturn;
	ExecuteForward(g_hResetBugForward, iReturn, id);

	return PLUGIN_HANDLED;
}

public CmdStuck(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED;
	}

	if(!is_user_alive(id)) {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_NOT_ALIVE", g_szPrefix);
		return PLUGIN_HANDLED;
	}

	if(!g_fCheckpoints[id][0][0] || !g_fCheckpoints[id][1][0]) {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_STUCK_NOT", g_szPrefix);
		return PLUGIN_HANDLED;
	}
		
	set_entvar(id, var_velocity, Float:{0.0, 0.0, 0.0});
	set_entvar(id, var_flags, get_entvar(id, var_flags) | FL_DUCKING);
	set_entvar(id, var_origin, g_fCheckpoints[id][g_fCheckpointAlternate[id]]);

	g_fCheckpointAlternate[id] = !g_fCheckpointAlternate[id];
	
	if(g_bSaveAngles[id]) {
		set_entvar(id, var_angles, g_fCheckpointAngles[id]);
		set_entvar(id, var_fixangle, 1);
	}

	return PLUGIN_HANDLED;
}

public CmdShowDamage(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED
	}

	g_bDamage[id] = !g_bDamage[id];

	if (g_bDamage[id]) {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_SHOW_ON", g_szPrefix);
	} else {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_SHOW_OFF", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}

public CmdSaveAngles(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED
	}

	g_bSaveAngles[id] = !g_bSaveAngles[id];

	if (g_bSaveAngles[id]) {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_ANGLES_ON", g_szPrefix);
	} else {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_ANGLES_OFF", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}

public cmdInvis(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED
	}

	g_bInvisPlayers[id] = !g_bInvisPlayers[id];

	if (g_bInvisPlayers[id]) {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_INVIS_ON", g_szPrefix);
	} else {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_INVIS_OFF", g_szPrefix);
	}

	return PLUGIN_HANDLED;
}

public cmdWeapons(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED
	}

	give_user_item(id, "weapon_awp", 10);
	give_user_item(id, "weapon_m249", 10);
	give_user_item(id, "weapon_m4a1", 10);
	give_user_item(id, "weapon_sg552", 10);
	give_user_item(id, "weapon_famas", 10);
	give_user_item(id, "weapon_p90", 10);
	give_user_item(id, "weapon_usp", 10, GT_REPLACE);
	give_user_item(id, "weapon_scout", 10);

	return PLUGIN_HANDLED;
}

public cmdScout(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED
	}

	give_user_item(id, "weapon_scout", 10, GT_REPLACE);
	return PLUGIN_HANDLED;
}

public cmdUsp(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED
	}

	give_user_item(id, "weapon_usp", 10, GT_REPLACE);
	return PLUGIN_HANDLED;
}

public cmdAWP(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED
	}

	give_user_item(id, "weapon_awp", 2, GT_REPLACE);
	return PLUGIN_HANDLED;
}

public cmdM4A1(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return PLUGIN_HANDLED
	}

	give_user_item(id, "weapon_m4a1", 10, GT_REPLACE);
	return PLUGIN_HANDLED;
}


public hns_training_menu(id) {
	if ((hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) || !is_user_connected(id))
		return PLUGIN_HANDLED;

	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_TRNING_TITLE");
	new hMenu = menu_create(szMsg, "hns_training_menu_code");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_TRNING_CPNT");
	menu_additem(hMenu, szMsg, "1");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_TRNING_TLPRT");
	menu_additem(hMenu, szMsg, "2");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_TRNING_NOCLIP");
	menu_additem(hMenu, szMsg, "3");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_TRNING_RESPAWN");
	menu_additem(hMenu, szMsg, "4");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_TRNING_DAMAGE");
	menu_additem(hMenu, szMsg, "5");

	if (g_bSaveAngles[id]) {
		formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_TRNING_ANGL_ON");
	} else {
		formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_TRNING_ANGL_OFF");
	}

	menu_additem(hMenu, szMsg, "6");

	if (g_bInvisPlayers[id]) {
		formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_TRNING_INVIS_ON");
	} else {
		formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_TRNING_INVIS_OFF");
	}

	menu_additem(hMenu, szMsg, "7");

	formatex(szMsg, charsmax(szMsg), "%L", LANG_PLAYER, "MENU_TRNING_WEAPONS");
	menu_additem(hMenu, szMsg, "8");


	menu_display(id, hMenu, 0);
	
	return PLUGIN_HANDLED;
}

public hns_training_menu_code(id, hMenu, item) {
	if (item == MENU_EXIT) {
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	new szData[6], szName[64], iAccess, iCallback;
	menu_item_getinfo(hMenu, item, iAccess, szData, charsmax(szData), szName, charsmax(szName), iCallback);
	menu_destroy(hMenu);

	new iKey = str_to_num(szData);
	switch (iKey) {
		case 1: {
			CmdCheckpoint(id);
		}
		case 2: {
			CmdGoCheck(id);
		}
		case 3: {
			CmdClipMode(id);
		}
		case 4: {
			CmdRespawn(id);
		}
		case 5: {
			CmdShowDamage(id);
		}
		case 6: {
			CmdSaveAngles(id);
		}
		case 7: {
			cmdInvis(id);
		}
		case 8: {
			cmdWeapons(id);
		}
	}
	hns_training_menu(id);

	return PLUGIN_HANDLED;
}

public rgPlayerSpawn(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return HC_CONTINUE;
	}

	set_task(0.2, "cmdUsp", id);

	return HC_CONTINUE;
}

public rgFlPlayerFallDamage(id) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return HC_CONTINUE
	}

	new dmg = floatround(Float:GetHookChainReturn(ATYPE_FLOAT));

	if(g_bDamage[id]) {
		client_print_color(id, print_team_blue, "%L", id, "TRNING_DMG", g_szPrefix, dmg);
	}

	return HC_CONTINUE;
}

public fmAddToFullPack(es, e, iEnt, id, hostflags, player, pSet) {
	if (hns_get_mode() != MODE_TRAINING && hns_get_state() != STATE_PAUSED) {
		return FMRES_IGNORED;
	}
	
	if (id == iEnt)
		return FMRES_IGNORED;

	if (player) {
		if (is_user_alive(iEnt)) {
			if (g_bInvisPlayers[id]) {
				set_es(es, ES_Solid, SOLID_NOT);
				set_es(es, ES_RenderMode, kRenderTransTexture);
				set_es(es, ES_RenderAmt, 0);
				set_es(es, ES_Origin, { 999999999.0, 999999999.0, 999999999.0 });
			}
		}
	}
	
	return FMRES_IGNORED;
}


public plugin_end() {
	DestroyForward(g_hResetBugForward);
}

stock give_user_item(id, const szWeapon[], numBullets, GiveType:giveType = GT_APPEND) {
	if (!is_user_alive(id)) return;

	new iWeapon = rg_give_item(id, szWeapon, giveType);

	if (!is_nullent(iWeapon) && iWeapon != -1) {
		rg_set_iteminfo(iWeapon, ItemInfo_iMaxClip, numBullets);
		rg_set_user_ammo(id, rg_get_weapon_info(szWeapon, WI_ID), numBullets);		
	}
}