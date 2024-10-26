require "util"
require "Requester"

---@type table<number, Requester>>
local requesterCache = {}

---@return LuaEntity[]
function get_item_requesters()
  return get_entities("item-requester")
end

function get_requester_cache()
  return requesterCache
end

---@param entity LuaEntity
---@return Requester?
function get_requester(entity)
  return requesterCache[entity.unit_number]
end

---@param requester Requester
---@return table<string, Signal>?
function get_merged_input_signals(requester)
  if not requester.isValid() then return nil end

  local greenInputSignals = requester.control.get_circuit_network(defines.wire_connector_id.circuit_green)
  local redInputSignals = requester.control.get_circuit_network(defines.wire_connector_id.circuit_red)

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

---@param requester Requester
---@return Signal?
local function get_signal_for_request_type(requester)
  if requester.state.itemType == nil then return nil end

  local defaultSignal = {
    signal = requester.state.itemType,
    count = 0
  }

  local inputSignals = get_merged_input_signals(requester)
  if inputSignals == nil then return defaultSignal end

  for signalName, signal in pairs(inputSignals) do
    if requester.state.itemType.name == signalName then
      return signal
    end
  end

  return defaultSignal
end

---@return table<number, Signal>
function process_requesters()
  ---@type table<number, Signal>
  local requests = {}

  for _, requester in pairs(requesterCache) do
    if not requester.isValid() then goto continue end

    local signal = get_signal_for_request_type(requester)
    if signal == nil then goto continue end

    local state = requester.state
    if signal.count < state.lowerLimit and not state.itemsRequested then
      requester.updateState({
        itemsRequested = true
      })
    elseif signal.count >= state.target and state.itemsRequested then
      requester.updateState({
        itemsRequested = false
      })
    end

    if state.itemsRequested then
      requests[requester.entity.unit_number] = {
        signal = state.itemType,
        count = state.target - signal.count
      }
    end

    ::continue::
  end

  return requests
end

local function validate_requester_state()
  if storage.requester_state == nil then
    storage.requester_state = {}
  end

  for unitNumber, _ in pairs(storage.requester_state) do
    if not requesterCache[unitNumber] then
      table.removekey(storage.requester_state, unitNumber)
    end
  end
end

function build_requester_cache()
  local requesterEntity = get_item_requesters()
  for _, entity in pairs(requesterEntity) do
    requesterCache[entity.unit_number] = Requester:new(entity)
  end

  validate_requester_state()
end

---@param entity LuaEntity
function on_requester_created(entity)
  if entity.name ~= "item-requester" then return end

  local requester = Requester:new(entity)
  requesterCache[entity.unit_number] = requester

  log("Created requester. " .. entity.unit_number ..
      " Cache: " .. serpent.block(requesterCache) ..
      " State: " .. serpent.block(requester.state))
end

---@param entity LuaEntity
function on_requester_removed(entity)
  if entity.name ~= "item-requester" then return end

  table.removekey(requesterCache, entity.unit_number)
  table.removekey(storage.requester_state, entity.unit_number)

  log("Removing requester. " .. entity.unit_number ..
      " Cache: " .. serpent.block(requesterCache) ..
      " State: " .. serpent.block(storage.requester_state))
end

---@param source LuaEntity
---@param target LuaEntity
function on_requester_settings_pasted(source, target)
  if target.name ~= "item-requester" then return end

  local sourceRequester = get_requester(source)
  if sourceRequester == nil then return end

  local targetRequester = get_requester(target)
  if targetRequester == nil then return end

  targetRequester.updateState(sourceRequester.state)
end