require("nvchad.configs.lspconfig").defaults()

-- <leader>ca for Dart files only (hooked via LspAttach for reliability)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == "dartls" then
      vim.keymap.set("n", "<leader>ca", function() vim.lsp.buf.code_action() end, {
        buffer = args.buf,
        desc = "LSP Code action (Dart)",
      })
    end
  end,
})

-- config before enable
vim.lsp.config("dartls", {
  settings = {
    dart = {
      completeFunctionCalls = true,
      showTodos = true,
      analysisExcludedFolders = {
        vim.fn.expand("$HOME/.pub-cache/"),
      },
    },
  },
})

local servers = { "html", "cssls", "gopls", "pyright", "vtsls", "dartls", "qmlls" }
vim.lsp.enable(servers)
