-- Define the monitor output names
local monitor1 = "eDP-1"
local monitor2 = "DP-1"

-- Monitor Setup --------------------------------------------------------------
hl.monitor({
  output = monitor1,
  mode = "1920x1080@60.00",
  position = "auto",
  scale = 1,
})

hl.monitor({
  output = monitor2,
  mode = "1920x1080@60.00",
  position = "auto-center-up",
  transform = 0,
  scale = 1,
})


-- ----------------------------------------------------------------------------
-- when the external monitor gets connected
hl.on("monitor.added", function(monitor)
  if monitor.name == monitor2 then
    hl.notification.create({ text = "External monitor attached: " .. monitor.name, timeout = 4000 })

    -- Workspace binding
    -- Bind workspaces 1 to 5 to Monitor 1
    for w = 1, 5 do
      hl.workspace_rule({
        workspace = tostring(w),
        monitor = monitor1,
        default = (w == 1) -- Makes workspace 1 the default on boot
      })
    end

    -- Bind workspaces 6 to 10 to Monitor 2
    for w = 6, 10 do
      hl.workspace_rule({
        workspace = tostring(w),
        monitor = monitor2,
        default = (w == 6) -- Makes workspace 6 the default on boot
      })
    end

    hl.exec_scheduled_prop_refresh_immediately()
  end
end)

-- when the external monitor gets disconnected
hl.on("monitor.removed", function(monitor)
  if monitor.name == monitor2 then
    hl.notification.create({ text = "External monitor REMOVED: " .. monitor.name, timeout = 4000 })
    -- Workspace binding
    -- Bind workspaces 1 to 10 to Monitor 1
    for w = 1, 10 do
      hl.workspace_rule({
        workspace = tostring(w),
        monitor = monitor1,
        default = (w == 1) -- Makes workspace 1 the default on boot
      })
    end
    hl.exec_scheduled_prop_refresh_immediately()
  end
end)

-- ----------------------------------------------------------------------------
-- Monitor 2 rotation toggle
local is_rotated = false

local function toggle_monitor_rotation()
  is_rotated = not is_rotated

  -- Choose 1 (90° portrait) or 0 (normal landscape)
  local new_transform = is_rotated and 1 or 0

  -- Re-apply the monitor config instantly with the new transform value
  hl.monitor({
    output = monitor2,
    transform = new_transform
  })
end

-- Bind the toggle to SUPER + R (Mod4 + R)
hl.bind("SUPER + R", toggle_monitor_rotation)
-- ----------------------------------------------------------------------------
