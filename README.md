# restisch.nvim

A very simple form-based REST client for Neovim. Unlike file-based approaches (like `.http` files), RESTisch provides a structured, interactive UI for building and sending HTTP requests.

![Neovim](https://img.shields.io/badge/Neovim-%23%3E%3D0.8-green?logo=neovim&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)

<img height="700" alt="Screenshot 2026-02-07" src="https://github.com/user-attachments/assets/384cd09e-7350-4e26-ae0c-3ca4963ae6b0" />

## Features

- Interactive split-panel UI (request on top, response below)
- HTTP method selector
- Header management with autocomplete for 35+ common headers
- JSON body editor with syntax highlighting
- Response display with pretty-printed JSON and syntax highlighting
- Copy request as cURL command (`c`)
- Request history (`<C-h>`) — last 20 requests
- Save/load requests to disk

## Requirements

- Neovim >= 0.8.0
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)
- `curl`

## Installation

### lazy.nvim

```lua
{
  "AFROnin/restisch.nvim",
  dependencies = {
    "MunifTanjim/nui.nvim",
  },
  config = function()
    require("restisch").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "AFROnin/restisch.nvim",
  requires = { "MunifTanjim/nui.nvim" },
  config = function()
    require("restisch").setup()
  end,
}
```

## Usage

### Commands

| Command | Description |
|---------|-------------|
| `:Restisch` | Open the REST client |
| `:RestischToggle` | Toggle the window |
| `:RestischClose` | Close the window |

### Keymaps

Global (set by plugin):

| Key | Action |
|-----|--------|
| `<leader>rr` | Open RESTisch |
| `<leader>rt` | Toggle RESTisch |

Request panel:

| Key | Action |
|-----|--------|
| `m` | Select HTTP method |
| `u` | Edit URL |
| `a` | Add header (with autocomplete) |
| `dd` | Delete header under cursor |
| `b` | Edit request body (JSON) |
| `c` | Copy request as cURL command |
| `<CR>` | Send request |

Global (both panels):

| Key | Action |
|-----|--------|
| `<Tab>` / `<S-Tab>` | Switch between request/response panels |
| `<C-s>` | Save request |
| `<C-o>` | Load saved request |
| `<C-n>` | New request (clear form) |
| `<C-h>` | Open request history |
| `q` / `<Esc>` | Close RESTisch |

Response panel:

| Key | Action |
|-----|--------|
| `h` | Toggle response headers |
| `y` | Copy response body to clipboard |

Header autocomplete:

| Key | Action |
|-----|--------|
| `<Tab>` / `<Down>` | Next suggestion |
| `<S-Tab>` / `<Up>` | Previous suggestion |
| `<Right>` / `<CR>` | Accept suggestion |
| `<Esc>` | Cancel |

Load dialog:

| Key | Action |
|-----|--------|
| `<CR>` | Load selected request |
| `d` | Delete selected request |
| `q` / `<Esc>` | Close |

## Configuration

```lua
require("restisch").setup({
  width = 100,           -- Window width
  height = 50,           -- Window height
  border = "rounded",    -- Border style
  default_headers = {    -- Default headers for new requests
    { key = "Accept", value = "*/*" },
    { key = "Content-Type", value = "application/json" },
  },
})
```

## Storage

Saved requests are stored as JSON files in:

```
~/.local/share/nvim/restisch/requests/
```

## License

[MIT](LICENSE)

## Credits

Built with [nui.nvim](https://github.com/MunifTanjim/nui.nvim).

AI coding agents were used in the development of this plugin.
