new HamHook:fwdDisableKnife;
new HamHook:fwdResetMaxSpeed;

enum
{
	LAST_FLASH_NO = 0,
	LAST_FLASH_MENU,
	LAST_FLASH_PICK
}
new g_bLastFlash;

public hns_init()
{
	g_GPFuncs[GAMEPLAY_HNS][GP_ENABLE]		= CreateOneForward(g_PluginId, "hns_enable_rules");
	g_GPFuncs[GAMEPLAY_HNS][GP_DISABLE]		= CreateOneForward(g_PluginId, "hns_disable_rules");
	g_GPFuncs[GAMEPLAY_HNS][GP_SETROLE]		= CreateOneForward(g_PluginId, "hns_setrole", FP_CELL);
	g_GPFuncs[GAMEPLAY_HNS][GP_KILLED]		= CreateOneForward(g_PluginId, "hns_killed", FP_CELL, FP_CELL);
	g_GPFuncs[GAMEPLAY_HNS][GP_ROUNDSTART]	= CreateOneForward(g_PluginId, "hns_roundstart");
	g_GPFuncs[GAMEPLAY_HNS][GP_ROUNDEND]	= CreateOneForward(g_PluginId, "hns_roundend", FP_CELL);
}

public hns_enable_rules()
{
	g_iCurrentGameplay = GAMEPLAY_HNS;

	if (g_iSettings[HNSBOOST]) {
		set_semiclip(SEMICLIP_OFF);
	} else {
		set_semiclip(SEMICLIP_ON, true);
	}

	if (!fwdDisableKnife)
	{
		fwdDisableKnife = RegisterHam(Ham_Item_Deploy, "weapon_knife", "fwd_Knife_Deploy_Post", true);
	}
	if (!fwdResetMaxSpeed)
	{
		fwdResetMaxSpeed = RegisterHam(Ham_CS_Player_ResetMaxSpeed, "player", "fwd_Player_ResetMaxSpeed_Post", true);
	}

	EnableHamForward(fwdDisableKnife);
	EnableHamForward(fwdResetMaxSpeed);
}

public hns_disable_rules()
{
	if (fwdDisableKnife)
	{
		DisableHamForward(fwdDisableKnife);
	}
	if (fwdResetMaxSpeed)
	{
		DisableHamForward(fwdResetMaxSpeed);
	}
}

public hns_setrole(id)
{
	if (!is_user_connected(id))
		return;

	rg_remove_all_items(id);
	switch (getUserTeam(id))
	{
		case TEAM_TERRORIST:
		{
			rg_give_item(id, "weapon_knife");
			rg_set_user_footsteps(id, true);
			if (g_iSettings[FLASH] >= 1)
			{
				new ent = rg_give_item(id, "weapon_flashbang", GT_APPEND);
				rg_set_iteminfo(ent, ItemInfo_iMaxAmmo1, 10);
				rg_set_user_bpammo(id, WEAPON_FLASHBANG, g_iSettings[FLASH]);
			}

			if (g_iSettings[SMOKE] >= 1)
			{
				new ent = rg_give_item(id, "weapon_smokegrenade");
				rg_set_iteminfo(ent, ItemInfo_iMaxAmmo1, 10);
				rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, g_iSettings[SMOKE]);
			}
		}
		case TEAM_CT:
		{
			rg_give_item(id, "weapon_knife");
			rg_set_user_footsteps(id, false);
		}
	}

	if (g_iSettings[ONEHPMODE] == 1)
	{
		set_entvar(id, var_health, 1.0);
	}
}

public hns_killed(victim, attacker)
{
	if (getUserTeam(victim) != TEAM_TERRORIST || g_bLastFlash != LAST_FLASH_NO)
	{
		return;
	}
	
	if (g_iCurrentMode == MODE_DM || !g_iSettings[LASTGRENADE])
	{
		return;
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "aech", "TERRORIST");
	if (iNum == 1)
	{
		g_bLastFlash = LAST_FLASH_MENU;
		NewNadesMenu(iPlayers[0]);
	}
}

public NewNadesMenu(id)
{
	new szMsg[64];

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_NADES_TITLE");
	new hMenu = menu_create(szMsg, "NadesHandler");

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_YES");
	menu_additem(hMenu, szMsg);

	formatex(szMsg, charsmax(szMsg), "%L", id, "MENU_NO");
	menu_additem(hMenu, szMsg);

	menu_setprop(hMenu, MPROP_PERPAGE, 0);
	menu_display(id, hMenu, 0);
	return PLUGIN_HANDLED;
}


public NadesHandler(id, hMenu, item)
{
	if (g_bLastFlash != LAST_FLASH_MENU)
	{
		menu_destroy(hMenu);
		return PLUGIN_HANDLED;
	}

	if (!item)
	{
		if (g_iSettings[FLASH] >= 1) 
		{
			if (user_has_weapon(id, CSW_FLASHBANG))
			{
				//ExecuteHam(Ham_GiveAmmo, id, 1, "Flashbang", 1024);
				rg_set_user_bpammo(id, WEAPON_FLASHBANG, rg_get_user_bpammo(id, WEAPON_FLASHBANG) + 1);
			}
			else
			{
				rg_give_item(id, "weapon_flashbang");
			}
		}

		if (g_iSettings[SMOKE] >= 1)
		{
			if (user_has_weapon(id, CSW_SMOKEGRENADE))
			{
				//ExecuteHam(Ham_GiveAmmo, id, 1, "SmokeGrenade", 1024);
				rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, rg_get_user_bpammo(id, WEAPON_SMOKEGRENADE) + 1);
			}
			else
			{
				rg_give_item(id, "weapon_smokegrenade");
			}
		}

		g_bLastFlash = LAST_FLASH_PICK;
	}

	menu_destroy(hMenu);
	return PLUGIN_HANDLED;
}

public hns_roundstart()
{
	g_bLastFlash = LAST_FLASH_NO;
}

public hns_roundend(bool:win_ct)
{
	if (g_iCurrentMode != MODE_MIX && g_iCurrentMode != MODE_ZM) {
		if (win_ct)
		{
			rg_swap_all_players();
		}
	}
}

public fwd_Player_ResetMaxSpeed_Post(id)
{
	if (getUserTeam(id) == TEAM_TERRORIST)
	{
		new weapon = get_member(id, m_pActiveItem);
		if (weapon != -1)
		{
			set_entvar(id, var_maxspeed, get_member(weapon, m_Weapon_fMaxSpeed));
		}
	}
}

public fwd_Knife_Deploy_Post(ent)
{
	new id = get_member(ent, m_pPlayer);

	if (getUserTeam(id) == TEAM_CT)
	{
		return HAM_IGNORED;
	}

	if (g_iCurrentMode == MODE_KNIFE)
	{
		return HAM_IGNORED;
	}

	set_entvar(id, var_weaponmodel, 0);

	return HAM_IGNORED;
}

