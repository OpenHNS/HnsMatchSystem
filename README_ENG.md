## HnsMatchSystem
Counter-Strike Hide'n'Seek Match System plugins

## Requirements

| Name | Version |
| :- | :- |
| [ReHLDS](https://github.com/rehlds/rehlds) | [![Download](https://img.shields.io/github/v/release/rehlds/rehlds?include_prereleases&style=flat-square)](https://github.com/rehlds/rehlds/releases) |
| [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS/releases) | [![Download](https://img.shields.io/github/v/release/s1lentq/ReGameDLL_CS?include_prereleases&style=flat-square)](https://github.com/rehlds/ReGameDLL_CS/releases) |
| [Metamod-R](https://github.com/rehlds/Metamod-R/releases) | [![Download](https://img.shields.io/github/v/release/rehlds/Metamod-R?include_prereleases&style=flat-square)](https://github.com/rehlds/Metamod-R/releases) |
| [ReSemiclip](https://github.com/rehlds/resemiclip/releases) | [![Download](https://img.shields.io/github/v/release/rehlds/resemiclip?include_prereleases&style=flat-square)](https://github.com/rehlds/resemiclip/releases) |
| [AMXModX (v1.9 or v1.10)](https://www.amxmodx.org/downloads-new.php) | [![Download](https://img.shields.io/badge/AMXModX-%3E%3D1.9.0-blue?style=flat-square)](https://www.amxmodx.org/downloads-new.php) |
| [ReAPI](https://github.com/rehlds/reapi) | [![Download](https://img.shields.io/github/v/release/rehlds/reapi?include_prereleases&style=flat-square)](https://github.com/rehlds/reapi) |

## Characteristics
- Public / DeathMatch / Knife / Captain mode
- MR / Wintime match system
- Watcher (admin) menu (N)
- System is admin dependent
- Surrender
- AFK, Player leave contol

## Installation
 
1. Compile the plugin.

2. Copy the compiled `.amxx` file to the directory: `amxmodx / plugins /`

3. Copy the contents of the `configs/` folder to the directory: `amxmodx/configs/`

4. Copy the contents of the `data/lang/` folder to the directory: `amxmodx/data/lang/`

5. Copy the contents of the `modules/` folder (If you have a server on Linux, then we take the `.so` file, if the Windows `.dll`) into the directory: `amxmodx/modules/`

6. Add `.amxx` in the file `amxmodx/configs/plugins.ini`

7. Restart the server or change the map.

## Customization

- Configuring pts
    1. open the file `configs/mixsystem/hnsmatch-sql.cfg`.
    2. Write the data for the database there
    3. Change the map.

- Customizing the configs for the map
    1. Go to the `configs/mixsystem/mapcfg/` folder.
    2. Create a file with the name of the map (rayish_brick-world.cfg)
    3. Write the necessary settings in the file:

            mp_roundtime "2.5"
            mp_freezetime "5" 
            hns_flash "1"
            hns_smoke "1"
    4. Save. Now we will have the settings automatically set on the rayish_brick-world map when the mix starts.
- Knife map
    1. open the file `configs/mixsystem/matchsystem.cfg`.
    2. Change the hns_knifemap quark to your knife map.
    3. All, now on the map you specified will be held captain and knaif mods, I recommend to put the knife map first in the list of maps `maps.ini`.
- Watcher

    For watcher `configs/cmdaccess.ini` must be configured, namely to make the following commands available for flag f:

        "amx_slay" "f" ; admincmd.amxx
        "amx_slap" "f" ; admincmd.amxx.
        "amx_map" "f" ; admincmd.amxx.
        "amx_slapmenu" "f" ; plmenu.amxx.
        "amx_teammenu" "f" ; plmenu.amxx.
        "amx_mapmenu" "f" ; mapsmenu.amxx

## Description
    
- Watcher
    The system is not automatic, in order for players to start mixes, there is a plugin 'HnsMatchWatcher.amxx'. 

    Watcher is the player who starts the mixes.     
    
- Starting a mix

    In order to start a match game, you need to change the map to a knife map, start the captain mod and select 2 captains.
    
    Then the captains play a knife round and select players to teams.
    
    After the knife round is played and the winners of the knife round must choose a map and Watcher or Admin must change the map.
    
    After changing the map, the system will wait for the players and start the mix.
    
- Match - Maxround mode

    The game has a total of even number of rounds (14) (hns_rounds * 2). Teams are given a timer which is 00:00.

    The timer is increased for the team playing for terrorists. Teams change each round.

    At the end of the rounds (14), the team with the higher timer wins.

- Match - Wintime mode

    Teams are given a certain amount of time (15).
    The team that plays for the terrorists has their time taken away.
    The team that runs out of time wins.

## Plugins
- HnsMatchSystem.sma - Main mod plugin
- HnsMatchStats.sma - Mix statistics plugin
- HnsMatchPlayerInfo.sma - Hud player info
- HnsMatchSql.sma - Plugin for interacting with the database
- HnsMatchPts.sma - Plugin for PTS (does not work without Sql plugin)
- HnsMatchOwnage.sma - Plugin for calculating Ownage (does not work without Sql plugin)
- HnsMatchChatmanager.sma - Modified HM, shows rank (skill) prefix.
- HnsMatchHideKnife.sma - Show/hide knife
- HnsMatchMaps.sma - List of maps for players (/maps)
- HnsMatchTraining.sma - Training menu (Checkpoints)
- HnsMatchWatcher.sma - Watcher system, allows players to become/vote for watcher

## Cvars

| Cvar | Default | Description |
| :------------------- | :--------: | :--------------------------------------------------- |
| hns_rules           | 0         | Match rules (0 - MR 1 - Timer) |
| hns_wintime           | 15         | Time to win |
| hns_rounds | 6 | rounds to win |
| hns_boost | 0 | Enable/Disable Boost Mode |
| hns_onehpmode | 0 | Enable/Disable 1hpmode |
| hns_flash | 1 | Number of flash drives (plugin changes itself) |
| hns_smoke | 1 | smoke packs (plugin modifies itself) |
| hns_last | 1 | Enable/disable grenades to the last TT |
| hns_dmrespawn | 3 | Time (in seconds) for the player to revive in DM mode |
| hns_survotetime | 10 | Time (in seconds) for surrender |
| hns_randompick | 1 | Enable/disable random player selection |
| hns_knifemap | 35hp_2 | Knifemap |
| hns_prefix | MATCH | System prefix |
| hns_gamename | Hide'n'Seek | GameName server |

## Commands

- Chat commands

- Watcher (ADMIN_MAP)

| Commands | Description |
| :------------------- | :--------------------------------------------------- |
| mix | admin menu |
| mode / type | mod menu |
| timer / wintime | Change the mix mode to Timer |
| mr / maxround | Change the mix mode to MR |
| training | training menu |
| pub / public | public | public mod |
| dm / deathmatch | DM mod |
| specall | move everyone behind the observers |
| ttall | move everyone to ttall |
| ctall | move all for CT |
| startmix / start | start the match |
| kniferound / kf | start a knife round |
| captain / cap | start captain mod |
| stop / cancel | stop the current mode |
| skill | skill | skill mod |
| boost | boost mod |
| rr / restart | restart round |
| swap / swap | swap | swap teams |
| pause / ps | pause |
| live / unpause | start |
| mr | Set the number of rounds |

- Player

| Commands | Description |
| :------------------- | :--------------------------------------------------- |
| hideknife / showknife / knife | hide, show knife |
| surrender / sur | vote to surrender |
| score / s | score |
| pick | pick menu |
| back / spec | jump or go back for observers |
| np / noplay | not playing |
| ip / play | play | play |
| checkpoint / cp | checkpoint | checkpoint |
| teleport / tp | teleport to a checkpoint |
| checkpoint | gocheck / gc | checkpoint |
| showdmg / showdamade | Damage |
| noclip / clip | noclip | noclip |
| respawn / resp | respawn | sleep |
| top / tops | top players per match |
| map / maps | show map list |
| rank / me | Show your pts stats |
| pts / ptstop | Show top players by pts |
| hud / hudinfo | disable/enable hud |
| rnw / rocknewwatcher | vote for new watcher |
| wt / watcher | transfer/assign a new watcher |
| speclist / showspec | Enable/Disable speclist |
| spechide / hidespec | Enable/Disable spechide |

## Acknowledgments / Authors of other plugins
[Garey](https://github.com/Garey27)

[Medusa](https://github.com/medusath)
