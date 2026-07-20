#if defined _hns_matchsystem_custom_knifes_included
	#endinput
#endif
#define _hns_matchsystem_custom_knifes_included

/**
* Returns whether HnsMatchCustomKnifes is loaded.
*
* This native is optional for HnsMatchSystem. Without the provider plugin the
* core native filter returns 0 and preserves the classic knife behaviour.
*
* @return        1 when the custom-knifes hub is loaded, otherwise 0
*/
native bool:hns_custom_knifes_is_loaded();

/**
* Asks HnsMatchCustomKnifes to validate the caller and open its selection menu.
*
* @param id      Player index
*
* @return        1 when the menu was opened, otherwise 0
*/
native hns_custom_knifes_open_menu(id);

/**
* Notifies HnsMatchCustomKnifes that team picking has finished.
*
* The hub uses this notification instead of the core automatically starting
* MATCH_TEAMKNIFE. A watcher can then use /kf and select a knife type.
*
* @return        1 when the notification was accepted
*/
native hns_custom_knifes_teams_ready();
