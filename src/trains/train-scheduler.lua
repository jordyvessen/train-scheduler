require "TrainWithState"
require "train-schedules"
require "scheduler-train-stop"

---@type table<number, TrainWithState>
local trainCache = {}

function get_train_cache()
  return trainCache
end

---@return LuaTrain[]
function get_trains()
  ---@type LuaTrain[]
  local trains = {}

  for _, surface in pairs(game.surfaces) do
    local surface_trains = game.train_manager.get_trains({
      surface = surface,
      is_manual = false
    })

    for _, train in pairs(surface_trains) do
      table.insert(trains, train)
    end
  end

  return trains
end

function build_train_cache()
  if storage.train_state == nil then
    storage.train_state = {}
  end

  local trains = get_trains()
  for _, train in pairs(trains) do
    local state = storage.train_state[train.id]
    if state == nil then goto continue end

    trainCache[train.id] = TrainWithState:new(train, state)

    ::continue::
  end
end

---@param train TrainWithState
---@return boolean
local function is_train_available(train)
  if not train.isValid() then return false end

  local fuelCount = train.getFuelCount()
  return train.state.activeState == trainActiveState.WAITING and
          train.state.autoSchedulingEnabled == true and
          fuelCount > 100
end

---@param train TrainWithState
---@param schedule TrainSchedule?
---@param station string
local function schedule_train(train, schedule, station)
  if schedule == nil then return end

  train.luaTrain.schedule = schedule
  train.updateState({
    activeState = trainActiveState.SCHEDULED
  })

  local cargoCount = train.getCargoCount()
  local fuelCount = train.getFuelCount()
  local itemName = getItemTypeName(train.state)
  log("Scheduled train " .. train.id .. " 🔥" .. fuelCount ..
    " to '" .. station .. "' with " .. cargoCount .. " " .. itemName)
end

---@param trainItemType SignalID
---@param requests table<number, Signal>
---@return boolean, Requester[]
local function is_train_requested(trainItemType, requests)
  ---@type Requester[]
  local requesters = {}

  for requesterId, request in pairs(requests) do
    if request.signal.name == trainItemType.name then
      local cache = get_requester_cache()
      local requester = cache[requesterId]
      if requester ~= nil then
        table.insert(requesters, requester)
      end
    end
  end

  local hasRequest = #requesters > 0
  return hasRequest, requesters
end

---@param train TrainWithState
---@param requests table<number, Signal>
---@return boolean
local function try_schedule_unloading_request(train, requests)
  if train.state.itemType == nil then return false end

  local isRequested, requesters = is_train_requested(train.state.itemType, requests)
  if not isRequested then return false end

  if not train.hasCargo(train.state.itemType) then return false end

  local unloadingStop = nil
  for _, requester in pairs(requesters) do
    unloadingStop = get_available_unloading_stop(train.state.itemType, requester)
    if unloadingStop ~= nil then break end
  end

  if unloadingStop == nil then return false end

  local schedule = create_unloading_schedule(train.luaTrain, unloadingStop.entity.backer_name)
  if schedule == nil then return false end

  schedule_train(train, schedule, unloadingStop.entity.backer_name)

  return true
end

---@param train TrainWithState
---@return boolean
local function try_schedule_loading_request(train)
  if train.state.itemType == nil then return false end

  local maxCapacity = train.getMaxCapacity()
  local currentCapacity = train.getCargoCount()
  if currentCapacity >= maxCapacity then return false end

  local stop = get_available_loading_stop(train.state.itemType)
  if stop == nil then return false end

  local schedule = create_loading_schedule(train.luaTrain, stop.entity.backer_name)
  if schedule == nil then return false end

  schedule_train(train, schedule, stop.entity.backer_name)

  return true
end

---@param requests table<number, Signal>
function try_schedule_trains(requests)
  local trainIndex = game.tick % 60

  local index = 0
  for _, train in pairs(trainCache) do
    index = index + 1

    if not train.isValid() then goto continue end
    if index ~= trainIndex then
      goto continue
    end

    local state = get_train_state(train.id)
    if state == nil then goto continue end

    local isAvailable = is_train_available(train)
    if not isAvailable then goto continue end

    local scheduled = execute_timed("try_schedule_unloading_request",
      function()
        return try_schedule_unloading_request(train, requests)
      end,
      nil,
      true)

    if scheduled then return end

    scheduled = execute_timed("try_schedule_loading_request",
      function()
        return try_schedule_loading_request(train)
      end,
      nil,
      true)
    if scheduled then return end

    ::continue::
  end
end

function on_train_removed(entity)
  if entity.name ~= "locomotive" then return end

  local train = entity.train
  if train == nil then return end

  trainCache[train.id] = nil
  storage.train_state[train.id] = nil
end

script.on_event(defines.events.on_train_created,
  function(event)
    local state = nil
    if event.old_train_id_1 then
      state = get_train_state(event.old_train_id_1)
      trainCache[event.old_train_id_1] = nil
      storage.train_state[event.old_train_id_1] = nil
    end

    if event.old_train_id_2 then
      state = get_train_state(event.old_train_id_2)
      trainCache[event.old_train_id_2] = nil
      storage.train_state[event.old_train_id_2] = nil
    end

    trainCache[event.train.id] = TrainWithState:new(event.train, {
      activeState = state and state.activeState or trainActiveState.WAITING,
      autoSchedulingEnabled = state and state.autoSchedulingEnabled or false,
      itemType = state and state.itemType or nil
    })
  end
)

script.on_event(defines.events.on_train_changed_state,
  function(event)
    local train = trainCache[event.train.id]
    if train == nil then return end

    if event.train.state == defines.train_state.wait_station then
      local stationState = get_train_stop_state(event.train.station)
      if stationState == nil then return end

      log("Train " .. train.id .. " (" .. getItemTypeName(train.state) .. ") " .. " arrived at station " .. event.train.station.backer_name .. " (" .. stationState.type .. ")" )

      if stationState.type == TrainStopType.LOADING then
        train.updateState({
          activeState = trainActiveState.LOADING
        })
      elseif stationState.type == TrainStopType.UNLOADING then
        train.updateState({
          activeState = trainActiveState.UNLOADING
        })
      elseif stationState.type == TrainStopType.WAITING then
        schedule_train(train, create_idle_schedule(event.train.station.backer_name), event.train.station.backer_name)

        train.updateState({
          activeState = trainActiveState.WAITING
        })
      end
    elseif event.train.state == defines.train_state.on_the_path then
      if train.luaTrain.schedule.current == #train.luaTrain.schedule.records then
        local newSchedule = {
          records = {},
          current = 1
        }

        table.insert(newSchedule.records, train.luaTrain.schedule.records[#train.luaTrain.schedule.records])
        train.luaTrain.schedule = newSchedule
      end
    end
  end
)
