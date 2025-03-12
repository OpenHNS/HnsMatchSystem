#include <amxmodx>
#include <reapi>
#include <hns_matchsystem>
#include <hns_matchsystem_bans>
#include <hns_matchsystem_stats>

#define rg_get_user_team(%0) get_member(%0, m_iTeam)

new g_szPrefix[24];

enum _:Data
{
	iTeam,
	Float:Velocity[3],
	Float:Angles[3],
	Float:Origin[3],
	iSmoke,
	iFlash,
	iHe,
	Float:flHealth
};

enum TransferType
{
	TRANSFER_TO,
	TRANSFER_IT
};

enum ControlType
{
	TYPE_REPLACE,
	TYPE_CONTROL
}
/*
[33] == [request]
*/
new g_ReplaceRequests[MAX_PLAYERS + 1]

new Float:g_flDelay[MAX_PLAYERS + 1];

new ControlType:g_ControlType[MAX_PLAYERS + 1];
new bool:g_bInvited[MAX_PLAYERS + 1];
new bool:g_bGiveWeapons[MAX_PLAYERS + 1];

new TransferType:g_eTransferType[MAX_PLAYERS + 1], g_iTransferPlayer[MAX_PLAYERS + 1];

new g_saveData[MAX_PLAYERS + 1][Data];

public plugin_init()
{
	register_plugin("Match: ReControl", "1.3", "OpenHNS"); // Thanks Conor, Denzer, Garey

	register_clcmd("drop", "Control");
	RegisterSayCmd("co", "co", "Control");
	RegisterSayCmd("control", "con", "Control");

	RegisterSayCmd("re", "re", "Replace");
	RegisterSayCmd("replace", "rep", "Replace");

	register_clcmd("hns_transfer", "ReplaceAdmin");
	RegisterSayCmd("rea", "rea", "ReplaceAdmin");

	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "@CSGameRules_PlayerSpawn", true);

	register_dictionary("match_additons.txt");
}

public plugin_cfg() {
	hns_get_prefix(g_szPrefix, charsmax(g_szPrefix));
}

public client_putinserver(id)
{
	ResetTransfer(id);

	arrayset(g_saveData[id], 0, Data);
	g_bGiveWeapons[id] = false;
	g_flDelay[id] = 0.0;
	g_bInvited[id] = false;
}

public client_disconnected(id)
{
	if (task_exists(1337))
		remove_task(1337);
	
	g_bInvited[id] = false;
}

@CSGameRules_PlayerSpawn(id)
{
	if (is_user_alive(id)) {
		RequestFrame("GiveWeapons", id);
	}
}

public Control(id)
{
	g_ControlType[id] = TYPE_CONTROL;
	Menu(id);
	
	return;
}

public Replace(id)
{
	g_ControlType[id] = TYPE_REPLACE;
	Menu(id);
	
	return;
}

public Menu(id)
{
	new const bool:is_control = (g_ControlType[id] == TYPE_CONTROL);
	// Only alive player can be controled, replace works any time.
	new const bool:can_control = (!is_control) || (is_control && is_user_alive(id));
	if (can_control && rg_get_user_team(id) != TEAM_SPECTATOR)
	{
		new m_Menu = menu_create(fmt("%L", LANG_PLAYER, is_control ? "RECON_TITLE_CONTROL" : "RECON_TITLE_REPLACE"), "MenuHandler");

		new Players[32], Count, szPlayer[10], Player, szName[MAX_NAME_LENGTH], szBuffer[64];

		if (is_control)
		{
			switch (rg_get_user_team(id))
			{
				case 1: get_players(Players, Count, "bce", "TERRORIST");
				case 2: get_players(Players, Count, "bce", "CT");
			}
		}
		else
			get_players(Players, Count, "bce", "SPECTATOR");
		
		for (new i; i < Count; i++)
		{
			Player = Players[i];

			if (id == Player)
				continue;

			get_user_name(Player, szName, charsmax(szName));

			num_to_str(Player, szPlayer, charsmax(szPlayer));

			if (g_bHnsBannedInit && e_bBanned[Player] && !is_control) {
				formatex(szBuffer, charsmax(szBuffer), "%L", LANG_PLAYER, "RECON_BANNED", szName);
				menu_additem(m_Menu, szBuffer, szPlayer);
			} else if (g_bInvited[Player]) {
				formatex(szBuffer, charsmax(szBuffer), "%L", LANG_PLAYER, "RECON_INVITED", szName);
				menu_additem(m_Menu, szBuffer, szPlayer);
			} else {
				menu_additem(m_Menu, szName, szPlayer);
			}
		}

		menu_setprop(m_Menu, MPROP_EXIT, MEXIT_ALL);

		menu_display(id, m_Menu, 0);
	}

	return;
}

