require "items.requested-hub"
require "items.item-requester-ui"
require "trains.train-scheduler-ui"
require "trains.scheduler-train-stop-ui"

local shouldInit = true

---@type table<number, Signal>
local itemRequests = {}

script.on_event(defines.events.on_tick,
  function(event)
    if shouldInit then
      build_requester_cache()
      build_hubs_cache()
      build_train_cache()
      build_train_stop_cache()
      shouldInit = false
    end

    if event.tick % 60 == 0 then
      itemRequests = process_requesters()
      update_hubs(itemRequests)
    end

    try_schedule_trains(itemRequests)
  end
)

---@param entity LuaEntity
local function on_create(entity)
  on_requester_created(entity)
  on_hub_created(entity)
  on_train_stop_created(entity)
end

---@param entity LuaEntity
local function on_remove(entity)
  on_requester_removed(entity)
  on_hub_removed(entity)
  on_train_stop_removed(entity)
end

script.on_event({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.script_raised_built,
  defines.events.script_raised_revive
},
  function(event)
    local entity = event.created_entity or event.entity
    on_create(entity)
  end
)

script.on_event({
  defines.events.on_pre_player_mined_item,
  defines.events.on_robot_pre_mined,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy
},
  function(event)
    on_remove(event.entity)
  end
)

-- ToDo: On chunk deleted, remove all requesters and hubs in that chunks

---@param event EventData.on_gui_opened | EventData.on_gui_closed
---@return LuaPlayer?, LuaEntity?
local function get_event_data(event)
  local entity = event.entity
  if entity == nil then return end

  local player = game.get_player(event.player_index)
  if player == nil then return end

  return player, entity
end

--- Gui events
script.on_event(defines.events.on_gui_opened,
  function(event)
    local player, entity = get_event_data(event)
    if player == nil or entity == nil then return end

    try_open_item_requester_ui(player, entity)
    try_open_train_ui(player, entity)
    try_open_train_stop_ui(player, entity)
  end
)

script.on_event(defines.events.on_gui_closed,
  function(event)
    local player, entity = get_event_data(event)
    if player == nil or entity == nil then return end

    try_close_item_requester_ui(player, entity)
    try_close_train_ui(player, entity)
    try_close_train_stop_ui(player, entity)
  end
)

script.on_event(defines.events.on_gui_elem_changed,
  function(event)
    local player = game.get_player(event.player_index)
    if player == nil then return end

    local element = event.element
    if element == nil then return end

    on_train_ui_elem_changed(player, element)
  end
)

script.on_event(defines.events.on_gui_value_changed,
  function(event)
    local player = game.get_player(event.player_index)
    if player == nil then return end

    local element = event.element
    if element == nil then return end

    on_requester_ui_value_changed(player, element)
  end
)