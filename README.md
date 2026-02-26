## [README in English](https://github.com/WessTorn/HnsMatchSystem/blob/main/README_ENG.md)

## HnsMatchSystem
Counter-Strike Hide'n'Seek Match System plugins.

## Требование

| Название | Версия |
| :- | :- |
| [ReHLDS](https://github.com/rehlds/rehlds) | [![Download](https://img.shields.io/github/v/release/rehlds/rehlds?include_prereleases&style=flat-square)](https://github.com/rehlds/rehlds/releases) |
| [ReGameDLL_CS](https://github.com/rehlds/ReGameDLL_CS/releases) | [![Download](https://img.shields.io/github/v/release/s1lentq/ReGameDLL_CS?include_prereleases&style=flat-square)](https://github.com/rehlds/ReGameDLL_CS/releases) |
| [Metamod-R](https://github.com/rehlds/Metamod-R/releases) | [![Download](https://img.shields.io/github/v/release/rehlds/Metamod-R?include_prereleases&style=flat-square)](https://github.com/rehlds/Metamod-R/releases) |
| [ReSemiclip](https://github.com/rehlds/resemiclip/releases) | [![Download](https://img.shields.io/github/v/release/rehlds/resemiclip?include_prereleases&style=flat-square)](https://github.com/rehlds/resemiclip/releases) |
| [AMXModX (v1.9 or v1.10)](https://www.amxmodx.org/downloads-new.php) | [![Download](https://img.shields.io/badge/AMXModX-%3E%3D1.9.0-blue?style=flat-square)](https://www.amxmodx.org/downloads-new.php) |
| [ReAPI](https://github.com/rehlds/reapi) | [![Download](https://img.shields.io/github/v/release/rehlds/reapi?include_prereleases&style=flat-square)](https://github.com/rehlds/reapi) |
| [MySQL (Необязательно)](https://dev.mysql.com/downloads/mysql/) | [![Download](https://img.shields.io/badge/MySQL-Latest-blue?style=flat-square)](https://dev.mysql.com/downloads/mysql/) |


## Характеристики

- Public / DeathMatch / Zombie - Моды для разминок.
- Knife / Captain - Режимы распределений команд.
- Battle race / Arenas - Альтернатива ножевому в knife-контексте и отдельные race-запуски.
- MR / Wintime / 1x1 - Режимы матчей
- Watcher (admin) menu (N)
- Система зависит от администратора.
- Surrender
- AFK, Player leave contol

## Установка / Настройка
 
### [1. Установка системы на сервер](https://github.com/OpenHNS/HnsMatchSystem/wiki/1.-%D0%A3%D1%81%D1%82%D0%B0%D0%BD%D0%BE%D0%B2%D0%BA%D0%B0-%D1%81%D0%B8%D1%81%D1%82%D0%B5%D0%BC%D1%8B-%D0%BD%D0%B0-%D1%81%D0%B5%D1%80%D0%B2%D0%B5%D1%80)

### [2. Настройка конфигурации карт для миксов](https://github.com/OpenHNS/HnsMatchSystem/wiki/2.-%D0%9D%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B9%D0%BA%D0%B0-%D0%BA%D0%BE%D0%BD%D1%84%D0%B8%D0%B3%D1%83%D1%80%D0%B0%D1%86%D0%B8%D0%B8-%D0%BA%D0%B0%D1%80%D1%82-%D0%B4%D0%BB%D1%8F-%D0%BC%D0%B8%D0%BA%D1%81%D0%BE%D0%B2)

### [3. (Опционально) Настройка PTS ‐ Mysql бд](https://github.com/OpenHNS/HnsMatchSystem/wiki/3.--%D0%9D%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B9%D0%BA%D0%B0-PTS-%E2%80%90-Mysql-%D0%B1%D0%B4)

### [4. Настройка привилегий Watcher Full watcher](https://github.com/OpenHNS/HnsMatchSystem/wiki/4.-%D0%9D%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B9%D0%BA%D0%B0-%D0%BF%D1%80%D0%B8%D0%B2%D0%B8%D0%BB%D0%B5%D0%B3%D0%B8%D0%B9-Watcher-Full-watcher)

## Описание
    
- Watcher

    Система не автоматическая, для того, чтобы игроки могли заводить миксы, есть плагин 'HnsMatchWatcher.amxx'. 
    
    Watcher - игрок, который запускает миксы.

- Full Watcher

    Данная привилегия такая же как и Watcher, только у нас добавляются возможности: Кикать, Банить на миксы, Забирать права у игроков кто Watcher.
    
- Запуск микса
    
    Для того чтобы запустить матч игру, вам необходимо поменять карту на ножевую карту, запустить капитан мод и выбрать 2х капитанов.
    
    Далее капитаны играют ножевой раунд и выбирают игроков в команды.
    
    После играется ножевой раунд и победители ножевого раунда должны выбрать карту, а Watcher или Админ поменять карту.
    
    После смены карты система будет ждать игроков и запустит микс.
    
- Матч - Maxround режим

    На игру дается в общей сумме четное кол-во раундов (14) (hns_rounds * 2). Командам дается таймер, который равен 00:00.

    Таймер увеличивается у команды играющие за террористов. Команды каждый раунд меняются.

    По истечению раундов (14) та команда, у которой больше таймер победила.

- Матч - Wintime режим

    Командам дается определенное кол-во времени (15)    
    У команды, которая играет за террористов время отнимается.
    Та команда, у которой закончилось время, победила.

- Матч - Дуэль режим

    Дм режим, дается минут 15 на всю игру.
    Между игроками показывает линию, которая отражает дистанцию игроков.  
    Есть 3 дистанции.
    Зелёная - примерно 100 юнитов, за нее даётся оч много очков.
    Жёлтая - примерно 250 юнитов даётся много очков
    Белая - примерно 400 юнитов, дается мало очков.
    Ну и Красная - больше 400 юнитов очков не даёт вообще.
    Ну и суть такова: Нужно набрать больше очков.
    Чем ближе ты к противнику, тем больше это ценится. 

## Плагины
- HnsMatchSystem.sma - Основной плагин системы
- HnsMatchStats.sma - Статистика матча (kills/deaths/dmg/survival и т.д.)
- HnsMatchStatsMysql.sma - MySQL/PTS статистика (`/rank`, `/pts`)
- HnsMatchOwnage.sma - Подсчет ownage (работает вместе с MySQL-статистикой)
- HnsMatchPlayerInfo.sma - HUD/round info/speclist
- HnsMatchChatmanager.sma - Chat manager и форматирование сообщений
- HnsMatchMaps.sma - Список карт и карта-настройки (`/maps`)
- HnsMatchMapRules.sma - Правила для отдельных карт
- HnsMatchTraining.sma - Тренировочный режим (cp/tp/respawn/noclip)
- HnsMatchBattles.sma - Battle race / Arenas (`/race`, `/arenas`, captain battle decide)
- HnsMatchRecontrol.sma - Замена/передача контроля игрока
- HnsMatchWatcher.sma - Система watcher и голосование за watcher
- HnsMatchBans.amxx - Плагин банов матч-системы (бинарный модуль в сборке)

## Команды / Cvars

### [5. Команды и CVAR микс системы](https://github.com/OpenHNS/HnsMatchSystem/wiki/5.-%D0%9A%D0%BE%D0%BC%D0%B0%D0%BD%D0%B4%D1%8B-%D0%B8-CVAR-%D0%BC%D0%B8%D0%BA%D1%81-%D1%81%D0%B8%D1%81%D1%82%D0%B5%D0%BC%D1%8B)

## Благодарности / Aвторы других плагинов
[Garey](https://github.com/Garey27)

[Medusa](https://github.com/medusath)

[juice](https://github.com/etojuice)
