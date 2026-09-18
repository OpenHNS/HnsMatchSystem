#if defined _hns_matchsystem_maps_included
	#endinput
#endif
#define _hns_matchsystem_maps_included

/**
* Returns map module init state.
*
* @return		1 if map module is available, otherwise 0
*/
native hnsmatch_maps_init();

/**
* Returns whether current map is knife map.
*
* @return		true if knife map, otherwise false
*/
native bool:hnsmatch_maps_is_knife();

/**
* Loads map-based settings (roundtime/freezetime/flash/smoke).
*
* @return		true if settings were loaded, otherwise false
*/
native bool:hnsmatch_maps_load_settings();

/**
* Returns the number of currently nominated maps.
*
* @return		Number of nominated maps
*/
native hnsmatch_maps_get_nominated_count();

/**
* Copies a nominated map name by index.
*
* @param iIndex	Zero-based index in the nominated maps list
* @param szMap		Buffer to copy the map name to
* @param iLen		Maximum buffer size
*
* @return		1 on success, 0 if index is invalid
*/
native bool:hnsmatch_maps_get_nominated(iIndex, szMap[], iLen);
