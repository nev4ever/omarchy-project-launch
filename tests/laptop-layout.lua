local apply = dofile("lib/laptop-layout.lua")
local windows = {
  { address = "run", stable_id = 1, mapped = true, floating = true, workspace = 1, initial_title = "run" },
  { address = "codex", stable_id = 2, mapped = true, workspace = 1, initial_title = "test-codex" },
  { address = "nvim", stable_id = 3, mapped = true, workspace = 1, initial_title = "nvim" },
  { address = "other", stable_id = 4, mapped = true, workspace = 6 },
  { address = "unmapped", stable_id = 5, mapped = false, workspace = 1 },
  { address = "pinned", stable_id = 6, mapped = true, pinned = true, workspace = 1 },
}
local additions = 0
local function make_group(window)
  local group = { members = { window }, locked = false }
  function group:add(member)
    assert(not self.locked)
    additions = additions + 1
    table.insert(self.members, member)
    member.group = self
  end
  function group:remove(member)
    for index, entry in ipairs(self.members) do
      if entry == member then table.remove(self.members, index); break end
    end
    member.group = nil
  end
  window.group = group
end

hl = {
  get_workspace_windows = function(workspace)
    local result = {}
    for _, window in ipairs(windows) do
      if tostring(window.workspace) == workspace then table.insert(result, window) end
    end
    return result
  end,
  dsp = {
    window = {
      float = function(options) return { "float", options } end,
      fullscreen_state = function(options) return { "fullscreen", options } end,
    },
    group = {
      toggle = function(options) return { "toggle", options } end,
      lock = function(options) return { "lock", options } end,
      active = function(options) return { "active", options } end,
    },
  },
  dispatch = function(action)
    local kind, options = action[1], action[2]
    local window = options.window
    assert(window.workspace <= 5, "Touched a protected workspace")
    if kind == "toggle" then make_group(window)
    elseif kind == "float" then window.floating = false
    elseif kind == "lock" then window.group.locked = options.action == "enable"
    elseif kind == "active" then window.group.current = window.group.members[options.index]
    end
  end,
}

make_group(windows[1]) -- An application may already have opened in a group.
assert(apply(1, "test-codex") == "Grouped 3 windows on workspace 1")
local group = windows[2].group
assert(#group.members == 3)
assert(group.current == windows[2], "Codex should be selected")
assert(group.locked, "Later unrelated windows should not join the group")
assert(not windows[1].floating)
assert(not windows[4].group and not windows[5].group and not windows[6].group)
local before = additions
apply(1, "test-codex")
assert(additions == before, "Repeated application must not duplicate tabs")
assert(apply(2, "") == "No windows on workspace 2")
assert(not pcall(apply, 6, ""), "Workspace 6 must be protected")
print("Lua grouping checks passed")
