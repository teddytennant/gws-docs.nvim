# gws-docs.nvim

Browse, edit, and sync Google Docs as Markdown from Neovim, powered by the [`gws`](https://github.com/nicholasgasior/gws) CLI.

## Requirements

- Neovim >= 0.10
- [`gws`](https://github.com/nicholasgasior/gws) CLI installed and authenticated
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (for the picker)

## Installation

### lazy.nvim

```lua
{
  "theodoretennant/gws-docs.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  opts = {},
}
```

### packer.nvim

```lua
use {
  "theodoretennant/gws-docs.nvim",
  requires = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("gws-docs").setup()
  end,
}
```

## Configuration

```lua
require("gws-docs").setup({
  gws_binary = "gws",           -- path to gws binary
  cache_dir = vim.fn.stdpath("cache") .. "/gws-docs",  -- where exported docs are saved
  auto_sync = true,              -- sync on save for cached docs
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:GwsDocs` | Open Telescope picker to browse and open Google Docs |
| `:GwsSync` | Sync current buffer back to its linked Google Doc |
| `:GwsCreate [title]` | Create a new Google Doc from the current buffer |

## Usage

1. Run `:GwsDocs` to open the picker
2. Select a document — it's exported as Markdown and opened in a buffer
3. Edit normally. On save, changes sync back to Google Docs automatically
4. Use `:GwsSync` to manually trigger a sync
5. Use `:GwsCreate My Doc Title` to create a new Google Doc from the current buffer

## How It Works

- **List**: Calls `gws drive.files.list` filtered to Google Docs
- **Export**: Calls `gws drive.files.export` with `mimeType=text/markdown`
- **Sync**: Reads the buffer and uses `gws docs.documents.batchUpdate` to replace the doc content
- **Create**: Uses `gws docs.documents.create` then pushes buffer content

## License

MIT
