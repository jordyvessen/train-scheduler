trainActiveState = {
  WAITING = "Waiting",
  SCHEDULED = "Scheduled",
  LOADING = "Loading",
  UNLOADING = "Unloading"
}

---@class TrainState
---@field autoSchedulingEnabled boolean
---@field activeState string
---@field itemType SignalID?
TrainState = {}

---@param trainId number
---@return TrainState?
function get_train_state(trainId)
  if storage.train_state == nil then return nil end
  return storage.train_state[trainId]
end

function TrainState:new()
  local s = {
    autoSchedulingEnabled = false,
    activeState = trainActiveState.WAITING,
    itemType = nil
  }

  setmetatable(s, self)
  self.__index = self
  return s
end

---@param s TrainState
function getItemTypeName(s)
  ---@type SignalID?
  local itemType = s.itemType

  if itemType == nil then return "None" end
  return itemType.name
end

---@param s TrainState
function getItemType(s)
  ---@type SignalID?
  local itemType = s.itemType

  if itemType == nil then return "None" end
  if itemType.type == "fluid" then 
    return "fluid"
  end

  return "item"
end