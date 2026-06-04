-- Pull in the wezterm API
local wezterm = require("wezterm")

-- This will hold the configuration.
local config = wezterm.config_builder()

-- This is where you actually apply your config choices

-- Pick a color scheme based on the macOS system appearance.
-- WezTerm re-reads the config (and re-runs this) when the appearance changes,
-- so toggling Dark/Light in System Settings switches the theme automatically.
local function scheme_for_appearance(appearance)
  if appearance:find("Dark") then
    return "Dracula"
  else
    return "Catppuccin Latte"
  end
end

config.color_scheme = scheme_for_appearance(wezterm.gui.get_appearance())
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
