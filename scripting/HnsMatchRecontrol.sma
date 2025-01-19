#include <amxmodx>
#include <reapi>
#include <hns_matchsystem>
#include <hns_matchsystem_bans>

#define rg_get_user_team(%0) get_member(%0, m_iTeam)

new const g_Prefix[] = ">";

const g_Access = ADMIN_BAN;

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

new g_FirstId[MAX_PLAYERS + 1], g_SecondId[MAX_PLAYERS + 1][MAX_PLAYERS + 1], g_arrData[MAX_PLAYERS + 1][Data];

new Float:g_flDelay[MAX_PLAYERS + 1];

new bool:g_bControl[MAX_PLAYERS + 1];
new bool:g_bInvited[MAX_PLAYERS + 1];
new bool:g_bGiveWeapons[MAX_PLAYERS + 1];

new TransferType:g_eTransferType[MAX_PLAYERS + 1], g_iTransferPlayer[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin("Match: ReControl", "1.2", "OpenHNS"); // Thanks Conor, Denzer

	register_clcmd("drop", "Control");
	RegisterSayCmd("co", "co", "Control");
	RegisterSayCmd("control", "con", "Control");

	RegisterSayCmd("re", "re", "Replace");
	RegisterSayCmd("replace", "rep", "Replace");

	register_clcmd("hns_transfer", "ReplaceAdmin");
	RegisterSayCmd("rea", "rea", "ReplaceAdmin");

	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "@CSGameRules_PlayerSpawn", true);
}

public client_putinserver(id)
{
	ResetTransfer(id);

	arrayset(g_arrData[id], 0, Data);
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
		set_task(0.1, "GiveWeapons", id);
	}
}

public Control(id)
{
	g_bControl[id] = true;
	Menu(id);
	
	return;
}

public Replace(id)
{
	g_bControl[id] = false;
	Menu(id);
	
	return;
}

