local M = {}

local clear_script = "/home/felix/nixos/bin/codex-clear-noctalia-for-pane"
local last_pane_by_window = {}

local function state_dirs()
	local configured = os.getenv("CODEX_NOCTALIA_STATE_DIR")
	if configured ~= nil and configured ~= "" then
		return { configured }
	end

	local dirs = {}
	local runtime_dir = os.getenv("XDG_RUNTIME_DIR")
	if runtime_dir ~= nil and runtime_dir ~= "" then
		table.insert(dirs, runtime_dir .. "/codex-noctalia")
	end

	local uid = os.getenv("UID")
	if uid ~= nil and uid ~= "" then
		table.insert(dirs, "/tmp/codex-noctalia-" .. uid)
	elseif #dirs == 0 then
		table.insert(dirs, "/tmp/codex-noctalia")
	end

	return dirs
end

local function tab_title(tab)
	local title = tab.tab_title
	if title and #title > 0 then
		return title
	end

	return tab.active_pane.title
end

local function pane_is_ready(pane_id)
	for _, dir in ipairs(state_dirs()) do
		local marker = dir .. "/ready-panes/" .. tostring(pane_id)
		local file = io.open(marker, "r")
		if file ~= nil then
			file:close()
			return true
		end
	end

	return false
end

local function truncate_right(wezterm, text, max_width)
	if max_width == nil or max_width < 1 then
		return ""
	end

	return wezterm.truncate_right(text, max_width)
end

local function clear_for_pane(wezterm, pane)
	if pane == nil then
		return
	end

	wezterm.background_child_process({
		clear_script,
		tostring(pane:pane_id()),
	})
end

function M.setup(wezterm)
	wezterm.on("window-focus-changed", function(window, pane)
		if not window:is_focused() then
			return
		end

		last_pane_by_window[window:window_id()] = pane:pane_id()
		clear_for_pane(wezterm, pane)
	end)

	wezterm.on("update-status", function(window, pane)
		if not window:is_focused() then
			return
		end

		local window_id = window:window_id()
		local pane_id = pane:pane_id()

		if last_pane_by_window[window_id] == pane_id then
			return
		end

		last_pane_by_window[window_id] = pane_id
		clear_for_pane(wezterm, pane)
	end)

	wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
		local title = tab_title(tab)
		local ready = not tab.is_active and pane_is_ready(tab.active_pane.pane_id)

		if not ready then
			return nil
		end

		local marker = "● "
		local title_width = max_width - 2
		return {
			{ Foreground = { Color = "#f5c542" } },
			{ Text = marker },
			{ Text = truncate_right(wezterm, title, title_width) },
		}
	end)
end

return M
