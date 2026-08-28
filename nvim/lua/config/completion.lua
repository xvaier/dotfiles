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

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("completion", { clear = true }),
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or not client:supports_method("textDocument/completion") then
      return
    end
    vim.lsp.completion.enable(true, client.id, args.buf, {
      autotrigger = true,
      convert = function(item)
        return { kind_hlgroup = kind_hl[vim.lsp.protocol.CompletionItemKind[item.kind]] }
      end,
    })
  end,
})

-- autotrigger above only fires on server trigger characters (".", ":", …);
-- also open the menu once an identifier is long enough to rank usefully — at one
-- or two characters servers return every auto-importable symbol in the environment
local min_trigger_chars = 3

vim.api.nvim_create_autocmd("InsertCharPre", {
  group = "completion",
  callback = function()
    if vim.fn.pumvisible() ~= 0 or not vim.v.char:match("[%w_]") then
      return
    end
    local before = vim.api.nvim_get_current_line():sub(1, vim.fn.col(".") - 1) .. vim.v.char
    if #before:match("[%w_]*$") < min_trigger_chars then
      return
    end
    if #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/completion" }) == 0 then
      return
    end
    vim.schedule(vim.lsp.completion.get)
  end,
})

vim.keymap.set("i", "<C-Space>", vim.lsp.completion.get, { desc = "Trigger completion" })
