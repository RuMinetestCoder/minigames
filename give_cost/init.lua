give_cost = {}
local settings = {}
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
function give_cost.set_boost(num)
    boost = num
end

function give_cost.get_boost()
    return boost
end

-- LOCAL FUNCTIONS
local function load_settings()
    settings = mod_configs.get_conf('give_cost', 'settings')
    if not settings then
        settings = {
            events = {
                craft = 0.05, dig = 0.01, place = 0.02, chat = 0.05, eat = 0.1, permin = 0.1
            }
        }
        mod_configs.save_conf('give_cost', 'settings', settings)
    end
end
load_settings()

local function tick()
    for _, player in ipairs(minetest.get_connected_players()) do
        coins.add_coins(player:get_player_name(), settings.events.permin * boost)
    end
    minetest.after(60, tick)
end
minetest.after(60, tick)

-- EVENTS
minetest.register_on_craft(function(itemstack, player, old_craft_grid, craft_inv)
    coins.add_coins(player:get_player_name(), settings.events.craft * boost)
end)

minetest.register_on_dignode(function(pos, oldnode, digger)
    coins.add_coins(digger:get_player_name(), settings.events.dig * boost)
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    coins.add_coins(placer:get_player_name(), settings.events.place * boost)
end)

minetest.register_on_chat_message(function(name, message)
    coins.add_coins(name, settings.events.chat * boost)
end)

minetest.register_on_item_eat(function(hp_change, replace_with_item, itemstack, user, pointed_thing)
    coins.add_coins(user:get_player_name(), settings.events.eat * boost)
end)

-- REGISTRATIONS
minetest.register_privilege('gcreload', S('Can use /gcreload'))

-- COMMANDS
minetest.register_chatcommand('gcreload', {
    params = 'none',
    description = S('reload give_cost settings'),
    privs = {gcreload = true},
    func = function(name, params)
        load_settings()
        return true, S('settings config reloaded')
    end,
})
