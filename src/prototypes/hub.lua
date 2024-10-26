---@param direction "N" | "E" | "S" | "W"
local function create_sprite(direction)
  local width = 90
  local height = 120

  if direction == "E" or direction == "W" then
    width = 120
    height = 90
  end

  return
  {
    filename = "__train_scheduler__/graphics/requested-hub/requested-hub-" .. direction .. ".png",
    priority = "extra-high",
    width = width,
    height = height,
    shift = util.by_pixel(0, 0),
    scale = 0.2
  }
end

local function generate_requested_hub()
  local combinator = generate_constant_combinator
  {
    name = "requested-hub",
    type = "constant-combinator",
    icon = "__train_scheduler__/graphics/requested-hub/requested-hub-icon.png",
    icon_size = 32,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.1, result = "requested-hub" },
    max_health = 55,
    corpse = "constant-combinator-remnants",
    dying_explosion = "constant-combinator-explosion",
    collision_box = {{-0.35, -0.35}, {0.35, 0.35}},
    selection_box = {{-0.5, -0.5}, {0.5, 0.5}},
    item_slot_count = 50,
    activity_led_light =
    {
      intensity = 0,
      size = 1,
      color = {r = 1.0, g = 1.0, b = 1.0}
    },

    activity_led_light_offsets =
    {
      {0.296875, -0.40625},
      {0.25, -0.03125},
      {-0.296875, -0.078125},
      {-0.21875, -0.46875}
    },

    circuit_wire_max_distance = 20
  }

  combinator.sprites =
  {
    north = create_sprite("N"),
    east = create_sprite("E"),
    south = create_sprite("S"),
    west = create_sprite("W")
  }

  return combinator
end

data:extend({
  {
    type = "recipe",
    name = "requested-hub",
    enabled = true,
    ingredients = {
      {
        name = "constant-combinator",
        type = "item",
        amount = 1
      },
      {
        name = "advanced-circuit",
        type = "item",
        amount = 1
      },
      {
        name = "processing-unit",
        type = "item",
        amount = 1
      }
    },
    results =
    {
      { type = "item", name = "requested-hub", amount = 1 }
    }
  },
  {
    type = "item",
    name = "requested-hub",
    icon = "__train_scheduler__/graphics/requested-hub/requested-hub-icon.png",
    icon_size = 32,
    subgroup = "circuit-network",
    order = "b[combinators]-c[constant-combinator]",
    place_result = "requested-hub",
    stack_size = 50
  },
  generate_requested_hub()
})