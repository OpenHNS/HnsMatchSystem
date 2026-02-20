#if defined _hns_matchsystem_cup_included
	#endinput
#endif
#define _hns_matchsystem_cup_included

/**
* Returns whether cup mode is enabled.
*
* @return		1 if enabled, otherwise 0
*/
native hns_cup_enabled();

/**
* Returns whether cup veto is currently active.
*
* @return		1 if active, otherwise 0
*/
native hns_cup_is_veto_active();

/**
* Stops active cup veto.
*
* @noreturn
*/
native hns_cup_stop_veto();

/**
* Sets veto turn owner team.
*
* @param team		Team index/identifier from cup plugin
*
* @noreturn
*/
native hns_cup_set_veto_turn_by_team(team);
