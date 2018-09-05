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
    image = ICON_DIR.."icon20.png",
    resize = false,
    paddings = 2,
    widget = wibox.widget.imagebox
  }

  local widget = wibox.widget {
    brightness_image,
    brightness_text,
    layout = wibox.layout.fixed.horizontal,
    widget = wibox.container.background
  }

  -- Generate image clip shape
  local function gen_clip_shape(level)
    return (function(cr, width, height)
      local start_angle = (3/4)*2*math.pi
      local end_angle = start_angle + (level / 100)*2*math.pi
      return gears.shape.pie(cr, width, height, start_angle, end_angle)
    end)
  end

  -- Update widget to match brightness
  local function bright_update()
    awful.spawn.easy_async("bash -c \"brightness\"", function(stdout, stderr, reason, exit_code)
      local level = tonumber(string.format("%.0f", stdout))
      brightness_text:set_text(" " .. level .. "% ")
      brightness_image:set_clip_shape(gen_clip_shape(level))
    end)

    return true
  end

  -- Trigger the update manually, then start a timer to trigger periodically
  bright_update()
  gears.timer.start_new(timeout, bright_update)

  return widget
end

return setmetatable(brightness_widget, {__call = function(_, ...) return worker(...) end})
