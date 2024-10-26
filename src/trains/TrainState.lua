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
---@field getItemTypeName fun(): string
---@field getItemType fun(): string
TrainState = {}

---@param trainId number
---@return TrainState?
function get_train_state(trainId)
  if global.train_state == nil then return nil end
  return global.train_state[trainId]
end

function TrainState:new()
  local s = {
    autoSchedulingEnabled = false,
    activeState = trainActiveState.WAITING,
    itemType = nil
  }

  function s.getItemTypeName()
    ---@type SignalID?
    local itemType = s.itemType

    if itemType == nil then return "None" end
    return itemType.name
  end

  function s.getItemType()
    ---@type SignalID?
    local itemType = s.itemType

    if itemType == nil then return "None" end

    return itemType.type
  end

  setmetatable(s, self)
  self.__index = self
  return s
end
