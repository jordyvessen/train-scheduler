require "util"

---@type table<number, LuaTrain>
local trainCache = { }

---@type table<number, LuaEntity>
local trainStopCache = { }

local trainStopType = {
  UNLOADING = "Unloading",
  LOADING = "Loading",
  WAITING = "Waiting",
  UNKNOWN = "Unknown"
}

local trainActiveState = {
  WAITING = "Waiting",
  SCHEDULED = "Scheduled",
  LOADING = "Loading",
  UNLOADING = "Unloading"
}

local trainStopTypeCharacterMap = {
  ["U"] = trainStopType.UNLOADING,
  ["L"] = trainStopType.LOADING,
  ["W"] = trainStopType.WAITING
}

---@param train LuaTrain
---@param newState table<"itemType" | "autoSchedulingEnabled" | "activeState", SignalID | boolean | string>
function update_train_state(train, newState)
  if not train.valid then return end

  if global.train_state[train.id] == nil then
    global.train_state[train.id] = {}
  end

  for key, value in pairs(newState) do
    global.train_state[train.id][key] = value
  end

  log("Updated train state for entity " ..
      " (" .. train.id .. ")" .. " to " .. serpent.block(global.train_state[train.id]))
end

---@param trainId number
---@return table<"itemType" | "autoSchedulingEnabled" | "activeState", SignalID | boolean | string>?
function get_train_state(trainId)
  if global.train_state == nil then return nil end
  return global.train_state[trainId]
end

---@return LuaTrain[]
function get_trains()
  ---@type LuaTrain[]
  local trains = { }

  for _, surface in pairs(game.surfaces) do
    for _, train in pairs(surface.get_trains()) do
      table.insert(trains, train)
    end
  end

  return trains
end

local function build_train_stop_cache()
  local stops = get_entities("train-stop")
  for _, stop in pairs(stops) do
    trainStopCache[stop.unit_number] = stop
  end
end

function build_train_cache()
  if global.train_state == nil then
    global.train_state = {}
  end

  local trains = get_trains()
  for _, train in pairs(trains) do
    local state = get_train_state(train.id)
    if state == nil then goto continue end

    if state.activeState == nil then
      update_train_state(train, {
        activeState = trainActiveState.WAITING
      })
    end

    trainCache[train.id] = train

    ::continue::
  end

  build_train_stop_cache()

  log("Built train cache. " .. serpent.block(trainCache))
end

---@param stop LuaEntity
---@param requester LuaEntity
---@return boolean
local function is_stop_connected_to_requester(stop, requester)
  local control = stop.get_or_create_control_behavior()
  if control == nil then return false end

  ---@cast control LuaTrainStopControlBehavior
  local redConnection = control.get_circuit_network(defines.wire_type.red)
  local redConnectionId = redConnection and redConnection.network_id or nil

  local greenConnection = control.get_circuit_network(defines.wire_type.green)
  local greenConnectionId = greenConnection and greenConnection.network_id or nil

  if redConnectionId == nil and greenConnectionId == nil then return false end

  local requesterControl = get_item_requester_control(requester)
  if requesterControl == nil then return false end

  local requesterRedConnection = requesterControl.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_output)
  local requesterRedConnectionId = requesterRedConnection and requesterRedConnection.network_id or nil

  local requesterGreenConnection = requesterControl.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_output)
  local requesterGreenConnectionId = requesterGreenConnection and requesterGreenConnection.network_id or nil

  if requesterRedConnectionId == nil and requesterGreenConnectionId == nil then return false end

  return (requesterRedConnectionId == redConnectionId and requesterRedConnectionId ~= nil) or
          (requesterGreenConnectionId == greenConnectionId and requesterGreenConnectionId ~= nil)
end

local function get_connected_stop_for_requester(requester)
  for _, stop in pairs(trainStopCache) do
    if is_stop_connected_to_requester(stop, requester) then
      return stop
    end
  end

  return nil
end

---@param stop LuaEntity
---@return "Unloading" | "Loading" | "Waiting" | "Unknown"
local function get_stop_type(stop)
  local stopTypeCharacter = string.sub(stop.backer_name, 1, 1)
  return trainStopTypeCharacterMap[stopTypeCharacter] or trainStopType.UNKNOWN
end

---@param train LuaTrain
---@param request SignalID
---@return boolean
local function is_filled(train, request)
  if request.type == "item" then
    return train.get_item_count(request.name) > 0
  elseif request.type == "fluid" then
    return train.get_fluid_count(request.name) > 0
  end

  return false
end

---@param request Signal
local function get_available_filled_train(request)
  ---@type LuaTrain[]
  local availableTrains = { }

  for _, train in pairs(trainCache) do
    if not train.valid then goto continue end

    local trainState = get_train_state(train.id)
    if trainState == nil then goto continue end
    if not trainState.autoSchedulingEnabled then goto continue end
    if trainState.activeState ~= trainActiveState.WAITING then goto continue end

    if trainState.itemType.name == request.signal.name and is_filled(train, request.signal) then
      table.insert(availableTrains, train)
    end

    ::continue::
  end

  ---@param a LuaTrain
  ---@param b LuaTrain
  local function compare(a, b)
    if request.signal.type == "item" then
      return a.get_item_count(request.signal.name) < b.get_item_count(request.signal.name)
    elseif request.signal.type == "fluid" then
      return a.get_fluid_count(request.signal.name) < b.get_fluid_count(request.signal.name)
    end

    return false
  end

  table.sort(availableTrains, compare)
  if #availableTrains > 0 then return availableTrains[1] end

  return nil
