-- Start a repo's dev services in one window, one labelled pane each.
--
-- Services are listed in .rex-services at the repo root, one per line:
--
--   web: npm run dev
--   # comments and blank lines are ignored
--
-- A worktree without its own file uses the main checkout's. Keep the file out
-- of git with .git/info/exclude. bin/service-run reports each service's state
-- to Rex and offers a restart when it exits, and agents can read a service's
-- output with `rex capture -b NAME`.

local term = require("terminal")

local function git(cwd, ...)
  local r = rex.exec({ "git", ... }, { cwd = cwd })
  if r and r.ok then return (r.stdout:gsub("%s+$", "")) end
end

local function read_services(path)
  local f = io.open(path)
  if not f then return nil end
  local services = {}
  for line in f:lines() do
    local name, command = line:match("^%s*([%w_.-]+)%s*:%s*(.-)%s*$")
    if name and command ~= "" then
      table.insert(services, { name = name, command = command })
    end
  end
  f:close()
  return services
end

local function find_services(cwd)
  local root = git(cwd, "rev-parse", "--show-toplevel")
  if not root then return nil, nil, "not in a git repository: " .. cwd end
  local common = git(cwd, "rev-parse", "--path-format=absolute", "--git-common-dir")
  local main = common and (common:gsub("/%.git$", ""))
  for _, dir in ipairs({ root, main }) do
    local services = read_services(dir .. "/.rex-services")
    if services then return root, services end
  end
  return nil, nil, "no .rex-services in " .. root
end

-- Panes stacked top to bottom, each the same height
local function stack(panes, i)
  i = i or 1
  if i == #panes then return panes[i] end
  return rex.layout.vertical(1 / (#panes - i + 1), panes[i], stack(panes, i + 1))
end

local function find_window(label)
  local view = rex.session.view{}
  for _, w in ipairs(view and view.windows or {}) do
    if w.label == label then return w.window_id end
  end
end

rex.action{
  name  = "services_start",
  title = "Start Dev Services",
  run   = function(ctx)
    local root, services, err = find_services(term.foreground(ctx.block_id).cwd or os.getenv("HOME"))
    if not root then error(err, 0) end
    if #services == 0 then error("no services listed in .rex-services", 0) end

    local label = "services: " .. root:match("([^/]+)$")
    local existing = find_window(label)
    if existing then
      rex.session.focus_window{ window_id = existing }
      return
    end

    local panes = {}
    for _, s in ipairs(services) do
      table.insert(panes, rex.layout.block{
        flavor  = term.shell,
        label   = s.name,
        options = {
          command = { term.bin .. "service-run", s.name, s.command },
          cwd     = root,
        },
      })
    end

    local _, werr = rex.session.new_window{
      window_label = label,
      focus        = true,
      layout       = stack(panes),
    }
    if werr ~= nil then error(werr, 0) end
  end,
}

rex.bind("ctrl+space>d", "services_start")
