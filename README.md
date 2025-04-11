# Weather Neovim plugin

## features

- Display weather for up to 3 cities for comparison
- Show min/max temperatures at a glance
- emoji show worst weather on top of each day line

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
    cmd = "Weather", -- Lazy Loading
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

![image](https://github.com/user-attachments/assets/a28a0244-5540-4c45-aa79-1a6a18176d69)


