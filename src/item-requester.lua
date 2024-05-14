require "util"

---@type table<number, LuaEntity>>
local requesterCache = {}

---@return LuaEntity[]
function get_item_requesters()
  return get_entities("item-requester")
end

---@param entity LuaEntity
---@param updatedProperties table<string, any>
function update_requester_state(entity, updatedProperties)
  if not entity.valid then return end

  if global.requester_state == nil then
    global.requester_state = {}
  end

  if global.requester_state[entity.unit_number] == nil then
    global.requester_state[entity.unit_number] = {}
  end

  for key, value in pairs(updatedProperties) do
    global.requester_state[entity.unit_number][key] = value
  end

  log("Updated requester state for entity " ..
    entity.name ..
    " (" .. entity.unit_number .. ")" .. " to " .. serpent.block(global.requester_state[entity.unit_number]))
end

---@param entity LuaEntity
---@return table<"target" | "lowerLimit" | "itemsRequested", number | boolean>?
local function get_requester_state(entity)
  if global.requester_state == nil then return nil end
  return global.requester_state[entity.unit_number]
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

---@param requester LuaEntity
---@return table<string, Signal>?
function get_merged_input_signals(requester)
  if not requester.valid then return nil end

  local control = get_item_requester_control(requester)
  if control == nil then return nil end

  local greenInputSignals = control.get_circuit_network(defines.wire_type.green,
    defines.circuit_connector_id.combinator_input)
  local redInputSignals = control.get_circuit_network(defines.wire_type.red,
    defines.circuit_connector_id.combinator_input)

  ---@type table<string, Signal>
  local mergedInputSignals = {}

  if greenInputSignals and greenInputSignals.signals then
    for _, signal in pairs(greenInputSignals.signals) do
      mergedInputSignals[signal.signal.name] = signal
    end
  end

  if redInputSignals and redInputSignals.signals then
    for _, signal in pairs(redInputSignals.signals) do
      if mergedInputSignals[signal.signal.name] then
        mergedInputSignals[signal.signal.name].count = mergedInputSignals[signal.signal.name].count + signal.count
      else
        mergedInputSignals[signal.signal.name] = signal
      end
    end
  end

  return mergedInputSignals
end

---@return table<string, Signal>
function get_all_item_requests()
  ---@type table<string, Signal>
  local requests = {}

  for _, requester in pairs(requesterCache) do
    if not requester.valid then goto continue end

    local control = get_item_requester_control(requester)
    if control == nil then goto continue end

    local inputSignals = get_merged_input_signals(requester)
    if inputSignals == nil then goto continue end

    local state = get_requester_state(requester)
    if state == nil then goto continue end

    for _, signal in pairs(inputSignals) do
      if state.itemsRequested then
        requests[signal.signal.name] = {
          signal = signal.signal,
          count = state.target - signal.count
        }
      end
    end

    ::continue::
  end

  return requests
end

function process_requesters()
  for _, requester in pairs(requesterCache) do
    if not requester.valid then goto continue end

    local control = get_item_requester_control(requester)
    if control == nil then goto continue end

    local inputSignals = get_merged_input_signals(requester)
    if inputSignals == nil then goto continue end

    local state = get_requester_state(requester)
    if state == nil then goto continue end

    for _, signal in pairs(inputSignals) do
      if signal.count < state.lowerLimit and not state.itemsRequested then
        update_requester_state(requester, {
          itemsRequested = true
        })
      elseif signal.count >= state.target and state.itemsRequested then
        update_requester_state(requester, {
          itemsRequested = false
        })
      end
    end

    ::continue::
  end
end

local function validate_requester_state()
  for unitNumber, _ in pairs(global.requester_state) do
    if not requesterCache[unitNumber] then
      table.removekey(global.requester_state, unitNumber)
    end
  end
end

function build_requester_cache()
  local requesters = get_item_requesters()
  for _, requester in pairs(requesters) do
    local control = get_item_requester_control(requester)
    if control == nil then goto continue end

    requesterCache[requester.unit_number] = requester

    local state = get_requester_state(requester)
    if state ~= nil then goto continue end

    update_requester_state(requester, {
      lowerLimit = control.parameters.constant,
      target = control.parameters.constant * 2,
      itemsRequested = false
    })

    ::continue::
  end

  validate_requester_state()
end

---@param entity LuaEntity
function on_requester_created(entity)
  if entity.name ~= "item-requester" then return end

  local control = get_item_requester_control(entity)
  if control == nil then return end

  control.parameters = {
    comparator = "≤",
    first_signal =
    {
      type = "virtual",
      name = "signal-everything"
    },
    constant = 25000,

    output_signal =
    {
      type = "virtual",
      name = "signal-green",
    },
    copy_count_from_input = false
  }

  requesterCache[entity.unit_number] = entity
  update_requester_state(entity, {
    lowerLimit = control.parameters.constant,
    target = control.parameters.constant * 2,
    itemsRequested = false
  })

  log("Created requester. " .. entity.unit_number ..
      " Cache: " .. serpent.block(requesterCache) ..
      " State: " .. serpent.block(global.requester_state))
end

---@param entity LuaEntity
function on_requester_removed(entity)
  if entity.name ~= "item-requester" then return end

  table.removekey(requesterCache, entity.unit_number)
  table.removekey(global.requester_state, entity.unit_number)

  log("Removing requester. " .. entity.unit_number ..
      " Cache: " .. serpent.block(requesterCache) ..
      " State: " .. serpent.block(global.requester_state))
end
