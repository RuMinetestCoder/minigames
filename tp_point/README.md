# tp_point

Add teleport positions. Support give and take cost, sending message to player. Give cost formula: *setting numer + boost*.

## Create point

Need *tppoint* priv.

* **/tppcreate [name] [give] [take] [mess?]**
* or **/tppedit [name]**
* Punch node.
* **/tppfrom** - add from position (teleport point)
* Stand on the position.
* **/tppto** - add to position
* **/tppdone**

Other commands:

* **/tppdel [name]**
* **/tppreload** - for reloading data from config file
* **/tppoints** - show list names points

## Depends

* mod_configs
*coins
* essentials
* initlib?

## API

* *tp_point.set_boost(num)*
* *tp_point.get_boost()* - return number
* *tp_point.get_all_points()* - return array
* *tp_point.get_point(pos)* - return string name or nil, pos - table "{x = number, y = number, z = number}"
* *tp_point.get_point_data(name)* - return table or nil, table - "{from = from_pos, to = to_pos, give = give_cost, take = take_cost}"
* *tp_point.add_point(name, from_pos, to_pos, give_cost, take_cost, message)* - message optional (set nil)
* *tp_point.del_point(name)*
* *tp_point.is_exists(name)* - return bool, true if name is exists
