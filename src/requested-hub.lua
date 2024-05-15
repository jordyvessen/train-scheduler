require "util"

---@type table<number, LuaEntity>
local hubsCache = {}

---@return table<LuaEntity>
function get_hubs()
  return get_entities("requested-hub")
end

---@param entity LuaEntity
---@return LuaConstantCombinatorControlBehavior?
local function get_hub_control(entity)
  if not entity.valid then return nil end

  local control = entity.get_or_create_control_behavior()
  if control == nil then return nil end

  ---@diagnostic disable-next-line: return-type-mismatch
  return control
end

---@param requesterRequests table<number, Signal>
function update_hubs(requesterRequests)
  for _, hub in pairs(hubsCache) do
    local control = get_hub_control(hub)
    if control == nil then return end

    local index = 1
    local indexedRequests = {}
    for _, request in pairs(requesterRequests) do
      if request.count > 0 then
        table.insert(indexedRequests, {
          index = index,
          signal = request.signal,
          count = request.count
        })

        index = index + 1
      end
    end

    control.parameters = nil
    control.parameters = indexedRequests
  end
end

function build_hubs_cache()
  local hubs = get_hubs()
  for _, hub in pairs(hubs) do
    hubsCache[hub.unit_number] = hub
  end
end

---@param entity LuaEntity
function on_hub_created(entity)
  if entity.name ~= "requested-hub" then return end

  hubsCache[entity.unit_number] = entity
end

---@param entity LuaEntity
function on_hub_removed(entity)
  if entity.name ~= "requested-hub" then return end

  table.removekey(hubsCache, entity.unit_number)
end