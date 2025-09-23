return {
  -- set my current colorscheme
  {
    "LazyVim/LazyVim",

    opts = function(_, opts)
      local hostname = vim.loop.os_gethostname()
      if hostname == "H77QF74G0F" then
        -- ^^^ THIS VERY GOOD vvv
        -- opts.colorscheme = "nordic"
        -- ^^^ THIS VERY GOOD ^^^

        -- THIS TOO:
        -- opts.colorscheme = "oldworld"
        -- opts.colorscheme = "onenord-light"
        -- ^^^ THIS VERY GOOD ^^^

        opts.colorscheme = "embark"

        -- Also good, but not the one I want (for now) I think :)
        -- opts.colorscheme = "shadow"
      elseif hostname == "nixos-home" then
        if vim.g.neovide then
          opts.colorscheme = "oh-lucy"
        else
          opts.colorscheme = "rose-pine-dawn"
        end
        -- override!
        opts.colorscheme = "tokyonight"
      elseif hostname == "nixos-work" then
        vim.opt.background = "light"
        opts.colorscheme = "gruvdark-light"
      elseif vim.g.neovide then
        -- colorscheme in neovide

        -- opts.colorscheme = "nordic"
        -- opts.colorscheme = "astrolight"
        -- opts.colorscheme = "embark"
        opts.colorscheme = "oh-lucy-evening"
      else
        -- colorscheme in terminal/otherwise

        -- opts.colorscheme = "astrolight"
        -- opts.colorscheme = "onenord-light"
        -- opts.colorscheme = "rose-pine-dawn"
        opts.colorscheme = "embark"
      end
      -- global override
      -- opts.colorscheme = "embark"
      -- opts.colorscheme = "kanagawa"
      -- opts.colorscheme = "oh-lucy" -- status line color not ideal atm. (2024-06-06)
      -- opts.colorscheme = "tokyonight"
    end,

    -- opts = {
    --   -- evergreen <3
    --   -- colorscheme = "nordic",
    --   -- colorscheme = "everforest",
    --   -- colorscheme = "rose-pine-moon",
    --   colorscheme = "astrolight",
    -- },
  },

  -- -- Grouped Colorschemes below --

  -- these I haven't tried out/sorted yet

  -- gruvdark
  -- https://github.com/darianmorat/gruvdark.nvim
  {
    "darianmorat/gruvdark.nvim",
    lazy = false,
    priority = 1000,
    opts = {},
  },

  -- most fav (but probably not always lol)
  -- (somewhat ordered from most to least liked)

  -- OldWorld
  -- https://github.com/dgox16/oldworld.nvim
  {
    "dgox16/oldworld.nvim",
    lazy = false,
    priority = 1000,
  },

  -- oh-lucy
  { "Yazeed1s/oh-lucy.nvim" },

  -- pinkmare
  { "Matsuuu/pinkmare" },

  -- embark-theme
  {
    "embark-theme/vim",
    name = "embark",
    opts = {},
  },

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

  -- mellifluous
  -- `set background=dark/light` for dark/light variant
  {
    "ramojus/mellifluous.nvim",
    config = true,
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

  {
    "rjshkhr/shadow.nvim",
    priority = 1000,
    -- config = function()
    --   vim.opt.termguicolors = true
    --   vim.cmd.colorscheme("shadow")
    -- end,
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
