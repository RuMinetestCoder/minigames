# pvp_arena

PvP arena minigame for minetest. Protect arena, there are lobby and spectate. The distribution of the prize coins. Take into account the order of leave, number of hits, being in the region. Support **gui_menu**.

## How to working?

* Gamers joining to lobby, moving coins cost from balance to fond.
* Gamers voting start.
* Chat separate.
* Gamers teleported to game point. Inventrory backup, give random kit.
* Pause.
* Start game.
* Game...
* End game, distribution of the prize coins, give coins. Formula: "fond / 2 * boost", "fond = fond / 2".

Commands:

* **/pa list** - show list available arenas
* **/pa join [arena]** - join to lobby
* **/pa spec [arena]** - watch
* **/pa leave** - leaving, if game not started - return coins cost
* **/pa start** - vote start

## How to create arena?

* **/pacreate [arena]**
* Punch node (pos 1 arena region)
* **/papos1**
* Punch node (pos 2 arena region)
* **/papos2**
* Punch node (pvp zone pos 1)
* **/pazpos1**
* Punch node (pvp zone pos 2)
* **/pazpos2**
* Stand on the position.
* **/palobby (save lobby position)**
* Stand on the position.
* **/paspec (save spectate position)**
* Stand on the position.
* **/pagame (save game position)**
* **/pasettings [min_p] [max_p] [after] [max_time] [cost]**
* **/pakit name (optional)** - add kit for random, you inventory
* **/pakits** - show kit names
* **/padone**

Done! Editing:

* **/paedit [arena]**
* ... editing ... (read above)
* **/padone**

For removing:

* **/paremove [arena]**

For reload config:

* **/pareload**

## Moder commands

* **/pakick [player]** - kick player from arena
* **/pastop [arena]** - force stop game
* **/pastart [arena]** - force start game

## Privs

* **pvpa** - for access game commands
* **pvpamod** - for access moder commands
* **pvpaadm** - for access admin commands (edit arenas)

## Depends

* cuboids_lib
* coins
* pvp_control?
* gui_menu?
* initlib?

## API

* **pvp_arena.get_arenas()** - get available arenas, return array
* **pvp_arena.get_active_arenas()** - get started arenas, return table "{arena = #players + #spectators}"
* **pvp_arena.get_wait_arenas()** - get waiting arenas (gamers in lobby), return table "{arena = #players + #spectators}"
* **pvp_arena.set_boost(num)**
* **pvp_arena.get_boost()**
