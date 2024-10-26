---@class TrainStopState
---@field type "Unloading" | "Loading" | "Waiting" | "Unknown"
---@field itemType SignalID?

---@class TrainStop
---@field entity LuaEntity
---@field control LuaTrainStopControlBehavior
---@field state TrainStopState
---@field updateState fun(newState: table): nil
---@field isValid fun(): boolean
TrainStop = { }

TrainStopType = {
  UNLOADING = "Unloading",
  LOADING = "Loading",
  WAITING = "Waiting",
  UNKNOWN = "Unknown"
}

---@param entity LuaEntity
---@param state TrainStopState
---@return string
local function create_stop_name(entity, state)
  
  if state.type == TrainStopType.UNKNOWN then
    return "Train stop" .. " (" .. entity.unit_number .. ")"

  elseif state.type == TrainStopType.WAITING then
    return state.type .. " (" .. entity.unit_number .. ")"
  end

  return state.type .. " " .. state.itemType.name .. " (" .. entity.unit_number .. ")"
end

---@param stop TrainStop
---@param newState table
local function update_state(stop, newState)
  if not stop.isValid() then return end

  for key, value in pairs(newState) do
    stop.state[key] = value
  end

  global.train_stop_state[stop.entity.unit_number] = stop.state

  log("Updated train stop state for entity " ..
      " (" .. stop.entity.unit_number .. ")" .. " to " .. serpent.block(stop.state))
end

---@param entity LuaEntity
---@return LuaTrainStopControlBehavior?
local function get_train_stop_control(entity)
  if not entity.valid then return nil end

  local control = entity.get_or_create_control_behavior()
  if control == nil then return nil end

  ---@diagnostic disable-next-line: return-type-mismatch
  return control
end

---@param entity LuaEntity
---@return TrainStop
function TrainStop:new(entity)
  local control = get_train_stop_control(entity)
  if control == nil then 
    error("Could not find control behavior for entity " .. entity.unit_number .. " " .. entity.name)
  end

  local initialState = global.train_stop_state[entity.unit_number] or {
    type = TrainStopType.UNKNOWN,
    itemType = nil
  }

  if entity.trains_limit == nil and initialState.type ~= TrainStopType.UNKNOWN then
    entity.trains_limit = 1
  end

  entity.backer_name = create_stop_name(entity, initialState)

  local stop = {
    entity = entity,
    control = control,
    state = initialState,
    isValid = function()
      return entity.valid
    end
  }

  stop.updateState = function(newState)
    update_state(stop, newState)
    entity.backer_name = create_stop_name(entity, stop.state)
  end

  global.train_stop_state[entity.unit_number] = stop.state

  setmetatable(stop, self)
  self.__index = self
  return stop
end