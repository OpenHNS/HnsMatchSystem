## [README in Russian](https://github.com/WessTorn/HnsMatchSystem/blob/main/README.md)

## HnsMatchSystem
Counter-Strike Hide'n'Seek Match System plugins.

## Requirements

| Name | Version |
| :- | :- |
| [ReHLDS](https://github.com/rehlds/rehlds) | [![Download](https://img.shields.io/github/v/release/rehlds/rehlds?include_prereleases&style=flat-square)](https://github.com/rehlds/rehlds/releases) |
| [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS/releases) | [![Download](https://img.shields.io/github/v/release/s1lentq/ReGameDLL_CS?include_prereleases&style=flat-square)](https://github.com/rehlds/ReGameDLL_CS/releases) |
| [Metamod-R](https://github.com/rehlds/Metamod-R/releases) | [![Download](https://img.shields.io/github/v/release/rehlds/Metamod-R?include_prereleases&style=flat-square)](https://github.com/rehlds/Metamod-R/releases) |
| [ReSemiclip](https://github.com/rehlds/resemiclip/releases) | [![Download](https://img.shields.io/github/v/release/rehlds/resemiclip?include_prereleases&style=flat-square)](https://github.com/rehlds/resemiclip/releases) |
| [AMXModX (v1.9 or v1.10)](https://www.amxmodx.org/downloads-new.php) | [![Download](https://img.shields.io/badge/AMXModX-%3E%3D1.9.0-blue?style=flat-square)](https://www.amxmodx.org/downloads-new.php) |
| [ReAPI](https://github.com/rehlds/reapi) | [![Download](https://img.shields.io/github/v/release/rehlds/reapi?include_prereleases&style=flat-square)](https://github.com/rehlds/reapi) |
| [MySQL (Optional)](https://dev.mysql.com/downloads/mysql/) | [![Download](https://img.shields.io/badge/MySQL-Latest-blue?style=flat-square)](https://dev.mysql.com/downloads/mysql/) |

## Features

- Public / DeathMatch / Zombie warmup modes.
- Knife / Captain team setup modes.
- MR / Wintime / 1x1 match modes.
- Watcher (admin) menu (`N`).
- Admin-driven match flow.
- Surrender vote.
- AFK and player-leave control.

## Installation / Setup

### [1. Install the system on server](https://github.com/OpenHNS/HnsMatchSystem/wiki/1.-%D0%A3%D1%81%D1%82%D0%B0%D0%BD%D0%BE%D0%B2%D0%BA%D0%B0-%D1%81%D0%B8%D1%81%D1%82%D0%B5%D0%BC%D1%8B-%D0%BD%D0%B0-%D1%81%D0%B5%D1%80%D0%B2%D0%B5%D1%80)

### [2. Configure map settings for mixes](https://github.com/OpenHNS/HnsMatchSystem/wiki/2.-%D0%9D%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B9%D0%BA%D0%B0-%D0%BA%D0%BE%D0%BD%D1%84%D0%B8%D0%B3%D1%83%D1%80%D0%B0%D1%86%D0%B8%D0%B8-%D0%BA%D0%B0%D1%80%D1%82-%D0%B4%D0%BB%D1%8F-%D0%BC%D0%B8%D0%BA%D1%81%D0%BE%D0%B2)

### [3. (Optional) Configure PTS / MySQL database](https://github.com/OpenHNS/HnsMatchSystem/wiki/3.--%D0%9D%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B9%D0%BA%D0%B0-PTS-%E2%80%90-Mysql-%D0%B1%D0%B4)

### [4. Configure Watcher / Full Watcher privileges](https://github.com/OpenHNS/HnsMatchSystem/wiki/4.-%D0%9D%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B9%D0%BA%D0%B0-%D0%BF%D1%80%D0%B8%D0%B2%D0%B8%D0%BB%D0%B5%D0%B3%D0%B8%D0%B9-Watcher-Full-watcher)

## Description

- Watcher

    The system is not fully automatic. To let players start mixes, the project uses `HnsMatchWatcher.amxx`.

    Watcher is the player who starts and controls the mix flow.

- Full Watcher

    Full Watcher has all Watcher privileges plus extra actions (for example, kicking players, mix bans, and watcher-right management).

- Starting a mix

    To start a match, change the map to a knife map, start captain mode, and select 2 captains.

    Captains play the knife round and pick players into teams.

    After that, knife-round winners choose the map, and Watcher/Admin changes to that map.

    After map change, the system waits for players and starts the mix.

- Match - Maxround mode

    The match has an even total round count (`hns_rounds * 2`). Both teams start with `00:00` timer.

    Timer increases for the Terrorist side. Teams swap every round.

    After all rounds are played, the team with the higher timer wins.

- Match - Wintime mode

    Teams get a fixed amount of time (`hns_wintime`).
    Time is reduced for the Terrorist side.
    Team whose timer reaches zero wins.

- Match - Duel mode

    This is a points-based duel mode with a match timer.
    The system shows a line between players that reflects their distance.

    There are 3 scoring distance zones:
    - Green: about 100 units, gives a lot of points.
    - Yellow: about 250 units, gives medium points.
    - White: about 400 units, gives low points.
    - Red: above ~400 units, gives 0 points.

    Goal: score more points than opponent.
    The closer you are to the opponent, the more points you get.

## Plugins

- HnsMatchSystem.sma - Core system plugin
- HnsMatchStats.sma - Match statistics (kills/deaths/dmg/survival, etc.)
- HnsMatchStatsMysql.sma - MySQL/PTS statistics (`/rank`, `/pts`)
- HnsMatchOwnage.sma - Ownage counter (used together with MySQL stats)
- HnsMatchPlayerInfo.sma - HUD/round info/speclist
- HnsMatchChatmanager.sma - Chat manager and message formatting
- HnsMatchMaps.sma - Map list and map settings (`/maps`)
- HnsMatchMapRules.sma - Rules for specific maps
- HnsMatchTraining.sma - Training mode (cp/tp/respawn/noclip)
- HnsMatchRecontrol.sma - Player replace/control transfer plugin
- HnsMatchWatcher.sma - Watcher system and watcher voting
- HnsMatchBans.amxx - Match bans plugin (binary module in release build)

## Commands / Cvars

### [5. Mix system commands and CVAR](https://github.com/OpenHNS/HnsMatchSystem/wiki/5.-%D0%9A%D0%BE%D0%BC%D0%B0%D0%BD%D0%B4%D1%8B-%D0%B8-CVAR-%D0%BC%D0%B8%D0%BA%D1%81-%D1%81%D0%B8%D1%81%D1%82%D0%B5%D0%BC%D1%8B)

## Credits / Authors of other plugins

[Garey](https://github.com/Garey27)

[Medusa](https://github.com/medusath)

[juice](https://github.com/etojuice)
