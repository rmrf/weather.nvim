# Weather Neovim plugin

## features

- Display weather for up to 3 cities for comparison
- Show min/max temperatures at a glance

## Installing

Using `vim-plug`

```
Plug 'rmrf/weather.nvim'
```

Using `packer.nvim`

```
use({
  "rmrf/weather.nvim",
  requires = {
    'nvim-lua/plenary.nvim',
  }
})

```

Using `lazy.nvim`

```
{
    "rmrf/weather.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
    },
    -- only pick the first 3 cities
    opts = { cities = { "Shanghai", "Chengdu", "Jilin", "SanJose" } },
    cmd = "Weather", -- Optional Lazy Loading
},

```

## Configuration

The plugin comes with the default configs, which can be overridden:

```lua
require("weather").setup({
    -- only pick the first 3 cities
    cities = { "Shanghai", "Chengdu", "Jilin", "SanJose"},
})
```

## Usage

```
:Weather
```

## Screenshot

![weather-vim](https://github.com/user-attachments/assets/e3e2c472-d999-4988-acf4-eaba730d5dee)

