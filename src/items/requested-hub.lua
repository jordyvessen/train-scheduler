require "util"

---@class RequestedHub
---@field entity LuaEntity
---@field control LuaConstantCombinatorControlBehavior
Hub = { }

---@param entity LuaEntity
---@return LuaConstantCombinatorControlBehavior?
local function get_hub_control(entity)
  if not entity.valid then return nil end

  local control = entity.get_or_create_control_behavior()
  if control == nil then return nil end

  ---@diagnostic disable-next-line: return-type-mismatch
  return control
end

function Hub:new(entity)
  local control = get_hub_control(entity)
  if control == nil then
    error("Could not find control behavior for entity " .. entity.unit_number .. " " .. entity.name)
  end

  return {
    entity = entity,
    control = control
  }
end

---@type table<number, RequestedHub>
local hubsCache = {}

---@return table<LuaEntity>
function get_hubs()
  return get_entities("requested-hub")
end

---@param requesterRequests table<number, Signal>
function update_hubs(requesterRequests)
  for _, hub in pairs(hubsCache) do
    local index = 1

    if hub.control.sections_count == 0 then
      hub.control.add_section()
    end

    for idx, section in pairs(hub.control.sections) do
      section.group = "Requested items " .. idx
      section.filters = {}
    end

    local section = hub.control.sections[1]
    for _, request in pairs(requesterRequests) do
      if request.count > 0 then
        local existing_entry = nil
        for _, filter in pairs(section.filters) do
          if filter.value.name == request.signal.name then
            existing_entry = filter
            break
          end
        end

        if existing_entry ~= nil then
          existing_entry.min = existing_entry.min + request.count
          existing_entry.max = existing_entry.max + request.count
          goto continue
        end

        section.set_slot(index, {
          value = {
            name = request.signal.name,
            type = request.signal.type,
            quality = "normal"
          },
          min = request.count,
          max = request.count
        })

        index = index + 1

        if index > 10 then
          hub.control.add_section()
          section = hub.control.sections[hub.control.sections_count]
          index = 1
        end

        ::continue::
      end
    end
  end
end

function build_hubs_cache()
  local hubs = get_hubs()
  for _, hub in pairs(hubs) do
    hubsCache[hub.unit_number] = Hub:new(hub)
  end
end

---@param entity LuaEntity
function on_hub_created(entity)
  if entity.name ~= "requested-hub" then return end

  hubsCache[entity.unit_number] = Hub:new(entity)
end

---@param entity LuaEntity
function on_hub_removed(entity)
  if entity.name ~= "requested-hub" then return end

  table.removekey(hubsCache, entity.unit_number)
end