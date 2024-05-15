require "item-requester"


local function add_slider(parent, name, caption, value)
  parent.add({
    type = "label",
    name = name .. "_label",
    caption = caption
  })

  local sliderContainer = parent.add({
    type = "flow",
    name = name,
    direction = "horizontal"
  })

  local slider = sliderContainer.add({
    type = "slider",
    name = name,
    allow_negative = false,
    minimum_value = 0,
    maximum_value = 100000,
    caption = caption,
    style="notched_slider",
    value_step = 5000,
    ---@cast value number
    value = value
  })

  sliderContainer.add({
    type = "label",
    name = name.. "_value",
    caption = value
  })

  return slider
end


---@param player LuaPlayer
---@param entity LuaEntity
local function open_item_requester_ui(player, entity)
  local state = get_requester_state(entity)

  local gui = player.gui.left
  local frame = gui.add({
    type = "frame",
    name = "item_requester_ui",
    caption = "Item Requester #" .. entity.unit_number,
    vertical_centering = true
  })
  frame.style.top_margin = 8
  frame.style.minimal_width = 200

  local table = frame.add({
    type = "table",
    name = "content",
    column_count = 2
  })
  table.style.cell_padding = 2
  table.style.horizontally_stretchable = true
  table.style.bottom_padding = 8

  table.add({
    type = "label",
    caption = "Item type"
  })

  local chooseItemType = table.add({
    type = "choose-elem-button",
    name = "item_requester_choose_item_type",
    elem_type = "signal"
  })
  local itemType = state and state.itemType or nil
  ---@cast itemType SignalID
  chooseItemType.elem_value = itemType

  add_slider(table, "item_requester_target_slider", "Target Quantity", state and state.target or 0)
  add_slider(table, "item_requester_lower_limit_slider", "Lower Limit", state and state.lowerLimit or 0)
end

---@param player LuaPlayer
local function close_item_requester_ui(player)
  local gui = player.gui.left
  if gui.item_requester_ui == nil then return end

  gui.item_requester_ui.destroy()
end

---@param player LuaPlayer
---@param entity LuaEntity
function try_open_item_requester_ui(player, entity)
  if entity.name ~= "item-requester" then return end

  open_item_requester_ui(player, entity)
end

---@param player LuaPlayer
---@param entity LuaEntity
function try_close_item_requester_ui(player, entity)
  local activeGui = player.gui.left.item_requester_ui
  if activeGui == nil then return end

  local itemType = activeGui.content.item_requester_choose_item_type.elem_value
  local target = activeGui.content.item_requester_target_slider.item_requester_target_slider.slider_value
  local lowerLimit = activeGui.content.item_requester_lower_limit_slider.item_requester_lower_limit_slider.slider_value

  update_requester_state(entity, {
    ---@cast itemType SignalID
    itemType = itemType,
    target = target,
    lowerLimit = lowerLimit
  })

  close_item_requester_ui(player)
end

---@param player LuaPlayer
---@param element LuaGuiElement
function on_requester_ui_value_changed(player, element)
  local gui = player.gui.left
  if gui.item_requester_ui == nil then return end

  gui = gui.item_requester_ui

  if element.name == "item_requester_target_slider" then
    local value = element.slider_value
    local slider = gui.content.item_requester_target_slider
    slider.item_requester_target_slider_value.caption = value
  end

  if element.name == "item_requester_lower_limit_slider" then
    local value = element.slider_value
    local slider = gui.content.item_requester_lower_limit_slider
    slider.item_requester_lower_limit_slider_value.caption = value
  end
end