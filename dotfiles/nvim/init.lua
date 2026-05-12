-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

local ok, nm = pcall(require, "noctalia-matugen")
if ok then
  nm.setup()
end
