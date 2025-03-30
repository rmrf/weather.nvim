local win, buf
local M = {}
local api = require("weather.api")

M.config = {
  cities = { "Shanghai" }, 
  cache_duration = 300,
}

-- main function
function M.setup(config)
  if vim.version().minor < 7 then
    vim.api.nvim_err_writeln("weather.nvim: you must use neovim 0.7 or higher")
    return
  end

  M.config = vim.tbl_extend("force", M.config, config or {})

  vim.api.nvim_create_user_command("Weather", function()
    api.display_weather(M.config.cities)
  end, { nargs = "*" })

  vim.api.nvim_create_user_command("WeatherClearCache", function()
    api.clear_cache()
  end, {})
end

return M
