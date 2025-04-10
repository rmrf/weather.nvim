-- (Keep all existing code from the beginning until create_weather_window)
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
  -- Add a User-Agent to potentially avoid blocks
  local response = curl.get({
    url = url,
    headers = {
      ["User-Agent"] = "curl/7.68.0" -- Example User-Agent
    }
  })


  if response and response.body then
    -- Add error handling for non-JSON responses
    local success, weather_data = pcall(vim.json.decode, response.body)
    if success and weather_data then
      -- Update cache
      cache[city] = {
        data = weather_data,
        timestamp = os.time()
      }
      return weather_data
    else
      vim.notify("Failed to decode weather data for " .. city .. ". Response: " .. (response.body or "empty"), vim.log.levels.WARN)
    end
  else
     vim.notify("No response or empty body received for " .. city, vim.log.levels.WARN)
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

  -- Error handling for window creation
  local ok, loading_win = pcall(vim.api.nvim_open_win, loading_buf, true, loading_opts)
  if not ok then
      vim.notify("Failed to create loading window", vim.log.levels.ERROR)
      return nil
  end

  -- Set buffer options
  pcall(vim.api.nvim_buf_set_option, loading_buf, 'modifiable', false)
  pcall(vim.api.nvim_buf_set_option, loading_buf, 'bufhidden', 'wipe')

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
  local success_count = 0

  for i, city in ipairs(cities) do
    local weather_data = call_wttr(city)

    -- More robust check for valid data structure
    if not weather_data or type(weather_data) ~= 'table' or
       not weather_data.nearest_area or type(weather_data.nearest_area) ~= 'table' or #weather_data.nearest_area == 0 or
       not weather_data.weather or type(weather_data.weather) ~= 'table' then
      vim.notify("Incomplete or invalid weather data structure for " .. city, vim.log.levels.WARN)
      goto continue -- Use goto to skip to the next iteration
    end

    success_count = success_count + 1 -- Increment count if data is valid so far

    -- Store current weather data for later use
    if weather_data.current_condition and type(weather_data.current_condition) == 'table' and #weather_data.current_condition > 0 then
       -- Check nested structure validity before accessing
       local current_cond = weather_data.current_condition[1]
       if type(current_cond) == 'table' and current_cond.temp_C and current_cond.FeelsLikeC and current_cond.weatherCode then
            current_weather_data[city] = current_cond
       else
            vim.notify("Invalid current_condition structure for " .. city, vim.log.levels.WARN)
       end
    end


    -- Get city name (with more checks)
    local city_name = "Unknown City"
    local region = "Unknown Region"
    local nearest_area = weather_data.nearest_area[1]
    if type(nearest_area) == 'table' then
        if nearest_area.areaName and type(nearest_area.areaName) == 'table' and #nearest_area.areaName > 0 and
           type(nearest_area.areaName[1]) == 'table' and nearest_area.areaName[1].value then
            city_name = nearest_area.areaName[1].value
        end
        if nearest_area.region and type(nearest_area.region) == 'table' and #nearest_area.region > 0 and
           type(nearest_area.region[1]) == 'table' and nearest_area.region[1].value then
            region = nearest_area.region[1].value
        end
    end


    -- Calculate temperature range
    local daily_temps = {}
    for day_idx = 1, math.min(3, #weather_data.weather) do
      local day = weather_data.weather[day_idx]

      -- Check if day data is valid
      if type(day) ~= 'table' or not day.maxtempC or not day.mintempC or not day.avgtempC or not day.date or not day.astronomy or type(day.astronomy) ~= 'table' or #day.astronomy == 0 then
         vim.notify(string.format("Invalid daily weather data structure for %s on day %d", city, day_idx), vim.log.levels.WARN)
         goto next_day -- Skip this day if structure is invalid
      end

      local max_temp = tonumber(day.maxtempC)
      local min_temp = tonumber(day.mintempC)
      local avg_temp = tonumber(day.avgtempC)
      local date = day.date
      local astronomy = day.astronomy[1]

      -- Check if astronomy data is valid
       if type(astronomy) ~= 'table' or not astronomy.sunrise or not astronomy.sunset then
          vim.notify(string.format("Invalid astronomy data for %s on day %d", city, day_idx), vim.log.levels.WARN)
          astronomy = { sunrise = "N/A", sunset = "N/A" } -- Provide defaults
       end


      -- Find weather conditions for max and min temperatures (with checks)
      local max_temp_weather_code = "113"  -- Default sunny
      local min_temp_weather_code = "113"
      if day.hourly and type(day.hourly) == 'table' then
        for _, hour in ipairs(day.hourly) do
           -- Check if hourly data is valid
           if type(hour) == 'table' and hour.tempC and hour.weatherCode then
              local temp = tonumber(hour.tempC)
              if temp and max_temp and temp == max_temp then -- Ensure max_temp is a number
                max_temp_weather_code = hour.weatherCode
              end
              if temp and min_temp and temp == min_temp then -- Ensure min_temp is a number
                min_temp_weather_code = hour.weatherCode
              end
           end
        end
      end

       -- Ensure temps are numbers before comparing/inserting
      if not max_temp or not min_temp or not avg_temp then
         vim.notify(string.format("Invalid temperature values for %s on day %d", city, day_idx), vim.log.levels.WARN)
         goto next_day -- Skip this day if temps are not valid numbers
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

      ::next_day:: -- Label for skipping a day within the loop
    end

    -- Only insert if we got some valid daily temps
    if #daily_temps > 0 then
        -- Sort by date
        table.sort(daily_temps, function(a, b) return a.date < b.date end)
        table.insert(all_daily_temps, {
          city = string.format("%s, %s", city_name, region),
          temps = daily_temps
        })
    end


    ::continue:: -- Label for skipping a city within the loop
  end

  -- Check if any data was successfully retrieved
  if success_count == 0 then
     return {}, nil, nil, {} -- Return empty tables and nil if no city data was fetched
  end


  -- Add some margin to temperature range only if temps were found
  if min_temp_all <= max_temp_all then -- Check if min/max were updated
    min_temp_all = math.floor(min_temp_all - 1)
    max_temp_all = math.ceil(max_temp_all + 1)
  else
      -- Handle case where no valid temps were found across all cities
      min_temp_all = 0
      max_temp_all = 10
      vim.notify("Could not determine temperature range, using default.", vim.log.levels.WARN)
  end


  return all_daily_temps, min_temp_all, max_temp_all, current_weather_data
end


-- Create city name and current weather lines
local function create_header_lines(all_daily_temps, cities, current_weather_data, temp_width, padding, col_width, city_spacing)
  local city_line = string.rep(" ", temp_width + #padding)
  local emoji_line = string.rep(" ", temp_width + #padding)  -- Emoji line
  local current_weather_line = "Now:"  -- Current weather line start, pad later if needed
  local city_start_positions = {}

  local current_city_line_pos = temp_width + #padding
  local current_emoji_line_pos = temp_width + #padding
  local current_weather_line_pos = string.len(current_weather_line)

  -- Phase 1: Build City Line and record positions
  for i, city_data in ipairs(all_daily_temps) do
      local city_display_name = city_data.city or "Unknown City" -- Fallback
      local city_col_span = col_width * math.max(1, #city_data.temps) -- Calculate span based on number of days

      table.insert(city_start_positions, current_city_line_pos)

      -- Format city name centered within its span
      local city_padding_total = city_col_span - #city_display_name
      local city_padding_left = math.floor(city_padding_total / 2)
      local city_padding_right = city_col_span - #city_display_name - city_padding_left
      local formatted_city = string.format("%s%s%s", string.rep(" ", city_padding_left), city_display_name, string.rep(" ", city_padding_right))

      city_line = city_line .. formatted_city

      if i < #all_daily_temps then -- Add spacing only between cities
          city_line = city_line .. string.rep(" ", city_spacing)
          current_city_line_pos = current_city_line_pos + city_col_span + city_spacing
      else
          current_city_line_pos = current_city_line_pos + city_col_span
      end
  end


  -- Phase 2: Build Emoji and Current Weather lines using recorded positions
  for i, city in ipairs(cities) do
      if i > #city_start_positions then break end -- Safety check

      local target_start_col = city_start_positions[i]
      local city_data = all_daily_temps[i]
      local city_col_span = col_width * math.max(1, #city_data.temps)

      -- Align Emoji Line
      local emoji_spaces_needed = target_start_col - current_emoji_line_pos
      if emoji_spaces_needed > 0 then
          emoji_line = emoji_line .. string.rep(" ", emoji_spaces_needed)
      end
      local current_weather = current_weather_data[city]
      local weather_emoji = " " -- Default to space if no current weather
      if current_weather and current_weather.weatherCode then
          weather_emoji = get_weather_emoji(current_weather.weatherCode)
      end
      -- Center emoji within the city's span
      local emoji_padding_total = city_col_span - #weather_emoji
      local emoji_padding_left = math.floor(emoji_padding_total / 2)
      local emoji_padding_right = city_col_span - #weather_emoji - emoji_padding_left
      emoji_line = emoji_line .. string.format("%s%s%s", string.rep(" ", emoji_padding_left), weather_emoji, string.rep(" ", emoji_padding_right))
      current_emoji_line_pos = target_start_col + city_col_span

      -- Align Current Weather Line
      local weather_spaces_needed = target_start_col - current_weather_line_pos
      if weather_spaces_needed > 0 then
          current_weather_line = current_weather_line .. string.rep(" ", weather_spaces_needed)
      end
      local current_weather_text = "N/A" -- Default if no current weather
      if current_weather and current_weather.temp_C and current_weather.FeelsLikeC then
          current_weather_text = string.format("%s°(feel %s°)", -- Use ° symbol
              current_weather.temp_C,
              current_weather.FeelsLikeC
          )
      end
      -- Center current weather text within the city's span
      local weather_text_padding_total = city_col_span - #current_weather_text
      local weather_text_padding_left = math.floor(weather_text_padding_total / 2)
      local weather_text_padding_right = city_col_span - #current_weather_text - weather_text_padding_left
      current_weather_line = current_weather_line .. string.format("%s%s%s", string.rep(" ", weather_text_padding_left), current_weather_text, string.rep(" ", weather_text_padding_right))
      current_weather_line_pos = target_start_col + city_col_span


      -- Add spacing between cities for emoji and weather lines
      if i < #cities and i < #city_start_positions then
          emoji_line = emoji_line .. string.rep(" ", city_spacing)
          current_weather_line = current_weather_line .. string.rep(" ", city_spacing)
          current_emoji_line_pos = current_emoji_line_pos + city_spacing
          current_weather_line_pos = current_weather_line_pos + city_spacing
      end
  end


  -- Pad "Now:" if needed to align with the first city's content start
  if #city_start_positions > 0 then
       local first_city_start = city_start_positions[1]
       local now_label_len = string.len("Now:")
       if first_city_start > now_label_len then
            local padding_needed = first_city_start - now_label_len
            -- Find the position of the first non-space character after "Now:"
            local content_start_index = string.find(current_weather_line, "%S", now_label_len + 1)
            if content_start_index and content_start_index > first_city_start then
                 -- Only add padding if the content actually starts after the target column
                 -- This logic might need refinement depending on exact desired alignment
            elseif content_start_index and content_start_index < first_city_start then
                 padding_needed = first_city_start - content_start_index
                 current_weather_line = string.sub(current_weather_line, 1, now_label_len) ..
                                        string.rep(" ", padding_needed) ..
                                        string.sub(current_weather_line, now_label_len + 1)

            end

       end
  end

  if #all_daily_temps > 1 then
    local right_scale_width = #padding + (temp_width - 1)
    local right_padding = string.rep(" ", right_scale_width)
    city_line = city_line .. right_padding
    emoji_line = emoji_line .. right_padding
    current_weather_line = current_weather_line .. right_padding
  end

  return city_line, emoji_line, current_weather_line
end


-- Create temperature chart lines
local function create_temperature_lines(all_daily_temps, min_temp_all, max_temp_all, temp_width, padding, col_width, city_spacing)
    local temp_lines = {}
    -- Check if temperature range is valid
    if not max_temp_all or not min_temp_all or max_temp_all < min_temp_all then
        table.insert(temp_lines, string.rep(" ", temp_width + #padding) .. "Error: Invalid temperature range")
        return temp_lines
    end

    for temp = max_temp_all, min_temp_all, -1 do
        -- Ensure temp_width accommodates the label format, e.g., "-10°C " needs at least 6
        local temp_label = string.format("%d°C", temp)
        local line = string.format("%" .. (temp_width - 1) .. "s %s", temp_label, padding) -- Right-align temp label LEFT

        for city_idx, city_data in ipairs(all_daily_temps) do
            if city_data.temps and #city_data.temps > 0 then
                for day_idx, day in ipairs(city_data.temps) do
                    local marker = " " -- Default: empty space
                    local marker_pos_in_col = math.floor(col_width / 2) -- Position within the day's column

                    -- Ensure day.max and day.min are numbers before comparing
                    if day.max and day.min and type(day.max) == 'number' and type(day.min) == 'number' then
                        -- Use math.floor to get integer part for comparison
                        local floored_max = math.floor(day.max)
                        local floored_min = math.floor(day.min)

                        if temp == floored_max then
                            marker = "H"
                        elseif temp == floored_min then
                            marker = "L"
                        -- Add condition for the vertical line between H and L
                        elseif temp < floored_max and temp > floored_min then
                            marker = "|" -- Use vertical bar for temperatures between high and low
                        end
                        -- If max and min are the same, only H or L will be marked based on the order above.
                        -- If temp is outside the range [floored_min, floored_max], marker remains " ".
                    end

                    -- Construct the column string with the marker centered
                    local left_padding = string.rep(" ", marker_pos_in_col)
                    local right_padding = string.rep(" ", col_width - marker_pos_in_col - #marker)
                    line = line .. left_padding .. marker .. right_padding
                end
            else
                 -- If a city has no temp data (e.g., API error for that city), add empty space for its columns
                 -- Determine the number of days dynamically if possible, otherwise keep the assumption (e.g., 3)
                 local num_days = 3 -- Default assumption or get from data if available (e.g., #all_daily_temps[1].temps if guaranteed)
                 if city_data.temps and #city_data.temps > 0 then num_days = #city_data.temps end -- Or use a more robust way
                 line = line .. string.rep(" ", col_width * num_days)
            end

            if city_idx < #all_daily_temps then -- Add spacing only between cities
                line = line .. string.rep(" ", city_spacing)
            end
        end

        if #all_daily_temps > 1 then
          line = line .. padding .. string.format("%" .. (temp_width -1) .. "s", temp_label) -- Changed from "%-" to "%" for right-alignment
        end

        table.insert(temp_lines, line)
    end

    return temp_lines
end


-- Create date line
local function create_date_line(all_daily_temps, temp_width, padding, col_width, city_spacing)
  local date_line = string.rep(" ", temp_width + #padding)
  local current_pos = temp_width + #padding

  for city_idx, city_data in ipairs(all_daily_temps) do
      if city_data.temps and #city_data.temps > 0 then
          for day_idx, day in ipairs(city_data.temps) do
              local date_str = "??-??" -- Default/error value
              if day.date and type(day.date) == 'string' then
                  -- Extract MM-DD, handle potential errors
                  local month, day_num = string.match(day.date, "%d%d%d%d%-(%d%d)%-(%d%d)")
                  if month and day_num then
                      date_str = month .. "-" .. day_num
                  end
              end
              -- Center the date string within the column width
              local date_padding_total = col_width - #date_str
              local date_padding_left = math.floor(date_padding_total / 2)
              local date_padding_right = col_width - #date_str - date_padding_left
              date_line = date_line .. string.format("%s%s%s", string.rep(" ", date_padding_left), date_str, string.rep(" ", date_padding_right))

              current_pos = current_pos + col_width
          end
      else
           -- If city has no temp data, add empty space for its date columns
           date_line = date_line .. string.rep(" ", col_width * 3) -- Assuming max 3 days
           current_pos = current_pos + col_width * 3
      end


      if city_idx < #all_daily_temps then -- Add spacing only between cities
          date_line = date_line .. string.rep(" ", city_spacing)
          current_pos = current_pos + city_spacing
      end
  end

  if #all_daily_temps > 1 then
    local right_scale_width = #padding + (temp_width - 1)
    local right_padding = string.rep(" ", right_scale_width)
    date_line = date_line .. right_padding
  end

  return date_line
end


-- Create floating window and display weather info
local function create_weather_window(lines)
  local current_win = vim.api.nvim_get_current_win()
  local win_height = vim.api.nvim_win_get_height(current_win)
  local win_width = vim.api.nvim_win_get_width(current_win)

  -- Ensure lines is a table
  if type(lines) ~= "table" then
      lines = {"Error: Invalid content for weather window"}
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Calculate window size
  local max_line_width = 0
  for _, line in ipairs(lines) do
    -- Calculate width based on actual character count, not byte length
    max_line_width = math.max(max_line_width, vim.fn.strdisplaywidth(line))
  end
  local width = max_line_width + 2

  local height = #lines
  -- Ensure height and width are within reasonable bounds relative to screen size
  height = math.min(height, win_height - 4) -- Leave some space
  width = math.min(width, win_width - 4)


  -- Calculate position centered
  local row = math.floor((win_height - height) / 2)
  local col = math.floor((win_width - width) / 2)
  -- Ensure row/col are not negative if window is too large
  row = math.max(0, row)
  col = math.max(0, col)

  local opts = {
    relative = 'editor', -- Use 'editor' for centering relative to the whole editor
    row = row,
    col = col,
    width = width, -- Use the adjusted width
    height = height,
    style = 'minimal',
    border = 'rounded',
    zindex = 50 -- Ensure it appears above other floating windows
  }

  local win_ok, win = pcall(vim.api.nvim_open_win, buf, true, opts)
  if not win_ok then
      vim.notify("Failed to open weather window: " .. tostring(win), vim.log.levels.ERROR)
      pcall(vim.api.nvim_buf_delete, buf, {force = true}) -- Clean up buffer
      return nil, nil
  end

  -- Set buffer options
  pcall(vim.api.nvim_buf_set_option, buf, 'modifiable', false)
  pcall(vim.api.nvim_buf_set_option, buf, 'bufhidden', 'wipe')
  pcall(vim.api.nvim_buf_set_option, buf, 'buftype', 'nofile')
  pcall(vim.api.nvim_buf_set_option, buf, 'swapfile', false)
  pcall(vim.api.nvim_buf_set_option, buf, 'filetype', 'weather') -- Optional: for potential syntax later

  -- Set close shortcuts
  pcall(vim.api.nvim_buf_set_keymap, buf, 'n', 'q', '<Cmd>close<CR>', {noremap = true, silent = true})
  pcall(vim.api.nvim_buf_set_keymap, buf, 'n', '<ESC>', '<Cmd>close<CR>', {noremap = true, silent = true})

  return buf, win
end

-- Apply current date highlight
local function apply_date_highlight(buf, all_daily_temps, temp_width, padding, col_width, city_spacing)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end -- Check if buffer is valid

  local current_date = os.date("%Y-%m-%d")
  local ns_id = vim.api.nvim_create_namespace('weather_date_highlight')
  -- Date line is the last line
  local highlight_line_idx = vim.api.nvim_buf_line_count(buf) - 1 -- 0-indexed line number

  local current_col_offset = temp_width + #padding -- Start after temp scale and padding

  for city_idx, city_data in ipairs(all_daily_temps) do
      if city_data.temps and #city_data.temps > 0 then
          for day_idx, day in ipairs(city_data.temps) do
              if day.date and day.date == current_date then
                  local date_str = string.sub(day.date, 6) -- "MM-DD"
                  local date_len = #date_str
                  -- Calculate centered position start column
                  local date_padding_total = col_width - date_len
                  local date_padding_left = math.floor(date_padding_total / 2)
                  local highlight_start_col = current_col_offset + date_padding_left -- Column where "MM-DD" starts

                  -- Apply highlight safely
                  pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, 'ErrorMsg',
                        highlight_line_idx, highlight_start_col, highlight_start_col + date_len)
              end
              current_col_offset = current_col_offset + col_width -- Move to next day's column start
          end
      else
           -- Skip columns if city has no data
           current_col_offset = current_col_offset + col_width * 3 -- Assuming max 3 days
      end


      if city_idx < #all_daily_temps then -- Add spacing only between cities
          current_col_offset = current_col_offset + city_spacing
      end
  end
end


-- *** NEW FUNCTION: Apply high temperature highlight ***
local function apply_high_temp_highlight(buf, all_daily_temps, max_temp_all, temp_width, padding, col_width, city_spacing)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end -- Check if buffer is valid
  if not max_temp_all then return end -- Need max temp for line calculation

  local ns_id = vim.api.nvim_create_namespace('weather_high_temp_highlight')
  local header_lines = 4 -- Number of lines before the temperature chart starts (city, emoji, now, blank)

  local current_col_offset = temp_width + #padding -- Start after temp scale and padding

  for city_idx, city_data in ipairs(all_daily_temps) do
      if city_data.temps and #city_data.temps > 0 then
          for day_idx, day in ipairs(city_data.temps) do
              -- Check if day.max is a valid number
              if day.max and type(day.max) == 'number' then
                  local floored_max_temp = math.floor(day.max)
                  -- Calculate line number (0-indexed)
                  -- Line 0 of chart corresponds to max_temp_all
                  local chart_line_idx = max_temp_all - floored_max_temp
                  local highlight_line_idx = header_lines + chart_line_idx -- Add offset for header lines

                  -- Calculate column number (0-indexed)
                  local marker_pos_in_col = math.floor(col_width / 2) -- Position within the day's column
                  local highlight_start_col = current_col_offset + marker_pos_in_col -- Column where 'H' is placed

                  -- Apply highlight safely
                  pcall(vim.api.nvim_buf_add_highlight, buf, ns_id, 'ErrorMsg',
                        highlight_line_idx, highlight_start_col, highlight_start_col + 1) -- Highlight only the 'H' character
              end
              current_col_offset = current_col_offset + col_width -- Move to next day's column start
          end
      else
          -- Skip columns if city has no data
          current_col_offset = current_col_offset + col_width * 3 -- Assuming max 3 days
      end


      if city_idx < #all_daily_temps then -- Add spacing only between cities
          current_col_offset = current_col_offset + city_spacing
      end
  end
end


-- Main function: display weather info
result.display_weather = function(cities)
  if type(cities) == "string" then -- Allow single city string as input
    cities = {cities}
  elseif type(cities) ~= "table" then
    vim.notify("Invalid input for cities. Expected a city name or a table of city names.", vim.log.levels.ERROR)
    return
  end

   -- Ensure cities table is not empty
  if #cities == 0 then
     vim.notify("No cities provided.", vim.log.levels.WARN)
     return
  end


  -- Limit number of cities
  local city_limit = 3
  if #cities > city_limit then
    cities = vim.list_slice(cities, 1, city_limit) -- Use vim.list_slice for safety
    vim.notify(string.format("Only showing weather for the first %d cities", city_limit), vim.log.levels.INFO)
  end

  -- Create loading window
  local loading_win = create_loading_window()

  -- Use vim.schedule to ensure UI updates and allow async operations
  vim.schedule(function()
    -- Fixed width settings
    local temp_width = 6    -- Increased width for temp label e.g., "-10°C "
    local col_width = 7     -- Column width per day
    local city_spacing = 3  -- Reduced spacing between cities
    local padding = "▏ "   -- Use a bar character + space for visual separation

    -- Collect city weather data
    local all_daily_temps, min_temp_all, max_temp_all, current_weather_data = collect_weather_data(cities)

    -- Close loading window safely
    if loading_win and vim.api.nvim_win_is_valid(loading_win) then
      pcall(vim.api.nvim_win_close, loading_win, true)
    end

    -- If no data retrieved or fundamental error, show message and return
    if #all_daily_temps == 0 or not min_temp_all or not max_temp_all then
      vim.notify("Failed to retrieve valid weather data for any requested city.", vim.log.levels.ERROR)
      return
    end

    -- Create city name and current weather lines
    local city_line, emoji_line, current_weather_line = create_header_lines(all_daily_temps, cities, current_weather_data, temp_width, padding, col_width, city_spacing)

    -- Create temperature chart lines
    local temp_lines = create_temperature_lines(all_daily_temps, min_temp_all, max_temp_all, temp_width, padding, col_width, city_spacing)

    -- Create date line
    local date_line = create_date_line(all_daily_temps, temp_width, padding, col_width, city_spacing)

    -- Build all lines
    local lines = {
      city_line,
      emoji_line,
      current_weather_line,
      string.rep("─", vim.fn.strdisplaywidth(city_line)) -- Separator line matching width
    }

    -- Add temperature chart lines
    vim.list_extend(lines, temp_lines)

    -- Add date line (add separator before it too)
    table.insert(lines, string.rep("─", vim.fn.strdisplaywidth(date_line))) -- Separator line
    table.insert(lines, date_line)

    -- Create floating window and display weather info
    local buf, win = create_weather_window(lines)

    -- Apply highlights only if buffer/window creation was successful
    if buf and win then
      -- Apply current date highlight
      apply_date_highlight(buf, all_daily_temps, temp_width, padding, col_width, city_spacing)

      -- *** Apply high temperature highlight ***
      apply_high_temp_highlight(buf, all_daily_temps, max_temp_all, temp_width, padding, col_width, city_spacing)
    end
  end)
end

return result

