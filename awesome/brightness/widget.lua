local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")
local gears = require("gears")

local brightness_widget = {}
local function worker(args)
  -- Args
  local args = args or {}

  -- Settings
  local font = args.font or beautiful.font or "Play 9"
  local ICON_DIR = awful.util.getdir("config").."/brightness/icons/"
  local timeout = args.timeout or 5

  -- Widgets
  local brightness_text = wibox.widget.textbox()
  brightness_text:set_font(font)
  local brightness_image = wibox.widget {
    {
      image = ICON_DIR.."brightness-display-symbolic.svg",
      resize = false,
      widget = wibox.widget.imagebox,
    },
    top = 3,
    widget = wibox.widget.margin
  }

  local widget = wibox.widget {
    brightness_image,
    brightness_text,
    layout = wibox.layout.fixed.horizontal
  }

  local function bright_update()
    awful.spawn.easy_async("bash -c \"brightness\"", function(stdout, stderr, reason, exit_code)
      local level = tonumber(string.format("%.0f", stdout))
      brightness_text:set_text(" " .. level .. "% ")
    end)

    return true
  end

  bright_update()

  gears.timer.start_new(timeout, bright_update)

  return widget
end

return setmetatable(brightness_widget, {__call = function(_, ...) return worker(...) end})
