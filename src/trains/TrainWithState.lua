require "TrainState"

---@class TrainWithState
---@field id number
---@field luaTrain LuaTrain
---@field state TrainState
---@field isValid fun(): boolean
---@field updateState fun(newState: table<"itemType" | "autoSchedulingEnabled" | "activeState", SignalID | boolean | string>): nil
---@field getFuelCount fun(): number
---@field getCargoCount fun(): number
---@field getMaxCapacity fun(): number
---@field hasCargo fun(request: SignalID): boolean
TrainWithState = {}

---@param train TrainWithState
---@param newState table<"itemType" | "autoSchedulingEnabled" | "activeState", SignalID | boolean | string>
local function update_state(train, newState)
  if not train.isValid() then return end

  for key, value in pairs(newState) do
    train.state[key] = value
  end

  global.train_state[train.id] = train.state
end

---@param train TrainWithState
---@param signal SignalID
---@return number
local function get_cargo_count(train, signal)
  if signal.type == "item" then
    return train.luaTrain.get_item_count(signal.name)
  elseif signal.type == "fluid" then
    return train.luaTrain.get_fluid_count(signal.name)
  end

  return 0
end

---@param train TrainWithState
---@return number
local function get_max_capacity(train)
  ---@type LuaItemPrototype
  local item = game.item_prototypes[train.state.getItemTypeName()]
  local trainItemType = train.state.getItemType()
  stackSize = item ~= nil and item.stack_size or stackSize

  local total = 0
  for _, carriage in pairs(train.luaTrain.carriages) do
    if carriage.name == "cargo-wagon" and trainItemType == "item" then
      local inventorySize = carriage.prototype.get_inventory_size(defines.inventory.cargo_wagon)
      if inventorySize ~= nil then
        total = total + (inventorySize * (stackSize or 1))
      end

    elseif carriage.name == "fluid-wagon" and trainItemType == "fluid" then
      total = total + carriage.prototype.fluid_capacity
    end
  end

  return total
end

---@param train TrainWithState
---@return number
local function get_fuel_count(train)
  local total = 0
  for _, locomotive in pairs(train.luaTrain.locomotives.front_movers) do
    total = total + locomotive.get_fuel_inventory().get_item_count()
  end

  for _, locomotive in pairs(train.luaTrain.locomotives.back_movers) do
    total = total + locomotive.get_fuel_inventory().get_item_count()
  end

  return total
end

---@param train TrainWithState
---@param request SignalID
---@return boolean
local function has_cargo(train, request)
  return get_cargo_count(train, request) > 0
end

---@param train LuaTrain
---@param initialState table?
function TrainWithState:new(train, initialState)
  local t = {
    id = train.id,
    luaTrain = train,
    state = TrainState:new()
  }

  function t.updateState(newState)
    update_state(t, newState)
  end

  function t.isValid()
    return t.luaTrain.valid
  end

  function t.getFuelCount()
    return get_fuel_count(t)
  end

  function t.getCargoCount()
    return get_cargo_count(t, t.state.itemType)
  end

  function t.getMaxCapacity()
    return get_max_capacity(t)
  end

  function t.hasCargo(request)
    return has_cargo(t, request)
  end

  t.updateState(initialState)
  setmetatable(t, self)
  self.__index = self
  return t
end