public MenuHandler(id, m_Menu, szKeys)
{
	if (!is_user_connected(id))
	{
		menu_destroy(m_Menu);
		return;
	}
	
	if (szKeys == MENU_EXIT)
	{
		menu_destroy(m_Menu);
		return;
	}

	new szData[6], szName[64], _Access, _Callback;
	
	menu_item_getinfo(m_Menu, szKeys, _Access, szData, charsmax(szData), szName, charsmax(szName), _Callback);
	
	new UserId = str_to_num(szData);
	
	new invited_id = UserId;

	g_ReplaceRequests[invited_id] = id;

	if (g_bHnsBannedInit) {
		if (e_bBanned[invited_id]) {
			Menu(id);
			return;
		}
	}
	
	if (!g_bInvited[invited_id])
	{
		new Float:szTime = get_gametime();
		
		if(szTime < g_flDelay[id])
			client_print_color(id, print_team_blue, "%L", LANG_PLAYER, "RECON_DELAY", g_szPrefix, g_flDelay[id] - szTime);
		else
		{
			g_bInvited[invited_id] = true;
			g_flDelay[id] = get_gametime() + 10.0;
			
			Confirmation(invited_id);
			
			new Parms[2];
			Parms[0] = id;
			Parms[1] = invited_id;
			
			set_task(10.0, "task_Response", 1337, Parms, 2);
		}
	}
	
	if (g_bInvited[invited_id])
	{
		Menu(id);
		return;
	}
	
	menu_destroy(m_Menu);
	
	return;	
}

public ReplaceAdmin(id)
{
	if (!is_user_connected(id))
	{
		return;
	}

	if (~get_user_flags(id) & hns_get_flag_admin())
	{
		return;
	}

	new title[128];

	if (g_eTransferType[id] == TRANSFER_TO)
	{
		formatex(title, charsmax(title), "%L", LANG_PLAYER, "RECON_ADM_TRANSF_TO");
	}
	else if (g_eTransferType[id] == TRANSFER_IT)
	{
		formatex(title, charsmax(title), "%L", LANG_PLAYER, "RECON_ADM_TRANSF_IT");
	}

	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");

	new menu = menu_create(title, "ReplaceAdmin_Handler");

	new players = 0;

	for (new i = 0; i < iNum; i++)
	{
		new iPlayer = iPlayers[i];

		new TeamName:team = rg_get_user_team(iPlayer);

		if (g_eTransferType[id] == TRANSFER_TO)
		{
			if (!(team == TEAM_TERRORIST || team == TEAM_CT))
			{
				continue;
			}
		}
		else if (g_eTransferType[id] == TRANSFER_IT)
		{
			if (g_iTransferPlayer[id] == iPlayer)
			{
				continue;
			}

			if (team != TEAM_SPECTATOR)
			{
				continue;
			}
		}

		new szPlayer[10]; num_to_str(iPlayer, szPlayer, charsmax(szPlayer));

		if ((g_bHnsBannedInit && e_bBanned[iPlayer] && (g_ControlType[iPlayer] == TYPE_REPLACE))) {
			menu_additem(menu, fmt("%L", LANG_PLAYER, "RECON_BANNED", iPlayer), szPlayer);
		} else {
			menu_additem(menu, fmt("%n", iPlayer), szPlayer);
		}

		players++;
	}

	if (!players)
	{
		ResetTransfer(id);
		menu_destroy(menu);
		return;
	}

	menu_display(id, menu);
}

