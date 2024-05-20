require "scheduler-train-stop"

---@type table<number, LuaTrain>
local trainCache = {}

trainActiveState = {
  WAITING = "Waiting",
  SCHEDULED = "Scheduled",
  LOADING = "Loading",
  UNLOADING = "Unloading"
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

  if trainCache[train.id] == nil then
    trainCache[train.id] = train
  end
end

---@param trainId number
---@return table<"itemType" | "autoSchedulingEnabled" | "activeState", SignalID | boolean | string>?
function get_train_state(trainId)
  if global.train_state == nil then return nil end
  return global.train_state[trainId]
end

function get_train_cache()
  return trainCache
end

---@return LuaTrain[]
function get_trains()
  ---@type LuaTrain[]
  local trains = {}

  for _, surface in pairs(game.surfaces) do
    for _, train in pairs(surface.get_trains()) do
      table.insert(trains, train)
    end
  end

  return trains
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
end

---@param train LuaTrain
---@param signal SignalID
---@return number
local function get_cargo_count(train, signal)
  if signal.type == "item" then
    return train.get_item_count(signal.name)
  elseif signal.type == "fluid" then
    return train.get_fluid_count(signal.name)
  end

  return 0
end

---@param train LuaTrain
---@param signal SignalID
---@return number
local function get_max_capacity(train, signal)
  ---@type LuaItemPrototype
  local item = game.item_prototypes[signal.name]
  stackSize = item ~= nil and item.stack_size or stackSize

  local total = 0
  for _, carriage in pairs(train.carriages) do
    if carriage.name ~= "cargo-wagon" and carriage.name ~= "fluid-wagon" then goto continue end

    if carriage.name == "cargo-wagon" and signal.type ~= "item" then goto continue end
    if carriage.name == "fluid-wagon" and signal.type ~= "fluid" then goto continue end

    local inventorySize = carriage.prototype.get_inventory_size(defines.inventory.cargo_wagon)
    if inventorySize == nil then goto continue end

    total = total + (inventorySize * (stackSize or 1))

    ::continue::
  end

  return total
end

---@param train LuaTrain
---@param request SignalID
---@return boolean
local function has_cargo(train, request)
  return get_cargo_count(train, request) > 0
end

---@param train LuaTrain
---@return number
local function get_fuel_count(train)
  local total = 0
  for _, locomotive in pairs(train.locomotives.front_movers) do
    total = total + locomotive.get_fuel_inventory().get_item_count()
  end

  for _, locomotive in pairs(train.locomotives.back_movers) do
    total = total + locomotive.get_fuel_inventory().get_item_count()
  end

  return total
end

---@param train LuaTrain
---@return boolean
local function is_train_available(train)
  if not train.valid then return false end

  local state = get_train_state(train.id)
  if state == nil then return false end

  local fuelCount = get_fuel_count(train)
  return state.activeState == trainActiveState.WAITING and
          state.autoSchedulingEnabled == true and
          fuelCount > 100
end

---@param station string
---@return TrainScheduleRecord
local function create_loading_record(station)
  ---@type TrainScheduleRecord
  return {
    station = station,
    wait_conditions = {
      {
        type = "full",
        compare_type = "or"
      }
    }
  }
end

---@param station string
local function create_wait_record(station)
  ---@type TrainScheduleRecord
  return {
    station = station,
    wait_conditions = {
      {
        type = "time",
        compare_type = "or",
        ticks = 60 * 5
      }
    }
  }
end

---@param station string
local function create_unloading_record(station)
  ---@type TrainScheduleRecord
  return {
    station = station,
    wait_conditions = {
      {
        type = "empty",
        compare_type = "or"
      },
      {
        type = "circuit",
        compare_type = "or",
        condition = {
          first_signal = {
            type = "virtual",
            name = "signal-green"
          },
          constant = 0,
          comparator = "="
        }
      }
    }
  }
end

---@param station string
---@param idleStation string
---@return TrainSchedule
local function create_unloading_schedule(station, idleStation)
  ---@type TrainSchedule
  local schedule = {
    records = {},
    current = 1
  }

  table.insert(schedule.records, create_unloading_record(station))
  table.insert(schedule.records, create_wait_record(idleStation))

  return schedule
end

---@param station string
---@param idleStation string
---@return TrainSchedule
local function create_loading_schedule(station, idleStation)
  ---@type TrainSchedule
  local schedule = {
    records = {},
    current = 1
  }

  table.insert(schedule.records, create_loading_record(station))
  table.insert(schedule.records, create_wait_record(idleStation))

  return schedule
end

---@param station string
---@return TrainSchedule
local function create_idle_schedule(station)
  ---@type TrainSchedule
  local schedule = {
    records = {},
    current = 1
  }

  table.insert(schedule.records, create_wait_record(station))

  return schedule
end

---@param train LuaTrain
---@param schedule TrainSchedule
---@param station string
---@param itemType SignalID
local function schedule_train(train, schedule, station, itemType)
  train.schedule = schedule
  update_train_state(train, {
    activeState = trainActiveState.SCHEDULED
  })

  local cargoCount = get_cargo_count(train, itemType)
  local fuelCount = get_fuel_count(train)
  log("Scheduled train " .. train.id .. " 🔥" .. fuelCount ..
    " to '" .. station .. " with " .. cargoCount .. " " .. itemType.name)
end

---@param trainItemType SignalID
---@param requests table<number, Signal>
---@return boolean, Requester?
local function is_train_requested(trainItemType, requests)
  for requesterId, request in pairs(requests) do
    if request.signal.name == trainItemType.name then
      local cache = get_requester_cache()
      return true, cache[requesterId]
    end
  end

  return false, nil
end

---@param train LuaTrain
---@param requests table<number, Signal>
---@return boolean
local function try_schedule_unloading_request(train, requests)
  local state = get_train_state(train.id)
  if state == nil then return false end

  local itemType = state.itemType
  ---@cast itemType SignalID

  local isRequested, requester = is_train_requested(itemType, requests)
  if not isRequested or requester == nil then return false end

  if not has_cargo(train, itemType) then return false end

  local unloadingStop = get_available_unloading_stop(itemType, requester)
  if unloadingStop == nil then return false end

  local idleStop = get_available_waiting_stop(train)
  if idleStop == nil then return false end

  schedule_train(train, create_unloading_schedule(unloadingStop.entity.backer_name, idleStop.entity.backer_name), unloadingStop.entity.backer_name, itemType)

  return true
end

---@param train LuaTrain
---@return boolean
local function try_schedule_loading_request(train)
  local state = get_train_state(train.id)
  if state == nil then return false end

  local itemType = state.itemType
  ---@cast itemType SignalID

  local maxCapacity = get_max_capacity(train, itemType)
  local currentCapacity = get_cargo_count(train, itemType)
  if currentCapacity >= maxCapacity then return false end

  local stop = get_available_loading_stop(itemType)
  if stop == nil then return false end

  local idleStop = get_available_waiting_stop(train)
  if idleStop == nil then return false end

  schedule_train(train, create_loading_schedule(stop.entity.backer_name, idleStop.entity.backer_name), stop.entity.backer_name, itemType)

  return true
end

---@param requests table<number, Signal>
function try_schedule_trains(requests)
  local trainIndex = game.tick % 60

  local index = 0
  for _, train in pairs(trainCache) do
    if not train.valid then goto continue end
    index = index + 1

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
  end
)

