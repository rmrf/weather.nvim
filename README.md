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

![image](https://github.com/user-attachments/assets/f855cb31-61c3-449a-8582-68ee45194da0)