public Menu(id)
{
	if ((is_user_alive(id) && g_bControl[id] || is_user_alive(id) && !g_bControl[id] || !is_user_alive(id) && !g_bControl[id]) && (rg_get_user_team(id) == 1 || rg_get_user_team(id) == 2))
	{
		new m_Menu = menu_create(fmt("%s", g_bControl[id] ? "\rChoose a player to give control" : "\rSelect a player to replace"), "MenuHandler");

		new Players[32], Count, szPlayer[10], Player, szName[MAX_NAME_LENGTH], szBuffer[64];

		if (g_bControl[id])
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

			if ((g_bHnsBannedInit && e_bBanned[Player] && !g_bControl[Player])) {
				formatex(szBuffer, charsmax(szBuffer), "\d%s \r[Banned]", szName);
				menu_additem(m_Menu, szBuffer, szPlayer);
			} else if (g_bInvited[Player]) {
				formatex(szBuffer, charsmax(szBuffer), "%s \d[\rInvited\d]", szName);
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
	
	new SecondId = g_SecondId[id][UserId] = UserId;
	new FirstId = g_FirstId[UserId] = id;

	if (g_bHnsBannedInit) {
		if (e_bBanned[SecondId]) {
			Menu(id);
			return;
		}
	}
	
	if (!g_bInvited[SecondId])
	{
		new Float:szTime = get_gametime();
		
		if(szTime < g_flDelay[FirstId])
			client_print_color(FirstId, print_team_blue, "%s Please wait ^3%.1f^1 sec..", g_Prefix, g_flDelay[FirstId] - szTime);
		else
		{
			g_bInvited[SecondId] = true;
			g_flDelay[FirstId] = get_gametime() + 10.0;
			
			Confirmation(SecondId);
			
			new Parms[2];
			Parms[0] = FirstId;
			Parms[1] = SecondId;
			
			set_task(10.0, "task_Response", 1337, Parms, 2);
		}
	}
	
	if (g_bInvited[SecondId])
	{
		Menu(FirstId);
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

	if (~get_user_flags(id) & g_Access)
	{
		return;
	}

	new title[128];

	if (g_eTransferType[id] == TRANSFER_TO)
	{
		formatex(title, charsmax(title), "\rSelect the player to replace");
	}
	else if (g_eTransferType[id] == TRANSFER_IT)
	{
		formatex(title, charsmax(title), "\rWho should we replace it with?");
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

		if ((g_bHnsBannedInit && e_bBanned[iPlayer] && !g_bControl[iPlayer])) {
			menu_additem(menu, fmt("\d%n \r[Banned]", iPlayer), szPlayer);
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
	if (~get_user_flags(id) & g_Access)
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
			Menu(id);
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
		new FirstId = g_FirstId[id];
		
		if (g_bControl[FirstId])
			m_Confirmation = menu_create(fmt("\rTake control of %n?", FirstId), "ConfirmationHandler");
		else
			m_Confirmation = menu_create(fmt("\r%n wants you to replace him", FirstId), "ConfirmationHandler");
		
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
	
	new FirstId = g_FirstId[id];
	new SecondId = g_SecondId[FirstId][id];
	
	g_bInvited[id] = false;
	
	switch (szKeys)
	{
		case 0:
		{
			ReControl(SecondId);
			
			show_menu(FirstId, 0, "", 1);
		}
		case 1:
		{
			client_print_color(FirstId, SecondId, "%s ^3%n^1 refused to %s", g_Prefix, SecondId, g_bControl[FirstId] ? "take control" : "replace");
			
			Menu(FirstId);
		}
	}
	
	menu_destroy(m_Confirmation);
	
	return;
}

public GiveWeapons(id)
{
	if (is_user_alive(id) && g_bGiveWeapons[id])
	{
		new FirstId = g_FirstId[id];

		rg_remove_all_items(id);
		rg_give_item(id, "weapon_knife");

		set_entvar(id, var_flags, get_entvar(id, var_flags) | FL_DUCKING);
		set_entvar(id, var_health, g_arrData[id][flHealth]);
		set_entvar(id, var_origin, g_arrData[id][Origin]);
		set_entvar(id, var_velocity, g_arrData[id][Velocity]);
		set_entvar(id, var_angles, g_arrData[id][Angles]);
		set_entvar(id, var_fixangle, 1);
		
		switch (rg_get_user_team(id))
		{
			case 1:
			{
				rg_set_user_footsteps(id, true);
				
				if (g_arrData[FirstId][iHe])
				{
					rg_give_item(id, "weapon_hegrenade");
					rg_set_user_bpammo(id, WEAPON_HEGRENADE, g_arrData[FirstId][iHe]);
				}
				
				if (g_arrData[FirstId][iFlash])
				{
					rg_give_item(id, "weapon_flashbang");
					rg_set_user_bpammo(id, WEAPON_FLASHBANG, g_arrData[FirstId][iFlash]);
				}
				
				if (g_arrData[FirstId][iSmoke])
				{
					rg_give_item(id, "weapon_smokegrenade");
					rg_set_user_bpammo(id, WEAPON_SMOKEGRENADE, g_arrData[FirstId][iSmoke]);
				}
			}
		case 2: rg_set_user_footsteps(id, false);
		}
		
		g_bGiveWeapons[id] = false;
	}
}

public ReControl(id)
{
	new FirstId = g_FirstId[id];
	new SecondId = g_SecondId[FirstId][id];
	
	g_arrData[FirstId][iTeam] = rg_get_user_team(FirstId);
	
	if (is_user_alive(FirstId))
	{
		get_entvar(FirstId, var_origin, g_arrData[FirstId][Origin], 3);
		get_entvar(FirstId, var_velocity, g_arrData[FirstId][Velocity], 3);
		get_entvar(FirstId, var_v_angle, g_arrData[FirstId][Angles], 3);
		
		g_arrData[FirstId][iHe] = rg_get_user_bpammo(FirstId, WEAPON_HEGRENADE);
		g_arrData[FirstId][iFlash] = rg_get_user_bpammo(FirstId, WEAPON_FLASHBANG);
		g_arrData[FirstId][iSmoke] = rg_get_user_bpammo(FirstId, WEAPON_SMOKEGRENADE);
		g_arrData[FirstId][flHealth] = get_entvar(FirstId, var_health);
		
		if (!g_bControl[FirstId])
		{
			rg_set_user_team(SecondId, g_arrData[FirstId][iTeam]);
			rg_set_user_team(FirstId, TEAM_SPECTATOR);
		}
		
		g_bGiveWeapons[SecondId] = true;
		
		rg_round_respawn(SecondId);
		
		user_kill(FirstId, true);
	}
	else
	{
		if (!g_bControl[FirstId])
		{
			rg_set_user_team(SecondId, g_arrData[FirstId][iTeam]);
			rg_set_user_team(FirstId, TEAM_SPECTATOR);
		}
	}
	
	if (!g_bControl[FirstId])
		client_print_color(0, print_team_blue, "%s ^3%n^1 was replaced by ^3%n", g_Prefix, SecondId, FirstId);
	
	show_menu(FirstId, 0, "", 1);
}

public task_Response(Parms[], task_id)
{
	new FirstId = Parms[0];
	new SecondId = Parms[1];
	
	if (g_bInvited[SecondId])
	{
		g_bInvited[SecondId] = false;
		
		Menu(FirstId);
		client_print_color(FirstId, SecondId, "%s Player ^3%n^1 didn't chose anything", g_Prefix, SecondId);
		
		show_menu(SecondId, 0, "", 1);
		client_print_color(SecondId, print_team_blue, "%s Time expired", g_Prefix);
	}
	
	return;
}

ReplacePlayers(replacement_player, substitutive_player, admin_replaced = 0) {
	g_arrData[substitutive_player][iTeam] = rg_get_user_team(replacement_player);

	if(is_user_alive(replacement_player)) {
		get_entvar(replacement_player, var_origin, g_arrData[substitutive_player][Origin], 3);
		get_entvar(replacement_player, var_velocity, g_arrData[substitutive_player][Velocity], 3);
		get_entvar(replacement_player, var_v_angle, g_arrData[substitutive_player][Angles], 3);

		g_arrData[substitutive_player][iSmoke]   = rg_get_user_bpammo(replacement_player, WEAPON_SMOKEGRENADE);
		g_arrData[substitutive_player][iFlash]   = rg_get_user_bpammo(replacement_player, WEAPON_FLASHBANG);
		g_arrData[substitutive_player][iHe]   = rg_get_user_bpammo(replacement_player, WEAPON_HEGRENADE);
		g_arrData[substitutive_player][flHealth]  = get_entvar(replacement_player, var_health);
		rg_set_user_team(substitutive_player, g_arrData[substitutive_player][iTeam]);
		rg_set_user_team(replacement_player, TEAM_SPECTATOR);
		g_bGiveWeapons[substitutive_player] = true;
		rg_round_respawn(substitutive_player);        
		user_silentkill(replacement_player);
	}
	else {
		rg_set_user_team(substitutive_player, g_arrData[substitutive_player][iTeam]);
		rg_set_user_team(replacement_player, TEAM_SPECTATOR);
	}

	client_print_color(0, print_team_blue, "%s Admin ^3%n^1 replaced the player ^3%n^1 with a ^3%n^1", g_Prefix, admin_replaced, replacement_player, substitutive_player);
}