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

---@param request Signal
---@param filter (fun(train: LuaTrain): boolean)?
local function get_available_train(request, filter)
  ---@type LuaTrain[]
  local availableTrains = {}

  for _, train in pairs(trainCache) do
    if not train.valid then goto continue end

    local isAvailable = is_train_available(train)
    local isValid = filter == nil or filter(train)

    local state = get_train_state(train.id)
    if state == nil then goto continue end

    local isCorrectType = state.itemType ~= nil and state.itemType.name == request.signal.name

    if isCorrectType and isAvailable and isValid then
      table.insert(availableTrains, train)
    end

    ::continue::
  end

  ---@param a LuaTrain
  ---@param b LuaTrain
  local function compare(a, b)
    local countA = get_cargo_count(a, request.signal)
    local countB = get_cargo_count(b, request.signal)

    return countA < countB
  end

  table.sort(availableTrains, compare)
  if #availableTrains > 0 then return availableTrains[1] end

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
      }
    }
  }
end

---@param stop LuaEntity
local function create_wait_record(stop)
  ---@type TrainScheduleRecord
  return {
    station = stop.backer_name,
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

---@param stop LuaEntity
---@param waitStop LuaEntity
---@return TrainSchedule
local function create_unloading_schedule(stop, waitStop)
  ---@type TrainSchedule
  local schedule = {
    records = {},
    current = 1
  }

  table.insert(schedule.records, create_unloading_record(stop))
  table.insert(schedule.records, create_wait_record(waitStop))

  return schedule
end

---@param stop LuaEntity
---@param waitStop LuaEntity
---@return TrainSchedule
local function create_loading_schedule(stop, waitStop)
  ---@type TrainSchedule
  local schedule = {
    records = {},
    current = 1
  }

  table.insert(schedule.records, create_loading_record(stop))
  table.insert(schedule.records, create_wait_record(waitStop))

  return schedule
end

---@param stop LuaEntity
---@return TrainSchedule
local function create_idle_schedule(stop)
  ---@type TrainSchedule
  local schedule = {
    records = {},
    current = 1
  }

  table.insert(schedule.records, create_wait_record(stop))

  return schedule
end

---@param train LuaTrain
---@param schedule TrainSchedule
---@param stop LuaEntity
---@param itemType SignalID
local function schedule_train(train, schedule, stop, itemType)
  train.schedule = schedule
  update_train_state(train, {
    activeState = trainActiveState.SCHEDULED
  })

  local stopType = get_stop_type(stop)
  local cargoCount = get_cargo_count(train, itemType)
  local fuelCount = get_fuel_count(train)
  log("Scheduled train " .. train.id .. " 🔥" .. fuelCount ..
    " to '" .. stop.backer_name .. "' (" .. stopType .. ")" ..
    " with " .. cargoCount .. " " .. itemType.name)
end

---@param requests table<number, Signal>
local function try_schedule_unloading_requests(requests)
  local requesterCache = get_requester_cache()

  for requesterId, itemRequest in pairs(requests) do
    local requester = requesterCache[requesterId]
    if requester == nil then goto continue end

    local stop = get_available_unloading_stop(itemRequest.signal, requester)
    if stop == nil then goto continue end

    local availableTrain = get_available_train(itemRequest,
    function(train)
      return has_cargo(train, itemRequest.signal)
    end)

    if availableTrain then
      local idleStop = get_available_waiting_stop(availableTrain)
      if idleStop == nil then goto continue end

      schedule_train(availableTrain, create_unloading_schedule(stop, idleStop), stop, itemRequest.signal)
    end

    ::continue::
  end
end

local function try_schedule_loading_requests()
  for _, train in pairs(trainCache) do
    local isAvailable = is_train_available(train)
    if not isAvailable then goto continue end

    local state = get_train_state(train.id)
    if state == nil then goto continue end

    local itemType = state.itemType
    ---@cast itemType SignalID

    local maxCapacity = get_max_capacity(train, itemType)
    local currentCapacity = get_cargo_count(train, itemType)
    if currentCapacity >= maxCapacity then goto continue end

    local stop = get_available_loading_stop(itemType)
    if stop == nil then goto continue end

    local idleStop = get_available_waiting_stop(train)
    if idleStop == nil then goto continue end

    schedule_train(train, create_loading_schedule(stop, idleStop), stop, itemType)

    ::continue::
  end
end

---@param requests table<number, Signal>
function try_schedule_trains(requests)
  try_schedule_unloading_requests(requests)
  try_schedule_loading_requests()
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

      log("Train " .. event.train.id .. " is now waiting at " .. event.train.station.name .. " type: " .. stationState.type)

      if stationState.type == trainStopType.LOADING then
        update_train_state(event.train, {
          activeState = trainActiveState.LOADING
        })
      elseif stationState.type == trainStopType.UNLOADING then
        update_train_state(event.train, {
          activeState = trainActiveState.UNLOADING
        })
      elseif stationState.type == trainStopType.WAITING then
        local itemType = state.itemType
        ---@cast itemType SignalID

        -- local idleStop = get_available_waiting_stop(event.train)
        -- if idleStop == nil then return end

        schedule_train(event.train, create_idle_schedule(event.train.station), event.train.station, itemType)

        update_train_state(event.train, {
          activeState = trainActiveState.WAITING
        })
      end
    elseif event.train.state == defines.train_state.on_the_path then
      if event.train.schedule.current == #event.train.schedule.records then
        -- local itemType = state.itemType
        -- ---@cast itemType SignalID

        -- local idleStop = get_available_waiting_stop(event.train)
        -- if idleStop == nil then return end

        -- schedule_train(event.train, create_idle_schedule(idleStop), idleStop, itemType)
      end
    end
  end
)
