#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <hns_matchsystem>

public stock const PluginName[] = "[Match] DM Death Respawn";
public stock const PluginVersion[] = "1.0.2";
public stock const PluginAuthor[] = "ufame";
public stock const PluginDescription[] = "Respawns deathmatch players at their death position";

/// Per-player unstuck check task id offset.
const TASK_UNSTUCK_CHECK = 260720;

/// Delay before the first unstuck check after the death spawn.
const Float: UNSTUCK_FIRST_DELAY = 0.1;

/// Delay between unstuck check retries.
const Float: UNSTUCK_RETRY_DELAY = 0.3;

/// Maximum number of unstuck attempts per spawn.
const UNSTUCK_MAX_ATTEMPTS = 4;

/// Initial and maximum unstuck search distance.
const Float: UNSTUCK_START_DISTANCE = 32.0;
const Float: UNSTUCK_MAX_DISTANCE = 1000.0;

/// Unstuck search directions.
new const Float: UNSTUCK_DIRECTIONS[][3] =
{
  {0.0, 0.0, 1.0},
  {0.0, 0.0, -1.0},
  {0.0, 1.0, 0.0},
  {0.0, -1.0, 0.0},
  {1.0, 0.0, 0.0},
  {-1.0, 0.0, 0.0},
  {-1.0, 1.0, 1.0},
  {1.0, 1.0, 1.0},
  {1.0, -1.0, 1.0},
  {1.0, 1.0, -1.0},
  {-1.0, -1.0, 1.0},
  {1.0, -1.0, -1.0},
  {-1.0, 1.0, -1.0},
  {-1.0, -1.0, -1.0}
};

new g_iEnabled;
new g_iUnstuckEnabled;

new Float: g_flDeathOrigin[MAX_PLAYERS + 1][3];
new Float: g_flDeathAngles[MAX_PLAYERS + 1][3];
new bool: g_bDeathSpawn[MAX_PLAYERS + 1];
new bool: g_bDeathDucked[MAX_PLAYERS + 1];
new bool: g_bFallDeath[MAX_PLAYERS + 1];
new g_iUnstuckAttempts[MAX_PLAYERS + 1];

public plugin_init()
{
  bind_pcvar_num(
    create_cvar(
      "hns_dm_deathspawn_enabled", "1",
      .description = "Respawn players in DM modes at their death location",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = 1.0
    ),
    g_iEnabled
  );

  bind_pcvar_num(
    create_cvar(
      "hns_dm_deathspawn_unstuck_enabled", "1",
      .description = "Extracting a player from within a texture after they respawn at the location of their death",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = 1.0
    ),
    g_iUnstuckEnabled
  );

  AutoExecConfig(true, "respawn_point", "match");

  RegisterHookChain(RG_CBasePlayer_Killed, "OnPlayerKilled", .post = true);
  RegisterHookChain(RG_CBasePlayer_Spawn, "OnPlayerSpawn", .post = true);
  RegisterHookChain(RG_CSGameRules_FlPlayerFallDamage, "OnPlayerFallDamage", .post = true);
  RegisterHookChain(RG_CSGameRules_RestartRound, "OnRoundRestart");
}

public OnPlayerKilled(const victim, const attacker)
{
  if (victim < 1 || victim > MaxClients)
    return;

  new bool: fellToDeath = g_bFallDeath[victim];

  g_bFallDeath[victim] = false;
  g_bDeathSpawn[victim] = false;
  g_bDeathDucked[victim] = false;

  if (!IsDeathSpawnActive() || !IsPlayer(victim))
    return;

  if (fellToDeath || attacker == victim || !IsPlayer(attacker))
    return;

  get_entvar(victim, var_origin, g_flDeathOrigin[victim], 3);
  get_entvar(victim, var_angles, g_flDeathAngles[victim], 3);
  g_bDeathDucked[victim] = bool: (get_entvar(victim, var_flags) & FL_DUCKING);
  g_bDeathSpawn[victim] = true;
}

public OnPlayerSpawn(const playerIndex)
{
  new bool: deathSpawn = g_bDeathSpawn[playerIndex];
  new bool: deathDucked = g_bDeathDucked[playerIndex];

  g_bDeathSpawn[playerIndex] = false;
  g_bDeathDucked[playerIndex] = false;
  g_bFallDeath[playerIndex] = false;

  if (!deathSpawn)
    return;

  if (!IsDeathSpawnActive() || !is_user_alive(playerIndex))
    return;

  if (deathDucked)
    set_entvar(playerIndex, var_flags, get_entvar(playerIndex, var_flags) | FL_DUCKING);

  set_entvar(playerIndex, var_origin, g_flDeathOrigin[playerIndex]);
  set_entvar(playerIndex, var_angles, g_flDeathAngles[playerIndex]);
  set_entvar(playerIndex, var_v_angle, g_flDeathAngles[playerIndex]);
  set_entvar(playerIndex, var_fixangle, 1);

  if (g_iUnstuckEnabled)
    ScheduleUnstuckCheck(playerIndex, UNSTUCK_FIRST_DELAY);
}

