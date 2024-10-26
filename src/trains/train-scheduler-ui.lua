require "train-scheduler"

---@param player LuaPlayer
---@param trainId number
local function build_train_ui(player, trainId)
  local state = get_train_state(trainId)

  local frame = player.gui.screen.add {
    type = "frame",
    name = "train_scheduler",
    direction = "vertical"
  }

  local header = frame.add {
    type = "flow",
    name = "header",
    direction = "horizontal"
  }
  header.style.bottom_padding = -4
  header.style.horizontally_stretchable = true

  header.add {
    type = "label",
    name = "train_id",
    caption = "Train ID: " .. trainId
  }

  local content = frame.add {
    type = "frame",
    name = "content",
    direction = "vertical"
  }
  content.style.top_margin = 8

  local table = content.add {
    type = "table",
    name = "layout",
    column_count = 2
  }
  table.style.cell_padding = 2
  table.style.horizontally_stretchable = true
  table.style.bottom_padding = 8

  local chooseItemTypeLabel = table.add({
    type = "label",
    caption = "Choose Item:"
  })
  chooseItemTypeLabel.style.top_margin = 5

  local chooseItemType = table.add({
    type = "choose-elem-button",
    name = "train_scheduler.choose_item_type",
    elem_type = "signal"
  })
  local itemType = state and state.itemType or nil

  ---@cast itemType SignalID
  chooseItemType.elem_value = itemType

  local enableAutoSchedulingLabel = table.add({
    type = "label",
    caption = "Enable Auto-Scheduling:"
  })
  enableAutoSchedulingLabel.style.top_margin = 5


  local autoSchedulingEnabled = state and state.autoSchedulingEnabled or false
  local enableAutoScheduling = table.add({
    type = "checkbox",
    name = "train_scheduler.enable_auto_scheduling",

    ---@cast autoSchedulingEnabled boolean
    state = autoSchedulingEnabled
  })
end

---@param player LuaPlayer
---@param entity LuaEntity
function try_close_train_ui(player, entity)
  if entity.name ~= "locomotive" then return end

  storage.activeGuiTrainId = nil
  local activeTrainGui = player.gui.screen.train_scheduler
  if activeTrainGui == nil then return end

  activeTrainGui.destroy()
end

---@param player LuaPlayer
---@param entity LuaEntity
function try_open_train_ui(player, entity)
  if entity.name ~= "locomotive" then return end

  local trainId = entity.train.id
  storage.activeGuiTrainId = trainId

  build_train_ui(player, trainId)
end

---@param player LuaPlayer
---@param element LuaGuiElement
function on_train_ui_elem_changed(player, element)
  if not storage.activeGuiTrainId then return end

  local train = game.train_manager.get_train_by_id(storage.activeGuiTrainId)
  if train == nil then return end

  if element.name == "train_scheduler.choose_item_type" then
    local selected = element.elem_value
    ---@cast selected SignalID

    local cache = get_train_cache()
    local trainWithState = cache[storage.activeGuiTrainId] or TrainWithState:new(train)

    trainWithState.updateState({
      itemType = selected
    })

    table.addIfNotExists(cache, train.id, trainWithState)
  end
end

script.on_event(defines.events.on_gui_checked_state_changed,
  function(event)
    local player = game.get_player(event.player_index)
    if player == nil then return end

    local element = event.element
    if element == nil then return end

    if not storage.activeGuiTrainId then return end

    local train = game.train_manager.get_train_by_id(storage.activeGuiTrainId)
    if train == nil then return end

    if element.name == "train_scheduler.enable_auto_scheduling" then
      local cache = get_train_cache()
      local trainWithState = cache[storage.activeGuiTrainId] or TrainWithState:new(train)

      trainWithState.updateState({
        autoSchedulingEnabled = element.state,
        activeState = trainActiveState.WAITING
      })

      table.addIfNotExists(cache, train.id, trainWithState)
    end
  end
)