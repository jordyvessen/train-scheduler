require "item-requester"

---@param player LuaPlayer
---@param entity LuaEntity
local function open_item_requester_ui(player, entity)
  local gui = player.gui.left

  gui.add({
    type = "frame",
    name = "item_requester_ui",
    caption = "Item Requester",
    position = { 0, 50 },
    vertical_centering = true
  })

  local sliderValue = 0
  if global.requester_state and global.requester_state[entity.unit_number] then
    sliderValue = global.requester_state[entity.unit_number].target
  end

  gui.item_requester_ui.add({
    type = "slider",
    name = "item_requester_slider",
    allow_negative = false,
    minimum_value = 0,
    maximum_value = 100000,
    caption = "Request Amount",
    style="notched_slider",
    value_step = 1000,
    value = sliderValue
  })

  gui.item_requester_ui.add({
    type = "textfield",
    name = "item_requester_textfield",
    text = "0",
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
    lose_focus_on_confirm = true,
    enabled = false
  })

  gui.item_requester_ui.item_requester_textfield.style.maximal_width = 100
end

---@param player LuaPlayer
local function close_item_requester_ui(player)
  local gui = player.gui.left
  if gui.item_requester_ui == nil then return end

  gui.item_requester_ui.destroy()
end

script.on_event(defines.events.on_gui_opened,
  function(event)
    if event.entity == nil then return end
    if event.entity.name ~= "item-requester" then return end

    local player = game.players[event.player_index]
    if player == nil then return end

    open_item_requester_ui(player, event.entity)
  end
)

script.on_event(defines.events.on_gui_closed,
  function(event)
    if event.entity == nil then return end
    if event.entity.name ~= "item-requester" then return end

    local player = game.players[event.player_index]
    if player == nil then return end

    local sliderValue = player.gui.left.item_requester_ui.item_requester_slider.slider_value
    update_requester_state(event.entity, {
      target = sliderValue
    })

    close_item_requester_ui(player)
  end
)