public OnPlayerFallDamage(const playerIndex)
{
  if (playerIndex < 1 || playerIndex > MaxClients || !is_user_connected(playerIndex))
    return;

  new Float: fallDamage = Float: GetHookChainReturn(ATYPE_FLOAT);

  new Float: health;
  get_entvar(playerIndex, var_health, health);

  g_bFallDeath[playerIndex] = bool: (fallDamage > 0.0 && fallDamage >= health);
}

public OnRoundRestart()
{
  arrayset(g_bDeathSpawn, false, sizeof(g_bDeathSpawn));
  arrayset(g_bDeathDucked, false, sizeof(g_bDeathDucked));
  arrayset(g_bFallDeath, false, sizeof(g_bFallDeath));
}

public client_disconnected(playerIndex)
{
  g_bDeathSpawn[playerIndex] = false;
  g_bDeathDucked[playerIndex] = false;
  g_bFallDeath[playerIndex] = false;
  g_iUnstuckAttempts[playerIndex] = 0;

  remove_task(TASK_UNSTUCK_CHECK + playerIndex);
}

stock bool: IsDeathSpawnActive()
{
  if (g_iEnabled == 0)
    return false;

  new HNS_MODES: mode = hns_get_mode();

  return mode == MODE_DM || mode == MODE_DM_1TT;
}

stock ScheduleUnstuckCheck(playerIndex, Float: delay)
{
  g_iUnstuckAttempts[playerIndex] = 0;

  remove_task(TASK_UNSTUCK_CHECK + playerIndex);
  set_task(delay, "TaskCheckUnstuck", TASK_UNSTUCK_CHECK + playerIndex);
}

public TaskCheckUnstuck(taskId)
{
  new playerIndex = taskId - TASK_UNSTUCK_CHECK;

  if (!IsPlayer(playerIndex))
    return;

  if (!is_user_alive(playerIndex) || !IsDeathSpawnActive())
    return;

  if (!IsPlayerStuck(playerIndex))
    return;

  g_iUnstuckAttempts[playerIndex]++;

  if (AttemptUnstuck(playerIndex))
    return;

  if (g_iUnstuckAttempts[playerIndex] >= UNSTUCK_MAX_ATTEMPTS)
    return;

  set_task(UNSTUCK_RETRY_DELAY, "TaskCheckUnstuck", taskId);
}

bool: AttemptUnstuck(playerIndex)
{
  new Float: origin[3];
  get_entvar(playerIndex, var_origin, origin);

  new Float: candidate[3];
  new hullSize = GetHullSize(playerIndex);

  for (new Float: distance = UNSTUCK_START_DISTANCE; distance <= UNSTUCK_MAX_DISTANCE; distance += UNSTUCK_START_DISTANCE)
  {
    for (new direction = 0; direction < sizeof UNSTUCK_DIRECTIONS; direction++)
    {
      candidate[0] = origin[0] + UNSTUCK_DIRECTIONS[direction][0] * distance;
      candidate[1] = origin[1] + UNSTUCK_DIRECTIONS[direction][1] * distance;
      candidate[2] = origin[2] + UNSTUCK_DIRECTIONS[direction][2] * distance;

      if (!IsHullVacant(playerIndex, candidate, hullSize))
        continue;

      engfunc(EngFunc_SetOrigin, playerIndex, candidate);
      set_entvar(playerIndex, var_velocity, NULL_VECTOR);

      return true;
    }
  }

  return false;
}

bool: IsPlayer(const playerIndex)
{
  return playerIndex >= 1 && playerIndex <= MaxClients && is_user_connected(playerIndex);
}

bool: IsPlayerStuck(playerIndex)
{
  new Float: origin[3];
  get_entvar(playerIndex, var_origin, origin);

  engfunc(EngFunc_TraceHull, origin, origin, DONT_IGNORE_MONSTERS, GetHullSize(playerIndex), playerIndex, 0);

  return bool: (get_tr2(0, TR_StartSolid) || get_tr2(0, TR_AllSolid));
}

bool: IsHullVacant(playerIndex, const Float: position[3], hullSize)
{
  engfunc(EngFunc_TraceHull, position, position, DONT_IGNORE_MONSTERS, hullSize, playerIndex, 0);

  return bool: (!get_tr2(0, TR_StartSolid) && !get_tr2(0, TR_AllSolid));
}

GetHullSize(playerIndex)
{
  return (get_entvar(playerIndex, var_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;
}