public ReplaceAdmin_Handler(id, menu, item)
{
	if (~get_user_flags(id) & hns_get_flag_admin())
	{
		ResetTransfer(id);
		menu_destroy(menu);
		return;
	}

	if (item == MENU_EXIT)
	{
		ResetTransfer(id);
		menu_destroy(menu);
		return;
	}

	new szPlayer[10]; menu_item_getinfo(menu, item, _, szPlayer, charsmax(szPlayer));
	menu_destroy(menu);
	new iPlayer = str_to_num(szPlayer);

	if (!is_user_connected(iPlayer))
	{
		ResetTransfer(id);
		return;
	}

	if (g_bHnsBannedInit) {
		if (e_bBanned[iPlayer]) {
			ReplaceAdmin(id);
			return;
		}
	}

	new TeamName:team = get_member(iPlayer, m_iTeam);

	if (g_eTransferType[id] == TRANSFER_TO)
	{
		if (!(team == TEAM_TERRORIST || team == TEAM_CT))
		{
			ResetTransfer(id);
			return;
		}

		g_iTransferPlayer[id] = iPlayer;
		g_eTransferType[id] = TRANSFER_IT;
		ReplaceAdmin(id);
	}
	else if (g_eTransferType[id] == TRANSFER_IT)
	{
		if (!is_user_connected(g_iTransferPlayer[id]))
		{
			ResetTransfer(id);
			return;
		}

		if (g_iTransferPlayer[id] == iPlayer || team != TEAM_SPECTATOR)
		{
			ResetTransfer(id);
			return;
		}

		ReplacePlayers(g_iTransferPlayer[id], iPlayer, id);
		ResetTransfer(id);
	}
}

ResetTransfer(id)
{
	g_eTransferType[id] = TRANSFER_TO;
	g_iTransferPlayer[id] = 0;
}

public Confirmation(id)
{
	if (!is_user_alive(id))
	{
		new m_Confirmation;
		
		new requested_id = g_ReplaceRequests[id];
					
		if (g_ControlType[requested_id] == TYPE_CONTROL)
			m_Confirmation = menu_create(fmt("%L", LANG_PLAYER, "RECON_CONFIRM_CONTROL", requested_id), "ConfirmationHandler");
		else
			m_Confirmation = menu_create(fmt("%L", LANG_PLAYER, "RECON_CONFIRM_REPLACE", requested_id), "ConfirmationHandler");
		
		menu_additem(m_Confirmation, "Yes");
		menu_additem(m_Confirmation, "No");
		
		menu_setprop(m_Confirmation, MPROP_EXIT, MEXIT_NEVER);
		
		menu_display(id, m_Confirmation, 0);
	}
	
	return;
}

public ConfirmationHandler(id, m_Confirmation, szKeys)
{
	if (!is_user_connected(id))
	{
		menu_destroy(m_Confirmation);
		return;
	}

	new requested_id = g_ReplaceRequests[id];
	
	g_bInvited[id] = false;
	
	switch (szKeys)
	{
		case 0:
		{
			ReControl(id);
			
			show_menu(requested_id, 0, "", 1);
		}
		case 1:
		{
			if (g_ControlType[requested_id] == TYPE_CONTROL) {
				client_print_color(requested_id, id, "%L", LANG_PLAYER, "RECON_REFUSED_CONTROL", g_szPrefix, id);
			}
			else {
				client_print_color(requested_id, id, "%L", LANG_PLAYER, "RECON_REFUSED_REPLACE", g_szPrefix, id);
			}
			
			Menu(requested_id);
		}
	}
	
	menu_destroy(m_Confirmation);
	
	return;
}

public GiveWeapons(id)
{
	if (is_user_alive(id) && g_bGiveWeapons[id])
	{
		rg_remove_all_items(id);
		rg_give_item(id, "weapon_knife");

		set_entvar(id, var_flags, get_entvar(id, var_flags) | FL_DUCKING);
		set_entvar(id, var_health, g_saveData[id][flHealth]);
		set_entvar(id, var_origin, g_saveData[id][Origin]);
		set_entvar(id, var_velocity, g_saveData[id][Velocity]);
		set_entvar(id, var_angles, g_saveData[id][Angles]);
		set_entvar(id, var_fixangle, 1);

		switch (rg_get_user_team(id))
		{
			case 1:
			{
				rg_set_user_footsteps(id, true);
				
				if (g_saveData[id][iHe])
				{
					rg_give_item(id, "weapon_hegrenade");
					rg_set_user_bpammo(id, WEAPON_HEGRENADE, g_saveData[id][iHe]);
				}
				
				if (g_saveData[id][iFlash])
				{
					rg_give_item(id, "weapon_flashbang");
					rg_set_user_bpammo(id, WEAPON_FLASHBANG, g_saveData[id][iFlash]);
				}
				
				if (g_saveData[id][iSmoke])
				{
					rg_give_item(id, "weapon_smokegrenade");
					rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, g_saveData[id][iSmoke]);
				}
			}
		case 2: rg_set_user_footsteps(id, false);
		}
		
		g_bGiveWeapons[id] = false;
	}
}

