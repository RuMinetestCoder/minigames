spleef = {}
-- {arena {
--  edit = true/false,
--  lobby = {xyz},
--  spec = {xyz},
--  game = {xyz},
--  floor = {{xyz} = {node}, ...}
--  y_level = number,
--  max_time = number,
--  after = number,
--  reg = {pos1 = {xyz}, pos2 = {xyz}},
--  minp = number,
--  maxp = number,
--  cost = number,
--  tool = string (optional)
-- }, ...}
local arenas = {}
-- {arena {
--  players = {array}, spectators = {array}, invs = {player_name = json string, ...}, locs = {player_name = {xyzpitchyaw}},
--  leaves = {player_name = number, ...}, blocks = {player_name = number, ...}, start = {array},
--  channels = {player_name = channel, ...}, started = true/false, time = number (time start), fond = number (all money)
-- }, ...}
local games = {}
-- arenas analog
local sets = {}
-- {
--  player_name = {arena = arena name, spec = true/false}, ...
-- }
local gamers = {}
-- {player_name = arena = string, pos1 = {xyz}, pos2 = {xyz}, fpos1 = {xyz}, fpos2 = {xyz}, pos = {xyz}}
local editors = {}
local boost = 1

-- INITLIB
local S, NS
if minetest.global_exists('intllib') then
    S, NS = intllib.make_gettext_pair(minetest.get_current_modname())
else
    S = function(s) return s end
    NS = S
end

-- API
function spleef.get_arenas()
    local result = {}
    for key, value in pairs(arenas) do
        if not value.edit then
            table.insert(result, key)
        end
    end
    return result
end

function spleef.get_active_arenas()
    local result = {}
    for key, value in pairs(games) do
        if value.started then
            result[key] = #value.players + #value.spectators
        end
    end
    return result
end

function spleef.get_wait_arenas()
    local result = {}
    for key, value in pairs(games) do
        if not value.started then
            result[key] = #value.players + #value.spectators
        end
    end
    return result
end

function spleef.set_boost(num)
    boost = num
end

function spleef.get_boost()
    return boost
end

-- LOCAL FUNCTIONS
local function load_file()
    arenas = mod_configs.load_json('spleef', 'arenas')
    if not arenas then arenas = {} end
end

local function load_cache()
    sets = mod_configs.load_json('spleef', 'cache_sets')
    editors = mod_configs.load_json('spleef', 'cache_editors')
    if not sets then sets = {} end
    if not editors then editors = {} end
end

load_file()
--load_cache()

local function tp_lobby(player, arena)
    games[arena].locs[player:get_player_name()] = player:getpos()
    games[arena].locs[player:get_player_name()].pitch = player:get_look_vertical()
    games[arena].locs[player:get_player_name()].yaw = player:get_look_horizontal()
    local pos = arenas[arena].lobby
    player:setpos(pos)
    player:set_look_vertical(pos.pitch)
    player:set_look_horizontal(pos.yaw)
end

local function tp_spectate(player, arena)
    games[arena].locs[player:get_player_name()] = player:getpos()
    games[arena].locs[player:get_player_name()].pitch = player:get_look_vertical()
    games[arena].locs[player:get_player_name()].yaw = player:get_look_horizontal()
    local pos = arenas[arena].spec
    player:setpos(pos)
    player:set_look_vertical(pos.pitch)
    player:set_look_horizontal(pos.yaw)
end

local function tp_game(player, arena)
    local pos = arenas[arena].game
    player:setpos(pos)
    player:set_look_vertical(pos.pitch)
    player:set_look_horizontal(pos.yaw)
end

local function tp_back(player, arena)
    local pos = games[arena].locs[player:get_player_name()]
    player:setpos(pos)
    player:set_look_vertical(pos.pitch)
    player:set_look_horizontal(pos.yaw)
end

local function create_game(arena)   
    games[arena] = {
        players = {}, spectators = {}, invs = {}, locs = {}, leaves = {}, blocks = {},
        start = {}, channels = {}, started = false, time = 0, fond = 0
    }
    superchat.add_channel('spleef.' .. arena)
end

