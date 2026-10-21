-- Use Hyprland's native tabbed groups without changing the launch list.
-- This is evaluated once after launch; no persistent window rules are installed.
return function(workspace, preferred_title)
  assert(type(workspace) == "number" and workspace >= 1 and workspace <= 5,
    "Project layouts are restricted to workspaces 1 through 5")

  local windows = {}
  for _, window in ipairs(hl.get_workspace_windows(tostring(workspace))) do
    if window.mapped and not window.pinned then
      table.insert(windows, window)
    end
  end
  if #windows == 0 then
    return "No windows on workspace " .. workspace
  end
  table.sort(windows, function(a, b) return a.stable_id < b.stable_id end)

  local primary = windows[1]
  for _, window in ipairs(windows) do
    if preferred_title ~= "" and window.initial_title == preferred_title then
      primary = window
      break
    end
  end

  -- Supporting apps may request floating mode. Keep the main windows tiled
  -- so the resulting group uses the whole available workspace.
  for _, window in ipairs(windows) do
    hl.dispatch(hl.dsp.window.fullscreen_state({
      window = window, internal = 0, client = 0, action = "set",
    }))
    hl.dispatch(hl.dsp.window.float({ window = window, action = "disable" }))
  end

  if not primary.group then
    hl.dispatch(hl.dsp.group.toggle({ window = primary }))
  end
  local group = assert(primary.group, "Could not create a window group")
  hl.dispatch(hl.dsp.group.lock({ window = primary, action = "disable" }))
  for _, window in ipairs(windows) do
    local member = false
    for _, grouped_window in ipairs(group.members) do
      if grouped_window.address == window.address then
        member = true
        break
      end
    end
    if not member then
      if window.group then
        window.group:remove(window)
      end
      group:add(window)
    end
  end
  for index, window in ipairs(group.members) do
    if window.address == primary.address then
      hl.dispatch(hl.dsp.group.active({ window = primary, index = index }))
      break
    end
  end
  -- Prevent unrelated windows opened later from joining a project group.
  hl.dispatch(hl.dsp.group.lock({ window = primary, action = "enable" }))
  return string.format("Grouped %d windows on workspace %d", #windows, workspace)
end
