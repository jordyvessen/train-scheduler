require "item-requester"
require "requested-hub"

local shouldInit = true

script.on_event(defines.events.on_tick,
  function(event)
    if shouldInit then
      build_requester_cache()
      build_hubs_cache()
      shouldInit = false
    end

    if not (event.tick % 60 == 0) then return end

    process_requesters()

    local itemRequests = get_all_item_requests()
    update_hubs(itemRequests)
  end
)

script.on_event(defines.events.on_built_entity,
  function(event)
    on_requester_created(event.created_entity)
    on_hub_created(event.created_entity)
  end
)

script.on_event(defines.events.on_robot_built_entity,
  function(event)
    on_requester_created(event.created_entity)
    on_hub_created(event.created_entity)
  end
)

script.on_event(defines.events.script_raised_built,
  function(event)
    on_requester_created(event.entity)
    on_hub_created(event.entity)
  end
)

script.on_event(defines.events.script_raised_revive,
  function(event)
    on_requester_created(event.entity)
    on_hub_created(event.entity)
  end
)

script.on_event(defines.events.on_pre_player_mined_item,
  function(event)
    on_requester_removed(event.entity)
    on_hub_removed(event.entity)
  end
)

script.on_event(defines.events.on_robot_pre_mined,
  function(event)
    on_requester_removed(event.entity)
    on_hub_removed(event.entity)
  end
)

script.on_event(defines.events.on_entity_died,
  function(event)
    on_requester_removed(event.entity)
    on_hub_removed(event.entity)
  end
)

script.on_event(defines.events.script_raised_destroy,
  function(event)
    on_requester_removed(event.entity)
    on_hub_removed(event.entity)
  end
)

-- ToDo: On chunk deleted, remove all requesters and hubs in that chunks