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
- MR / Wintime / 1x1 - Режими матчей
- Watcher (admin) menu (N)
- Система зависит от администратора.
- Surrender
- AFK, Player leave contol

## Установка
 
1. Скомпилируйте плагин.

2. Скопируйте скомпилированный файл `.amxx` в директорию: `amxmodx/plugins/`

3. Скопируйте содержимое папки `configs/` в директорию: `amxmodx/configs/`

4. Скопируйте содержимое папки `data/lang/` в директорию: `amxmodx/data/lang/`

5. Скопируйте содержимое папки `modules/` (Если у вас сервер на линуксе, то берем файл `.so` , если винда `.dll`) в директорию: `amxmodx/modules/`

6. Пропишите `.amxx` в файле `amxmodx/configs/plugins.ini`

7. Перезапустите сервер или поменяйте карту.

## Настройка

- Настройка птc

    1. Открыть файл `configs/mixsystem/hnsmatch-sql.cfg`
    2. Вписать туда данные для базы данных
    3. Поменять карту.

- Настройка конфигов для карты
    1. Заходим в папку `configs/mixsystem/mapcfg/`
    2. Создаем файл с названием карты (rayish_brick-world.cfg)
    3. Вписываем в файл нужные настройки:

            mp_roundtime "2.5"
            mp_freezetime "5" 
            hns_flash "1"
            hns_smoke "1"
    4. Сохраняем. Теперь у нас при старте микса на карте rayish_brick-world будут выставляться настройки автоматически.

- Ножевая карта
    1. Открываем файл `configs/mixsystem/matchsystem.cfg`
    2. Изменяем квар hns_knifemap под вашу ножевую карту.
    3. Все, теперь на указанной вами карте будут проходить капитан и кнайф моды, рекомендую ножевую карту ставить первой в списке карт `maps.ini`

- Watcher

    Для watcher'а необходимо настроить `configs/cmdaccess.ini`, а именно сделать доступным для флага f следующие команды:

        "amx_slay" 	"f" ; admincmd.amxx
        "amx_slap" 	"f" ; admincmd.amxx
        "amx_map" 	"f" ; admincmd.amxx
        "amx_slapmenu" 	"f" ; plmenu.amxx
        "amx_teammenu" 	"f" ; plmenu.amxx
        "amx_mapmenu" 	"f" ; mapsmenu.amxx   

## Описание
    
- Watcher

    Система не автоматическая, для того, чтобы игроки могли заводить миксы, есть плагин 'HnsMatchWatcher.amxx'. 
    
    Watcher - игрок, который запускает миксы.     
    
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

## Плагины
- HnsMatchSystem.sma - Основной плагин мода
- HnsMatchStats.sma - Плагин статистики микса
- HnsMatchPlayerInfo.sma - Hud информация игрока
- HnsMatchSql.sma - Плагин для взаимодействия с БД
- HnsMatchPts.sma - Плагин для ПТС (не работает без Sql плагина)
- HnsMatchOwnage.sma - Плагин для подсчета Ownage (не работает без Sql плагина)
- HnsMatchChatmanager.sma - Измененый ЧМ, показывает префикс ранга (скилла)
- HnsMatchMaps.sma - Список карт для игроков (/maps)
- HnsMatchTraining.sma - Трейнинг меню (Чектоинты)
- HnsMatchWatcher.sma - Watcher система, позволяет игрокам становиться/голосовать за watcher
- HnsMatchMapRules.sma - Плагин для установления правил для карт (убийство в воде на карте de_piranesi) 

## Cvars

| Cvar                 | Default    | Description |
| :------------------- | :--------: | :--------------------------------------------------- |
| hns_rules            | 0          | Режим по умолчанию (0 - MR 1 - Timer) |
| hns_wintime          | 15         | Время для победы |
| hns_rounds           | 6          | Кол-во раундов для победы |
| hns_duel             | 3          | Кол-во выигранных раундов для победы |
| hns_boost            | 0          | Включить/Отключить буст режим |
| hns_onehpmode        | 0          | Включить/Отключить 1 хп режим |
| hns_flash	           | 1          | Кол-во флешек (Плагин сам изменяет) |
| hns_smoke            | 1          | Кол-во дыма (Плагин сам изменяет) |
| hns_last             | 1          | Включить/Отключить выдачу гранат последнему ТТ |
| hns_dmrespawn        | 3          | Время (в секундах), в течение которого игрок возродится в режиме DM |
| hns_survotetime      | 10         | Время (в секундах), в течение которого идет голосование (surrender) |
| hns_randompick       | 1          | Включить/Отключить случайный выбор игроков |
| hns_knifemap         | 35hp_2     | Ножевая карта |
| hns_prefix           | MATCH      | Префикс системы |
| hns_gamename         | Hide'n'Seek | Геймнейм сервера |

## Комманды

- Комманды в чат

- Watcher (ADMIN_MAP)

| Commands | Description |
| :------------------- |  :--------------------------------------------------- |
| mix | Админ меню |
| mode / type | Мод меню |
| timer / wintime | Изменить режим микса на Таймер |
| mr / maxround | Изменить режим микса на Мр |
| training | Тренировочное меню |
| pub / public | Паблик мод |
| dm / deathmatch | ДМ мод |
| specall | Перенести всех за наблюдателей |
| ttall | Перенести всех за ТТ |
| ctall | Перенести всех за КТ |
| startmix / start | Запустить матч |
| kniferound / kf | Запустить ножевой раунд |
| captain / cap | Запустить капитан мод |
| stop / cancel | Остановить текущий режим  |
| skill | Скилл мод |
| boost | Буст мод |
| rr / restart | Рестарт раунда |
| swap / swap | Поменять команды местами |
| pause / ps | Пауза |
| live / unpause | Запуск |
| mr 5 | Выставить кол-во раундов |

- Player

| Commands | Description |
| :------------------- |  :--------------------------------------------------- |
| hideknife / showknife / knife | Спрятать, Показать нож |
| surrender / sur | Голосование за сдачу |
| score / s | Счет |
| pick | Меню пика |
| back / spec | Перейти или вернуться за наблюдателей |
| np / noplay | Не играю |
| ip / play | Играю |
| checkpoint / cp | Чекпоинт |
| teleport / tp | Телепорт к чекпоинту |
| gocheck / gc | Чекпоинтn |
| showdmg / showdamade | Дамаг |
| noclip / clip | Ноуклип |
| respawn / resp | Заспавниться |
| top / tops | Топ игроков за матч |
| map / maps | Показать список карт |
| rank / me | Показать свою статистику птс |
| pts / ptstop | Показать топ игроков по птс |
| hud / hudinfo | Отключить/Включить худ |
| rnw / rocknewwatcher | Голосовать за нового watcher |
| wt / watcher | Передать/Назначить нового watcher |
| speclist / showpec | Включить/выключить speclist |
| spechide / hidespec | Включить/выключить spechide |

## Благодарности / Aвторы других плагинов
[Garey](https://github.com/Garey27)

[Medusa](https://github.com/medusath)

[juice](https://github.com/etojuice)
