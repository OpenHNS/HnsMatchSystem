#if defined _hns_matchsystem_battles_included
	#endinput
#endif
#define _hns_matchsystem_battles_included

/**
* Returns battles module init state.
*
* @return		1 if battles module is available, otherwise 0
*/
native hns_battle_init();

/**
* Returns arenas init state for current map.
*
* @return		1 if arenas are loaded and available, otherwise 0
*/
native hns_battle_arenas_init();

/**
* Starts battle flow.
*
* @param iArena	Arena index from battles config/menu
* @param bChance	Whether chance-for-players mode is enabled
*
* @return		true if battle was started, otherwise false
*/
native bool:hns_battle_start(iArena = 0, bool:bChance = false);

/**
* Stops current battle flow.
*
* @param bSetTraining	Whether to return to training mode
*
* @return		true if battle is stopped, otherwise false
*/
native bool:hns_battle_end(bool:bSetTraining = true);

/**
* Opens battles race menu for player.
*
* @param id		Player index
*
* @return		true if menu call was accepted, otherwise false
*/
native bool:hns_battle_menu(id);
