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

## Screenshot

![image](https://github.com/user-attachments/assets/96e58803-1aac-4afc-b85e-196ba5de59b8)

