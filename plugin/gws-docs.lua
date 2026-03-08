if vim.g.loaded_gws_docs then
  return
end
vim.g.loaded_gws_docs = true

-- Commands are registered in setup(), but provide a fallback if the user
-- hasn't called setup yet.
vim.api.nvim_create_user_command("GwsDocsSetup", function()
  require("gws-docs").setup()
end, { desc = "Initialize gws-docs plugin" })
