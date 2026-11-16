#include <amxmodx>
#include <fakemeta>
#include <reapi>
#include <hns_matchsystem>

/// Unstuck check task id offset.
const TASK_UNSTUCK_CHECK = 260810;

/// Maximum tracked CT spawn points.
const MAX_CT_SPAWNS = 64;

/// Delay before the first unstuck check after the teleport.
const Float: UNSTUCK_FIRST_DELAY = 0.1;

/// Delay between unstuck check retries.
const Float: UNSTUCK_RETRY_DELAY = 0.3;

/// Maximum number of unstuck attempts per teleport.
const UNSTUCK_MAX_ATTEMPTS = 4;

/// Initial and maximum unstuck search distance.
const Float: UNSTUCK_START_DISTANCE = 32.0;
const Float: UNSTUCK_MAX_DISTANCE = 1000.0;

/// Spawn HUD position and hold time.
const Float: SPAWN_HUD_X = -1.0;
const Float: SPAWN_HUD_Y = 0.35;
const Float: SPAWN_HUD_HOLD = 1.5;
const SPAWN_HUD_CHANNEL = 4;

public stock const PluginName[] = "[Match] CT Spawn Picker";
public stock const PluginVersion[] = "1.0.0";
public stock const PluginAuthor[] = "ufame";
public stock const PluginDescription[] = "Lets CT players pick a spawn point by pressing E during the mix freeze time";

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

new g_iHudSync;

new Float: g_flSpawnOrigin[MAX_CT_SPAWNS][3];
new g_iSpawnCount;

new g_iSpawnIndex[MAX_PLAYERS + 1];
new g_iUnstuckAttempts[MAX_PLAYERS + 1];

public plugin_init()
{
  register_dictionary("match/spawn_picker.ini");

  bind_pcvar_num(
    create_cvar(
      "hns_ct_spawn_pick_enabled", "1",
      .description = "Allow selection of CT spawn point via the 'E' key during the freeze period in a mix match.",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = 1.0
    ),
    g_iEnabled
  );

  bind_pcvar_num(
    create_cvar(
      "hns_ct_spawn_unstuck_enabled", "1",
      .description = "Pull the player out of the texture after teleporting to the selected spawn",
      .has_min = true, .min_val = 0.0,
      .has_max = true, .max_val = 1.0
    ),
    g_iUnstuckEnabled
  );

  AutoExecConfig(true, "spawn_picker", "match");

 g_iHudSync = CreateHudSyncObj();

  RegisterHookChain(RG_CBasePlayer_UseEmpty, "OnUseEmpty");

  CollectCtSpawns();
}

public client_putinserver(playerIndex)
{
  g_iSpawnIndex[playerIndex] = -1;
  g_iUnstuckAttempts[playerIndex] = 0;
}

public client_disconnected(playerIndex)
{
  g_iSpawnIndex[playerIndex] = -1;
  g_iUnstuckAttempts[playerIndex] = 0;

  remove_task(TASK_UNSTUCK_CHECK + playerIndex);
}

public hns_round_start()
{
  arrayset(g_iSpawnIndex, -1, sizeof(g_iSpawnIndex));
}

public OnUseEmpty(const playerIndex)
{
  if (!g_iEnabled || !IsSpawnPickAllowed(playerIndex))
    return;

  if (!g_iSpawnCount)
    CollectCtSpawns();

  if (g_iSpawnCount < 1)
    return;

  g_iSpawnIndex[playerIndex] = (g_iSpawnIndex[playerIndex] + 1) % g_iSpawnCount;

  TeleportToSpawn(playerIndex, g_iSpawnIndex[playerIndex]);
  ShowSpawnHud(playerIndex, g_iSpawnIndex[playerIndex]);
}

bool: IsSpawnPickAllowed(playerIndex)
{
  if (hns_get_mode() != MODE_MIX)
    return false;

  if (!is_user_alive(playerIndex))
    return false;

  if (rg_get_user_team(playerIndex) != TEAM_CT)
    return false;

  return bool: get_member_game(m_bFreezePeriod);
}

CollectCtSpawns()
{
  g_iSpawnCount = 0;

  new spawnEntity = -1;

  while ((spawnEntity = engfunc(EngFunc_FindEntityByString, spawnEntity, "classname", "info_player_start")))
  {
    if (g_iSpawnCount >= MAX_CT_SPAWNS)
      break;

    get_entvar(spawnEntity, var_origin, g_flSpawnOrigin[g_iSpawnCount], 3);
    g_iSpawnCount++;
  }
}

TeleportToSpawn(playerIndex, spawnIndex)
{
  set_entvar(playerIndex, var_origin, g_flSpawnOrigin[spawnIndex]);
  set_entvar(playerIndex, var_velocity, Float:{ 0.0, 0.0, 0.0 });

  if (g_iUnstuckEnabled)
    ScheduleUnstuckCheck(playerIndex);
}

ShowSpawnHud(playerIndex, spawnIndex)
{
  set_hudmessage(0, 190, 255, SPAWN_HUD_X, SPAWN_HUD_Y,
    .holdtime = SPAWN_HUD_HOLD, .fadeintime = 0.1, .fadeouttime = 0.2, .channel = SPAWN_HUD_CHANNEL);
  ShowSyncHudMsg(playerIndex, g_iHudSync, "%L", playerIndex, "HUD_CTSPAWN", spawnIndex + 1, g_iSpawnCount);
}

stock ScheduleUnstuckCheck(playerIndex)
{
  g_iUnstuckAttempts[playerIndex] = 0;

  remove_task(TASK_UNSTUCK_CHECK + playerIndex);
  set_task(UNSTUCK_FIRST_DELAY, "TaskCheckUnstuck", TASK_UNSTUCK_CHECK + playerIndex);
}

public TaskCheckUnstuck(taskId)
{
  new playerIndex = taskId - TASK_UNSTUCK_CHECK;

  if (playerIndex < 1 || playerIndex > MaxClients || !is_user_connected(playerIndex))
    return;

  if (!is_user_alive(playerIndex) || hns_get_mode() != MODE_MIX)
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

  for (new Float: distance = UNSTUCK_START_DISTANCE; distance <= UNSTUCK_MAX_DISTANCE;
    distance += UNSTUCK_START_DISTANCE)
  {
    for (new direction = 0; direction < sizeof UNSTUCK_DIRECTIONS; direction++)
    {
      candidate[0] = origin[0] + UNSTUCK_DIRECTIONS[direction][0] * distance;
      candidate[1] = origin[1] + UNSTUCK_DIRECTIONS[direction][1] * distance;
      candidate[2] = origin[2] + UNSTUCK_DIRECTIONS[direction][2] * distance;

      if (!IsHullVacant(playerIndex, candidate, hullSize))
        continue;

      engfunc(EngFunc_SetOrigin, playerIndex, candidate);
      set_entvar(playerIndex, var_velocity, Float:{ 0.0, 0.0, 0.0 });

      return true;
    }
  }

  return false;
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

  return bool: (!get_tr2(0, TR_StartSolid) || !get_tr2(0, TR_AllSolid));
}

GetHullSize(playerIndex)
{
  return (get_entvar(playerIndex, var_flags) & FL_DUCKING) ? HULL_HEAD : HULL_HUMAN;
}
