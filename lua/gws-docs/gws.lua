local M = {}

local function get_config()
  return require("gws-docs").config
end

--- Run a gws command asynchronously.
--- @param args string[] subcommand and flags
--- @param opts table|nil options ({ silent = bool })
--- @param callback fun(stdout: string|nil, err: string|nil)
local function run_async(args, opts, callback)
  opts = opts or {}
  local cmd = { get_config().gws_binary }
  for _, a in ipairs(args) do
    table.insert(cmd, a)
  end

  vim.system(cmd, { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        local msg = result.stderr or "unknown error"
        if not opts.silent then
          vim.notify("[gws-docs] gws failed: " .. msg, vim.log.levels.ERROR)
        end
        callback(nil, msg)
      else
        callback(result.stdout, nil)
      end
    end)
  end)
end

--- List Google Docs accessible to the user (async, handles pagination).
--- @param callback fun(docs: table[]|nil, err: string|nil)
function M.list_docs(callback)
  local all_docs = {}

  local function fetch_page(page_token)
    local params_tbl = {
      q = "mimeType='application/vnd.google-apps.document'",
      fields = "files(id,name),nextPageToken",
      pageSize = 100,
    }
    if page_token then
      params_tbl.pageToken = page_token
    end

    local params = vim.json.encode(params_tbl)

    run_async({
      "drive.files.list",
      "--params", params,
    }, {}, function(raw, err)
      if not raw then
        callback(nil, err)
        return
      end

      local ok, decoded = pcall(vim.json.decode, raw)
      if not ok or not decoded or not decoded.files then
        vim.notify("[gws-docs] failed to parse file list", vim.log.levels.ERROR)
        callback(nil, "json parse error")
        return
      end

      for _, f in ipairs(decoded.files) do
        table.insert(all_docs, f)
      end

      if decoded.nextPageToken then
        fetch_page(decoded.nextPageToken)
      else
        callback(all_docs, nil)
      end
    end)
  end

  fetch_page(nil)
end

--- Export a Google Doc as Markdown (async).
--- @param file_id string
--- @param callback fun(md: string|nil, err: string|nil)
function M.export_doc(file_id, callback)
  local params = vim.json.encode({
    fileId = file_id,
    mimeType = "text/markdown",
  })

  run_async({
    "drive.files.export",
    "--params", params,
  }, {}, callback)
end

--- Create a new Google Doc with the given title (async).
--- @param title string
--- @param callback fun(doc: table|nil, err: string|nil)
function M.create_doc(title, callback)
  local body = vim.json.encode({
    title = title,
  })

  run_async({
    "docs.documents.create",
    "--json", body,
  }, {}, function(raw, err)
    if not raw then
      callback(nil, err)
      return
    end

    local ok, decoded = pcall(vim.json.decode, raw)
    if not ok or not decoded then
      callback(nil, "json parse error")
      return
    end

    callback({
      id = decoded.documentId,
      name = decoded.title,
    }, nil)
  end)
end

--- Replace the entire content of a Google Doc with new text (async).
--- Uses docs.documents.batchUpdate to clear then insert.
--- @param doc_id string
--- @param text string
--- @param callback fun(ok: boolean|nil, err: string|nil)
function M.update_doc(doc_id, text, callback)
  -- Step 1: get current document to find content length
  local params = vim.json.encode({
    documentId = doc_id,
  })

  run_async({
    "docs.documents.get",
    "--params", params,
  }, {}, function(raw, err)
    if not raw then
      callback(nil, err)
      return
    end

    local ok, doc = pcall(vim.json.decode, raw)
    if not ok or not doc then
      callback(nil, "json parse error")
      return
    end

    -- Find the end index of the body content (subtract 1 for the trailing newline)
    local end_index = 1
    if doc.body and doc.body.content then
      for _, elem in ipairs(doc.body.content) do
        if elem.endIndex and elem.endIndex > end_index then
          end_index = elem.endIndex
        end
      end
    end

    local requests = {}

    -- Delete existing content (if any beyond the initial newline)
    if end_index > 2 then
      table.insert(requests, {
        deleteContentRange = {
          range = {
            startIndex = 1,
            endIndex = end_index - 1,
          },
        },
      })
    end

    -- Insert new text at position 1
    if text and #text > 0 then
      table.insert(requests, {
        insertText = {
          location = { index = 1 },
          text = text,
        },
      })
    end

    if #requests == 0 then
      callback(true, nil)
      return
    end

    local body = vim.json.encode({ requests = requests })
    run_async({
      "docs.documents.batchUpdate",
      "--params", vim.json.encode({ documentId = doc_id }),
      "--json", body,
    }, {}, function(result, update_err)
      if not result then
        callback(nil, update_err)
      else
        callback(true, nil)
      end
    end)
  end)
end

return M
