local curl = require("plenary.curl")
local util = require("weather.util")

local result = {}
local cache = {}  -- Cache storage
local CACHE_DURATION = 300  -- Cache duration (seconds), 5 minutes

local function is_cache_valid(cache_entry)
  if not cache_entry or not cache_entry.timestamp then
    return false
  end
  return os.time() - cache_entry.timestamp < CACHE_DURATION
end

local function call_wttr(city)
  -- Check cache
  if cache[city] and is_cache_valid(cache[city]) then
    return cache[city].data
  end

  local url = string.format("https://wttr.in/%s?format=j1", city)
  local response = curl.get({ url = url })

  if response and response.body then
    local weather_data = vim.json.decode(response.body)
    if weather_data then
      -- Update cache
      cache[city] = {
        data = weather_data,
        timestamp = os.time()
      }
      return weather_data
    end
  end

  return nil
end

-- Add function to clear cache
result.clear_cache = function()
  cache = {}
  vim.notify("Weather cache cleared")
end

-- Create loading window
local function create_loading_window()
  local loading_buf = vim.api.nvim_create_buf(false, true)
  local loading_text = {"Fetching weather data...", "", "Please wait..."}
  vim.api.nvim_buf_set_lines(loading_buf, 0, -1, false, loading_text)

  local current_win = vim.api.nvim_get_current_win()
  local win_height = vim.api.nvim_win_get_height(current_win)
  local win_width = vim.api.nvim_win_get_width(current_win)

  local loading_width = 30
  local loading_height = #loading_text
  local loading_row = math.floor((win_height - loading_height) / 2)
  local loading_col = math.floor((win_width - loading_width) / 2)

  local loading_opts = {
    relative = 'win',
    win = current_win,
    row = loading_row,
    col = loading_col,
    width = loading_width,
    height = loading_height,
    style = 'minimal',
    border = 'rounded'
  }

  local loading_win = vim.api.nvim_open_win(loading_buf, true, loading_opts)

  -- Set buffer options
  vim.api.nvim_buf_set_option(loading_buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(loading_buf, 'bufhidden', 'wipe')

  return loading_win
end

-- Weather code to emoji mapping
local function get_weather_emoji_map()
  return {
    -- Sunny/Clear
    ["113"] = "☀️",
    -- Partly Cloudy
    ["116"] = "⛅️",
    -- Cloudy
    ["119"] = "☁️",
    -- Very Cloudy
    ["122"] = "☁️",
    -- Fog
    ["143"] = "🌫️",
    ["248"] = "🌫️",
    ["260"] = "🌫️",
    -- Light Rain/Showers
    ["176"] = "🌦️",
    ["263"] = "🌦️",
    ["293"] = "🌦️",
    ["296"] = "🌦️",
    ["353"] = "🌦️",
    -- Light Sleet
    ["179"] = "🌧️",
    ["182"] = "🌧️",
    ["185"] = "🌧️",
    ["281"] = "🌧️",
    ["284"] = "🌧️",
    ["311"] = "🌧️",
    ["314"] = "🌧️",
    ["317"] = "🌧️",
    ["350"] = "🌧️",
    ["377"] = "🌧️",
    -- Light Snow
    ["227"] = "🌨️",
    ["320"] = "🌨️",
    ["323"] = "🌨️",
    ["326"] = "🌨️",
    ["368"] = "🌨️",
    -- Heavy Rain
    ["299"] = "🌧️",
    ["302"] = "🌧️",
    ["305"] = "🌧️",
    ["308"] = "🌧️",
    ["356"] = "🌧️",
    ["359"] = "🌧️",
    -- Heavy Snow
    ["230"] = "❄️",
    ["329"] = "❄️",
    ["332"] = "❄️",
    ["335"] = "❄️",
    ["338"] = "❄️",
    ["371"] = "❄️",
    ["395"] = "❄️",
    -- Thunder
    ["200"] = "⛈️",
    ["386"] = "⛈️",
    ["389"] = "⛈️",
    ["392"] = "⛈️",
    -- Light Sleet Showers
    ["362"] = "🌧️",
    ["365"] = "🌧️",
    ["374"] = "🌧️",
  }
end

local function get_weather_emoji(weather_code)
  local emoji_map = get_weather_emoji_map()
  return emoji_map[weather_code] or "✨"  -- Use ✨ as default icon for unknown weather
end

-- Collect city weather data
local function collect_weather_data(cities)
  local all_daily_temps = {}
  local min_temp_all, max_temp_all = 100, -100
  local current_weather_data = {}  -- Store current weather data

  for i, city in ipairs(cities) do
    local weather_data = call_wttr(city)

    if not weather_data or not weather_data.nearest_area or #weather_data.nearest_area == 0 then
      vim.api.nvim_err_writeln("Failed to retrieve weather data for " .. city)
      goto continue
    end

    -- Store current weather data for later use
    if weather_data.current_condition and #weather_data.current_condition > 0 then
      current_weather_data[city] = weather_data.current_condition[1]
    end

    -- Get city name
    local city_name = weather_data.nearest_area[1].areaName[1].value
    local region = weather_data.nearest_area[1].region[1].value

    -- Calculate temperature range
    local daily_temps = {}
    for i = 1, math.min(3, #weather_data.weather) do
      local day = weather_data.weather[i]
      local max_temp = tonumber(day.maxtempC)
      local min_temp = tonumber(day.mintempC)
      local avg_temp = tonumber(day.avgtempC)
      local date = day.date
      local astronomy = day.astronomy[1]

      -- Find weather conditions for max and min temperatures
      local max_temp_weather_code = "113"  -- Default sunny
      local min_temp_weather_code = "113"
      if day.hourly then
        for _, hour in ipairs(day.hourly) do
          local temp = tonumber(hour.tempC)
          if temp == max_temp then
            max_temp_weather_code = hour.weatherCode
          end
          if temp == min_temp then
            min_temp_weather_code = hour.weatherCode
          end
        end
      end

      table.insert(daily_temps, {
        date = date,
        max = max_temp,
        min = min_temp,
        avg = avg_temp,
        sunrise = astronomy.sunrise,
        sunset = astronomy.sunset,
        max_weather_code = max_temp_weather_code,
        min_weather_code = min_temp_weather_code
      })

      min_temp_all = math.min(min_temp_all, min_temp)
      max_temp_all = math.max(max_temp_all, max_temp)
    end

    -- Sort by date
    table.sort(daily_temps, function(a, b) return a.date < b.date end)
    table.insert(all_daily_temps, {
      city = string.format("%s, %s", city_name, region),
      temps = daily_temps
    })

    ::continue::
  end

  -- Add some margin to temperature range
  min_temp_all = math.floor(min_temp_all - 1)
  max_temp_all = math.ceil(max_temp_all + 1)

  return all_daily_temps, min_temp_all, max_temp_all, current_weather_data
end

-- Create city name and current weather lines
local function create_header_lines(all_daily_temps, cities, current_weather_data, temp_width, padding, col_width, city_spacing)
  local city_line = string.rep(" ", temp_width + #padding)
  local emoji_line = string.rep(" ", temp_width + #padding)  -- Emoji line
  local current_weather_line = "Now:"  -- Current weather line
  local city_start_positions = {}

  -- Record start position of each city name
  for i, city_data in ipairs(all_daily_temps) do
    table.insert(city_start_positions, #city_line)
    city_line = city_line .. string.format("%-" .. (col_width * 3) .. "s", city_data.city)
    city_line = city_line .. string.rep(" ", city_spacing)
  end

  -- Reset current weather and emoji lines for alignment
  current_weather_line = "Now:"
  emoji_line = string.rep(" ", temp_width + #padding)

  -- Add current weather information
  for i, city in ipairs(cities) do
    local current_weather = current_weather_data[city]
    if current_weather then
      local current_temp = current_weather.temp_C  -- Without °C
      local current_feels = current_weather.FeelsLikeC  -- Without °C
      local weather_emoji = get_weather_emoji(current_weather.weatherCode)

      -- Calculate position for current city's weather info
      if i <= #city_start_positions then
        -- Calculate spaces needed to align with city name position
        local target_pos = city_start_positions[i]

        -- Align current weather line
        local current_pos = #current_weather_line
        local spaces_needed = target_pos - current_pos
        if spaces_needed > 0 then
          current_weather_line = current_weather_line .. string.rep(" ", spaces_needed)
        end

        -- Align emoji line
        local emoji_pos = #emoji_line
        local emoji_spaces = target_pos - emoji_pos
        if emoji_spaces > 0 then
          emoji_line = emoji_line .. string.rep(" ", emoji_spaces)
        end

        -- Add current weather info (without emoji and units)
        current_weather_line = current_weather_line .. string.format("%-" .. (col_width * 3) .. "s",
          string.format("%s (Feel %s)",
            current_temp,
            current_feels
          )
        )

        -- Add emoji to separate line, centered
        local emoji_padding = math.floor((col_width * 3 - #weather_emoji) / 2)
        emoji_line = emoji_line .. string.format("%" .. emoji_padding .. "s%s%" ..
          (col_width * 3 - emoji_padding - #weather_emoji) .. "s", "", weather_emoji, "")

        -- Add city spacing
        if i < #cities and i < #city_start_positions then
          current_weather_line = current_weather_line .. string.rep(" ", city_spacing)
          emoji_line = emoji_line .. string.rep(" ", city_spacing)
        end
      end
    end
  end

  return city_line, emoji_line, current_weather_line
end

-- Create temperature chart lines
local function create_temperature_lines(all_daily_temps, min_temp_all, max_temp_all, temp_width, padding, col_width, city_spacing)
  local temp_lines = {}
  local temp_highlights = {}  -- Keep this variable, but no longer add highlight info

  for temp = max_temp_all, min_temp_all, -1 do
    local line = string.format("%2d°C %s", temp, padding)  -- Show °C in temperature scale
    local line_idx = #temp_lines + 1

    -- Add temperature markers for each city
    local current_pos = #line
    for _, city_data in ipairs(all_daily_temps) do
      for _, day in ipairs(city_data.temps) do
        if temp == math.floor(day.max) then
          local square_pos = current_pos + math.floor(col_width/2)
          line = line .. string.format("%" .. math.floor(col_width/2) .. "s%-" .. math.floor(col_width/2) .. "s", "H", "")
        elseif temp == math.floor(day.min) then
          local square_pos = current_pos + math.floor(col_width/2)
          line = line .. string.format("%" .. math.floor(col_width/2) .. "s%-" .. math.floor(col_width/2) .. "s", "L", "")
        else
          line = line .. string.rep(" ", col_width)
        end
        current_pos = current_pos + col_width
      end
      line = line .. string.rep(" ", city_spacing)  -- Add spacing between cities
      current_pos = current_pos + city_spacing
    end
    table.insert(temp_lines, line)
  end

  return temp_lines, temp_highlights
end

-- Create date line
local function create_date_line(all_daily_temps, temp_width, padding, col_width, city_spacing)
  local date_line = string.rep(" ", temp_width + #padding)

  for _, city_data in ipairs(all_daily_temps) do
    for _, day in ipairs(city_data.temps) do
      date_line = date_line .. string.format("%-" .. col_width .. "s", string.sub(day.date, 6))
    end
    date_line = date_line .. string.rep(" ", city_spacing)
  end

  return date_line
end

-- Create floating window and display weather info
local function create_weather_window(lines)
  local current_win = vim.api.nvim_get_current_win()
  local win_height = vim.api.nvim_win_get_height(current_win)
  local win_width = vim.api.nvim_win_get_width(current_win)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Calculate window size
  local width = 0
  for _, line in ipairs(lines) do
    width = math.max(width, #line)
  end
  width = width + 2  -- Add some margin

  local height = #lines
  local row = math.floor((win_height - height) / 2)
  local col = math.floor((win_width - width) / 2)

  local opts = {
    relative = 'win',
    win = current_win,
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded'
  }

  local win = vim.api.nvim_open_win(buf, true, opts)

  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  -- Set close shortcuts
  vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', {noremap = true, silent = true})
  vim.api.nvim_buf_set_keymap(buf, 'n', '<ESC>', ':q<CR>', {noremap = true, silent = true})

  return buf, win
end

-- Apply current date highlight
local function apply_date_highlight(buf, all_daily_temps, temp_width, padding, col_width, city_spacing)
  local current_date = os.date("%Y-%m-%d")
  local ns_id = vim.api.nvim_create_namespace('weather_date_highlight')  -- Use different namespace
  local highlight_pos = vim.api.nvim_buf_line_count(buf) - 1  -- Date line position (last line)

  -- Add highlight for current date in each city
  local current_pos = temp_width + #padding
  for _, city_data in ipairs(all_daily_temps) do
    for i, day in ipairs(city_data.temps) do
      if day.date == current_date then
        local highlight_start = current_pos + (i-1) * col_width
        local highlight_length = 5  -- Length of "MM-DD"
        vim.api.nvim_buf_add_highlight(buf, ns_id, 'ErrorMsg', highlight_pos, highlight_start, highlight_start + highlight_length)
      end
    end
    current_pos = current_pos + col_width * #city_data.temps + city_spacing
  end
end

-- Main function: display weather info
result.display_weather = function(cities)
  if type(cities) ~= "table" then
    cities = {cities}  -- Convert single city to array
  end

  -- Only take first three cities
  if #cities > 3 then
    cities = {cities[1], cities[2], cities[3]}
    vim.notify("Only showing weather for the first 3 cities", vim.log.levels.INFO)
  end

  -- Create loading window
  local loading_win = create_loading_window()

  -- Use vim.schedule to ensure UI updates
  vim.schedule(function()
    -- Fixed width settings
    local temp_width = 5    -- Temperature scale width "XX°C "
    local col_width = 7     -- Column width
    local city_spacing = 4  -- Spacing between cities
    local padding = string.rep(" ", 2)  -- Spacing between temperature scale and chart

    -- Collect city weather data
    local all_daily_temps, min_temp_all, max_temp_all, current_weather_data = collect_weather_data(cities)

    -- Close loading window
    vim.api.nvim_win_close(loading_win, true)

    -- If no data retrieved, show error and return
    if #all_daily_temps == 0 then
      vim.api.nvim_err_writeln("Failed to retrieve weather data for any city")
      return
    end

    -- Create city name and current weather lines
    local city_line, emoji_line, current_weather_line = create_header_lines(all_daily_temps, cities, current_weather_data, temp_width, padding, col_width, city_spacing)

    -- Create temperature chart lines
    local temp_lines, temp_highlights = create_temperature_lines(all_daily_temps, min_temp_all, max_temp_all, temp_width, padding, col_width, city_spacing)

    -- Create date line
    local date_line = create_date_line(all_daily_temps, temp_width, padding, col_width, city_spacing)

    -- Build all lines
    local lines = {
      city_line,
      emoji_line,
      current_weather_line,
      ""  -- Empty line
    }

    -- Add temperature chart lines
    for _, line in ipairs(temp_lines) do
      table.insert(lines, line)
    end

    -- Add date line
    table.insert(lines, date_line)

    -- Create floating window and display weather info
    local buf, win = create_weather_window(lines)

    -- Apply current date highlight - apply date highlight later
    apply_date_highlight(buf, all_daily_temps, temp_width, padding, col_width, city_spacing)
  end)
end

return result
