# spleef

Spleef minigame for minetest. Auto regen floor, protect arena, there are lobby and spectate. The distribution of the prize coins. Take into account the order of leave, number of broken blocks, the Y coordinate. Support **gui_menu**.

## How to working?

* Gamers joining to lobby, moving coins cost from balance to fond.
* Gamers voting start.
* Regenerate floor.
* Chat separate.
* Gamers teleported to game point. Inventrory backup, give tool.
* Pause.
* Start game.
* Game... floor immediately disappears from punch.
* End game, distribution of the prize coins, give coins. Formula: "fond / 2 * boost", "fond = fond / 2".

Commands:

* **/spleef list** - show list available arenas
* **/spleef join [arena]** - join to lobby
* **/spleef spec [arena]** - watch
* **/spleef leave** - leaving, if game not started - return coins cost
* **/spleef start** - vote start

## How to create arena?

* **/spcreate [arena]**
* Punch node (pos 1 arena region)
* **/sppos1**
* Punch node (pos 2 arena region)
* **/sppos2**
* Punch node (floor pos 1)
* **/spfpos1**
* Punch node (floor pos 2)
* **/spfpos2**
* Stand on the position.
* **/splobby (save lobby position)**
* Stand on the position.
* **/spspec (save spectate position)**
* Stand on the position.
* **/spgame (save game position)**
* **/spsettings [min_p] [max_p] [after] [max_time] [cost]**
* **/sptool itemstring (optional)**
* **/spdone**

Done! Editing:

* **/spedit [arena]**
* ... editing ... (read above)
* **/spdone**

For removing:

* **/spremove [arena]**

For reload config:

* **/spreload**

## Moder commands

* **/spkick [player]** - kick player from arena
* **/spstop [arena]** - force stop game
* **/spstart [arena]** - force start game

## Privs

* **spleef** - for access game commands
* **spleefmod** - for access moder commands
* **spleefadm** - for access admin commands (edit arenas)

## Settings for minetest.conf

* **spleef.tool = [itemstring]** - default item (optional, defaut - diamond shovel)

## Depends

* mod_configs
* superchat
* coins
* cuboids_lib
* gui_menu?
* initlib?

## API

* **spleef.get_arenas()** - get available arenas, return array
* **spleef.get_active_arenas()** - get started arenas, return table "{arena = #players + #spectators}"
* **spleef.get_wait_arenas()** - get waiting arenas (gamers in lobby), return table "{arena = #players + #spectators}"
* **spleef.set_boost(num)**
* **spleef.get_boost()**
