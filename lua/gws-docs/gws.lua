local M = {}

local config = require("gws-docs").config

local function run(args, opts)
  opts = opts or {}
  local cmd = { config.gws_binary }
  for _, a in ipairs(args) do
    table.insert(cmd, a)
  end

  local result = vim.system(cmd, { text = true }):wait()

  if result.code ~= 0 then
    local msg = result.stderr or "unknown error"
    if not opts.silent then
      vim.notify("[gws-docs] gws failed: " .. msg, vim.log.levels.ERROR)
    end
    return nil, msg
  end

  return result.stdout
end

--- List Google Docs accessible to the user.
--- Returns a list of { id = string, name = string } or nil on error.
function M.list_docs()
  local params = vim.json.encode({
    q = "mimeType='application/vnd.google-apps.document'",
    fields = "files(id,name)",
    pageSize = 100,
  })

  local raw, err = run({
    "drive.files.list",
    "--params", params,
  })
  if not raw then
    return nil, err
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or not decoded or not decoded.files then
    vim.notify("[gws-docs] failed to parse file list", vim.log.levels.ERROR)
    return nil, "json parse error"
  end

  return decoded.files
end

--- Export a Google Doc as Markdown.
--- Returns the markdown string or nil on error.
function M.export_doc(file_id)
  local params = vim.json.encode({
    fileId = file_id,
    mimeType = "text/markdown",
  })

  local raw, err = run({
    "drive.files.export",
    "--params", params,
  })
  return raw, err
end

--- Create a new Google Doc with the given title.
--- Returns { id, name } or nil on error.
function M.create_doc(title)
  local body = vim.json.encode({
    title = title,
  })

  local raw, err = run({
    "docs.documents.create",
    "--json", body,
  })
  if not raw then
    return nil, err
  end

  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok or not decoded then
    return nil, "json parse error"
  end

  return {
    id = decoded.documentId,
    name = decoded.title,
  }
end

--- Replace the entire content of a Google Doc with new text.
--- Uses docs.documents.batchUpdate to clear then insert.
function M.update_doc(doc_id, text)
  -- Step 1: get current document to find content length
  local params = vim.json.encode({
    documentId = doc_id,
  })

  local raw, err = run({
    "docs.documents.get",
    "--params", params,
  })
  if not raw then
    return nil, err
  end

  local ok, doc = pcall(vim.json.decode, raw)
  if not ok or not doc then
    return nil, "json parse error"
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
    return true
  end

  local body = vim.json.encode({ requests = requests })
  local result, update_err = run({
    "docs.documents.batchUpdate",
    "--params", vim.json.encode({ documentId = doc_id }),
    "--json", body,
  })

  if not result then
    return nil, update_err
  end

  return true
end

return M
