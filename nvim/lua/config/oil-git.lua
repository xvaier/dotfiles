-- Git status in oil buffers: colours each entry by its status, appends a
-- symbol after the name, and dims anything git ignores.
local oil = require("oil")

local ns = vim.api.nvim_create_namespace("oil-git")

-- Directories take the highest-priority status found beneath them. Ignored
-- never bubbles up: a directory is only dimmed when git ignores it as a whole.
local statuses = {
  conflict = { hl = "OilGitConflict", symbol = "!", priority = 6 },
  deleted = { hl = "OilGitDeleted", symbol = "D", priority = 5 },
  modified = { hl = "OilGitModified", symbol = "~", priority = 4 },
  added = { hl = "OilGitAdded", symbol = "+", priority = 3 },
  renamed = { hl = "OilGitRenamed", symbol = "→", priority = 2 },
  untracked = { hl = "OilGitUntracked", symbol = "?", priority = 1 },
  ignored = { hl = "OilGitIgnored", symbol = "", priority = 0 },
}

local links = {
  OilGitConflict = "DiagnosticError",
  OilGitDeleted = "Removed",
  OilGitModified = "DiagnosticWarn",
  OilGitAdded = "Added",
  OilGitRenamed = "Statement",
  OilGitUntracked = "Constant",
  OilGitIgnored = "NonText",
}

local function define_highlights()
  for group, link in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = link, default = true })
  end
end

-- XY columns of `git status --porcelain`, see git-status(1)
local function classify(xy)
  local x, y = xy:sub(1, 1), xy:sub(2, 2)
  if xy == "??" then
    return "untracked"
  elseif xy == "!!" then
    return "ignored"
  elseif x == "U" or y == "U" or xy == "AA" or xy == "DD" then
    return "conflict"
  elseif x == "D" or y == "D" then
    return "deleted"
  elseif x == "R" or y == "R" or x == "C" or y == "C" then
    return "renamed"
  elseif x == "A" then
    return "added"
  end
  return "modified"
end

-- Parse NUL-separated porcelain output into root-relative path → status.
-- Directories git collapses (untracked, ignored) keep their trailing slash.
local function parse(stdout)
  local result = {}
  local records = vim.split(stdout, "\0", { trimempty = true })
  local i = 1
  while i <= #records do
    local status = classify(records[i]:sub(1, 2))
    result[records[i]:sub(4)] = status
    -- renames and copies are followed by a second record holding the old path
    i = i + (status == "renamed" and 2 or 1)
  end
  return result
end

-- Reduce repo-wide statuses to the entries of one directory, given its
-- root-relative prefix ("" for the repo root, "a/b/" otherwise).
local function statuses_in(all, prefix)
  local result = {}
  local inherited -- set when the whole directory sits inside a collapsed one

  for path, status in pairs(all) do
    if path:sub(-1) == "/" and prefix:sub(1, #path) == path then
      inherited = status
    elseif path:sub(1, #prefix) == prefix then
      local name = path:sub(#prefix + 1):match("^[^/]+")
      local is_own = path == prefix .. name or path == prefix .. name .. "/"
      local current = result[name]
      if
        (is_own or status ~= "ignored") and (not current or statuses[status].priority > statuses[current].priority)
      then
        result[name] = status
      end
    end
  end

  return result, inherited
end

local function decorate(buf, by_name, inherited)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

  for lnum, line in ipairs(lines) do
    local entry = oil.get_entry_on_line(buf, lnum)
    local status = entry and entry.name ~= ".." and (by_name[entry.name] or inherited)
    if status then
      local spec = statuses[status]
      -- the name follows the hidden id column and the icon
      local start = line:find(entry.name, line:find(" ") or 1, true)
      if start then
        vim.api.nvim_buf_set_extmark(buf, ns, lnum - 1, start - 1, {
          end_col = #line,
          hl_group = spec.hl,
          priority = 5000,
          virt_text = spec.symbol ~= "" and { { " " .. spec.symbol, spec.hl } } or nil,
          virt_text_pos = "eol",
        })
      end
    end
  end
end

local function git(dir, args, on_done)
  local cmd = vim.list_extend({ "git" }, args)
  vim.system(
    cmd,
    { cwd = dir },
    vim.schedule_wrap(function(result)
      on_done(result.code == 0 and result.stdout or nil)
    end)
  )
end

local function refresh(buf)
  local dir = vim.api.nvim_buf_is_valid(buf) and oil.get_current_dir(buf)
  if not dir or vim.fn.isdirectory(dir) == 0 then
    return
  end
  local tick = vim.api.nvim_buf_get_changedtick(buf)
  local function is_stale()
    return not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_buf_get_changedtick(buf) ~= tick
  end

  -- porcelain paths are relative to the repo root, so find where this dir sits
  git(dir, { "rev-parse", "--show-prefix" }, function(prefix)
    if not prefix then
      return -- not a git repo
    end
    if is_stale() then
      return
    end
    -- the pathspec limits the scan to this directory, which keeps large repos fast
    git(dir, { "status", "--porcelain=v1", "-z", "--ignored", "--", "." }, function(stdout)
      if stdout and not is_stale() then
        decorate(buf, statuses_in(parse(stdout), vim.trim(prefix)))
      end
    end)
  end)
end

-- Opening a buffer fires several events in a row; collapse them into one run.
local timers = {}
local function schedule(buf)
  if not timers[buf] then
    timers[buf] = vim.uv.new_timer()
  end
  timers[buf]:start(
    30,
    0,
    vim.schedule_wrap(function()
      refresh(buf)
    end)
  )
end

local function refresh_visible()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "oil" then
      schedule(buf)
    end
  end
end

define_highlights()

local group = vim.api.nvim_create_augroup("oil-git", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = define_highlights })

-- oil rewrites the buffer on every render, which fires TextChanged
vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged" }, {
  group = group,
  pattern = "oil://*",
  callback = function(ev)
    schedule(ev.buf)
  end,
})
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "OilEnter",
  callback = function(ev)
    schedule(ev.data.buf)
  end,
})

-- status can change behind our back: saving a file, lazygit in a terminal,
-- or anything done while the editor wasn't focused
vim.api.nvim_create_autocmd({ "BufWritePost", "TermClose", "FocusGained" }, {
  group = group,
  callback = refresh_visible,
})

vim.api.nvim_create_autocmd("BufWipeout", {
  group = group,
  pattern = "oil://*",
  callback = function(ev)
    if timers[ev.buf] then
      timers[ev.buf]:close()
      timers[ev.buf] = nil
    end
  end,
})
