require "scheduler-train-stop"

---@param station string
---@return TrainScheduleRecord
local function create_loading_record(station)
  ---@type TrainScheduleRecord
  return {
    station = station,
    wait_conditions = {
      {
        type = "full",
        compare_type = "or"
      }
    }
  }
end

---@param station string
local function create_wait_record(station)
  ---@type TrainScheduleRecord
  return {
    station = station,
    wait_conditions = {
      {
        type = "time",
        compare_type = "or",
        ticks = 60 * 5
      }
    }
  }
end

---@param station string
local function create_unloading_record(station)
  ---@type TrainScheduleRecord
  return {
    station = station,
    wait_conditions = {
      {
        type = "empty",
        compare_type = "or"
      },
      {
        type = "circuit",
        compare_type = "or",
        condition = {
          first_signal = {
            type = "virtual",
            name = "signal-green"
          },
          constant = 0,
          comparator = "="
        }
      }
    }
  }
end

---@param train LuaTrain
---@param station string
---@return TrainSchedule?
function create_unloading_schedule(train, station)
  ---@type TrainSchedule
  local schedule = {
    records = {},
    current = 1
  }

  table.insert(schedule.records, create_unloading_record(station))

  local idleStation = get_available_waiting_stop(train)
  if idleStation == nil then return nil end

  table.insert(schedule.records, create_wait_record(idleStation.entity.backer_name))

  return schedule
end

---@param train LuaTrain
---@param station string
---@return TrainSchedule?
function create_loading_schedule(train, station)
  ---@type TrainSchedule
  local schedule = {
    records = {},
    current = 1
  }

  table.insert(schedule.records, create_loading_record(station))

  local idleStation = get_available_waiting_stop(train)
  if idleStation == nil then return nil end

  table.insert(schedule.records, create_wait_record(idleStation.entity.backer_name))

  return schedule
end

---@param station string
---@return TrainSchedule?
function create_idle_schedule(station)
  ---@type TrainSchedule
  local schedule = {
    records = {},
    current = 1
  }

  table.insert(schedule.records, create_wait_record(station))

  return schedule
end