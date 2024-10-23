-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- based on https://github.com/ornicar/dotfiles/blob/crom/nvim/lua/config/keymaps.lua
-- and https://www.lazyvim.org/configuration/general
local function map(mode, lhs, rhs, opts)
  local keys = require("lazy.core.handler").handlers.keys
  ---@cast keys LazyKeysHandler
  -- do not create the keymap if a lazy keys handler exists
  if not keys.active[keys.parse({ lhs, mode = mode }).id] then
    opts = opts or {}
    opts.silent = opts.silent ~= false
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

-- Add empty lines before and after cursor line
map("n", "[<space>", "<Cmd>call append(line('.') - 1, repeat([''], v:count1))<CR>", { desc = "Put empty line above" })
map("n", "]<space>", "<Cmd>call append(line('.'),     repeat([''], v:count1))<CR>", { desc = "Put empty line below" })

-- Fix M-Space with Neo + Darwin
if vim.loop.os_uname().sysname == "Darwin" then
  map({ "i", "v", "n", "o", "c", "t" }, "<M-Space>", "<Space>")

  -- From https://neovide.dev/faq.html#how-can-i-use-cmd-ccmd-v-to-copy-and-paste
  if vim.g.neovide then
    map({ "i", "v", "n", "o", "c", "t" }, "<D-Left>", "^")
    map({ "i", "v", "n", "o", "c", "t" }, "<D-Right>", "$")
  end
end
