# gws-docs.nvim

Browse, edit, and sync Google Docs as Markdown from Neovim, powered by the [Google Workspace CLI (`gws`)](https://github.com/googleworkspace/cli).

## Requirements

- Neovim >= 0.10
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [`gws`](https://github.com/googleworkspace/cli) CLI installed and authenticated (see below)

## Installing `gws`

### Option 1: npm (easiest)

```bash
npm install -g @googleworkspace/cli
```

### Option 2: Cargo (from source)

```bash
cargo install --git https://github.com/googleworkspace/cli --locked
```

### Option 3: Pre-built binary

Download from [GitHub Releases](https://github.com/googleworkspace/cli/releases) and put it on your `$PATH`.

### Authenticating `gws`

Run the one-time setup to create a Google Cloud project, enable APIs, and log in:

```bash
gws auth setup
```

This will:
1. Create/select a Google Cloud project
2. Enable the Drive and Docs APIs
3. Open a browser for OAuth login

For subsequent logins:

```bash
gws auth login
```

**Important:** If using a personal Google account, you may need to add yourself as a test user in the [OAuth consent screen](https://console.cloud.google.com/apis/credentials/consent) before login will work.

### Verify it works

```bash
# List your Google Docs
gws drive.files.list --params '{"q": "mimeType='\''application/vnd.google-apps.document'\''", "pageSize": 5}'
```

You should see JSON output with your documents.

## Installing the plugin

### lazy.nvim

```lua
{
  "teddytennant/gws-docs.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  cmd = { "GwsDocs", "GwsSync", "GwsCreate" },
  opts = {},
}
```

### packer.nvim

```lua
use {
  "teddytennant/gws-docs.nvim",
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
  auto_sync = true,              -- auto-sync on save for cached docs
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:GwsDocs` | Open Telescope picker to browse and open Google Docs |
| `:GwsSync` | Sync current buffer back to its linked Google Doc |
| `:GwsCreate [title]` | Create a new Google Doc from the current buffer |

## Usage

1. Run `:GwsDocs` to open the Telescope picker
2. Select a document — it's exported as Markdown and opened in a buffer
3. Edit normally. On save, changes sync back to Google Docs automatically
4. Use `:GwsSync` to manually trigger a sync at any time
5. Use `:GwsCreate My Doc Title` to create a new Google Doc from the current buffer

## How it works

- **List**: `gws drive.files.list` filtered to Google Docs → Telescope
- **Export**: `gws drive.files.export` with `mimeType=text/markdown` → local cache file
- **Sync**: Reads the buffer, uses `gws docs.documents.batchUpdate` to clear + insert
- **Create**: `gws docs.documents.create` then pushes buffer content

## Troubleshooting

**"gws not found"** — Make sure `gws` is on your `$PATH`. You can set a custom path:
```lua
require("gws-docs").setup({ gws_binary = "/path/to/gws" })
```

**Auth errors** — Re-run `gws auth login` and make sure Drive + Docs APIs are enabled in your Cloud project.

**Export returns HTML instead of Markdown** — Google's export for some docs may not support `text/markdown`. The plugin will still save whatever format is returned.

## License

MIT
