#if defined _hns_matchsystem_bans_included
	#endinput
#endif
#define _hns_matchsystem_bans_included

new bool:g_bHnsBannedInit = false; // Включен ли плагин hns bans
new bool:e_bBanned[MAX_PLAYERS + 1]; // Забанен ли игрок
new g_iBanExpired[MAX_PLAYERS + 1]; // Секунды до конца бана

/**
* Called when bans module is initialized.
*
* @noreturn
*/
forward hns_banned_init();

/**
* Called when player's match-ban status is updated.
*
* @param id		Player index
* @param bBanned	Player ban state
* @param iBanExpired	Unix time when ban expires
*
* @noreturn
*/
forward hns_player_banned(id, bool:bBanned, iBanExpired);

public hns_banned_init() {
	g_bHnsBannedInit = true;
}

public hns_player_banned(id, bool:bBanned, iBanExpired) {
	e_bBanned[id] = bBanned;
	g_iBanExpired[id] = iBanExpired;
}

stock secondsToDHM(time) {
	new szTime[32]
	if (time < 60) {
		formatex(szTime, charsmax(szTime), "%ds.", time)
	} else {
		new days = time / 86400
		new hours = (time - days * 86400) / 3600
		new minutes = ((time - days * 86400) - 3600 * hours) / 60
		new seconds = time % 60

		if (days) formatex(szTime, charsmax(szTime), "%dd.", days)
		if (hours) formatex(szTime, charsmax(szTime), "%s %dh.", szTime, hours)
		if (minutes) formatex(szTime, charsmax(szTime), "%s %dm.", szTime, minutes)
		if (seconds) formatex(szTime, charsmax(szTime), "%s %ds.", szTime, seconds)

		trim(szTime)
	}
	return szTime
}
