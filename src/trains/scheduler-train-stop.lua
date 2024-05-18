---@type table<number, LuaEntity>
local trainStopCache = { }

trainStopType = {
  UNLOADING = "Unloading",
  LOADING = "Loading",
  WAITING = "Waiting",
  UNKNOWN = "Unknown"
}

function get_train_stop_cache()
  return trainStopCache
end

---@class TrainStopState
---@field type "Unloading" | "Loading" | "Waiting" | "Unknown"
---@field itemType SignalID?
TrainStopState = { }

---@param s table?
function TrainStopState:new(s)
  s = s or {}
  setmetatable(s, self)
  self.__index = self
  return s
end

---@param stop LuaEntity
---@return TrainStopState?
function get_train_stop_state(stop)
  return global.train_stop_state[stop.unit_number]
end

---@param stop LuaEntity
---@param newState table
function update_train_stop_state(stop, newState)
  if not stop.valid then return end

  if global.train_stop_state[stop.unit_number] == nil then
    global.train_stop_state[stop.unit_number] = TrainStopState:new { }
  end

  for key, value in pairs(newState) do
    global.train_stop_state[stop.unit_number][key] = value
  end

  log("Updated train stop state for entity " ..
      " (" .. stop.unit_number .. ")" .. " to " .. serpent.block(global.train_stop_state[stop.unit_number]))
end

function build_train_stop_cache()
  if global.train_stop_state == nil then
    global.train_stop_state = { }
  end

  local stops = get_entities("train-stop")
  for _, stop in pairs(stops) do
    local state = get_train_stop_state(stop)
    if state == nil then goto continue end

    trainStopCache[stop.unit_number] = stop

    ::continue::
  end
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

---@param requester LuaEntity
---@return LuaEntity?
function get_connected_stop_for_requester(requester)
  for _, stop in pairs(trainStopCache) do
    if is_stop_connected_to_requester(stop, requester) then
      return stop
    end
  end

  return nil
end

---@param stop LuaEntity
---@return "Unloading" | "Loading" | "Waiting" | "Unknown"
function get_stop_type(stop)
  local state = get_train_stop_state(stop)
  return state and state.type or trainStopType.UNKNOWN
end

---@param stopType "Unloading" | "Loading" | "Waiting"
---@param request SignalID?
---@param ignoreLimit boolean?
---@param filter (fun(stop: LuaEntity): boolean)?
---@return LuaEntity?
local function get_stop_of_type(stopType, request, ignoreLimit, filter)

  ---@type LuaEntity[]
  local availableStops = table.filter(trainStopCache, function(stop)
    local state = get_train_stop_state(stop)
    if state == nil then return false end

    local isOfType = state.type == stopType
    local isAvailable = (#stop.get_train_stop_trains() < stop.trains_limit) or ignoreLimit == true
    local validItemType = request == nil or (state.itemType ~= nil and state.itemType.name == request.name)

    local isValid = filter == nil or filter(stop)

    return isOfType and isAvailable and validItemType and isValid
  end)

  if #availableStops > 0 then return availableStops[1] end

  return nil
end

---@param request SignalID
---@return LuaEntity?
function get_available_loading_stop(request)
  return get_stop_of_type(trainStopType.LOADING, request)
end

---@param request SignalID
---@param requester LuaEntity
---@return LuaEntity?
function get_available_unloading_stop(request, requester)
  return get_stop_of_type(trainStopType.UNLOADING, request, false,
    function (stop)
      return is_stop_connected_to_requester(stop, requester)
    end)
end

---@param train LuaTrain
---@return LuaEntity?
function get_available_waiting_stop(train)
  return get_stop_of_type(trainStopType.WAITING, nil, true,
    function (stop)
      local stoppedTrain = stop.get_stopped_train()
      return #stop.get_train_stop_trains() < stop.trains_limit or (stoppedTrain ~= nil and stoppedTrain.id == train.id)
    end)
end


---@param entity LuaEntity
function on_train_stop_created(entity)
  if entity.name ~= "train-stop" then return end

  entity.trains_limit = 1
  trainStopCache[entity.unit_number] = entity
  update_train_stop_state(entity, {
    type = trainStopType.UNKNOWN,
    itemType = nil
  })
end

---@param entity LuaEntity
function on_train_stop_removed(entity)
  if entity.name ~= "train-stop" then return end

  table.removekey(trainStopCache, entity.unit_number)
  table.removekey(global.train_stop_state, entity.unit_number)
end