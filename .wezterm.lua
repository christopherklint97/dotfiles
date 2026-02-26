-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

-- For example, changing the color scheme:
-- config.color_scheme = "Gruvbox (Gogh)"
config.color_scheme = "Dracula"
config.font_size = 13.0

-- Bypass tmux mouse reporting when CMD is held (enables Cmd+click on links)
config.bypass_mouse_reporting_modifiers = "CMD"

-- Keybindings
config.keys = {
  { key = "Backspace", mods = "CMD", action = wezterm.action.SendKey({ key = "u", mods = "CTRL" }) },
  { key = "LeftArrow", mods = "CMD", action = wezterm.action.SendKey({ key = "a", mods = "CTRL" }) },
  { key = "RightArrow", mods = "CMD", action = wezterm.action.SendKey({ key = "e", mods = "CTRL" }) },
}

-- and finally, return the configuration to wezterm
return config
