---@class RequesterState
---@field target number
---@field lowerLimit number
---@field itemsRequested boolean
---@field itemType SignalID?

---@class Requester
---@field entity LuaEntity
---@field control LuaDeciderCombinatorControlBehavior
---@field state RequesterState
---@field updateState fun(newState: table): nil
---@field isValid fun(): boolean

---@param control LuaDeciderCombinatorControlBehavior
---@param updatedParameters DeciderCombinatorParameters
local function update_control_parameters(control, updatedParameters)
  ---@type DeciderCombinatorParameters
  local newParameters = { }

  for key, value in pairs(control.parameters) do
    newParameters[key] = value
  end

  for key, value in pairs(updatedParameters) do
    newParameters[key] = value
  end

  log("Updated control parameters with values " .. serpent.block(updatedParameters) .. " to " .. serpent.block(newParameters))

  control.parameters = newParameters
end

---@param requester Requester
---@param updatedProperties table<"target" | "lowerLimit" | "itemsRequested" | "itemType", number | boolean | SignalID>
local function update_state(requester, updatedProperties)
  if global.requester_state == nil then
    global.requester_state = {}
  end

  if global.requester_state[requester.entity.unit_number] == nil then
    global.requester_state[requester.entity.unit_number] = {}
  end

  local updatedValues = {}
  for key, value in pairs(updatedProperties) do
    local currentValue = requester.state[key]

    if currentValue ~= value then
      requester.state[key] = value
      updatedValues[key] = value

      if key == "target" then
        ---@cast value number
        update_control_parameters(requester.control, {
          constant = value
        })

      elseif key == "itemType" then
        ---@cast value SignalID
        update_control_parameters(requester.control, {
          first_signal = value
        })
      end
    end
  end

  log("Updated requester state for entity " ..
      " (" .. requester.entity.unit_number .. ")" .. " with values " .. serpent.block(updatedValues) .. " to "
      .. serpent.block(requester.state))

  log(serpent.block(requester.control.parameters))

  global.requester_state[requester.entity.unit_number] = requester.state
  return requester.state
end

---@param entity LuaEntity
---@return LuaDeciderCombinatorControlBehavior?
function get_item_requester_control(entity)
  if not entity.valid then return nil end

  local control = entity.get_or_create_control_behavior()
  if control == nil then return nil end

  ---@diagnostic disable-next-line: return-type-mismatch
  return control
end

Requester = {}
function Requester:new(entity)
  local control = get_item_requester_control(entity)
  if control == nil then
    error("Could not find control behavior for entity " .. entity.unit_number .. " " .. entity.name)
  end

  control.parameters = {
    comparator = "<",
    constant = 50000,
    output_signal = {
      type = "virtual",
      name = "signal-green"
    },
    copy_count_from_input = false
  }

  local initialState = global.requester_state[entity.unit_number]
  if initialState == nil then
    initialState = {
      target = control.parameters.constant * 2,
      lowerLimit = control.parameters.constant,
      itemsRequested = false,
      itemType = control.parameters.first_signal
    }
  end

  local r = {
    entity = entity,
    control = control,
    state = initialState,
    isValid = function () return entity.valid end
  }

  r.updateState = function (newState)
    return update_state(r, newState)
  end

  update_control_parameters(control, {
    constant = r.state.target,
    first_signal = r.state.itemType
  })

  global.requester_state[entity.unit_number] = r.state

  setmetatable(r, self)
  self.__index = self
  return r
end