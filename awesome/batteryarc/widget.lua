local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")
local gears = require("gears")

local battery_widget = {}

local function worker(args)
  -- Args
  local args = args or {}

  -- Settings
  local timeout = args.timeout or 10
  local popup_position = args.popup_position or naughty.config.defaults.position
  local font = args.font or "Play 5"

  -- Widgets
  -- main text
  local text = wibox.widget.textbox()
  -- mirrored text, because the whole thing will be mirrored after
  local mirrored_text = wibox.container.mirror(text, { horizontal = true })
  -- mirrored text with background
  local mirrored_text_with_background = wibox.container.background(mirrored_text)
  -- battery arc
  local batteryarc = wibox.widget {
    mirrored_text_with_background,
    max_value = 1,
    rounded_edge = true,
    thickness = 2,
    start_angle = 4.71238898, -- 2*pi*3/4
    forced_height = 17,
    forced_width = 17,
    bg = "#ffffff11",
    paddings = 2,
    widget = wibox.container.arcchart,
    set_value = function(self, value)
      self.value = value
    end,
  }
  local widget = {}

  local function text_grabber()
    local msg = ""
    local font = beautiful.font

    local raw_acpi_text = ""
    f = io.popen("acpi")
    for line in f:lines() do
      msg = msg..
            "<span font_desc=\""..font.."\">"..
            line.."</span>\n"
    end
    f:close()

    return msg
  end

  text:set_text("")
  text:set_font(font)
  -- mirror the widget so the chart value increases clockwise
  widget = wibox.container.mirror(batteryarc, { horizontal = true })

  local last_battery_check = os.time()
  local function battery_update()
    awful.spawn.easy_async("bash -c \"acpi\"", function(stdout, stderr, reason, exit_code)
      local batteryType
      local battery_info = {}
      local charge = 0
      local charge_sum = 0
      local status
      
      for s in stdout:gmatch("[^\r\n]+") do
        local _, status, charge_str, time = string.match(s, '(.+): (%a+), (%d?%d?%d)%%,? ?.*')
        table.insert(battery_info, { status = status, charge = tonumber(charge_str) })
      end

      for i, batt in ipairs(battery_info) do
        if batt.charge >= charge then
          charge = batt.charge
          status = batt.status -- use most charged battery status
          -- this is arbitrary and maybe another metric should be used
        end
        charge_sum = charge_sum + batt.charge
      end
      charge = charge_sum / #battery_info -- use average charge for battery icon

      batteryarc:set_value(charge / 100)

      if status == 'Charging' then
        mirrored_text_with_background.bg = beautiful.widget_green
        mirrored_text_with_background.fg = beautiful.widget_black
      else
        mirrored_text_with_background.bg = beautiful.widget_transparent
        mirrored_text_with_background.fg = beautiful.widget_main_color
      end

      if charge < 15 then
        batteryarc.colors = { beautiful.widget_red }
        if status ~= 'Charging' and os.difftime(os.time(), last_battery_check) > 300 then
          -- if 5 minutes have elapsed since last warning
          last_battery_check = os.time()
          widget:show_warning(0)
        end
      elseif charge > 15 and charge < 40 then
        batteryarc.colors = { beautiful.widget_yellow }
      else
        batteryarc.colors = { beautiful.widget_main_color }
      end
      text:set_text(charge)
      widget:set_widget(batteryarc)
    end)

    return true
  end

  local notification = nil
  function widget:hide()
    if notification ~= nil then
      naughty.destroy(notification)
      notification = nil
    end
  end

  function widget:show(t_out)
    widget:hide()

    notification = naughty.notify({
      preset = fs_notification_preset,
      text = text_grabber(),
      title = "Battery Status",
      timeout = t_out,
      screen = mouse.screen,
      position = popup_position,
      hover_timeout = 0.5,
      width = 200
    })
  end

  function widget:show_warning(t_out)
    widget:hide()

    notification = naughty.notify({
      preset = fs_notification_preset,
      text = "Huston, we have problem :(",
      title = "Battery is dying!",
      timeout = t_out,
      hover_timeout = 0.5,
      screen = mouse.screen,
      position = popup_position,
      bg = "#F06060",
      fg = "#EEE9EF",
      width = 300
    })
  end

  if onclick then
    widget:buttons(awful.util.table.join(
      awful.button({}, 1, function() awful.util.spawn(onclick) end)
    ))
  end

  widget:connect_signal('mouse::enter', function() widget:show(0) end)
  widget:connect_signal('mouse::leave', function() widget:hide() end)

  battery_update()
  gears.timer.start_new(timeout, battery_update)

  return widget
end

return setmetatable(battery_widget, {__call = function(_, ...) return worker(...) end})
