-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- for neovide Pog
if vim.loop.os_gethostname() == "H77QF74G0F" then
  vim.o.guifont = "FiraCode Nerd Font Mono:h14"
else
  vim.o.guifont = "FiraCode Nerd Font Mono:h12"
end

-- turn off relativenumbers, they make scrolling non-smooth
vim.o.relativenumber = false

-- try out Snacks!
vim.g.lazyvim_picker = "snacks"

vim.filetype.add({
  extension = {
    ["edge-plan"] = "json5",
    -- this is not correct 🙃
    -- ["edge-test"] = "json5",
  },
})

-- neovide-only settings
if vim.g.neovide then
end
