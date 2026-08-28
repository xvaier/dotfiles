-- disable Python provider — neovim searches for pynvim on every Python file open, taking ~20s
vim.g.loaded_python3_provider = 0

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true
vim.opt.undofile = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
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
vim.opt.grepprg = "rg --vimgrep --smart-case"
