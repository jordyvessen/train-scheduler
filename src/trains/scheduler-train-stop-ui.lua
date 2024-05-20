require "scheduler-train-stop"

---@param player LuaPlayer
---@param trainStop LuaEntity
local function build_ui(player, trainStop)
  local state = get_train_stop_state(trainStop)

  local frame = player.gui.screen.add{
    type = "frame",
    name = "train_stop_ui",
    direction = "vertical"
  }

  local header = frame.add{
    type = "flow",
    name = "header",
    direction = "horizontal"
  }
  header.style.bottom_padding = -4
  header.style.horizontally_stretchable = true

  header.add{
    type = "label",
    name = "train_stop_id",
    caption = "Train Stop ID: " .. trainStop.unit_number
  }

  local contentTable = frame.add{
    type = "table",
    name = "content",
    column_count = 2
  }
  contentTable.style.cell_padding = 2
  contentTable.style.horizontally_stretchable = true
  contentTable.style.bottom_padding = 8

  local chooseItemTypeLabel = contentTable.add{
    type = "label",
    caption = "Choose Item:"
  }
  chooseItemTypeLabel.style.top_margin = 5

  local chooseItemType = contentTable.add{
    type = "choose-elem-button",
    name = "choose_item_type",
    elem_type = "signal"
  }
  chooseItemType.elem_value = state and state.itemType or nil

  local chooseStopTypeLabel = contentTable.add{
    type = "label",
    caption = "Choose Stop Type:"
  }

  local options = { TrainStopType.LOADING, TrainStopType.UNLOADING, TrainStopType.WAITING, TrainStopType.UNKNOWN }
  local selectedIndex = state and table.indexOf(options, state.type) or #options
  local chooseStopType = contentTable.add{
    type = "drop-down",
    name = "choose_stop_type",
    items = options,
    selected_index = selectedIndex
  }
end


---@param player LuaPlayer
---@param entity LuaEntity
function try_open_train_stop_ui(player, entity)
  if entity.name ~= "train-stop" then return end

  build_ui(player, entity)
end

---@param player LuaPlayer
---@param entity LuaEntity
function try_close_train_stop_ui(player, entity)
  if entity.name ~= "train-stop" then return end

  local activeGui = player.gui.screen.train_stop_ui
  if activeGui == nil then return end

  local selectedItemType = activeGui.content.choose_item_type.elem_value
  local selectedStopType = activeGui.content.choose_stop_type.items[activeGui.content.choose_stop_type.selected_index]

  update_train_stop_state(entity, {
    itemType = selectedItemType,
    type = selectedStopType or TrainStopType.UNKNOWN
  })

  activeGui.destroy()
end