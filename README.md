# Weather Neovim plugin 

## features
- Display max 3 cities' weather for compare
- Show min/max easily have a glance

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
use({
  "rmrf/weather.nvim",
  dependencies = {
    'nvim-lua/plenary.nvim',
  }
})
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

