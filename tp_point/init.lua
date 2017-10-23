tp_point = {}
local data = {}
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
function tp_point.set_boost(num)
    boost = num
end

function tp_point.get_boost()
    return boost
end

function tp_point.get_all_points()
    local result = {}
    for key in pairs(data) do table.insert(result, key) end
    return result
end

function tp_point.get_point(pos)
    pos = essentials.table_floor(pos)
    for key, value in pairs(data) do
        if essentials.table_equals(pos, value.from) then return key end
    end
    return nil
end

function tp_point.get_point_data(name)
    if not data[name] then return nil end
    return data[name]
end

function tp_point.add_point(name, from_pos, to_pos, give_cost, take_cost, message)
    data[name] = {
        from = from_pos, to = to_pos, give = give_cost, take = take_cost
    }
    if message then data[name].mess = message end
    mod_configs.save_json('tp_point', 'points', data)
end

function tp_point.del_point(name)
    data[name] = nil
    mod_configs.save_json('tp_point', 'points', data)
end

function tp_point.is_exists(name)
    if data[name] then return true end
    return false
end

-- LOCAL FUNCTIONS
local function load_data()
    data = mod_configs.load_json('tp_point', 'points')
    if not data then data = {} end
end
load_data()

local function tp(point, player_name)
    if data[point].take > 0 and data[point].take >= coins.get_coins(player_name) then
        coins.take_coins(player_name, data[point].take)
        minetest.chat_send_player(player_name, S('take %d coins for teleport'):format(data[point].take))
    end
    essentials.set_full_pos(minetest.get_player_by_name(player_name), data[point].to)
    if data[point].give > 0 then
        coins.add_coins(player_name, data[point].give * boost)
        minetest.chat_send_player(player_name, S('give %d coins to you'):format(data[point].give))
    end
    if data[point].mess then minetest.chat_send_player(player_name, data[point].mess) end
end

local function tick()
    for _, player in ipairs(minetest.get_connected_players()) do
        local point = tp_point.get_point(player:getpos())
        if point then tp(point, player:get_player_name()) end
    end
    minetest.after(0.5, tick)
end
minetest.after(0.5, tick)

local function edit(player_name, point)
    editors[player_name] = {}
    editors[player_name]['point'] = point
    editors[player_name].from = data[point].from
    editors[player_name].to = data[point].to
    editors[player_name].give = data[point].give
    editors[player_name].take = data[point].take
    if data[point].mess then editors[player_name].mess = data[point].mess end
    data[point] = nil
end

local function done(player_name)
    data[editors[player_name].point] = {
        from = editors[player_name].from, to = editors[player_name].to,
        give = editors[player_name].give, take = editors[player_name].take
    }
    if editors[player_name].mess then data[editors[player_name].point].mess = editors[player_name].mess end
    mod_configs.save_json('tp_point', 'points', data)
    editors[player_name] = nil
end

-- EVENTS
minetest.register_on_leaveplayer(function(player)
    editors[player:get_player_name()] = nil
end)

minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing)
    local player_name = puncher:get_player_name()
    if editors[player_name] then
        pos.y = pos.y + 1
        editors[player_name].pos = pos
        minetest.chat_send_player(player_name, S('Pos') .. ': ' .. minetest.pos_to_string(pos))
    end
end)

-- REGISTRATIONS
minetest.register_privilege('tppoint', S('Access to admin commands tp_point'))

-- COMMANDS
minetest.register_chatcommand('tppoints', {
    params = 'none',
    description = S('show points list'),
    privs = {tppoint = true},
    func = function(name, params)
        local str = ''
        for key in ipairs(data) do
            str = str .. key .. ', '
        end
        if str:len() > 0 then return true, S('Points') .. ': ' .. str:sub(0, str:len() - 2)
        else return false, S('no points') end
    end,
})

minetest.register_chatcommand('tppcreate', {
    params = '<name> <give> <take> <mess?>',
    description = S('create tp point'),
    privs = {tppoint = true},
    func = function(name, params)
        if not params or params:trim():len() == 0 then return false, S('invalid command, not point name') end
        local params = params:split(' ')
        if #params < 1 then return false, S('invalid command, not point name') end
        if #params < 2 then return false, S('invalid command, not give cost') end
        if #params < 3 then return false, S('invalid command, not take cost') end
        if not params[2]:trim():match('^[0-9]*$') then return false, S('invalid number %s'):format(params[2]) end
        if not params[3]:trim():match('^[0-9]*$') then return false, S('invalid number %s'):format(params[3]) end
        if editors[name] then return false, S('you already editing %s'):format(editors[name].point) end
        editors[name] = {
            point = params[1]:trim(), give = tonumber(params[2]:trim()), take = tonumber(params[3]:trim())
        }
        if #params > 3 then
            local message = ''
            for i = 4, #params do message = message .. params[i]:trim() .. ' ' end
            editors[name].mess = message:sub(0, message:len()-1)
        end
        return true, S('%s point created'):format(params[1])
    end,
})

minetest.register_chatcommand('tppdone', {
    params = 'none',
    description = S('done editing tp point'),
    privs = {tppoint = true},
    func = function(name, params)
        if not editors[name] then return false, S('you no edit mode') end
        done(name)
        return true, S('done, edit mode off')
    end,
})

minetest.register_chatcommand('tppedit', {
    params = '<name>',
    description = S('editing tp point'),
    privs = {tppoint = true},
    func = function(name, params)
        if not params or params:trim():len() == 0 then return false, S('invalid command, not point name') end
        if editors[name] then return false, S('you already editing %s'):format(editors[name].point) end
        if not data[name] then return false, S('%s not found'):format(params) end
        edit(name, params)
        return true, S('you editing %s, edit mode on'):format(params)
    end,
})

minetest.register_chatcommand('tppfrom', {
    params = 'none',
    description = S('set from pos for tp point'),
    privs = {tppoint = true},
    func = function(name, params)
        if not editors[name] then return false, S('you no edit mode') end
        if not editors[name].pos then return false, S('punch node for getting position') end
        editors[name].from = essentials.table_floor(editors[name].pos)
        return true, S('from pos for %s set'):format(editors[name].point)
    end,
})

minetest.register_chatcommand('tppto', {
    params = 'none',
    description = S('set to pos for tp point'),
    privs = {tppoint = true},
    func = function(name, params)
        if not editors[name] then return false, S('you no edit mode') end
        editors[name].to = essentials.get_full_pos(minetest.get_player_by_name(name))
        return true, S('to pos for %s set'):format(editors[name].point)
    end,
})

minetest.register_chatcommand('tppdel', {
    params = '<name>',
    description = S('remove tp point'),
    privs = {tppoint = true},
    func = function(name, params)
        if not data[params] then return false, S('point %s not found'):format(params) end
        tp_point.del_point(params)
        return true, S('point %s deleted'):format(params)
    end,
})

minetest.register_chatcommand('tppreload', {
    params = 'none',
    description = S('reload data from json config'),
    privs = {tppoint = true},
    func = function(name, params)
        load_data()
        return true, S('config reloaded')
    end,
})
