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

---@param t table
---@param filterIter fun(value: any, key: any, t: table): boolean
table.filter = function(t, filterIter)
  local out = { }

  for k, v in pairs(t) do
    if filterIter(v, k, t) then
      table.insert(out, v)
    end
  end

  return out
end

---@param t table
---@param value any
---@return number?
table.indexOf = function(t, value)
  for i, v in ipairs(t) do
    if v == value then
      return i
    end
  end

  return nil
end

---@param t table
---@param value any
table.addIfNotExists = function(t, key, value)
  if t[key] == nil then
    t[key] = value
  end

  return t[key]
end

---@param parentName string
---@param child LuaGuiElement
---@return boolean
function is_child_of(parentName, child)
  local parent = child.parent

  if parent == nil then
    return false
  end

  if parent.name == parentName then
    return true
  end

  return is_child_of(parentName, parent)
end

---@param name string
---@param func fun(): any
---@param profiler LuaProfiler?
---@param logIfValueEquals any?
---@return any
function execute_timed(name, func, profiler, logIfValueEquals)
  if profiler == nil then
    profiler = game.create_profiler(true)
    profiler.reset()
  end

  profiler.restart()
  local result = func()

  profiler.stop()

  if logIfValueEquals == nil or result == logIfValueEquals then
    log{"__1__ took __2__", name, profiler}
  end


  return result
end