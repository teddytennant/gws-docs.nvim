local M = {}

function M.open()
  local has_telescope, _ = pcall(require, "telescope")
  if not has_telescope then
    vim.notify("[gws-docs] telescope.nvim is required for the picker", vim.log.levels.ERROR)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  local gws = require("gws-docs.gws")
  local config = require("gws-docs").config

  vim.notify("[gws-docs] fetching docs...", vim.log.levels.INFO)

  gws.list_docs(function(docs, err)
    if not docs then
      vim.notify("[gws-docs] failed to list docs: " .. (err or ""), vim.log.levels.ERROR)
      return
    end

    if #docs == 0 then
      vim.notify("[gws-docs] no docs found", vim.log.levels.WARN)
      return
    end

    pickers
      .new({}, {
        prompt_title = "Google Docs",
        finder = finders.new_table({
          results = docs,
          entry_maker = function(entry)
            return {
              value = entry,
              display = entry.name,
              ordinal = entry.name,
            }
          end,
        }),
        sorter = conf.generic_sorter({}),
        attach_mappings = function(prompt_bufnr)
          actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            if not selection then
              return
            end

            local doc = selection.value
            vim.notify("[gws-docs] exporting " .. doc.name .. "...", vim.log.levels.INFO)

            gws.export_doc(doc.id, function(md, export_err)
              if not md then
                vim.notify("[gws-docs] export failed: " .. (export_err or ""), vim.log.levels.ERROR)
                return
              end

              -- Write to cache dir
              local cache_dir = vim.fn.expand(config.cache_dir)
              vim.fn.mkdir(cache_dir, "p")

              local filename = doc.name:gsub("[^%w%-_ ]", ""):gsub("%s+", "_") .. ".md"
              -- Prevent path traversal: strip leading dots and any slashes
              filename = filename:gsub("^%.+", ""):gsub("/", ""):gsub("\\", "")
              if filename == "" or filename == ".md" then
                filename = "untitled_" .. doc.id .. ".md"
              end
              local filepath = cache_dir .. "/" .. filename

              local f, open_err = io.open(filepath, "w")
              if not f then
                vim.notify("[gws-docs] could not write " .. filepath .. ": " .. (open_err or ""), vim.log.levels.ERROR)
                return
              end
              f:write(md)
              f:close()

              -- Store doc id mapping
              local meta = require("gws-docs")
              meta._file_map[filepath] = doc.id

              vim.cmd("edit " .. vim.fn.fnameescape(filepath))
              vim.notify("[gws-docs] opened " .. doc.name, vim.log.levels.INFO)
            end)
          end)
          return true
        end,
      })
      :find()
  end)
end

return M
