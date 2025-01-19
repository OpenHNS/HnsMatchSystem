#if defined _hns_matchsystem_bans_included
	#endinput
#endif
#define _hns_matchsystem_bans_included

new bool:g_bHnsBannedInit = false; // Включен ли плагин hns bans
new bool:e_bBanned[MAX_PLAYERS + 1];

forward hns_banned_init();

public hns_banned_init() {
	g_bHnsBannedInit = true;
}

forward hns_player_banned(id, bool:bBanned);

public hns_player_banned(id, bool:bBanned) {
	e_bBanned[id] = bBanned;
}