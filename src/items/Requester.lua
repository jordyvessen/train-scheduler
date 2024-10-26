---@diagnostic disable: missing-fields
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
---@field updateControlParameters fun(updatedParameters: DeciderCombinatorParameters): nil
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

  control.parameters = newParameters
end

---@param requester Requester
---@param updatedProperties table<"target" | "lowerLimit" | "itemsRequested" | "itemType", number | boolean | SignalID>
local function update_state(requester, updatedProperties)
  if storage.requester_state == nil then
    storage.requester_state = {}
  end

  if storage.requester_state[requester.entity.unit_number] == nil then
    storage.requester_state[requester.entity.unit_number] = {}
  end

  local updatedValues = {}
  for key, value in pairs(updatedProperties) do
    local currentValue = requester.state[key]

    if currentValue ~= value then
      requester.state[key] = value
      updatedValues[key] = value

      local condition = requester.control.get_condition(1)

      if key == "target" and condition ~= nil then
        condition.constant = value

        ---@cast value number
        update_control_parameters(requester.control, {
          conditions = { condition }
        })

      elseif key == "itemType" and condition ~= nil then
        condition.first_signal = value

        ---@cast value SignalID
        update_control_parameters(requester.control, {
          conditions = { condition }
        })
      elseif key == "itemsRequested" then
        update_control_parameters(requester.control, {
          outputs = { }
        })

        if value == true then
          requester.control.add_output({
            signal = { name = "signal-green", type = "virtual" },
            copy_count_from_input = false
          }, 1)
        end
      end
    end
  end

  log("Updated requester state for entity " ..
      " (" .. requester.entity.unit_number .. ")" .. " with values " .. serpent.block(updatedValues) .. " to "
      .. serpent.block(requester.state))

  storage.requester_state[requester.entity.unit_number] = requester.state
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

  local initialState = storage.requester_state[entity.unit_number]
  if initialState == nil then
    local condition = {
      first_signal = { name = "signal-everything", type = "virtual" },
      comparator = "<",
      constant = 50000
    }
    control.add_condition(condition, 1)

    initialState = {
      target = condition.constant * 2,
      lowerLimit = condition.constant,
      itemsRequested = false,
      itemType = condition.first_signal
    }
  end

  local r = {
    entity = entity,
    control = control,
    state = initialState,
    isValid = function () return entity.valid end,
    updateControlParameters = function (updatedParameters)
      return update_control_parameters(control, updatedParameters)
    end
  }

  r.updateState = function (newState)
    return update_state(r, newState)
  end

  update_control_parameters(control, {
    constant = r.state.target,
    first_signal = r.state.itemType
  })

  storage.requester_state[entity.unit_number] = r.state

  setmetatable(r, self)
  self.__index = self
  return r
end