---@param name string
---@return LuaEntity[]
function get_entities(name)
  ---@type LuaEntity[]
  local entities = {}
  for _, surface in pairs(game.surfaces) do
    local requesters = surface.find_entities_filtered { name = name }
    for _, requester in pairs(requesters) do
      table.insert(entities, requester)
    end
  end

  return entities
end

---@param table table
---@param key any
function table.removekey(table, key)
  local element = table[key]
  table[key] = nil
  return element
end

---@param table table
function table.print(table)
  for key, value in pairs(table) do
    log(key .. ": " .. serpent.block(value))
  end
end