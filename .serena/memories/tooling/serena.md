# Serena Usage

- Serena is configured for this repo with Nix and Lua LSP support.
- Nix support is useful for symbol overviews, option-field structure, and diagnostics, but shallow for module semantics. Use it for navigation, not as a replacement for `nix eval` or source/eval truth.
- For Nix option usages, `search_for_pattern` is often more reliable than `find_referencing_symbols`; reference lookup may fail on Nix option paths.
- Lua support is useful for locals/functions and returned table structure.
- Large Lazy.nvim plugin spec tables are most navigable when the returned table is top-level. Prefer `find_symbol("/return", depth=...)`, `find_symbol("config")`, `find_symbol("keys")`, and narrowed `find_symbol("opts")` for plugin-spec exploration.
- Treat `find_referencing_symbols` as helpful but incomplete inside deeply nested Lua plugin tables.