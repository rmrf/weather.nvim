local curl = require("plenary.curl")
local util = require("weather.util")

local result = {}
local cache = {}  -- 缓存存储
local CACHE_DURATION = 300  -- 缓存时间（秒），5分钟

local function is_cache_valid(cache_entry)
  if not cache_entry or not cache_entry.timestamp then
    return false
  end
  return os.time() - cache_entry.timestamp < CACHE_DURATION
end

local function call_wttr(city)
  -- 检查缓存
  if cache[city] and is_cache_valid(cache[city]) then
    return cache[city].data
  end
  
  local url = string.format("https://wttr.in/%s?format=j1", city)
  local response = curl.get({ url = url })
  
  if response and response.body then
    local weather_data = vim.json.decode(response.body)
    if weather_data then
      -- 更新缓存
      cache[city] = {
        data = weather_data,
        timestamp = os.time()
      }
      return weather_data
    end
  end
  
  return nil
end

-- 添加清除缓存的函数
result.clear_cache = function()
  cache = {}
  vim.notify("Weather cache cleared")
end

result.display_weather = function(cities)
  if type(cities) ~= "table" then
    cities = {cities}  -- 如果是单个城市，转换为数组
  end
  
  -- 首先创建一个加载提示窗口
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
  
  -- 设置缓冲区选项
  vim.api.nvim_buf_set_option(loading_buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(loading_buf, 'bufhidden', 'wipe')
  
  -- 使用 vim.schedule 来确保UI更新
  vim.schedule(function()
    -- 准备所有城市的数据
    local all_lines = {}
    local min_temp_all, max_temp_all = 100, -100
    local all_daily_temps = {}
    local current_date = os.date("%Y-%m-%d")
    
    -- 固定宽度设置 - 移到前面来
    local temp_width = 5    -- 温度刻度宽度 "XX°C "
    local col_width = 7     -- 每列宽度
    local city_spacing = 4  -- 城市之间的间距
    local padding = string.rep(" ", 2)  -- 温度刻度和图表之间的间距
    
    -- 添加天气代码到 emoji 的映射
    local weather_emoji = {
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
    
    local function get_weather_emoji(weather_code)
      return weather_emoji[weather_code] or "✨"  -- 使用 ✨ 作为未知天气的默认图标
    end
    
    -- 首先收集所有城市的数据和温度范围
    for _, city in ipairs(cities) do
      local weather_data = call_wttr(city)
      
      if not weather_data or not weather_data.nearest_area or #weather_data.nearest_area == 0 then
        vim.api.nvim_err_writeln("Failed to retrieve weather data for " .. city)
        goto continue
      end
      
      -- 获取城市名
      local city_name = weather_data.nearest_area[1].areaName[1].value
      local region = weather_data.nearest_area[1].region[1].value
      
      -- 获取当前天气状况
      local current_weather = weather_data.current_condition[1]
      local current_temp = current_weather.temp_C .. "°C"
      local current_feels = current_weather.FeelsLikeC .. "°C"
      
      -- 计算温度范围
      local daily_temps = {}
      for i = 1, math.min(3, #weather_data.weather) do
        local day = weather_data.weather[i]
        local max_temp = tonumber(day.maxtempC)
        local min_temp = tonumber(day.mintempC)
        local avg_temp = tonumber(day.avgtempC)
        local date = day.date
        local astronomy = day.astronomy[1]
        
        -- 找到最高温和最低温对应的天气状况
        local max_temp_weather_code = "113"  -- 默认晴天
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
      
      -- 按日期排序
      table.sort(daily_temps, function(a, b) return a.date < b.date end)
      table.insert(all_daily_temps, {
        city = string.format("%s, %s", city_name, region),
        temps = daily_temps
      })
      
      ::continue::
    end
    
    -- 关闭加载窗口
    vim.api.nvim_win_close(loading_win, true)
    
    -- 如果没有获取到任何数据，显示错误信息并返回
    if #all_daily_temps == 0 then
      vim.api.nvim_err_writeln("Failed to retrieve weather data for any city")
      return
    end
    
    -- 添加一些边距到温度范围
    min_temp_all = math.floor(min_temp_all - 1)
    max_temp_all = math.ceil(max_temp_all + 1)
    
    -- 现在创建城市名行和当前天气行
    local city_line = string.rep(" ", temp_width + #padding)
    local current_weather_line = "Now:"  -- 直接从最左边开始，不添加前置空格
    local city_start_positions = {}
    
    -- 记录每个城市名的起始位置
    for i, city_data in ipairs(all_daily_temps) do
      table.insert(city_start_positions, #city_line)
      city_line = city_line .. string.format("%-" .. (col_width * 3) .. "s", city_data.city)
      city_line = city_line .. string.rep(" ", city_spacing)
    end
    
    -- 添加当前天气信息
    for i, city in ipairs(cities) do
      local weather_data = call_wttr(city)
      if weather_data and weather_data.current_condition then
        local current_weather = weather_data.current_condition[1]
        local current_temp = current_weather.temp_C .. "°C"
        local current_feels = current_weather.FeelsLikeC .. "°C"
        
        -- 计算当前城市的天气信息应该放在哪个位置
        if i <= #city_start_positions then
          -- 计算需要添加多少空格才能对齐到城市名的位置
          local target_pos = city_start_positions[i]
          local current_pos = #current_weather_line
          local spaces_needed = target_pos - current_pos
          
          if spaces_needed > 0 then
            current_weather_line = current_weather_line .. string.rep(" ", spaces_needed)
          end
          
          -- 添加当前天气信息
          current_weather_line = current_weather_line .. string.format("%-" .. (col_width * 3) .. "s", 
            string.format("%s (体感 %s) %s", 
              current_temp,
              current_feels,
              get_weather_emoji(current_weather.weatherCode)
            )
          )
          
          -- 添加城市间距
          if i < #cities and i < #city_start_positions then
            current_weather_line = current_weather_line .. string.rep(" ", city_spacing)
          end
        end
      end
    end
    
    -- 构建所有行
    local lines = {}
    
    -- 1. 添加城市名行
    table.insert(lines, city_line)
    
    -- 2. 添加当前天气行
    table.insert(lines, current_weather_line)
    
    -- 3. 添加空行
    table.insert(lines, "")
    
    -- 4. 为每个温度创建一行
    for temp = max_temp_all, min_temp_all, -1 do
      local line = string.format("%2d°C %s", temp, padding)
      
      -- 添加每个城市的温度标记
      for _, city_data in ipairs(all_daily_temps) do
        for _, day in ipairs(city_data.temps) do
          if temp == math.floor(day.max) then
            line = line .. string.format("%-" .. col_width .. "s", "↑")
          elseif temp == math.floor(day.min) then
            line = line .. string.format("%-" .. col_width .. "s", "↓")
          else
            line = line .. string.format("%-" .. col_width .. "s", " ")
          end
        end
        line = line .. string.rep(" ", city_spacing)  -- 添加城市间距
      end
      table.insert(lines, line)
    end
    
    -- 5. 添加日期行，不包含天气图标
    local date_line = string.rep(" ", temp_width + #padding)
    for _, city_data in ipairs(all_daily_temps) do
      for _, day in ipairs(city_data.temps) do
        -- 只显示日期，不显示天气图标
        date_line = date_line .. string.format("%-" .. col_width .. "s", string.sub(day.date, 6))
      end
      date_line = date_line .. string.rep(" ", city_spacing)
    end
    table.insert(lines, date_line)
    
    -- 创建浮动窗口
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    
    -- 计算窗口大小
    local width = math.max(#city_line + 2, #date_line + 2)
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
    
    -- 设置缓冲区选项
    vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    vim.api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
    
    -- 设置关闭快捷键
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':q<CR>', {noremap = true, silent = true})
    vim.api.nvim_buf_set_keymap(buf, 'n', '<ESC>', ':q<CR>', {noremap = true, silent = true})
    
    -- 应用当前日期高亮
    local ns_id = vim.api.nvim_create_namespace('weather_highlight')
    local highlight_pos = #lines - 1  -- 日期行的位置（最后一行）
    
    -- 为每个城市的当前日期添加高亮
    local current_pos = temp_width + #padding
    for _, city_data in ipairs(all_daily_temps) do
      for i, day in ipairs(city_data.temps) do
        if day.date == current_date then
          local highlight_start = current_pos + (i-1) * col_width
          local highlight_length = 5  -- "MM-DD" 的长度
          vim.api.nvim_buf_add_highlight(buf, ns_id, 'ErrorMsg', highlight_pos, highlight_start, highlight_start + highlight_length)
        end
      end
      current_pos = current_pos + col_width * #city_data.temps + city_spacing
    end
  end)
end

return result
