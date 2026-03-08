local M = {}

--- Sync the current buffer back to its corresponding Google Doc.
function M.sync_current()
  local filepath = vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    vim.notify("[gws-docs] buffer has no file", vim.log.levels.WARN)
    return
  end

  local meta = require("gws-docs")
  local doc_id = meta._file_map[filepath]

  if not doc_id then
    vim.notify("[gws-docs] this file is not linked to a Google Doc", vim.log.levels.WARN)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local text = table.concat(lines, "\n")

  local gws = require("gws-docs.gws")
  vim.notify("[gws-docs] syncing to Google Docs...", vim.log.levels.INFO)

  local ok, err = gws.update_doc(doc_id, text)
  if not ok then
    vim.notify("[gws-docs] sync failed: " .. (err or ""), vim.log.levels.ERROR)
    return
  end

  vim.notify("[gws-docs] synced successfully", vim.log.levels.INFO)
end

--- Set up auto-sync on BufWritePost for files in the cache directory.
function M.setup_autocmd()
  local config = require("gws-docs").config
  if not config.auto_sync then
    return
  end

  local cache_dir = vim.fn.expand(config.cache_dir)

  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("GwsDocsAutoSync", { clear = true }),
    pattern = cache_dir .. "/*",
    callback = function()
      M.sync_current()
    end,
  })
end

return M