end

---@param requester LuaEntity
local function get_available_empty_train(requester)
  for _, train in pairs(trainCache) do
    if not train.valid then goto continue end

    local trainState = get_train_state(train.id)
    if trainState == nil then goto continue end
    if not trainState.autoSchedulingEnabled then goto continue end
    if trainState.activeState ~= trainActiveState.WAITING then goto continue end

    local stop = get_connected_stop_for_requester(requester)
    if stop == nil then goto continue end

    if #stop.get_train_stop_trains() > 0 then goto continue end

    if is_filled(train, state.itemType) then goto continue end

    ::continue::
  end

  return nil

end

---@param stop LuaEntity
---@return TrainScheduleRecord
local function create_loading_record(stop)
  ---@type TrainScheduleRecord
  return {
    station = stop.backer_name,
    wait_conditions = {
      {
        type = "full",
        compare_type = "or"
      },
      {
        type = "circuit",
        compare_type = "or",
        condition = {
          first_signal = {
            type = "virtual",
            name = "signal-red"
          },
          constant = 0,
          comparator = ">"
        }
      }
    }
  }
end

local function create_wait_record()
  ---@type TrainScheduleRecord
  return {
    station = "W - YARD",
    wait_conditions = {
      {
        type = "time",
        compare_type = "or",
        ticks = 60 * 5
      }
    }
  }
end

---@param stop LuaEntity
local function create_unloading_record(stop)
  ---@type TrainScheduleRecord
  return {
    station = stop.backer_name,
    wait_conditions = {
      {
        type = "empty",
        compare_type = "or"
      }
    }
  }
end

---@param stop LuaEntity
---@return TrainSchedule
local function create_request_schedule(stop)
  ---@type TrainSchedule
  local schedule = {
    records = {},
    current = 1
  }

  table.insert(schedule.records, create_unloading_record(stop))
  table.insert(schedule.records, create_wait_record())

  return schedule
end

---@param requests table<number, Signal>
local function try_schedule_unloading_requests(requests)
  local requesterCache = get_requester_cache()

  for requesterId, itemRequest in pairs(requests) do
    local requester = requesterCache[requesterId]
    if requester == nil then goto continue end

    local stop = get_connected_stop_for_requester(requester)
    if stop == nil then goto continue end

    if #stop.get_train_stop_trains() > 0 then goto continue end

    local stopType = get_stop_type(stop)
    if stopType == trainStopType.UNKNOWN then goto continue end

    local availableTrain = get_available_filled_train(itemRequest)

    if availableTrain then
      availableTrain.schedule = create_request_schedule(stop)
      update_train_state(availableTrain, {
        activeState = trainActiveState.SCHEDULED
      })

      log("Scheduled train " .. availableTrain.id .. " to " .. stop.backer_name .. " (" .. stopType .. ")")
    end

    ::continue::
  end
end

local function try_schedule_loading_requests()
  local requesterCache = get_requester_cache()

  for requesterId, requester in pairs(requesterCache) do
    local stop = get_connected_stop_for_requester(requester)
    if stop == nil then goto continue end

    if #stop.get_train_stop_trains() > 0 then goto continue end

    local stopType = get_stop_type(stop)
    if stopType == trainStopType.UNKNOWN then goto continue end

    local availableTrain = get_available_filled_train(itemRequest)

    if availableTrain then
      availableTrain.schedule = create_request_schedule(stop)
      update_train_state(availableTrain, {
        activeState = trainActiveState.SCHEDULED
      })

      log("Scheduled train " .. availableTrain.id .. " to " .. stop.backer_name .. " (" .. stopType .. ")")
    end

    ::continue::
  end

end

---@param requests table<number, Signal>
function try_schedule_trains(requests)
  try_schedule_unloading_requests(requests)
end


script.on_event(defines.events.on_train_changed_state,
  function(event)
    if not trainCache[event.train.id] then return end

    -- log("Train changed state: " .. serpent.block(event))
  end
)

script.on_event(defines.events.on_train_created,
  function(event)
    local state = nil
    if event.old_train_id_1 then
      state = get_train_state(event.old_train_id_1)
      trainCache[event.old_train_id_1] = nil
      global.train_state[event.old_train_id_1] = nil
    end

    if event.old_train_id_2 then
      state = get_train_state(event.old_train_id_2)
      trainCache[event.old_train_id_2] = nil
      global.train_state[event.old_train_id_2] = nil
    end

    trainCache[event.train.id] = event.train
    update_train_state(event.train, {
      activeState = state and state.activeState or trainActiveState.WAITING,
      autoSchedulingEnabled = state and state.autoSchedulingEnabled or false,

      ---@diagnostic disable-next-line: assign-type-mismatch
      itemType = state and state.itemType or nil
    })

    log("Train created: " .. serpent.block(event))
    log("Train cache: " .. serpent.block(trainCache))
  end
)