-- -- stylua: ignore -- I want formatting, damn it!
if true then
  local snippetsDir = vim.fn.stdpath("config") .. "/snippets"

  return {
    -- setup neotest with jest for ts
    -- https://github.com/nvim-neotest/neotest-jest
    {
      "nvim-neotest/neotest",
      dependencies = {
        { "nvim-neotest/neotest-jest" },
      },
      -- optional = true,
      opts = {
        adapters = {
          -- adapted from here:
          -- https://github.com/LeonardsonCC/nvim/blob/70c1e53f67d0e453aff9c4c58b011a8b0586d99d/lua/plugins/neotest-jest.lua#L3
          ["neotest-jest"] = {},
          --   jestCommand = "npm test --",
          --   jestConfigFile = "custom.jest.config.ts",
          --   env = { CI = true },
          --   cwd = function(path)
          --     return vim.fn.getcwd()
          --   end,
        },
      },
    },

    -- Setup markdownlint-cli2 config to adjust some lints
    -- see https://github.com/LazyVim/LazyVim/discussions/4094
    {
      "mfussenegger/nvim-lint",
      optional = true,
      opts = {
        linters = {
          ["markdownlint-cli2"] = {
            args = { "--config", os.getenv("HOME") .. "/nixos/dotfiles/.markdownlint.yaml", "--" },
          },
        },
      },
    },

    -- Setup markdownlint-cli2 config to adjust some lints
    -- see https://github.com/LazyVim/LazyVim/discussions/4094
    {
      "stevearc/conform.nvim",
      optional = true,
      opts = {
        formatters = {
          ["markdownlint-cli2"] = {
            args = { "--config", os.getenv("HOME") .. "/nixos/dotfiles/.markdownlint.yaml", "--" },
          },
        },
      },
    },

    -- {
    --   "saghen/blink.cmp",
    --   opts = function(_, opts)
    --     opts.completion = vim.tbl_deep_extend("error", opts.completion or {}, {
    --       accept = {
    --         -- should be default, but neither default nor this works :/
    --         dot_repeat = true,
    --       },
    --     })
    --     -- print(vim.inspect(opts))
    --   end,
    -- },

    -- SudaWrite (& SudaRead)
    -- https://github.com/lambdalisue/vim-suda
    {
      "lambdalisue/vim-suda",
    },

    -- https://github.com/HiPhish/jinja.vim
    {
      -- needs manual "syntax=on" (website has AutoCmd instructions), but then its sloow
      -- actually seems fine, but needs that extra setup; website only has vim-style instructions >.>
      "HiPhish/jinja.vim",
      -- opts = {},
    },

    -- fzf-lua, new Telescope-like on the block 😎
    -- https://github.com/ibhagwan/fzf-lua
    -- {
    --   "ibhagwan/fzf-lua",
    --   opts = function(_, opts)
    --     local defaults = require("fzf-lua").config.defaults
    --
    --     opts.files.rg_opts = (opts.files.rg_opts or defaults.files.rg_opts) .. ' -g "!.jj"'
    --     opts.files.fd_opts = (opts.files.fd_opts or defaults.files.fd_opts) .. " --no-require-git --exclude .jj"
    --   end,
    -- },

    -- Snacks.nvim config
    -- https://github.com/folke/snacks.nvim/tree/main?tab=readme-ov-file#-usage
    {
      "folke/snacks.nvim",
      priority = 1000,
      lazy = false,
      keys = {
        {
          "<leader>gB",
          function()
            Snacks.gitbrowse()
          end,
          desc = "Git Browse",
          mode = { "n", "v" },
        },
      },
      -- https://github.com/folke/snacks.nvim/issues/164
      opts_extend = { "gitbrowse.remote_patterns" },
      opts = {
        gitbrowse = {
          ---@diagnostic disable-next-line: unused-local
          config = function(opts, defaults)
            -- add to _start_ of list, because they are applied in order.
            opts.remote_patterns = vim.list_extend({
              -- cf bitbucket
              --   ssh://git@bitbucket.cfdata.org:7999/devops/salt.git
              --   https://bitbucket.cfdata.org/projects/OXY/repos/oxy/browse/integration-tests/tests/http2.rs?at=0f5a4f702da88ef6e671521fd82b497b3ac7fa75
              {
                "^ssh://git@bitbucket%.cfdata%.org:7999/(.*)/(.*)%.git$",
                "https://bitbucket.cfdata.org/projects/%1/repos/%2",
              },
              {
                "^ssh://git@bitbucket%.cfdata%.org:7999/(.*)/(.*)$",
                "https://bitbucket.cfdata.org/projects/%1/repos/%2",
              },
              -- cf gitlab
              --   git@gitlab.cfdata.org:cloudflare/ares/oxy-teams
              --   https://gitlab.cfdata.org/cloudflare/ares/gateway-rule-engine/-/blob/iain/GFI-502/Cargo.toml?ref_type=heads#L47
              {
                "^git@gitlab%.cfdata%.org:cloudflare/(.*)/(.*)%.git$",
                "https://gitlab.cfdata.org/cloudflare/%1/%2",
              },
              { "^git@gitlab%.cfdata%.org:cloudflare/(.*)/(.*)$", "https://gitlab.cfdata.org/cloudflare/%1/%2" },
            }, opts.remote_patterns or {})
          end,
          url_patterns = {
            ["bitbucket%.cfdata%.org"] = {
              file = "/browse/{file}?at={branch}#{line}",
            },
            -- see https://github.com/folke/snacks.nvim/blob/main/docs/gitbrowse.md
            ["gitlab%.cfdata%.org"] = {
              branch = "/-/tree/{branch}",
              file = "/-/blob/{branch}/{file}#L{line_start}-L{line_end}",
              commit = "/-/commit/{commit}",
            },
          },
        },
      },
    },

    -- Bookmarks
    -- https://github.com/LintaoAmons/bookmarks.nvim
    {
      "LintaoAmons/bookmarks.nvim",
      -- tag = "v0.5.4", -- optional, pin the plugin at specific version for stability
      dependencies = {
        { "kkharji/sqlite.lua" },
        { "nvim-telescope/telescope.nvim" },
        { "stevearc/dressing.nvim" }, -- optional: to have the same UI shown in the GIF
      },
      lazy = false,
      dev = false,
      opts = {
        json_db_path = vim.fs.normalize(vim.fn.stdpath("config") .. "/bookmarks_" .. vim.fn.hostname() .. ".db.json"),
        signs = {
          mark = { icon = "󰃁", color = "", line_bg = "" },
          desc_format = function(desc)
            return "󰃁 " .. desc
          end,
        },
        -- shows an empty buffer after `:BookmarksCalibration`, don't need that
        show_calibrate_result = false,
        -- disabling this actually makes it work?? lol, but ok :)
        auto_calibrate_cur_buf = false,
      },
      keys = {
        {
          mode = { "n", "v" },
          "äa",
          "<cmd>BookmarksMark<cr>",
          desc = "Add current line into active BookmarkList.",
        },
        {
          mode = { "n", "v" },
          "äg",
          function()
            local picker = require("bookmarks.adapter.picker")
            local api = require("bookmarks.api")
            picker.pick_bookmark_of_current_project(function(bookmark)
              api.goto_bookmark(bookmark)
            end, { all = true })
          end,
          desc = "Go to bookmark in current project",
        },
        {
          mode = { "n", "v" },
          "äd",
          function()
            local api = require("bookmarks.api")
            local bm = api.find_existing_bookmark_under_cursor()
            if bm then
              api.mark({ name = "" })
            end
          end,
          desc = "Delete bookmark in current line",
        },
        { mode = { "n", "v" }, "äc", "<cmd>BookmarksCommands<cr>", desc = "Find and trigger a bookmark command." },
        {
          mode = { "n", "v" },
          "är",
          "<cmd>BookmarksGotoRecent<cr>",
          desc = "Go to latest visited/created Bookmark",
        },
        {
          mode = { "n", "v" },
          "ät",
          "<cmd>BookmarksTree<cr>",
          desc = "Open Bookmarks Tree View",
        },
      },
    },

    -- :Telescope emoji
    -- https://github.com/xiyaowong/telescope-emoji.nvim
    {
      "xiyaowong/telescope-emoji.nvim",
      dependencies = {
        "nvim-telescope/telescope.nvim",
        opts = {
          extensions = {
            emoji = {
              action = function(emoji)
                -- argument emoji is a table.
                -- {name="", value="", cagegory="", description=""}

                -- vim.fn.setreg("*", emoji.value)
                -- print([[Press p or "*p to paste this emoji]] .. emoji.value)

                -- insert emoji when picked
                vim.api.nvim_put({ emoji.value }, "c", false, true)
              end,
            },
          },
        },
      },
      config = function()
        require("telescope").load_extension("emoji")
      end,
    },

    -- scrollbar with symbols
    -- https://github.com/lewis6991/satellite.nvim
    {
      "lewis6991/satellite.nvim",
      opts = {},
    },

    -- IDE-style breadcrumbs
    -- https://github.com/Bekaboo/dropbar.nvim
    {
      "Bekaboo/dropbar.nvim",
      -- optional, but required for fuzzy finder support
      -- dependencies = {
      --   "nvim-telescope/telescope-fzf-native.nvim",
      -- },
      opts = {
        sources = {
          path = {
            relative_to = function(_, win)
              -- Workaround for Vim:E5002: Cannot find window number
              local ok, win_cwd = pcall(vim.fn.getcwd, win)
              local cwd = ok and win_cwd or vim.fn.getcwd()

              local is_subdir_of_home = vim.fn.fnamemodify(cwd, ":~") ~= cwd

              -- this allows me to see `~/.cargo/...` paths (:
              return is_subdir_of_home and vim.env.HOME or "/"
            end,
          },
        },
      },
    },

    -- Project local (and global) LSP settings
    -- must come BEFORE lspconfig (but I don't use that)
    -- https://github.com/folke/neoconf.nvim/
    { "folke/neoconf.nvim" },

    -- Improve `gx` handling
    -- https://github.com/chrishrb/gx.nvim
    {
      "chrishrb/gx.nvim",
      keys = { { "gx", "<cmd>Browse<cr>", mode = { "n", "x" } } },
      cmd = { "Browse" },
      init = function()
        vim.g.netrw_nogx = 1 -- disable netrw gx
      end,
      dependencies = { "nvim-lua/plenary.nvim" },
      config = true, -- default settings
      submodules = false,
    },

    -- tokyonight colorscheme, from folke
    {
      "folke/tokyonight.nvim",
      lazy = false,
      priority = 1000,
      opts = {},
    },
    --  precognition.nvim [shows where `w`, `e`, etc. will jump]
    --  https://github.com/tris203/precognition.nvim
    {
      "tris203/precognition.nvim",
      opts = {
        startVisible = false,
      },
    },

    --  vim-matchup [improved % motion]
    --  https://github.com/andymass/vim-matchup
    {
      "andymass/vim-matchup",
      -- event = "VeryLazy",
      config = function()
        vim.g.matchup_matchparen_deferred = 1 -- work async
        vim.g.matchup_matchparen_offscreen = {} -- disable status bar icon
      end,
    },

    -- overseer, task runner
    {
      "stevearc/overseer.nvim",
      opts = {},
    },

    -- typst lsp, nil lsp
    {
      "neovim/nvim-lspconfig",
      ---@class PluginLspOpts
      opts = {
        -- ---@type lspconfig.options
        servers = {
          typst_lsp = {
            mason = false,
            settings = {
              exportPdf = "onType",
            },
          },
          nil_ls = {
            mason = false,
            settings = {
              ["nil"] = {
                formatting = {
                  command = { "nixfmt" },
                },
              },
            },
          },
          lua_ls = {
            mason = false,
          },
          jsonls = {
            cmd = { "vscode-json-languageserver", "--stdio" },
          },
        },
      },
    },

    -- disable these, I use Nix
    {
      "mason-org/mason-lspconfig.nvim",
      enabled = false,
    },
    {
      "mason-org/mason.nvim",
      enabled = false,
    },

    -- optimizations for big files - https://github.com/LunarVim/bigfile.nvim
    {
      "LunarVim/bigfile.nvim",
      opts = {},
    },

    -- let's try out harpoon: https://github.com/ThePrimeagen/harpoon/tree/harpoon2
    {
      "ThePrimeagen/harpoon",
      branch = "harpoon2",
      dependencies = {
        "nvim-lua/plenary.nvim",
      },
      opts = {},
      keys = function()
        local harpoon = require("harpoon")

        -- stylua: ignore
        return {
          { "<leader>a", function() harpoon:list():add() end },
          { "<C-e>", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, desc = "Open harpoon window" },
          -- <M-n> already bound to "Next Reference"
          -- { "<M-n>", function() harpoon:list():select(1) end },
          { "<M-r>", function() harpoon:list():select(1) end },
          { "<M-t>", function() harpoon:list():select(2) end },
          { "<M-d>", function() harpoon:list():select(3) end },

          -- Toggle previous & next buffers stored within Harpoon list
          { "<M-g>", function() harpoon:list():prev() end },
          { "<M-f>", function() harpoon:list():next() end },
        }
      end,
    },

    -- lsp file ops, i.e., rename -> lsp adjustments automatically
    {
      "antosha417/nvim-lsp-file-operations",
      dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-neo-tree/neo-tree.nvim",
      },
      config = function()
        require("lsp-file-operations").setup()
      end,
    },

    -- preview colors inline
    {
      "NvChad/nvim-colorizer.lua",
      opts = {
        user_default_options = {
          css = true,
        },
      },
    },

    -- copilot.lua
    -- {
    --   "zbirenbaum/copilot.lua",
    --   -- enable more filetypes
    --   opts = function(_, opts)
    --     opts.filetypes = {
    --       yaml = true,
    --       markdown = true,
    --       help = true,
    --       gitcommit = true,
    --       gitrebase = true,
    --     }
    --   end,
    -- },

    -- ft .yuck (for eww)
    { "elkowar/yuck.vim" },

    -- parinfer, for lisp (including yuck)
    { "eraserhd/parinfer-rust", build = "nix-shell --run 'cargo build --release '" },

    -- snippet editing & creation: https://github.com/chrisgrieser/nvim-scissors
    {
      "chrisgrieser/nvim-scissors",
      dependencies = "nvim-telescope/telescope.nvim", -- optional
      opts = {
        snippetDir = snippetsDir,
      },
    },

    -- Use <tab> for completion and snippets (supertab)
    -- first: disable default <tab> and <s-tab> behavior in LuaSnip
    {
      "L3MON4D3/LuaSnip",
      config = function()
        require("luasnip.loaders.from_vscode").lazy_load({ paths = { snippetsDir } })
      end,
    },

    -- tabout.nvim -- didn't really use this, let's disable it.
    -- Use <tab> for completion and snippets (supertab)
    -- first: disable default <tab> and <s-tab> behavior in LuaSnip
    -- {
    --   "L3MON4D3/LuaSnip",
    --   keys = function()
    --     return {}
    --   end,
    -- },
    -- {
    --   'abecodes/tabout.nvim',
    --   requires = {
    --     "nvim-treesitter/nvim-treesitter",
    --   },
    --   -- opts = {},
    --   opts = function(_, opts)
    --     local has_words_before = function()
    --       unpack = unpack or table.unpack
    --       local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    --       return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
    --     end
    --
    --     local luasnip = require("luasnip")
    --     local cmp = require("cmp")
    --
    --     local base_table = {}
    --     if (opts['mapping'] ~= nil) then
    --       base_table = opts.mapping
    --     end
    --
    --     opts.mapping = vim.tbl_extend("force", base_table, {
    --       ["<Tab>"] = cmp.mapping(function(fallback)
    --         if cmp.visible() then
    --           cmp.select_next_item()
    --           -- You could replace the expand_or_jumpable() calls with expand_or_locally_jumpable()
    --           -- this way you will only jump inside the snippet region
    --         elseif luasnip.expand_or_jumpable() then
    --           luasnip.expand_or_jump()
    --         elseif has_words_before() then
    --           cmp.complete()
    --         else
    --           fallback()
    --         end
    --       end, { "i", "s" }),
    --       ["<S-Tab>"] = cmp.mapping(function(fallback)
    --         if cmp.visible() then
    --           cmp.select_prev_item()
    --         elseif luasnip.jumpable(-1) then
    --           luasnip.jump(-1)
    --         else
    --           fallback()
    --         end
    --       end, { "i", "s" }),
    --     })
    --   end,
    -- },

    -- codeium config, to support the downloaded LSP
    -- {
    --   "Exafunction/codeium.nvim",
    --   opts = {
    --     -- see ~/bin/wrap-codeium-nix-alien
    --     wrapper = "wrap-codeium-nix-alien",
    --   },
    --   enabled = false,
    -- },

    -- nu support
    -- required a manual `:TSInstall nu` once
    {
      "LhKipp/nvim-nu",
      opts = {},
    },

    -- Octo.nvim <3
    {
      "pwntester/octo.nvim",
      requires = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope.nvim",
        "nvim-tree/nvim-web-devicons",
      },
      opts = {
        enable_builtin = true,
      },
      keys = {
        { "<leader>gO", "<cmd>Octo<cr>", desc = "Octo" },
      },
    },

    -- (postgres)-SQL interface based on vim-dadbod
    {
      "kristijanhusak/vim-dadbod-ui",
      dependencies = {
        { "tpope/vim-dadbod", lazy = true },
        { "kristijanhusak/vim-dadbod-completion", ft = { "sql", "mysql", "plsql" }, lazy = true },
      },
      cmd = {
        "DBUI",
        "DBUIToggle",
        "DBUIAddConnection",
        "DBUIFindBuffer",
      },
      init = function()
        -- Your DBUI configuration
        vim.g.db_ui_use_nerd_fonts = 1
      end,
    },

    -- auto pairs
    -- BROKEN
    -- {
    --   'altermo/ultimate-autopair.nvim',
    --   event={'InsertEnter','CmdlineEnter'},
    --   branch='v0.6',
    --   opts={
    --     --Config goes here
    --   },
    -- },
    -- disable lazyvim default instead
    -- {
    --   "echasnovski/mini.pairs",
    --   enable = false,
    -- },

    -- telescope settings
    {
      "nvim-telescope/telescope.nvim",
      dependencies = {
        "nvim-telescope/telescope-github.nvim",
        config = function()
          require("telescope").load_extension("gh")
        end,
      },
      opts = function(_, opts)
        local live_grep_with_hidden = function()
          local action_state = require("telescope.actions.state")
          local line = action_state.get_current_line()
          require("telescope.builtin").live_grep({
            additional_args = { "--hidden" },
            default_text = line,
          })
        end

        opts.pickers = vim.tbl_deep_extend("error", opts.pickers or {}, {
          live_grep = {
            mappings = {
              i = {
                ["<a-h>"] = live_grep_with_hidden,
              },
            },
          },
        })
      end,
    },

    -- syntax highlighting etc. for `Earthfile`s
    { "earthly/earthly.vim" },

    -- rustaceanvim
    -- just needed to stash this somewhere (from a .vscode/settings.json) "commented-out.rust-analyzer.cargo.buildScripts.invocationLocation": "root",
    {
      "mrcjkb/rustaceanvim",
      version = "^6",
      opts = {
        server = {
          -- this replaces the default keybindings, see https://www.lazyvim.org/extras/lang/rust#rustaceanvim
          on_attach = function(_, bufnr)
            vim.keymap.set("n", "<leader>cR", function()
              vim.cmd.RustLsp("codeAction")
            end, { desc = "Code Action", buffer = bufnr })
            vim.keymap.set("n", "<leader>rr", function()
              vim.cmd.RustLsp("runnables")
            end, { desc = "Rust Runnables", buffer = bufnr })
            vim.keymap.set("n", "<C-r>", function()
              vim.cmd.RustLsp({ "run", bang = true })
            end, { desc = "Rust Rerun Last Runnable", buffer = bufnr })
          end,
          default_settings = {
            -- rust-analyzer language server configuration
            ["rust-analyzer"] = {
              cargo = {
                allFeatures = true, -- not good for (some) projects, disable with a `.vscode/settings.json` then, like here: https://github.com/rust-analyzer/rust-project.json-example/blob/master/.vscode/settings.json
                targetDir = true, -- causes a subdirectory in `target` to be used
              },
              -- also the default from LazyVim, but I like having it here explicitly
              check = {
                command = "clippy",
                extraArgs = { "--no-deps" },
              },
              -- check = {
              --   command = "check",
              --   -- extraArgs = { "--no-deps" },
              -- },
              diagnostics = {
                -- list of all r-a diagnostics: https://rust-analyzer.github.io/manual.html#diagnostics
                disabled = {
                  -- don't make explicitly disabled proc-macros with squiggly lines everywhere
                  -- actually, please do, because these can lead to r-a showing errors, in which case I want to see (:
                  -- "proc-macro-disabled",
                },
                experimental = {
                  enable = true,
                },
              },
              procMacro = {
                ignored = {
                  -- just do it, otherwise causes errors that aren't errors
                  ["async-trait"] = {},
                },
              },
              files = {
                -- sadly relative to workspace root, so if any of these are in a nested dir, it needs per-project config
                -- should be able to not set this explicitly with https://github.com/LazyVim/LazyVim/pull/5664, if I want
                exclude = {
                  ".direnv",
                  ".git",
                  ".jj",
                  ".github",
                  ".gitlab",
                  -- "bin", -- don't ignore this..
                  "node_modules",
                  "target",
                  "venv",
                  ".venv",
                },

                excludeDirs = {
                  ".direnv",
                  ".git",
                  ".jj",
                  ".github",
                  ".gitlab",
                  -- "bin", -- don't ignore this..
                  "node_modules",
                  "target",
                  "venv",
                  ".venv",
                },
              },
              -- this no worky, think the option doesn't exist anymore :/
              -- server = {
              --   extraEnv = {
              --     -- use nightly r-a by default (let's try this out :shrug:)
              --     RUSTUP_TOOLCHAIN = "nightly",
              --   },
              -- },
            },
          },
        },
      },
    },

    -- yank-ring etc.
    {
      "gbprod/yanky.nvim",
      opts = {
        ring = {
          storage = "shada", -- "sqlite" needs extra config on Nix, don't have it yet
        },
      },
    },
    {
      "kkharji/sqlite.lua",
      enabled = false, -- needs extra config on Nix, see above
    },

    -- telescope settings
    {
      "nvim-telescope/telescope.nvim",
      keys = {
        -- this respects tab-cwd better in my experience.
        { "<leader><space>", "<cmd>Telescope find_files<cr>", desc = "Find Files" },
        -- sadly doesn't work :( getting some error about marks not set
        -- should allow searching the command history (useful for `:'<,'> s//``
        -- commands) while in visual mode
        -- {
        --   "<leader>sc",
        --   "<cmd>Telescope command_history<cr>",
        --   desc = "Telescope Command History",
        --   mode = { "v" },
        -- },
      },
    },

    -- projects for neovim
    {
      "ahmedkhalf/project.nvim",
      keys = {
        -- open the projects picker in a new tab, because I scope tabs to projects.
        { "<leader>fp", "<Cmd>:tabnew | Telescope projects<CR>", desc = "Projects" },
      },
      opts = {
        -- this is enabled by LazyVim, but we want auto-cd behavior!
        manual_mode = false,
        -- show us a message when changing directory :)
        silent_chdir = false,
        -- change directory for the current tab, not globally or per-window
        scope_chdir = "tab",
        -- "pattern" before "lsp", to avoid "subprojects"
        detection_methods = { "pattern", "lsp" },
        -- don't want stuff like "package.json" in here, also to avoid subprojects
        -- .project_nvim_root as an escape-hatch for me
        patterns = { ".project_nvim_root", ".git", "_darcs", ".hg", ".bzr", ".svn", ".jj" },
      },
    },

    -- bufferline
    {
      "akinsho/bufferline.nvim",
      opts = {
        options = {
          always_show_bufferline = true,
          -- mode = "tabs", -- just trying this out.. - don't like it, need another way for named tabs.
        },
      },
    },

    -- per-tab buffers
    {
      "tiagovla/scope.nvim",
      event = "VeryLazy",
      opts = {},
    },

    -- Metals setup with the official plugin
    {
      "scalameta/nvim-metals",
      dependencies = {
        "nvim-lua/plenary.nvim",
      },
      ft = { "scala", "sbt", "java" },
      config = function(_, _)
        -- ref: https://github.com/ornicar/dotfiles/blob/crom/nvim/lua/plugins/metals.lua

        local metals = require("metals")
        local metals_config = metals.bare_config()

        metals_config.settings = {
          showImplicitArguments = true,
          showInferredType = true,
          excludedPackages = {},
          useGlobalExecutable = true,
        }

        -- make sure to have "g:metals_status" or an equivalent in the status bar
        metals_config.init_options = {
          statusBarProvider = "on",
          decorationProvider = true,
          -- doesn't work with nvim-metals yet (2023-09-21)
          -- inlineDecorationProvider = true,
        }

        metals_config.capabilities = require("blink.cmp").get_lsp_capabilities(metals_config.capabilities or {})

        -- metals_config.on_attach = function(client, bufnr)
        --   require("lsp-format").on_attach(client, bufnr)
        -- end

        -- Autocmd that will actually be in charge of starting the whole thing
        local nvim_metals_group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
        vim.api.nvim_create_autocmd("FileType", {
          pattern = { "scala", "sbt", "java" },
          callback = function()
            metals.initialize_or_attach(metals_config)
          end,
          group = nvim_metals_group,
        })
      end,
    },

    -- lualine (status line)
    {
      "nvim-lualine/lualine.nvim",
      event = "VeryLazy",
      opts = function(_, opts)
        -- always show full path, don't abbreviate.
        -- want this for now, let's see how it works out :)
        opts.sections.lualine_c[#opts.sections.lualine_c - 1] = { LazyVim.lualine.pretty_path({ length = 0 }) }

        -- table.remove(opts.sections.lualine_x, 1) -- remove command
        -- table.remove(opts.sections.lualine_x, 3) -- remove lazy update count
        table.insert(opts.sections.lualine_x, "g:metals_status")
        -- table.insert(opts.sections.lualine_x, "overseer")
      end,
    },

    -- Diffview https://github.com/sindrets/diffview.nvim
    {
      "sindrets/diffview.nvim",
      keys = {
        { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Open Diffview" },
      },
      opts = {},
    },

    -- neogit - magit for neovim
    {
      "NeogitOrg/neogit",
      dependencies = {
        "nvim-lua/plenary.nvim", -- required
        "nvim-telescope/telescope.nvim", -- optional
        "sindrets/diffview.nvim", -- optional
        "ibhagwan/fzf-lua", -- optional
      },
      keys = { { "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit" } },
      cmd = "Neogit",
      opts = {
        disable_insert_on_commit = false,
      },
    },

    -- TODO: figure out how to use this on nixos
    -- add telescope-fzf-native
    -- {
    --   "telescope.nvim",
    --   dependencies = {
    --     "nvim-telescope/telescope-fzf-native.nvim",
    --     build = "make",
    --     config = function()
    --       require("telescope").load_extension("fzf")
    --     end,
    --   },
    -- },

    -- add more treesitter parsers
    {
      "nvim-treesitter/nvim-treesitter",
      dependencies = {
        "andymass/vim-matchup",
      },
      opts = {
        ensure_installed = {
          "bash",
          "html",
          "javascript",
          "json",
          "lua",
          "markdown",
          "markdown_inline",
          "python",
          -- "query",
          "regex",
          "tsx",
          "typescript",
          "vim",
          "yaml",
          "scala",
          "rust",
          "css",
          "dhall",
          "dockerfile",
          "fish",
          "nix",
          "prisma",
          "sql",
          "terraform",
        },
        matchup = {
          enable = true,
          enable_quotes = true,
          include_match_words = true,
        },
      },
    },
  }
end

-- every spec file under the "plugins" directory will be loaded automatically by lazy.nvim
--
-- In your plugin files, you can:
-- * add extra plugins
-- * disable/enabled LazyVim plugins
-- * override the configuration of LazyVim plugins
return {
  -- add gruvbox
  { "ellisonleao/gruvbox.nvim" },

  -- Configure LazyVim to load gruvbox
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "gruvbox",
    },
  },

  -- change trouble config
  {
    "folke/trouble.nvim",
    -- opts will be merged with the parent spec
    opts = { use_diagnostic_signs = true },
  },

  -- disable trouble
  { "folke/trouble.nvim", enabled = false },

  -- add symbols-outline
  {
    "simrat39/symbols-outline.nvim",
    cmd = "SymbolsOutline",
    keys = { { "<leader>cs", "<cmd>SymbolsOutline<cr>", desc = "Symbols Outline" } },
    config = true,
  },

  -- override nvim-cmp and add cmp-emoji
  {
    "hrsh7th/nvim-cmp",
    dependencies = { "hrsh7th/cmp-emoji" },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local cmp = require("cmp")
      opts.sources = cmp.config.sources(vim.list_extend(opts.sources, { { name = "emoji" } }))
    end,
  },

  -- change some telescope options and a keymap to browse plugin files
  {
    "nvim-telescope/telescope.nvim",
    keys = {
      -- add a keymap to browse plugin files
      -- stylua: ignore
      {
        "<leader>fp",
        function() require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root }) end,
        desc = "Find Plugin File",
      },
    },
    -- change some options
    opts = {
      defaults = {
        layout_strategy = "horizontal",
        layout_config = { prompt_position = "top" },
        sorting_strategy = "ascending",
        winblend = 0,
      },
    },
  },

  -- add telescope-fzf-native
  {
    "telescope.nvim",
    dependencies = {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
      config = function()
        require("telescope").load_extension("fzf")
      end,
    },
  },

  -- add pyright to lspconfig
  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      -- ---@type lspconfig.options
      servers = {
        -- pyright will be automatically installed with mason and loaded with lspconfig
        pyright = {},
      },
    },
  },

  -- add tsserver and setup with typescript.nvim instead of lspconfig
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      "jose-elias-alvarez/typescript.nvim",
      init = function()
        require("lazyvim.util").on_attach(function(_, buffer)
          -- stylua: ignore
          vim.keymap.set( "n", "<leader>co", "TypescriptOrganizeImports", { buffer = buffer, desc = "Organize Imports" })
          vim.keymap.set("n", "<leader>cR", "TypescriptRenameFile", { desc = "Rename File", buffer = buffer })
        end)
      end,
    },
    ---@class PluginLspOpts
    opts = {
      -- ---@type lspconfig.options
      servers = {
        -- tsserver will be automatically installed with mason and loaded with lspconfig
        tsserver = {},
      },
      -- you can do any additional lsp server setup here
      -- return true if you don't want this server to be setup with lspconfig
      ---@type table<string, fun(server:string, opts:_.lspconfig.options):boolean?>
      setup = {
        -- example to setup with typescript.nvim
        tsserver = function(_, opts)
          require("typescript").setup({ server = opts })
          return true
        end,
        -- Specify * to use this function as a fallback for any server
        -- ["*"] = function(server, opts) end,
      },
    },
  },

  -- for typescript, LazyVim also includes extra specs to properly setup lspconfig,
  -- treesitter, mason and typescript.nvim. So instead of the above, you can use:
  { import = "lazyvim.plugins.extras.lang.typescript" },

  -- add more treesitter parsers
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "tsx",
        "typescript",
        "vim",
        "yaml",
      },
    },
  },

  -- since `vim.tbl_deep_extend`, can only merge tables and not lists, the code above
  -- would overwrite `ensure_installed` with the new value.
  -- If you'd rather extend the default config, use the code below instead:
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      -- add tsx and treesitter
      vim.list_extend(opts.ensure_installed, {
        "tsx",
        "typescript",
      })
    end,
  },

  -- the opts function can also be used to change the default opts:
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, "😄")
    end,
  },

  -- or you can return new options to override all the defaults
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function()
      return {
        --[[add your custom lualine config here]]
      }
    end,
  },

  -- use mini.starter instead of alpha
  { import = "lazyvim.plugins.extras.ui.mini-starter" },

  -- add jsonls and schemastore packages, and setup treesitter for json, json5 and jsonc
  { import = "lazyvim.plugins.extras.lang.json" },

  -- add any tools you want to have installed below
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "stylua",
        "shellcheck",
        "shfmt",
        "flake8",
      },
    },
  },

  -- Use <tab> for completion and snippets (supertab)
  -- first: disable default <tab> and <s-tab> behavior in LuaSnip
  {
    "L3MON4D3/LuaSnip",
    keys = function()
      return {}
    end,
  },
  -- then: setup supertab in cmp
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-emoji",
    },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      local has_words_before = function()
        unpack = unpack or table.unpack
        local line, col = unpack(vim.api.nvim_win_get_cursor(0))
        return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
      end

      local luasnip = require("luasnip")
      local cmp = require("cmp")

      opts.mapping = vim.tbl_extend("force", opts.mapping, {
        ["<Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          -- You could replace the expand_or_jumpable() calls with expand_or_locally_jumpable()
          -- this way you will only jump inside the snippet region
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          elseif has_words_before() then
            cmp.complete()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<S-Tab>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { "i", "s" }),
      })
    end,
  },
}
