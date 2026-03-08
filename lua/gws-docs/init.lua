local M = {}

M.config = {
  gws_binary = "gws",
  cache_dir = vim.fn.stdpath("cache") .. "/gws-docs",
  auto_sync = true,
}

-- Maps filepath -> Google Doc ID for open documents
M._file_map = {}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- :GwsDocs - open Telescope picker
  vim.api.nvim_create_user_command("GwsDocs", function()
    require("gws-docs.picker").open()
  end, { desc = "Browse Google Docs" })

  -- :GwsSync - sync current buffer to Google Docs
  vim.api.nvim_create_user_command("GwsSync", function()
    require("gws-docs.sync").sync_current()
  end, { desc = "Sync current buffer to Google Docs" })

  -- :GwsCreate - create a new Google Doc from current buffer
  vim.api.nvim_create_user_command("GwsCreate", function(cmd_opts)
    local title = cmd_opts.args
    if title == "" then
      title = vim.fn.expand("%:t:r")
    end
    if title == "" then
      title = "Untitled"
    end

    local gws = require("gws-docs.gws")
    vim.notify("[gws-docs] creating doc: " .. title, vim.log.levels.INFO)

    local doc, err = gws.create_doc(title)
    if not doc then
      vim.notify("[gws-docs] create failed: " .. (err or ""), vim.log.levels.ERROR)
      return
    end

    -- Link current buffer file to the new doc
    local filepath = vim.api.nvim_buf_get_name(0)
    if filepath ~= "" then
      M._file_map[filepath] = doc.id
    end

    -- Push current content
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local text = table.concat(lines, "\n")
    if #text > 0 then
      local ok, sync_err = gws.update_doc(doc.id, text)
      if not ok then
        vim.notify("[gws-docs] initial sync failed: " .. (sync_err or ""), vim.log.levels.WARN)
      end
    end

    vim.notify("[gws-docs] created doc: " .. doc.name .. " (" .. doc.id .. ")", vim.log.levels.INFO)
  end, { nargs = "?", desc = "Create a new Google Doc from current buffer" })

  -- Set up auto-sync
  require("gws-docs.sync").setup_autocmd()
end

return M
