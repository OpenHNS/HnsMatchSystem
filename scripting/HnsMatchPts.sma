#include <amxmodx>
#include <reapi>
#include <sqlx>
#include <hns_matchsystem>
#include <hns_matchsystem_dbmysql>

#define PTS_WIN 15
#define PTS_LOSS 10

new const g_szLinkPts[] = "https://SITENAME/pts/pts.php";

new g_sPrefix[24];
new Float:g_flMatchDelay;


public plugin_init() {
	register_plugin("Match: Pts", "1.2", "OpenHNS"); // Garey

	RegisterSayCmd("rank", "me", "CmdRank", 0, "Show rank");
	RegisterSayCmd("pts", "ptstop", "CmdPts", 0, "Show top pts players");
}

public CmdRank(id) {
	client_print_color(id, print_team_blue, "%L", id, "PTS_RANK", g_sPrefix, hns_get_pts_data(id, e_iTop), hns_get_pts_data(id, e_iPts), hns_get_pts_data(id, e_iWins), hns_get_pts_data(id, e_iLoss), get_skill_player(id));
}

public CmdPts(id) {
	new szMotd[MAX_MOTD_LENGTH];

	formatex(szMotd, sizeof(szMotd) - 1,\
	"<html><head><meta http-equiv=^"Refresh^" content=^"0;url=%s^"></head><body><p><center>LOADING...</center></p></body></html>",\
	g_szLinkPts);

	show_motd(id, szMotd);
}

public plugin_cfg() {
	hns_get_prefix(g_sPrefix, charsmax(g_sPrefix));
}

public hns_match_started() {
	g_flMatchDelay = get_gametime() + 600;
}

public hns_match_canceled() {
	g_flMatchDelay = 0.0;
}

public hns_match_finished(iWinTeam) {
	if (g_flMatchDelay > get_gametime()) {
		client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "PTS_NOT_TIME", g_sPrefix);
	} else {
		if (get_num_players_in_match() < 5) {
			client_print_color(0, print_team_blue, "%L", LANG_PLAYER, "PTS_NOT_PLR", g_sPrefix);
		} else {
			new iPlayers[MAX_PLAYERS], iNum;
			if (iWinTeam == 1) {
				get_players(iPlayers, iNum, "che", "TERRORIST");

				for(new i; i < iNum; i++) {
					new id = iPlayers[i];
					hns_set_pts_win(id, PTS_WIN);
				}
			} else {
				get_players(iPlayers, iNum, "che", "CT");

				for(new i; i < iNum; i++) {
					new id = iPlayers[i];
					hns_set_pts_lose(id, PTS_LOSS);
				}
			}
		}
	}
	g_flMatchDelay = 0.0;
}

stock get_num_players_in_match() {
	new iPlayers[MAX_PLAYERS], iNum;
	get_players(iPlayers, iNum, "ch");
	new numGameplr;
	for (new i; i < iNum; i++) {
		new tempid = iPlayers[i];
		if (rg_get_user_team(tempid) == TEAM_SPECTATOR) continue;
		numGameplr++;
	}
	return numGameplr;
}