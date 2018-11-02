local wibox = require("wibox")
local awful = require("awful")
local beautiful = require("beautiful")
local naughty = require("naughty")
local gears = require("gears")

local ram_widget = {}

local function worker(args)
  -- Args
  local args = args or {}
  local ICON_DIR = awful.util.getdir("config").."/ram/icons/"

  -- Settings
  local timeout = args.timeout or 5
  local popup_position = args.popup_position or naughty.config.defaults.position
  local font = args.font or beautiful.font

  local ram_info = {}

  -- Widgets
  local ram = wibox.widget.textbox()
  local ram_image = wibox.widget {
    image = ICON_DIR.."ram_128.png",
    resize = true,
    forced_height = 18,
    paddings = 2,
    widget = wibox.widget.imagebox
  }
  local ram_image_margin = wibox.widget {
    ram_image,
    right = 2,
    widget = wibox.container.margin
  }
  local background = wibox.widget {
    ram_image_margin,
    ram,
    left = 2,
    right = 2,
    layout = wibox.layout.fixed.horizontal,
    widget = wibox.container.background
  }
  local widget = wibox.widget {
    background,
    left = 2,
    right = 2,
    widget = wibox.container.margin
  }

  -- ram graph
  local ram_graph = wibox.widget {
    data_list = {
      { 'Used', 34 },
      { 'Free', 33 },
      { 'Cache', 33 },
    },
    colors = {
      gears.color("#e53935"),
      gears.color("#43a047"),
      gears.color("#c0ca33"),
    },
    forced_width = 100,
    border_width = 1,
    border_color = gears.color("#000000"),
    display_labels = true,
    widget = wibox.widget.piechart,
  }

  -- Ram Detail

  local ram_detail_header = wibox.widget {
    text = "Memory Usage",
    font = font,
    align = "center",
    widget = wibox.widget.textbox,
  }
  ram_detail_header:set_markup_silently(
    "<b><big>Memory Usage</big></b>"
  )

  local function createDetailTextbox()
    return wibox.widget {
      text = "",
      font = font,
      align = "center",
      widget = wibox.widget.textbox,
    }
  end

  local ram_detail_text = {
    used = createDetailTextbox(),
    free = createDetailTextbox(),
    cache = createDetailTextbox(),
  }

  local ram_detail_text_container = wibox.widget {
    ram_detail_text.used,
    ram_detail_text.free,
    ram_detail_text.cache,
    align = "center",
    layout = wibox.layout.flex.horizontal,
  }

  local ram_detail_header_container = wibox.widget {
    ram_detail_header,
    ram_detail_text_container,
    layout = wibox.layout.flex.vertical,
  }

  local ram_detail_container = wibox.widget {
    ram_detail_header_container,
    ram_graph,
    layout = wibox.layout.align.vertical,
  }

  -- wibox ram detail
  local ram_detail = wibox {
    height = 200,
    width = 270,
    ontop = true,
    screen = mouse.screen,
    expand = true,
    bg = '#1e252c',
    max_widget_size = 500,
  }

  ram_detail:setup {
    ram_detail_container,
    left = 5,
    right = 5,
    top = 5,
    bottom = 5,
    id = "battery_detail",
    widget = wibox.container.margin,
  }

  local function get_percentage(value)
    if (ram_info.total + ram_info.total_swap) == 0 then
      return 0
    end
    return math.floor(value / (ram_info.total + ram_info.total_swap) * 100 + 0.5)
  end

  local function get_percentage_str(value)
    return get_percentage(value)..'%'
  end

  local function get_ram_values(output)
    -- Parse ram values and put them into the map
    local total, used, free, shared, buff_cache, available, total_swap, used_swap, free_swap = output:match('(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*(%d+)%s*Swap:%s*(%d+)%s*(%d+)%s*(%d+)')
    return {
      total = total,
      used = used,
      free = free,
      shared = shared,
      buff_cache = buff_cache,
      available = available,
      total_swap = total_swap,
      used_swap = used_swap,
      free_swap = free_swap
    }
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
    ram_info = get_ram_values(raw_mem_text)

    msg = "<span font_desc=\""..font.."\">"..
          "┌Used:\t"..get_percentage_str(ram_info.used + ram_info.used_swap).."\n"..
          "├Free:\t"..get_percentage_str(ram_info.free + ram_info.free_swap).."\n"..
          "└Cache:\t"..get_percentage_str(ram_info.buff_cache).."</span>"
    return msg
  end

  local function ram_update()
    awful.spawn.easy_async("bash -c \"free | grep -z Mem.*Swap.*\"", function(stdout, stderr, reason, exit_code)
      ram_info = get_ram_values(stdout)
      ram:set_text((get_percentage_str(ram_info.used + ram_info.used_swap) or "N/A"))
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
    if ram_detail.visible then
      ram_detail.visible = false
    end
  end

  function widget:show(t_out)
    widget:hide()

    local function formatText(label, value)
      return "<span font_desc=\""..beautiful.font.."\">"..label..": "..value.."</span>"
    end

    awful.placement.top_right(ram_detail, { margins = { top = 25, right = 5 } })

    ram_graph:set_data_list({
      { 'Used', get_percentage(ram_info.used + ram_info.used_swap) },
      { 'Free', get_percentage(ram_info.free + ram_info.free_swap) },
      { 'Cache', get_percentage(ram_info.buff_cache) },
    })
    ram_detail_text.used:set_markup_silently(formatText('Used', get_percentage_str(ram_info.used + ram_info.used_swap)))
    ram_detail_text.free:set_markup_silently(formatText('Free', get_percentage_str(ram_info.free + ram_info.free_swap)))
    ram_detail_text.cache:set_markup_silently(formatText('Cache', get_percentage_str(ram_info.buff_cache)))
    ram_detail:set_screen(mouse.screen)
    ram_detail.visible = true
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