script.on_event(defines.events.on_train_changed_state,
  function(event)
    local state = get_train_state(event.train.id)
    if state == nil then return end

    if event.train.state == defines.train_state.wait_station then
      local stationState = get_train_stop_state(event.train.station)
      if stationState == nil then return end

      log("Train " .. event.train.id .. " arrived at station " .. event.train.station.backer_name .. " (" .. stationState.type .. ")" )

      if stationState.type == TrainStopType.LOADING then
        update_train_state(event.train, {
          activeState = trainActiveState.LOADING
        })
      elseif stationState.type == TrainStopType.UNLOADING then
        update_train_state(event.train, {
          activeState = trainActiveState.UNLOADING
        })
      elseif stationState.type == TrainStopType.WAITING then
        local itemType = state.itemType
        ---@cast itemType SignalID

        schedule_train(event.train, create_idle_schedule(event.train.station.backer_name), event.train.station.backer_name, itemType)

        update_train_state(event.train, {
          activeState = trainActiveState.WAITING
        })
      end
    elseif event.train.state == defines.train_state.on_the_path then
      if event.train.schedule.current == #event.train.schedule.records then
        local newSchedule = {
          records = {},
          current = 1
        }

        table.insert(newSchedule.records, event.train.schedule.records[#event.train.schedule.records])
        event.train.schedule = newSchedule
      end
    end
  end
)
