local win, buf
local M = {}
local api = require("weather.api")

M.config = {
  cities = { "Shanghai", "Beijing" }, -- 默认显示两个城市
  cache_duration = 300, -- 缓存时间（秒），可配置
}

-- main function
function M.setup(config)
  if vim.version().minor < 7 then
    vim.api.nvim_err_writeln("weather.nvim: you must use neovim 0.7 or higher")
    return
  end

  M.config = vim.tbl_extend("force", M.config, config or {})

  -- 显示天气命令
  vim.api.nvim_create_user_command("Qian", function()
    api.display_weather(M.config.cities)
  end, { nargs = "*" })

  -- 清除缓存命令
  vim.api.nvim_create_user_command("QianClearCache", function()
    api.clear_cache()
  end, {})
end

return M