public ReControl(id)
{
	new requested_id = g_ReplaceRequests[id];
		
	g_saveData[id][iTeam] = rg_get_user_team(requested_id);
	if (is_user_alive(requested_id))
	{
		get_entvar(requested_id, var_origin, 	g_saveData[id][Origin], 3);
		get_entvar(requested_id, var_velocity, 	g_saveData[id][Velocity], 3);
		get_entvar(requested_id, var_v_angle, 	g_saveData[id][Angles], 3);
		
		g_saveData[id][iHe] = rg_get_user_bpammo(requested_id, WEAPON_HEGRENADE);
		g_saveData[id][iFlash] = rg_get_user_bpammo(requested_id, WEAPON_FLASHBANG);
		g_saveData[id][iSmoke] = rg_get_user_bpammo(requested_id, WEAPON_SMOKEGRENADE);
		g_saveData[id][flHealth] = get_entvar(requested_id, var_health);
		
		if (g_ControlType[requested_id] == TYPE_REPLACE)
		{
			set_entvar(id, var_frags, Float:get_entvar(requested_id, var_frags));
			set_member(id, m_iDeaths, get_member(requested_id, m_iDeaths));

			rg_set_user_team(id, g_saveData[id][iTeam]);
			rg_set_user_team(requested_id, TEAM_SPECTATOR);

			hns_stats_replace(STATS_ALL, requested_id, id);
		}
		
		g_bGiveWeapons[id] = true;
		
		rg_round_respawn(id);
		
		user_kill(requested_id, true);
	}
	else
	{
		if (g_ControlType[requested_id] == TYPE_REPLACE)
		{
			set_entvar(id, var_frags, Float:get_entvar(requested_id, var_frags));
			set_member(id, m_iDeaths, get_member(requested_id, m_iDeaths));	

			rg_set_user_team(id, g_saveData[id][iTeam]);
			rg_set_user_team(requested_id, TEAM_SPECTATOR);

			hns_stats_replace(STATS_ALL, requested_id, id);
		}
	}
	
	if (g_ControlType[requested_id] == TYPE_REPLACE)
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "RECON_REPLACE", g_szPrefix, id, requested_id);
	
	show_menu(requested_id, 0, "", 1);
}

public task_Response(Parms[], task_id)
{
	new requested_id = Parms[0];
	new id = Parms[1];
	
	if (g_bInvited[id])
	{
		g_bInvited[id] = false;
		
		Menu(requested_id);
		client_print_color(requested_id, id, "%L", LANG_PLAYER, "RECON_DIDNT_CHOOSE", g_szPrefix, id);
		
		show_menu(id, 0, "", 1);
		client_print_color(id, print_team_blue, "%L", LANG_PLAYER, "RECON_EXPIRED", g_szPrefix);
	}
	
	return;
}

ReplacePlayers(replacement_player, substitutive_player, admin_replaced = 0) {
	g_saveData[substitutive_player][iTeam] = rg_get_user_team(replacement_player);

	set_entvar(substitutive_player, var_frags, Float:get_entvar(replacement_player, var_frags));
	set_member(substitutive_player, m_iDeaths, get_member(replacement_player, m_iDeaths));

	if(is_user_alive(replacement_player)) {
		get_entvar(replacement_player, var_origin, g_saveData[substitutive_player][Origin], 3);
		get_entvar(replacement_player, var_velocity, g_saveData[substitutive_player][Velocity], 3);
		get_entvar(replacement_player, var_v_angle, g_saveData[substitutive_player][Angles], 3);

		g_saveData[substitutive_player][iSmoke]   = rg_get_user_bpammo(replacement_player, WEAPON_SMOKEGRENADE);
		g_saveData[substitutive_player][iFlash]   = rg_get_user_bpammo(replacement_player, WEAPON_FLASHBANG);
		g_saveData[substitutive_player][iHe]   = rg_get_user_bpammo(replacement_player, WEAPON_HEGRENADE);
		g_saveData[substitutive_player][flHealth]  = get_entvar(replacement_player, var_health);

		rg_set_user_team(substitutive_player, g_saveData[substitutive_player][iTeam]);
		rg_set_user_team(replacement_player, TEAM_SPECTATOR);

		g_bGiveWeapons[substitutive_player] = true;

		rg_round_respawn(substitutive_player);        
		user_silentkill(replacement_player);
	}
	else {
		rg_set_user_team(substitutive_player, g_saveData[substitutive_player][iTeam]);
		rg_set_user_team(replacement_player, TEAM_SPECTATOR);
	}

	hns_stats_replace(STATS_ALL, replacement_player, substitutive_player);

	client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "RECON_ADM_REPLACE", g_szPrefix, admin_replaced, replacement_player, substitutive_player);
}