#if defined _hns_matchsystem_dbmysql_included
	#endinput
#endif
#define _hns_matchsystem_dbmysql_included

/**
* Returns MySQL stats module init state.
*
* @return		1 if module is available, otherwise 0
*/
native hns_mysql_stats_init();

enum _:PTS_DATA {
	e_iPts,
    e_iWins,
    e_iLoss,
	e_iTop
};

/**
* Returns MySQL stats value by type.
*
* @param id		Client index
* @param PTS_DATA	Requested field type
*
* @return		Integer value for requested field
*/
native hns_mysql_stats_data(id, _:PTS_DATA);

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

stock hns_mysql_stats_skill(id) {
	new iPts = hns_mysql_stats_data(id, e_iPts);
	new szSkill[10];
	for (new i; i < sizeof(g_eSkillData); i++) {
		if (iPts >= g_eSkillData[i][SKILL_PTS]) {
			formatex(szSkill, charsmax(szSkill), "%s", g_eSkillData[i][SKILL_LVL]);
		}
	}
	return szSkill;
}

/**
* Returns player's ownage value from MySQL stats module.
*
* @param id		Client index
*
* @return		Ownage value
*/
native hns_mysql_stats_get_ownage(id);

/**
* Requests ownage update for player in MySQL stats module.
*
* @param id		Client index
*
* @noreturn
*/
native hns_mysql_stats_set_ownage(id);
