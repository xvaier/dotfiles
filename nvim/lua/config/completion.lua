-- native LSP completion: trigger while typing identifiers, color menu kinds
-- (nvim only autotriggers on server triggerCharacters and leaves kinds unhighlighted)

-- nosort keeps fuzzy filtering but restores the server's sortText ordering,
-- which "fuzzy" alone discards (in-scope symbols before auto-imports)
vim.opt.completeopt = { "menuone", "noselect", "popup", "fuzzy", "nosort" }
vim.opt.pummaxwidth = 60

local kind_hl = {
  Text = "String",
  Method = "Function",
  Function = "Function",
  Constructor = "Function",
  Field = "Identifier",
  Variable = "Identifier",
  Property = "Identifier",
  Class = "Type",
  Interface = "Type",
  Struct = "Type",
  Enum = "Type",
  TypeParameter = "Type",
  EnumMember = "Constant",
  Constant = "Constant",
  Module = "Include",
  Unit = "Number",
  Value = "Number",
  Keyword = "Keyword",
  Snippet = "Special",
  Reference = "Special",
  Event = "Special",
  File = "Directory",
  Folder = "Directory",
  Operator = "Operator",
  -- Color intentionally absent: nvim renders its own swatch
}

-- member completions ("x.") are sorted and coloured by the class that defines them
local origin = require("config.member-origin")

local tiers = {
  own = { rank = 1, hl = "CompletionOwn", link = "Identifier" },
  inherited = { rank = 2, hl = "CompletionInherited", link = "Type" },
  library = { rank = 3, hl = "CompletionLibrary", link = "Comment" },
  unlabelled = { rank = 4, hl = "CompletionUnlabelled", link = "Comment" },
}

local function define_highlights()
  for _, tier in pairs(tiers) do
    vim.api.nvim_set_hl(0, tier.hl, { link = tier.link, default = true })
  end
end
define_highlights()
vim.api.nvim_create_autocmd("ColorScheme", { callback = define_highlights })

-- the member access being completed ("buf:row:dot_col") and which class defines each member
local member_key, member_origins

local function origin_of(item)
  local found = member_origins and member_origins[item.label]
  return found, tiers[found and found.tier or "unlabelled"]
end

local function is_deprecated(item)
  return item.deprecated or vim.list_contains(item.tags or {}, vim.lsp.protocol.CompletionTag.Deprecated)
end

local function convert(item)
  local converted = { kind_hlgroup = kind_hl[vim.lsp.protocol.CompletionItemKind[item.kind]] }
  if not member_origins then
    return converted
  end
  local found, tier = origin_of(item)
  if found then
    local detail = vim.tbl_get(item, "labelDetails", "description") or item.detail or ""
    converted.menu = found.class .. " · " .. detail
  end
  if not is_deprecated(item) then
    converted.abbr_hlgroup = tier.hl
  end
  return converted
end

local function sort_key(entry)
  local item = vim.tbl_get(entry, "user_data", "nvim", "lsp", "completion_item") or {}
  local found, tier = origin_of(item)
  return tier.rank, found and found.depth or 0, item.sortText or item.label or entry.word
end

local function compare(a, b)
  local rank_a, depth_a, text_a = sort_key(a)
  local rank_b, depth_b, text_b = sort_key(b)
  if rank_a ~= rank_b then
    return rank_a < rank_b
  end
  if depth_a ~= depth_b then
    return depth_a < depth_b
  end
  return text_a < text_b
end

-- clients whose "." trigger is handled below, after resolving the receiver's class
local dot_clients = {}

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("completion", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or not client:supports_method("textDocument/completion") then
      return
    end
    local triggers = vim.tbl_get(client.server_capabilities, "completionProvider", "triggerCharacters") or {}
    if vim.list_contains(triggers, ".") then
      dot_clients[client.id] = true
      client.server_capabilities.completionProvider.triggerCharacters = vim.tbl_filter(function(char)
        return char ~= "."
      end, triggers)
    end
    vim.lsp.completion.enable(true, client.id, args.buf, {
      autotrigger = true,
      convert = convert,
      cmp = compare,
    })
  end,
})

-- opens the menu, first resolving member origins when `before` ends in "receiver." or "receiver.partial"
local function complete(before, opts)
  local function open()
    vim.lsp.completion.get(opts)
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local row = vim.fn.line(".")
  local dot = before:match("()%.[%w_]*$")
  local key = dot and dot > 1 and ("%d:%d:%d"):format(bufnr, row, dot) or nil
  if key == member_key then
    return vim.schedule(open)
  end

  member_key, member_origins = nil, nil
  local client = key and vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/typeDefinition" })[1]
  if not client then
    return vim.schedule(open)
  end
  local position = { line = row - 1, character = vim.str_utfindex(before, client.offset_encoding, dot - 2, false) }
  origin.resolve(client, bufnr, position, function(origins)
    member_key, member_origins = key, origins
    if vim.api.nvim_get_current_buf() == bufnr and vim.api.nvim_get_mode().mode:match("^i") then
      open()
    end
  end)
end

local function line_before_cursor()
  return vim.api.nvim_get_current_line():sub(1, vim.fn.col(".") - 1)
end

local dot_trigger =
  { ctx = { triggerKind = vim.lsp.protocol.CompletionTriggerKind.TriggerCharacter, triggerCharacter = "." } }

-- autotrigger above only fires on the servers' other trigger characters;
-- also open the menu once an identifier is long enough to rank usefully — at one
-- or two characters servers return every auto-importable symbol in the environment
local min_trigger_chars = 3

vim.api.nvim_create_autocmd("InsertCharPre", {
  group = "completion",
  callback = function()
    if vim.fn.pumvisible() ~= 0 then
      return
    end
    local char = vim.v.char
    local clients = vim.lsp.get_clients({ bufnr = 0, method = "textDocument/completion" })
    local before = line_before_cursor() .. char
    if char == "." then
      if vim.iter(clients):any(function(c)
        return dot_clients[c.id]
      end) then
        complete(before, dot_trigger)
      end
    elseif char:match("[%w_]") and #before:match("[%w_]*$") >= min_trigger_chars and #clients > 0 then
      complete(before)
    end
  end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
  group = "completion",
  callback = function()
    member_key, member_origins = nil, nil
  end,
})

vim.keymap.set("i", "<C-Space>", function()
  complete(line_before_cursor())
end, { desc = "Trigger completion" })
