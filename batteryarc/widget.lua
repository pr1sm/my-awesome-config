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
  local timeout = args.timeout or 30
  local popup_position = args.popup_position or naughty.config.defaults.position
  local font = args.font or "Play 5"

  -- Widgets
  
  -- main text
  local text = wibox.widget.textbox()
  text:set_align("center")
  -- mirrored text, since everything gets mirrored at the end
  local mirrored_text = wibox.container.mirror(text, { horizontal = true })
  -- mirrored text, with background
  local mirrored_text_bg = wibox.container.background(mirrored_text)
  -- arcchart
  local battery_arc = wibox.widget {
    mirrored_text_bg,
    min_value = 0,
    max_value = 1,
    rounded_edge = true,
    thickness = 2,
    start_angle = 2*math.pi*(3/4),
    forced_height = 18,
    forced_width = 18,
    bg = "#ffffff11",
    paddings = 2,
    widget = wibox.container.arcchart,
  }
  -- mirrored widget to increase clockwise
  local widget = wibox.container.mirror(battery_arc, { horizontal = true })

  -- battery graph
  local battery_graph = wibox.widget {
    max_value = 100,
    min_value = 0,
    forced_width = 200,
    step_width = 3,
    step_spacing = 1,
    step_shape = function(cr, width, height)
      cr:set_source(gears.color(beautiful.widget_green))
      return gears.shape.rectangle(cr, width, height)
    end,
    background_color = "#ffffff11",
    widget = wibox.widget.graph,
  }

  local battery_graph_mirrored = wibox.container.mirror(battery_graph, { horizontal = true })

  local battery_detail_text = wibox.widget.textbox()
  battery_detail_text:set_text("")
  battery_detail_text:set_font(font)

  local battery_detail_container = wibox.widget {
    battery_detail_text,
    battery_graph_mirrored,
    layout = wibox.layout.align.vertical,
  }

  -- wibox battery detail
  local battery_detail = wibox {
    height = 200,
    width = 210,
    ontop = true,
    screen = mouse.screen,
    expand = true,
    bg = '#1e252c',
    max_widget_size = 500,
  }

  battery_detail:setup {
    battery_detail_container,
    left = 5,
    right = 5,
    top = 5,
    bottom = 5,
    id = "battery_detail",
    widget = wibox.container.margin,
  }

  -- Widget Setup
  text:set_text("")
  text:set_font(font)

  -- Local Variables

  -- time for last battery check (when in critical)
  local last_battery_check = os.time()
  -- data structure for storing battery info records
  local batt_info = {
    records = {},
    records_count = 0,
    records_cap = 50,
    records_pop = function(self)
      table.remove(self.records, 1)
      self.records_count = self.records_count - 1
    end,
    records_push = function(self, record)
      table.insert(self.records, record)
      self.records_count = self.records_count + 1
      if self.records_count > self.records_cap then
        self.records_pop(self)
      end
    end,
  }
  -- Notification Object
  local notification = nil

  local function parse_acpi_output(output)
    local info = {}
    -- Get info for each battery device
    for s in output:gmatch("[^\r\n]+") do
      local name, status, charge_str, time, _ = string.match(s, '(.+): (%w+), (%d?%d?%d)%%, (%d*:?%d*:?%d*).*')
      table.insert(info, { name = name, status = status, charge = tonumber(charge_str), time = time })
    end

    return info
  end

  local function text_grabber()
    local msg = ""
    local font = beautiful.font
    local raw_acpi_text = ""
    -- Get the current battery info
    f = io.popen("acpi")
    for line in f:lines() do
      raw_acpi_text = raw_acpi_text..line
    end
    f:close()

    -- Parse the battery info string
    local info = parse_acpi_output(raw_acpi_text)

    -- Craft Message Header
    msg = msg.."<span font_desc=\""..font.."\" size=\"large\"><b>Battery Status</b></span>"

    -- Craft Battery Info Sections
    for _, battery in ipairs(info) do
      local time_label = battery.time.." remaining"
      local status = battery.status
      if battery.charge == 100 then
        time_label = "N/A"
        status = "Charged"
        if battery.status == 'Charging' then
          status = status.." (on AC)"
        end
      elseif battery.status == 'Charging' then
        time_label = battery.time.." until charged"
      end
      msg = msg.."\n"..
            "<span font_desc=\""..font.."\">"..battery.name.."</span>\n"..
            "<span font_desc=\""..font.."\">├Charge:\t"..battery.charge.."%</span>\n"..
            "<span font_desc=\""..font.."\">├Status:\t"..status.."</span>\n"..
            "<span font_desc=\""..font.."\">└Time:\t"..time_label.."</span>"
    end
    return msg
  end

  local function battery_update()
    awful.spawn.easy_async("bash -c \"acpi\"", function(stdout, stderr, reason, exit_code)
      local time
      local charge = 0
      local charge_sum = 0
      local count = 0
      local charge_val = 0.0
      local status

      -- Get info for each battery device
      local info = parse_acpi_output(stdout)

      -- Get an average battery charge
      for _, record in ipairs(info) do
        if record.charge >= charge then
          charge = record.charge -- use most charged battery status
          status = record.status  -- this is arbitrary and maybe another metric should be used
        end
        charge_sum = charge_sum + record.charge
        count = count + 1
      end
      charge = charge_sum / count
      charge_val = charge / 100.0
      time = os.time()

      -- store battery info
      batt_info.records_push(batt_info, {
        time = time,
        status = status,
        charge_avg = charge,
        charge_val = charge_val,
        charge_data = info,
        charge_count = count
      })

      -- set correct value
      battery_arc.value = charge_val

      -- set the correct background color
      if status == 'Charging' then
        mirrored_text_bg.bg = beautiful.widget_green
        mirrored_text_bg.fg = beautiful.widget_black
      else
        mirrored_text_bg.bg = beautiful.widget_transparent
        mirrored_text_bg.fg = beautiful.widget_main_color
      end

      -- set the correct color
      if charge < 15 then
        battery_arc.colors = { beautiful.widget_red }
        -- check if 5 minutes have elapsed since last warning
        if status ~= 'Charging' and os.difftime(os.time(), last_battery_check) > 300 then
          last_battery_check = os.time()
          widget:show_warning(0)
        end
      elseif charge > 15 and charge < 40 then
        battery_arc.colors = { beautiful.widget_yellow }
      else
        battery_arc.colors = { beautiful.widget_main_color }
      end

      if charge == 100 then
        text:set_text('+')
      else
        text:set_text(charge)
      end
    end)

    return true
  end

  -- hide notification if it is showing
  function widget:hide()
    if notification ~= nil then
      naughty.destroy(notification)
      notification = nil
    end
    if battery_detail.visible then
      battery_detail.visible = false
    end
  end

  -- show battery status notification
  function widget:show(t_out)
    widget:hide()

    local msg = text_grabber()

    awful.placement.top_right(battery_detail, { margins = { top = 25, right = 5 } })
    battery_graph:clear()
    for _, record in ipairs(batt_info.records) do
      battery_graph:add_value(record.charge_avg)
    end
    battery_detail_text:set_markup_silently(msg)
    battery_detail.visible = true
  end

  -- show battery warning notification
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

  -- attach an on click handler if given one
  if onclick then
    widget:buttons(awful.util.table.join(
      awful.button({}, 1, function() awful.util.spawn(onclick) end)
    ))
  end

  -- connect signals to show/hide battery status notification when entering/leaving the widget area
  widget:connect_signal('mouse::enter', function() widget:show(0) end)
  widget:connect_signal('mouse::leave', function() widget:hide() end)

  -- call first battery update
  battery_update()

  -- start timer to continue calling battery update
  gears.timer.start_new(timeout, battery_update)

  -- return widget
  return widget
end

return setmetatable(battery_widget, {__call = function(_, ...) return worker(...) end})
