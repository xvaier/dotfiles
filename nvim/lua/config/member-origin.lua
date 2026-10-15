-- works out which class in a receiver's type hierarchy defines each member, using only
-- standard LSP requests, since completion items don't say where a member comes from

local M = {}

local timeout_ms = 300
local max_classes = 10

-- documentSymbol results for files outside the workspace, which don't change
local library_symbols = {}

local function in_workspace(client, uri)
  local path = vim.uri_to_fname(uri)
  if path:find("/site-packages/", 1, true) or path:find("/node_modules/", 1, true) then
    return false
  end
  local roots = vim.tbl_map(function(folder)
    return vim.uri_to_fname(folder.uri)
  end, client.workspace_folders or {})
  if #roots == 0 and client.root_dir then
    roots = { client.root_dir }
  end
  return vim.iter(roots):any(function(root)
    return vim.fs.relpath(root, path) ~= nil
  end)
end

local function is_open(client, uri)
  for bufnr in pairs(client.attached_buffers) do
    if vim.uri_from_bufnr(bufnr) == uri then
      return true
    end
  end
  return false
end

local function contains(range, pos)
  local s, e = range.start, range["end"]
  return (pos.line > s.line or (pos.line == s.line and pos.character >= s.character))
    and (pos.line < e.line or (pos.line == e.line and pos.character <= e.character))
end

local function find_symbol(symbols, pos)
  for _, sym in ipairs(symbols) do
    if contains(sym.selectionRange, pos) then
      return sym
    end
    if sym.children and contains(sym.range, pos) then
      local found = find_symbol(sym.children, pos)
      if found then
        return found
      end
    end
  end
end

--- Resolves the class of the expression ending at `position` and calls `on_done` with
--- `{ [member] = { class, depth, tier } }`, or nil when it can't tell (not a class, timeout).
function M.resolve(client, bufnr, position, on_done)
  local has_hierarchy = client:supports_method("textDocument/prepareTypeHierarchy")
  local finished = false
  local pending = 0
  local opened = {}
  local seen = {}
  local classes = {}

  local function build()
    if #classes == 0 then
      return nil
    end
    table.sort(classes, function(a, b)
      if a.depth ~= b.depth then
        return a.depth < b.depth
      end
      return a.path < b.path
    end)
    local origins = {}
    for _, class in ipairs(classes) do
      local tier = class.depth == 0 and "own" or class.library and "library" or "inherited"
      for _, name in ipairs(class.members) do
        origins[name] = origins[name] or { class = class.name, depth = class.depth, tier = tier }
      end
    end
    return origins
  end

  local function finish(result)
    if finished then
      return
    end
    finished = true
    for uri in pairs(opened) do
      client:notify("textDocument/didClose", { textDocument = { uri = uri } })
    end
    on_done(result)
  end

  local function request(method, params, callback, retries)
    retries = retries or 2
    pending = pending + 1
    local ok = client:request(method, params, function(err, result)
      pending = pending - 1
      if finished then
        return
      end
      -- opening a base file can invalidate requests already in flight; the spec says retry
      if err and err.code == vim.lsp.protocol.ErrorCodes.ContentModified and retries > 0 then
        return request(method, params, callback, retries - 1)
      end
      if not err then
        callback(result)
      end
      if pending == 0 then
        finish(build())
      end
    end, bufnr)
    if not ok then
      pending = pending - 1
    end
  end

  -- documentSymbol and prepareTypeHierarchy only answer for files open in the session
  local function ensure_open(uri)
    if opened[uri] or is_open(client, uri) then
      return
    end
    local path = vim.uri_to_fname(uri)
    local file = io.open(path)
    if not file then
      return
    end
    local text = file:read("*a")
    file:close()
    client:notify("textDocument/didOpen", {
      textDocument = { uri = uri, languageId = vim.filetype.match({ filename = path }) or "", version = 0, text = text },
    })
    opened[uri] = true
  end

  local function symbols(uri, library, callback)
    local cache_key = client.id .. ":" .. uri
    if library and library_symbols[cache_key] then
      return callback(library_symbols[cache_key])
    end
    ensure_open(uri)
    request("textDocument/documentSymbol", { textDocument = { uri = uri } }, function(result)
      result = result or {}
      if library then
        library_symbols[cache_key] = result
      end
      callback(result)
    end)
  end

  -- `path` orders classes at the same depth by their position in each supertypes list
  local function visit(item, depth, path)
    local pos = item.selectionRange.start
    local key = ("%s:%d:%d"):format(item.uri, pos.line, pos.character)
    if seen[key] or #classes >= max_classes then
      return
    end
    seen[key] = true
    local class =
      { name = item.name, depth = depth, path = path, library = not in_workspace(client, item.uri), members = {} }
    table.insert(classes, class)
    symbols(item.uri, class.library, function(result)
      local symbol = find_symbol(result, pos)
      class.name = class.name or (symbol and symbol.name)
      for _, child in ipairs(symbol and symbol.children or {}) do
        table.insert(class.members, child.name)
      end
    end)
    if has_hierarchy then
      request("typeHierarchy/supertypes", { item = item }, function(supers)
        for i, super in ipairs(supers or {}) do
          visit(super, depth + 1, path .. ("%03d"):format(i))
        end
      end)
    end
  end

  vim.defer_fn(function()
    finish(nil)
  end, timeout_ms)

  local params = { textDocument = { uri = vim.uri_from_bufnr(bufnr) }, position = position }
  request("textDocument/typeDefinition", params, function(result)
    -- Location | Location[] | LocationLink[]
    local target = result and (result[1] or result)
    local uri = target and (target.targetUri or target.uri)
    if not uri then
      return
    end
    local range = target.targetSelectionRange or target.range
    if not has_hierarchy then
      return visit({ uri = uri, selectionRange = range }, 0, "")
    end
    ensure_open(uri)
    local hierarchy_params = { textDocument = { uri = uri }, position = range.start }
    request("textDocument/prepareTypeHierarchy", hierarchy_params, function(items)
      if items and items[1] then
        visit(items[1], 0, "")
      end
    end)
  end)
end

return M
