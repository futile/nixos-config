-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- for neovide Pog
vim.o.guifont = "FiraCode Nerd Font Mono:h12"

-- turn off relativenumbers, they make scrolling non-smooth
vim.o.relativenumber = false

-- neovide-only settings
if vim.g.neovide then
end
