return {
  -- set my current colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      -- evergreen <3
      -- colorscheme = "nordic",
      -- colorscheme = "everforest",
      -- colorscheme = "rose-pine-moon",
      colorscheme = "astrolight",
    },
  },

  -- -- Grouped Colorschemes below --

  -- these I haven't tried out/sorted yet
  -- < none atm. >

  -- most fav (but probably not always lol)
  -- (somewhat ordered from most to least liked)

  -- https://github.com/rose-pine/neovim
  { "rose-pine/neovim" },

  -- https://github.com/sainnhe/everforest
  { "sainnhe/everforest" },

  -- ok, but doesn't quite do it
  {
    "2nthony/vitesse.nvim",
    dependencies = {
      "tjdevries/colorbuddy.nvim",
    },
  },

  -- catppuccin-{mocha,macchiato}

  -- https://github.com/rmehri01/onenord.nvim
  { "rmehri01/onenord.nvim" },

  -- these work well with (lazy-nvim) :D

  -- https://github.com/AlexvZyl/nordic.nvim
  { "AlexvZyl/nordic.nvim" },

  -- https://github.com/rebelot/kanagawa.nvim
  { "rebelot/kanagawa.nvim" },

  -- are okay-ish, but the others are better.

  -- https://github.com/cocopon/iceberg.vim
  { "cocopon/iceberg.vim" },

  -- Ok, but not my thing (atm)
  {
    "AstroNvim/astrotheme",
    opts = {},
  },

  -- look good with (lazy-)nvim, but I just don't like them :(

  -- https://github.com/mcchrish/zenbones.nvim
  -- { "mcchrish/zenbones.nvim",
  --   dependencies = {
  --     "rktjmp/lush.nvim",
  --   },
  -- },
  --
  -- https://github.com/ellisonleao/gruvbox.nvim
  -- { "ellisonleao/gruvbox.nvim" },

  -- https://github.com/sainnhe/sonokai
  -- { "sainnhe/sonokai" },

  -- https://github.com/maxmx03/dracula.nvim
  -- { "Mofiqul/dracula.nvim" },

  -- https://github.com/joshdick/onedark.vim
  -- { "joshdick/onedark.vim" },

  -- https://github.com/shaunsingh/nord.nvim
  -- { "shaunsingh/nord.nvim" },

  -- sadly don't look good with (lazy-)nvim :(

  -- https://github.com/sts10/vim-pink-moon
  -- { "sts10/vim-pink-moon" },

  -- https://github.com/FrenzyExists/aquarium-vim
  -- { "FrenzyExists/aquarium-vim" },

  -- https://github.com/w0ng/vim-hybrid
  -- { "w0ng/vim-hybrid" },

  -- https://github.com/jonathanfilip/vim-lucius
  -- { "jonathanfilip/vim-lucius" },
}
