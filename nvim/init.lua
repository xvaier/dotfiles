-- basic options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "number"
vim.opt.cursorline = true
vim.opt.undofile = true
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.undofile = true
vim.opt.breakindent = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true
vim.opt.timeoutlen = 300

-- highlight when yanking
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking text",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),

	callback = function()
		vim.highlight.on_yank()
	end,
})

-- copy absolute path
vim.keymap.set("n", "<leader>ya", function()
	vim.fn.setreg("+", vim.fn.expand("%:p"))
end, { desc = "Copy absolute path to clipboard" })

-- copy relative path
vim.keymap.set("n", "<leader>yr", function()
	vim.fn.setreg("+", vim.fn.expand("%:."))
end, { desc = "Copy relative path to clipboard" })

-- Copy file contents with relative path to system clipboard
vim.keymap.set("n", "<leader>yf", function()
	local relativepath = vim.fn.expand("%:.")
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	table.insert(lines, 1, relativepath)
	local content = table.concat(lines, "\n")
	vim.fn.setreg("+", content)
end, { desc = "Copy relative path and buffer contents to clipboard" })

-- Copy buffer to system clipboard
vim.keymap.set("n", "<leader>yb", function()
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local content = table.concat(lines, "\n")
	vim.fn.setreg("+", content)
end, { desc = "Copy buffer contents to clipboard" })

vim.diagnostic.config({
	virtual_text = false,
	signs = true,
	underline = true,
	update_in_insert = false,
})

vim.api.nvim_create_autocmd("LspAttach", {
	desc = "LSP actions",
	callback = function()
		vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Show hover information" })
		vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, { desc = "Expand diagnostic" })
		vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, { desc = "Go to definition" })
		vim.keymap.set("n", "<leader>gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
		vim.keymap.set("n", "<leader>gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
		vim.keymap.set("n", "<leader>go", vim.lsp.buf.type_definition, { desc = "Go to type definition" })
		vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, { desc = "Find references" })
		vim.keymap.set("n", "<leader>gs", vim.lsp.buf.signature_help, { desc = "Show signature help" })
		vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
	end,
})

-- load language server configs
-- vim.lsp.enable("lua_ls")
-- vim.lsp.enable("basedpyright")
-- vim.lsp.enable("ruff")
-- vim.lsp.enable("terraformls")
-- vim.lsp.enable("vue_ls")
-- vim.lsp.enable("ts_ls")
-- vim.lsp.enable("clangd")

-- only load plugins if we are not in vscode
if not vim.g.vscode then
	require("config.lazy")
end
