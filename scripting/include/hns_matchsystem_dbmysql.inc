#if defined _hns_matchsystem_dbmysql_included
	#endinput
#endif
#define _hns_matchsystem_dbmysql_included

native hns_db_init();

enum _:PTS_DATA {
	e_iPts,
    e_iWins,
    e_iLoss,
    e_iTop
};

native hns_get_pts_data(id, _:PTS_DATA);

enum _:SKILL_INFO
{
	SKILL_PTS,
	SKILL_LVL[10]
};

new const g_eSkillData[][SKILL_INFO] = {
	// pts	 skill
	{ 0,	"L-" },
	{ 650,	"L" },
	{ 750,	"L+" },
	{ 850,	"M-" },
	{ 950,	"M" },
	{ 1050,	"M+" },
	{ 1150,	"H-" },
	{ 1250,	"H" },
	{ 1350,	"H+" },
	{ 1450,	"P-" },
	{ 1550,	"P" },
	{ 1650,	"P+" },
	{ 1750,	"G-" },
	{ 1850,	"G" },
	{ 1950,	"G+" },
};

stock get_skill_player(id) {
	new iPts = hns_get_pts_data(id, e_iPts);
	new szSkill[10];
	for (new i; i < sizeof(g_eSkillData); i++) {
		if (iPts >= g_eSkillData[i][SKILL_PTS]) {
			formatex(szSkill, charsmax(szSkill), "%s", g_eSkillData[i][SKILL_LVL]);
		}
	}
	return szSkill;
}

native hns_get_ownage(id);

native hns_set_ownage(id);