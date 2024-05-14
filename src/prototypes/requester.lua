---@param direction "N" | "E" | "S" | "W"
local function create_sprite(direction)
  local width = 78
  local height = 118

  if direction == "E" or direction == "W" then
    width = 118
    height = 78
  end

  return
  {
    filename = "__train_scheduler__/graphics/item-requester-" .. direction .. ".png",
    priority = "extra-high",
    width = width,
    height = height,
    shift = util.by_pixel(0, 0),
    scale = 0.3
  }
end


local function generate_item_requester()
  local combinator = generate_decider_combinator
      {
        name = "item-requester",
        type = "decider-combinator",
        icon = "__train_scheduler__/graphics/item-requester-icon.png",
        icon_size = 32,
        flags = { "placeable-neutral", "player-creation" },
        minable = { mining_time = 0.1, result = "item-requester" },
        max_health = 55,
        order = "z[zebra]",
        corpse = "small-remnants",
        collision_box = { { -0.4, -0.9 }, { 0.4, .9 } },
        selection_box = { { -.5, -1.0 }, { 0.5, 1.0 } },
        energy_source =
        {
          type = "electric",
          usage_priority = "secondary-input",
        },
        active_energy_usage = "1KW",

        activity_led_light =
        {
          intensity = 0,
          size = 1,
          color = { r = 1.0, g = 1.0, b = 1.0 }
        },

        activity_led_light_offsets =
        {
          { 0.265625, -0.53125 },
          { 0.515625, -0.078125 },
          { -0.25,    0.03125 },
          { -0.46875, -0.5 }
        },

        screen_light =
        {
          intensity = 0,
          size = 0.6,
          color = { r = 1.0, g = 1.0, b = 1.0 }
        },

        screen_light_offsets =
        {
          { 0.015625, -0.265625 },
          { 0.015625, -0.359375 },
          { 0.015625, -0.265625 },
          { 0.015625, -0.359375 }
        },

        input_connection_bounding_box = { { -0.5, 0 }, { 0.5, 1 } },
        output_connection_bounding_box = { { -0.5, -1 }, { 0.5, 0 } },

        circuit_wire_max_distance = 20,
      }

  combinator.sprites =
  {
    north = create_sprite("N"),
    east = create_sprite("E"),
    south = create_sprite("S"),
    west = create_sprite("W")
  }

  combinator.equal_symbol_sprites = nil
  combinator.not_equal_symbol_sprites = nil
  combinator.greater_or_equal_symbol_sprites = nil
  combinator.greater_symbol_sprites = nil
  combinator.less_or_equal_symbol_sprites = nil
  combinator.less_symbol_sprites = nil
  combinator.equal_symbol_sprites = nil

  return combinator
end

data:extend({
  {
    type = "recipe",
    name = "item-requester",
    enabled = true,
    ingredients =
    {
      { "electronic-circuit", 1 }
    },
    results =
    {
      { type = "item", name = "item-requester", amount = 1 }
    }
  },
  {
    type = "item",
    name = "item-requester",
    icon = "__train_scheduler__/graphics/item-requester-icon.png",
    icon_size = 32,
    subgroup = "circuit-network",
    order = "c-a",
    place_result = "item-requester",
    stack_size = 50
  },
  generate_item_requester()
})