local function regen_floors(arena)
    for pos, node in pairs(arenas[arena].floor) do
        minetest.set_node(minetest.parse_json(pos), node)
    end
end

local function get_top(arena)
    local players = {}
    local blocks = {}
    for key, value in pairs(games[arena].blocks) do blocks[value] = key end
    local result = {}
    local i = 1
    for key, value in pairs(blocks) do
        result[value] = i
        i = i + 1
    end
    local ys = {}
    for key, value in pairs(games[arena].players) do
        local y = minetest.get_player_by_name(value):getpos().y
        if not ys[y] then ys[y] = value end
        table.insert(players, value)
    end
    local result2 = {}
    i = 1
    for key, value in pairs(ys) do
        result2[value] = i
        i = i + 1
    end
    for key in pairs(games[arena].leaves) do table.insert(players, key) end
    local result3 = {}
    i = math.abs(#games[arena].players - #games[arena].leaves)
    for key, value in pairs(players) do
        if games[arena].leaves[value] then
            result3[games[arena].leaves[value]] = value
        elseif result2[value] then
            result3[result2[value]] = value
        elseif result[value] then
            local p = result[value]
            while result3[p] do p = p - 1 end
            result3[p] = value
        else
            while result3[i] do i = i - 1 end
            result3[i] = value
            i = i - 1
        end
    end
    return result3
end

local function get_inv(inv)
    local result = {}
    for key, value in pairs(inv:get_lists()) do
        local list = {}
        for k, v in pairs(value) do list[k] = v:to_table() end
        result[key] = list
    end
    return result
end

local function clear_inv(inv)
    for key, value in pairs(inv:get_lists()) do
        for k, v in pairs(value) do inv:remove_item(key, v) end
    end
end

local function set_inv(inv, data)
    clear_inv(inv)
    for key, value in pairs(data) do
        for k, v in pairs(value) do inv:add_item(key, v) end
    end
end

local function stop_game(arena)
    local fond = games[arena].fond
    local mess = ''
    local top = get_top(arena)
    for key, value in pairs(top) do
        local priz = 0
        if #top > 2 then priz = fond / 2 else priz = fond end
        if priz > 0 then
            coins.add_coins(value, priz * boost)
            minetest.chat_send_player(value, S('%dst, give %d coins'):format(key, priz * boost))
        end
        mess = mess .. S('%dst'):format(key) .. ': ' .. value
        fond = fond - priz
    end
    for _, name in pairs(games[arena].players) do
        local player = minetest.get_player_by_name(name)
        tp_back(player, arena)
        set_inv(player:get_inventory(), games[arena].invs[name])
        minetest.chat_send_player(name, mess)
        superchat.change_channel(name, games[arena].channels[name])
        gamers[name] = nil
        gui_menu.reset_formspec(name)
    end
    for _, name in pairs(games[arena].spectators) do
        local player = minetest.get_player_by_name(name)
        tp_back(player, arena)
        minetest.chat_send_player(name, mess)
        superchat.change_channel(name, games[arena].channels[name])
        superchat.del_channel('spleef.' .. arena)
        gamers[name] = nil
        gui_menu.reset_formspec(name)
    end
    superchat.del_channel('superchat.' .. arena)
    games[arena] = nil
end

local function leave(player_name)
    local arena = gamers[player_name].arena
    local player = minetest.get_player_by_name(player_name)
    tp_back(player, arena)
    if games[arena].invs[player_name] then
        set_inv(player:get_inventory(), games[arena].invs[player_name])
    end
    if games[arena].channels[player_name] then
        superchat.change_channel(player_name, games[arena].channels[player_name])
    end
    games[arena].channels[player_name] = nil
    games[arena].invs[player_name] = nil
    if games[arena].started then
        coins.add_coins(player_name, arenas[arena].cost)
        games[arena].fond = games[arena].fond - arenas[arena].cost
    end
    local i = 1
    if gamers[player_name].spec then
        for key, value in pairs(games[arena].spectators) do
            if value == player_name then
                table.remove(games[arena].spectators, i)
                break
            end
        end
    else
        if games[arena].started then games[arena].leaves[player_name] = #games[arena].players end
        for key, value in pairs(games[arena].players) do
            if value == player_name then
                table.remove(games[arena].players, i)
                break
            end
            i = i + 1
        end
    end
    gamers[player_name] = nil
    gui_menu.reset_formspec(player_name)
    if player:is_player_connected() then
        minetest.chat_send_player(player_name, S('You leaving from %s'):format(arena))
    end
    if not games[arena].players or #games[arena].players <= 1 then stop_game(arena) end
end

local function worker(arena)
    if not games[arena] then return end
    for _, name in ipairs(games[arena].players) do
        local player = minetest.get_player_by_name(name)
        local y = player:getpos().y
        if y < arenas[arena].y_level then
            leave(name)
        end
    end
    if not games[arena] then return end
    if os.time() - games[arena].time >= arenas[arena].max_time then
        stop_game(arena)
        return
    end
    minetest.after(1, worker, arena)
end

local function start_game(arena)
    regen_floors(arena)
    superchat.add_channel('spleef.' .. arena)
    local tool = minetest.setting_get('spleef.tool')
    if not tool then tool = 'default:shovel_diamond' end
    if arenas.tool then tool = arenas.tool end
    for _, name in ipairs(games[arena].players) do
        local inv = minetest.get_player_by_name(name):get_inventory()
        games[arena].invs[name] = get_inv(inv)
        clear_inv(inv)
        inv:add_item('main', tool)
        games[arena].channels[name] = superchat.get_player_channel(name)
        superchat.change_channel(name, 'spleef.' .. arena)
        tp_game(minetest.get_player_by_name(name), arena)
        gamers[name] = minetest.parse_json('{"arena":"' .. arena .. '","spec":false}')
        minetest.chat_send_player(name, S('============ SPLEEF ============'))
        minetest.chat_send_player(name, S('-------> CHAT SEPARATE <-------'))
        minetest.chat_send_player(name, S('GAME WILL STARTING, PLEASE WAIT...'))
        minetest.chat_send_player(name, S('============ SPLEEF ============'))
    end
    for _, name in ipairs(games[arena].spectators) do
        games[arena].channels[name] = superchat.get_player_channel(name)
        superchat.change_channel(name, 'spleef.' .. arena)
        gamers[name] = minetest.parse_json('{"arena":' .. arena .. ',"spec":false}')
        minetest.chat_send_player(name, S('============ SPLEEF ============'))
        minetest.chat_send_player(name, S('-------> CHAT SEPARATE <-------'))
        minetest.chat_send_player(name, S('GAME WILL STARTING, PLEASE WAIT...'))
        minetest.chat_send_player(name, S('============ SPLEEF ============'))
    end
    minetest.after(arenas[arena].after, function(a)
        if not games[a] then return end
        games[a].time = os.time()
        games[a].started = true
        for _, name in ipairs(games[a].players) do
            minetest.chat_send_player(name, S('START GAME!!! RUN!'))
        end
        for _, name in ipairs(games[a].spectators) do
            minetest.chat_send_player(name, S('START GAME!!! SEE!'))
        end
        minetest.after(1, worker, arena)
    end, arena)
    games[arena].fond = #games[arena].players * arenas[arena].cost
end

local function tfloor(pos)
    for key, value in pairs(pos) do pos[key] = math.floor(value) end
    return pos
end

local function set_area(arena, pos1, pos2)
    sets[arena].reg = {tfloor(pos1), tfloor(pos2)}
end

local function set_floor(arena, pos1, pos2)
    sets[arena].floor = {}
    pos1 = tfloor(pos1)
    pos2 = tfloor(pos2)
    for _, pos in ipairs(cuboids_lib.get_nodes(cuboids_lib.get_cube(pos1, pos2))) do
        sets[arena].floor[minetest.write_json(pos)] = minetest.get_node_or_nil(pos)
    end
    local y = 0
    if pos1.y <= pos2.y then y = pos1.y else y = pos2.y end
    if not sets[arena].y_level or y < sets[arena].y_level then sets[arena].y_level = y end
end

local function set_settings(arena, min_p, max_p, after, max_time, cost)
    sets[arena].minp = min_p
    sets[arena].maxp = max_p
    sets[arena]['max_time'] = max_time
    sets[arena]['after'] = after
    sets[arena]['cost'] = cost
end

local function save()
    mod_configs.save_json('spleef', 'arenas', arenas)
end

local function done(arena)
    arenas[arena] = sets[arena]
    arenas[arena].edit = false
    save()
    sets[arena] = nil
end

local function remove(arena)
    arenas[arena] = nil
    save()
end

local function is_floor(arena, pos)
    if arenas[arena].floor[minetest.write_json(pos)] then return true end
    return false
end

local function is_arena(arena, pos)
    if not arenas[arena] or not arenas[arena].reg or not arenas[arena].reg.pos1 or not arenas[arena].reg.pos2 then
        return false
    end
    return cuboids_lib.contains(cuboids_lib.get_cube(arenas[arena].reg.pos1, arenas[arena].reg.pos2), pos)
end

local function can_break(player_name, pos)
    if editors[player_name] and is_arena(editors[player_name].arena, pos) then return true end
    if not gamers[player_name] then
        for key in pairs(arenas) do
            if is_arena(key, pos) then return false end
        end
    end
    if (gamers[player_name] and not gamers[player_name].spec and games[gamers[player_name].arena].started and
        is_floor(gamers[player_name].arena, pos)) then
        return true
    end
    return false
end

local function to_lobby(player, arena)
    local player_name = player:get_player_name()
    if not games[arena] then create_game(arena) end
    table.insert(games[arena].players, player_name)
    gamers[player_name] = minetest.parse_json('{"arena":"' .. arena .. '","spec":false}')
    coins.take_coins(player_name, arenas[arena].cost)
    tp_lobby(player, arena)
end

local function to_spectate(player, arena)
    local player_name = player:get_player_name()
    table.insert(games[arena].spectators, player_name)
    gamers[player_name] = minetest.parse_json('{"arena":"' .. arena .. '","spec":true}')
    tp_spectate(player, arena)
end

local function vote_start(arena, name)
    if games[arena].start then
        for key, value in pairs(games[arena].start) do
            if value == name then return false end
        end
    end
    table.insert(games[arena].start, name)
    if #games[arena].start == #games[arena].players and #games[arena].players >= arenas[arena].minp then
        start_game(arena)
    end
    return true
end

-- EVENTS
minetest.register_on_player_hpchange(function(player, hp_change)
    if gamers[player:get_player_name()] then return true end
end, nil)

minetest.register_on_respawnplayer(function(player)
	local player_name = player:get_player_name()
	if gamers[player_name] then leave(player_name) end
end)

minetest.register_on_dignode(function(pos, oldnode, digger)
    if not can_break(digger:get_player_name(), pos) then return true end
end)

minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
    local player_name = puncher:get_player_name()
    if editors[player_name] then
        editors[player_name].pos = pos
        minetest.chat_send_player(player_name, S('Pos') .. ': ' .. minetest.pos_to_string(pos))
    end
    if not can_break(player_name, pos) then return true
    elseif gamers[player_name] then
        minetest.remove_node(pos)
        local b = games[gamers[player_name].arena].blocks[player_name]
        if b then
            games[gamers[player_name].arena].blocks[player_name] = b + 1
        else
            games[gamers[player_name].arena].blocks[player_name] = 1
        end
    end
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    local player_name = placer:get_player_name()
    if not editors[player_name] and gamers[player_name] then return true end
end)

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
    if gamers[player:get_player_name()] then return true end
