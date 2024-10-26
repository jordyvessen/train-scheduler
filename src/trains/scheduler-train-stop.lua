require "TrainStop"

---@type table<number, TrainStop>
local trainStopCache = { }



function get_train_stop_cache()
  return trainStopCache
end

---@param stop LuaEntity
---@return TrainStopState?
function get_train_stop_state(stop)
  return global.train_stop_state[stop.unit_number]
end

function build_train_stop_cache()
  if global.train_stop_state == nil then
    global.train_stop_state = { }
  end

  local stopEntities = get_entities("train-stop")
  for _, entity in pairs(stopEntities) do
    local state = get_train_stop_state(entity)
    if state == nil then goto continue end

    trainStopCache[entity.unit_number] = TrainStop:new(entity)

    ::continue::
  end
end

---@param stop TrainStop
---@param requester Requester
---@return boolean
local function is_stop_connected_to_requester(stop, requester)
  local redConnection = stop.control.get_circuit_network(defines.wire_type.red)
  local redConnectionId = redConnection and redConnection.network_id or nil

  local greenConnection = stop.control.get_circuit_network(defines.wire_type.green)
  local greenConnectionId = greenConnection and greenConnection.network_id or nil

  if redConnectionId == nil and greenConnectionId == nil then return false end

  local requesterRedConnection = requester.control.get_circuit_network(defines.wire_type.red, defines.circuit_connector_id.combinator_output)
  local requesterRedConnectionId = requesterRedConnection and requesterRedConnection.network_id or nil

  local requesterGreenConnection = requester.control.get_circuit_network(defines.wire_type.green, defines.circuit_connector_id.combinator_output)
  local requesterGreenConnectionId = requesterGreenConnection and requesterGreenConnection.network_id or nil

  if requesterRedConnectionId == nil and requesterGreenConnectionId == nil then return false end

  return (requesterRedConnectionId == redConnectionId and requesterRedConnectionId ~= nil) or
          (requesterGreenConnectionId == greenConnectionId and requesterGreenConnectionId ~= nil)
end

---@param requester Requester
---@return TrainStop?
function get_connected_stop_for_requester(requester)
  for _, stop in pairs(trainStopCache) do
    if is_stop_connected_to_requester(stop, requester) then
      return stop
    end
  end

  return nil
end

---@param stopType "Unloading" | "Loading" | "Waiting"
---@param request SignalID?
---@param ignoreLimit boolean?
---@param filter (fun(stop: TrainStop): boolean)?
---@return TrainStop?
local function get_stop_of_type(stopType, request, ignoreLimit, filter)
  for _, stop in pairs(trainStopCache) do
    local isOfType = stop.state.type == stopType
    local isAvailable = (#stop.entity.get_train_stop_trains() < stop.entity.trains_limit) or ignoreLimit == true
    local validItemType = request == nil or (stop.state.itemType ~= nil and stop.state.itemType.name == request.name)

    local isValid = filter == nil or filter(stop)

    if isOfType and isAvailable and validItemType and isValid then
      return stop
    end
  end

  return nil
end

---@param request SignalID
---@return TrainStop?
function get_available_loading_stop(request)
  return get_stop_of_type(TrainStopType.LOADING, request)
end

---@param request SignalID
---@param requester Requester
---@return TrainStop?
function get_available_unloading_stop(request, requester)
  return get_stop_of_type(TrainStopType.UNLOADING, request, false,
    function (stop)
      return is_stop_connected_to_requester(stop, requester)
    end)
end

---@param train LuaTrain
---@return TrainStop?
function get_available_waiting_stop(train)
  return get_stop_of_type(TrainStopType.WAITING, nil, true,
    function (stop)
      local stoppedTrain = stop.entity.get_stopped_train()
      return #stop.entity.get_train_stop_trains() < stop.entity.trains_limit or (stoppedTrain ~= nil and stoppedTrain.id == train.id)
    end)
end


---@param entity LuaEntity
function on_train_stop_created(entity)
  if entity.name ~= "train-stop" then return end

  local stop = TrainStop:new(entity)
  trainStopCache[entity.unit_number] = stop
end

---@param entity LuaEntity
function on_train_stop_removed(entity)
  if entity.name ~= "train-stop" then return end

  table.removekey(trainStopCache, entity.unit_number)
  table.removekey(global.train_stop_state, entity.unit_number)
end

---@param source LuaEntity
---@param target LuaEntity
function on_stop_settings_pasted(source, target)
  if target.name ~= "item-requester" then return end

  local sourceStop = trainStopCache[source.unit_number]
  if sourceStop == nil then return end

  local targetStop = trainStopCache[target.unit_number]
  if targetStop == nil then return end

  targetStop.updateState(sourceStop.state)
end