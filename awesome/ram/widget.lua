local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")
local gears = require("gears")

local ram_widget = {}
local function worker(args)
  -- Args
  local args = args or {}

  -- Widgets
  local widget = wibox.container.background()
  local ram = wibox.widget.textbox()

  -- Settings
  local timeout = args.timeout or 5
  local popup_position = args.popup_position or naughty.config.defaults.position

  local total = 0
  local used = 0
  local free = 0
  local shared = 0
  local buff_cache = 0
  local available = 0
  local total_swap = 0
  local used_swap = 0
  local free_swap = 0
  local function get_percentage(value)
    if (total + total_swap) == 0 then
      return '0%'
    end
    return math.floor(value / (total + total_swap) * 100 + 0.5)..'%'
  end
  
  local function text_grabber() 
    local msg = ""
    local font = beautiful.font

    local raw_mem_text = ""
    f = io.popen("free | grep -z Mem.*Swap.*")
    for line in f:lines() do
      raw_mem_text = raw_mem_text.."\n"..line
    end
    f:close()
    total, used, free, shared, buff_cache, available, total_swap, used_swap, free_swap = raw_mem_text:match('(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*Swap:%s*(%d+)%s*(%d+)%s*(%d+)')

    msg = "<span font_desc=\""..font.."\">"..
          "┌Used:\t"..get_percentage(used + used_swap).."\n"..
          "├Free:\t"..get_percentage(free + free_swap).."\n"..
          "└Cache:\t"..get_percentage(buff_cache).."</span>"

    --msg = "<span font_desc=\""..font.."\">"..raw_mem_text.."</span>"

    return msg
  end

  ram:set_text("Ram: ")
  widget:set_widget(ram)

  local function ram_update()
    awful.spawn.easy_async("bash -c \"free | grep -z Mem.*Swap.*\"", function(stdout, stderr, reason, exit_code)
      total, used, free, shared, buff_cache, available, total_swap, used_swap, free_swap = stdout:match('(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*Swap:%s*(%d+)%s*(%d+)%s*(%d+)')
      ram:set_text("Ram: "..(get_percentage(used + used_swap) or "N/A"))
      widget:set_widget(ram)
    end)

    return true
  end

  ram_update()

  gears.timer.start_new(timeout, ram_update)

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
      title = "Memory Usage",
      timeout = t_out,
      screen = mouse.screen,
      position = popup_position
    })
  end

  -- Bind onclick event function
  if onclick then
    widget:buttons(awful.util.table.join(
      awful.button({}, 1, function() awful.util.spawn(onclick) end)
    ))
  end

  widget:connect_signal('mouse::enter', function() widget:show(0) end)
  widget:connect_signal('mouse::leave', function() widget:hide() end)
  return widget
end

return setmetatable(ram_widget, {__call = function(_, ...) return worker(...) end})