end)

minetest.register_on_leaveplayer(function(player)
    local player_name = player:get_player_name()
    if gamers[player_name] then leave(player_name) end
end)

minetest.register_on_shutdown(function()
    for key in pairs(games) do stop_game(key) end
    mod_configs.save_json('spleef', 'chache_games', games)
    mod_configs.save_json('spleef', 'chache_gamers', gamers)
    mod_configs.save_json('spleef', 'chache_sets', sets)
    mod_configs.save_json('spleef', 'cache_editors', editors)
end)

local old_is_protected = minetest.is_protected
function minetest.is_protected(pos, name)
	if not can_break(name, pos) then
		return true
	end
	return old_is_protected(pos, name)
end

-- REGISTRATIONS
minetest.register_privilege('spleef', S('For using spleef'))
minetest.register_privilege('spleefmod', S('For manage spleef games'))
minetest.register_privilege('spleefadm', S('For editing arenas'))

--  COMMANDS
minetest.register_chatcommand('spcreate', {
    params = '<arena>',
    description = S('start creating spleef arena'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not params or params:trim():len() == 0 then return false, S('invalid command, not arena') end
        if arenas[params] or sets[params] then
            return false, S('%s is found'):format(params)
        end
        sets[params] = minetest.parse_json('{"edit":false}')
        editors[name] = minetest.parse_json('{"arena":"' .. params .. '"}')
        return true, S('arena %s created'):format(params)
    end,
})

minetest.register_chatcommand('spedit', {
    params = '<arena>',
    description = S('start editing spleef arena'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not params or params:trim():len() == 0 then return false, S('invalid command, not arena') end
        if games[params] then return false, S('%s is started'):format(params) end
        if not arenas[params] then return false, S('%s not found') end
        sets[params] = arenas[params]
        arenas[params].edit = true
        editors[name] = minetest.parse_json('{"arena":"' .. params .. '"}')
        return true, S('%s edit mode on'):format(params)
    end,
})

minetest.register_chatcommand('spdone', {
    params = 'none',
    description = S('done editing'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not editors[name] then return false, S('need edit mode on') end
        local arena = editors[name].arena
        done(arena)
        editors[name] = nil
        return true, S('%s done editing'):format(arena)
    end,
})

minetest.register_chatcommand('spremove', {
    params = '<arena>',
    description = S('remove arena'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not params or params:trim():len() == 0 then return false, S('invalid command, not arena') end
        if not arenas[params] then return false, S('%s not found') end
        remove(params)
        return true, S('%s removed'):format(params)
    end,
})

minetest.register_chatcommand('spreload', {
    params = 'none',
    description = S('reload arenas config'),
    privs = {spleefadm = true},
    func = function(name, params)
        load_file()
        return true, S('settings reloaded')
    end,
})

minetest.register_chatcommand('sppos1', {
    params = 'none',
    description = S('set spleef arena region pos1'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not editors[name] then return false, S('need edit mode on') end
        local arena = editors[name].arena
        if not editors[name].pos then return false, S('not selected point') end
        editors[name].pos1 = editors[name].pos
        if editors[name].pos2 then
            set_area(arena, editors[name].pos1, editors[name].pos2)
        end
        return true, S('pos1 for %s set'):format(arena)
    end,
})

minetest.register_chatcommand('sppos2', {
    params = '<arena>',
    description = S('set spleef arena region pos2'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not editors[name] then return false, S('need edit mode on') end
        local arena = editors[name].arena
        if not editors[name].pos then return false, S('not selected point') end
        editors[name].pos2 = editors[name].pos
        if editors[name].pos1 then
            set_area(arena, editors[name].pos1, editors[name].pos2)
        end
        return true, S('pos2 for %s set'):format(arena)
    end,
})

minetest.register_chatcommand('spfpos1', {
    params = 'none',
    description = S('set spleef arena floor pos1'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not editors[name] then return false, S('need edit mode on') end
        local arena = editors[name].arena
        if not editors[name].pos then return false, S('not selected point') end
        editors[name].fpos1 = editors[name].pos
        if editors[name].fpos2 then
            set_floor(arena, editors[name].fpos1, editors[name].fpos2)
        end
        return true, S('fpos1 for %s set'):format(arena)
    end,
})

minetest.register_chatcommand('spfpos2', {
    params = 'none',
    description = S('set spleef arena floor pos2'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not editors[name] then return false, S('need edit mode on') end
        local arena = editors[name].arena
        if not editors[name].pos then return false, S('not selected point') end
        editors[name].fpos2 = editors[name].pos
        if editors[name].fpos1 then
            set_floor(arena, editors[name].fpos1, editors[name].fpos2)
        end
        return true, S('fpos2 for %s set'):format(arena)
    end,
})

minetest.register_chatcommand('spsettings', {
    params = '<min_p> <max_p> <after> <max_time> <cost>',
    description = S('set spleef arena settings'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not editors[name] then return false, S('need edit mode on') end
        local arena = editors[name].arena
        if not params or params:trim():len() == 0 then return false, S('invalid command, not args') end
        local params = params:split(' ')
        if #params < 1 then return false, S('invalid command, not min_players') end
        if #params < 2 then return false, S('invalid command, not max_players') end
        if #params < 3 then return false, S('invalid command, not after') end
        if #params < 4 then return false, S('invalid command, not max_time') end
        if #params < 5 then return false, S('invalid command, not cost') end
        for i = 1, 5 do
            params[i] = params[i]:trim()
            if not params[i]:match('^[0-9]*$') then
                return false, S('incorrect number %s'):format(params[1])
            end
        end
        set_settings(
            arena, tonumber(params[1]), tonumber(params[2]),
            tonumber(params[3]), tonumber(params[4]), tonumber(params[5])
        )
        return true, S('%s settings set'):format(arena)
    end,
})

minetest.register_chatcommand('splobby', {
    params = 'none',
    description = S('set spleef arena lobby point'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not editors[name] then return false, S('need edit mode on') end
        local arena = editors[name].arena
        local player = minetest.get_player_by_name(name)
        local pos = player:getpos()
        pos.pitch = player:get_look_vertical()
        pos.yaw = player:get_look_horizontal()
        sets[arena].lobby = pos
        return true, S('%s lobby point set'):format(arena)
    end,
})

minetest.register_chatcommand('spspec', {
    params = 'none',
    description = S('set spleef arena spectate point'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not editors[name] then return false, S('need edit mode on') end
        local arena = editors[name].arena
        local player = minetest.get_player_by_name(name)
        local pos = player:getpos()
        pos.pitch = player:get_look_vertical()
        pos.yaw = player:get_look_horizontal()
        sets[arena].spec = pos
        return true, S('%s spectate point set'):format(arena)
    end,
})

minetest.register_chatcommand('spgame', {
    params = 'none',
    description = S('set spleef arena game point'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not editors[name] then return false, S('need edit mode on') end
        local arena = editors[name].arena
        local player = minetest.get_player_by_name(name)
        local pos = player:getpos()
        pos.pitch = player:get_look_vertical()
        pos.yaw = player:get_look_horizontal()
        sets[arena].game = pos
        return true, S('%s game point set'):format(arena)
    end,
})

minetest.register_chatcommand('sptool', {
    params = '<itemstering>',
    description = S('set tool for spleef arena'),
    privs = {spleefadm = true},
    func = function(name, params)
        if not params or params:trim():len() == 0 then return false, S('invalid command, not itemstring') end
        if not editors[name] then return false, S('need edit mode on') end
        local arena = editors[name].arena
        if not pcall(ItemStack(params)) then return false, S('invalid itemstring') end
        sets[arena].tool = params
        return true, S('%s tool set'):format(arena)
    end,
})


minetest.register_chatcommand('spkick', {
    params = '<player>',
    description = S('kick player from spleef arena'),
    privs = {spleefmod = true},
    func = function(name, params)
        if not params or params:trim():len() == 0 then return false, S('invalid command, not player name') end
        if not gamers[params] then return false, S('%s not in spleef'):format(params) end
        local arena = gamers[params].arena
        leave(params)
        minetest.chat_send_player(params, S('%s kicking you from spleef arena %s'):format(name, arena))
        return true, S('%s kicked from spleef arena %s'):format(params, arena)
    end,
})

minetest.register_chatcommand('spstop', {
    params = '<arena>',
    description = S('stop spleef arena'),
    privs = {spleefmod = true},
    func = function(name, params)
        if not params or params:trim():len() == 0 then return false, S('invalid command, not arena') end
        if not games[params] or not games[params].started then return false, S('%s not started'):format(params) end
        superchat.send(name, 'spleef.' .. params, S('FORCE STOPPING GAME'))
        stop_game(params)
        return true, S('%s stopped'):format(params)
    end,
})

minetest.register_chatcommand('spstart', {
    params = '<arena>',
    description = S('start spleef arena'),
    privs = {spleefmod = true},
    func = function(name, params)
        if not params or params:trim():len() == 0 then return false, S('invalid command, not arena') end
        if not games[params] or not games[params].started then return false, S('%s not started'):format(params) end
        superchat.send(name, 'spleef.' .. params, S('FORCE STARTING GAME'))
        start_game(params)
        return true, S('%s started'):format(params)
    end,
})

minetest.register_chatcommand('spleef', {
    params = '<list/join/spec/leave/start>',
    description = S('gamers commands'),
    privs = {spleef = true},
    func = function(name, params)
        if not params or params:trim():len() == 0 then return false, S('invalid command, not arg') end
        local player = minetest.get_player_by_name(name)
        if params == 'list' then
            local str = ''
            for key, value in ipairs(spleef.get_arenas()) do
                str = str .. value .. ', '
            end
            if str:len() > 0 then return true, S('Arenas') .. ': ' .. str:sub(0, str:len() - 2)
            else return false, S('not arenas') end
        elseif params:sub(0, 4) == 'join' then
            local params = params:split(' ')
            if #params < 2 then return false, S('invalid command, not arena') end
            local arena = params[2]
            if not arenas[arena] then return false, S('%s not found'):format(arena) end
            if games[arena] and games[arena].started then return false, S('%s is started'):format(arena) end
            if not coins.get_coins(name) or coins.get_coins(name) < arenas[arena].cost then
                return false, S('sorry, not %d coins in you balance'):format(arenas[arena].cost)
            end
            if games[arena] and #games[arena].players >= arenas[arena].maxp then
                return false, S('%s is full'):format(arena)
            end
            if gamers[name] then return false, S('You playing arena %s'):format(arena) end
            to_lobby(player, arena)
            return true, S('Joined %s arena, taking %d coins'):format(arena, arenas[arena].cost)
        elseif params:sub(0, 4) == 'spec' then
            local params = params:split(' ')
            if #params < 2 then return false, S('invalid command, not arena') end
            if not games[params[2]] then return false, S('%s not started'):format(params[2]) end
            if gamers[name] then return false, S('You playing arena %s'):format(arena) end
            to_spectate(player, params[2])
            return true, S('You spectate %s arena'):format(params[2])
        elseif params == 'leave' then
            if not gamers[name] then return false, S('you not in spleef arena') end
            local arena = gamers[name].arena
            leave(name)
            gui_menu.reset_formspec(name)
            return true, S('you leaving from %s arena'):format(arena)
        elseif params == 'start' then
            if not gamers[name] then return false, S('you not in spleef arena') end
            local arena = gamers[name].arena
            local v = vote_start(arena, name)
            if not v then return false, S('you have already voted') end
            return true, S('You vote start game')
        else
            return false, S('Using /spleef list/join/spec/leave/start')
        end
    end,
})

-- MENU SUPPORT
if minetest.global_exists('gui_menu') then
    gui_menu.add_listener(function(player_name, cat, page, fields)
        local player = minetest.get_player_by_name(player_name)
        
        local function ga()
            local add = spleef.get_arenas()
            if add then
                local result = {}
                result[S('Spleef arenas')] = {}
                for key, value in pairs(add) do
                    result[S('Spleef arenas')]['spleef.' .. value] = {text = value}
                end
                return result
            end
        end
        
        local ga2 = ga()
        if not ga2 then return nil end
        if not cat and not fields then
            return ga()
        elseif not fields then return nil
        elseif fields['gui_menu:cat.' .. S('Spleef arenas')] then
            gui_menu.show_buttons(player_name, S('Spleef arenas'), ga2[S('Spleef arenas')], 1)
        elseif cat == S('Spleef arenas') and fields['gui_menu:pgo'] then
            gui_menu.show_buttons(player_name, S('Spleef arenas'), ga2[S('Spleef arenas')], page + 1)
        elseif cat == S('Spleef arenas') and fields['gui_menu:pback'] then
            gui_menu.show_buttons(player_name, S('Spleef arenas'), ga2[S('Spleef arenas')], page - 1)
        elseif cat == S('Spleef arenas') and fields then
            local lstr = 'size[3,1]button[0,0;3,1;spleef.leave;' .. S('Leave') .. ']'
            local sstr = 'size[6,1]button[0,0;3,1;spleef.start;' .. S('Vote start') .. ']button[3,0;3,1;spleef.leave;' .. S('Leave') .. ']'
            if fields['spleef.leave'] then
                if not gamers[player_name] then
                    minetest.chat_send_player(player_name, S('you not in spleef arena'))
                    gui_menu.reset_formspec(player_name)
                    gui_menu.show_cat(player_name, nil)
                    return
                end
                leave(player_name)
                gui_menu.reset_formspec(player_name)
                gui_menu.show_cat(player_name, nil)
                return
            elseif fields['spleef.close'] then
                gui_menu.show_cat(player_name, nil)
                return
            elseif fields['spleef.start'] then
                if not gamers[player_name] then
                    minetest.chat_send_player(player_name, S('you not in spleef arena'))
                    gui_menu.set_formspec(player_name, lstr)
                    minetest.show_formspec(player_name, 'gui_menu', lstr)
                    return
                end
                local v = vote_start(gamers[player_name].arena, player_name)
                if not v then
                    minetest.chat_send_player(player_name, S('you have already voted'))
                end
                minetest.chat_send_player(player_name, S('You vote start game'))
                gui_menu.set_formspec(player_name, lstr)
                minetest.show_formspec(player_name, 'gui_menu', lstr)
                return
            end
        
            local function f(player, arena)
                local result = 'size[8,1]button[7,0;1,1;spleef.close;X]'
                if games[arena] then
                    result = result .. 'button[4,0;3,1;spleef.' .. arena .. '.spec;' .. S('Spectate') .. ']'
                end
                if not games[arena] or not games[arena].started or #games[arena].players < arenas[arena].maxp then
                    result = result .. 'button[0,0;3,1;spleef.' .. arena .. '.join;' .. S('Join') .. ']'
                end
                minetest.show_formspec(player_name, 'gui_menu', result)
            end
            
            local ar = spleef.get_arenas()
            if not arenas then return nil end
            for key, value in pairs(ar) do
                if fields['spleef.' .. value] then
                    return {func = f, args = {value}}
                elseif fields['spleef.' .. value .. '.join'] then
                    if gamers[player_name] then
                        minetest.chat_send_player(player_name, S('You playing arena %s'):format(value))
                        return
                    end
                    if games[value] and games[value].started then
                        minetest.chat_send_player(player_name, S('%s is started'):format(value))
                        return
                    end
                    if not coins.get_coins(player_name) or coins.get_coins(player_name) < arenas[value].cost then
                        minetest.chat_send_player(player_name, S('sorry, not %d coins in you balance'):format(arenas[value].cost))
                        return
                    end
                    if games[value] and #games[value].players >= arenas[value].maxp then
                        minetest.chat_send_player(player_name, S('%s is full'):format(value))
                        return
                    end
                    to_lobby(player, value)
                    minetest.chat_send_player(player_name, S('Joined %s arena, taking %d coins'):format(value, arenas[value].cost))
                    gui_menu.set_formspec(player_name, sstr)
                    minetest.show_formspec(player_name, 'gui_menu', sstr)
                elseif fields['spleef.' .. value .. '.spec'] then
                    if not games[value] then
                        minetest.chat_send_player(player_name, S('%s not started'):format(value))
                        return
                    end
                    if gamers[player_name] then
                        minetest.chat_send_player(player_name, S('You playing arena %s'):format(value))
                        return
                    end
                    to_spectate(player, value)
                    minetest.chat_send_player(player_name, S('You spectate %s arena'):format(value))
                    gui_menu.set_formspec(player_name, lstr)
                    minetest.show_formspec(player_name, 'gui_menu', lstr)
                end
            end
        end
    end)
end
