-- Diagnostic symbols in the sign column. Plain `●` so it renders in any font.
-- Re-applied after tiny-inline-diagnostic to make sure it's not overridden.
local function apply_diag_config()
  vim.diagnostic.config({
    signs = false, -- end-of-line dot covers it; no need for sign column entry
    virtual_text = {
      prefix = "",
      spacing = 2,
      format = function() return "●" end, -- end-of-line indicator, no text
    },
    severity_sort = true,
  })
end
apply_diag_config()
vim.api.nvim_create_autocmd("User", { pattern = "TinyDiagnosticReady", callback = apply_diag_config })
vim.defer_fn(apply_diag_config, 100) -- belt + suspenders

-- Hide noisy "unused using directive" diagnostics from Roslyn locally —
-- equivalent to a per-user .editorconfig (which doesn't exist). Filters
-- both pull (`textDocument/diagnostic`) and push (`publishDiagnostics`).
-- Add codes here to silence more analyzers in nvim only.
local SILENCED_DIAG_CODES = {
  IDE0005 = true, -- Roslyn: Using directive is unnecessary
  CS8019  = true, -- C# compiler equivalent of the above
}

local function diag_code(d)
  local c = d.code
  if type(c) == "table" then c = c.value end
  return c
end

local function strip(diagnostics)
  if not diagnostics then return diagnostics end
  return vim.tbl_filter(function(d)
    return not SILENCED_DIAG_CODES[diag_code(d)]
  end, diagnostics)
end

local function wrap_handler(name)
  local orig = vim.lsp.handlers[name]
  if not orig then return end
  vim.lsp.handlers[name] = function(err, result, ctx, config)
    if result then
      result.diagnostics = strip(result.diagnostics) -- push protocol
      result.items       = strip(result.items)       -- pull protocol
    end
    return orig(err, result, ctx, config)
  end
end

wrap_handler("textDocument/publishDiagnostics")
wrap_handler("textDocument/diagnostic")

-- Mason — register the crashdummyy registry, which hosts the `roslyn` package
-- (the modern C# language server, configured via roslyn.nvim — see plugins/roslyn.lua).
require("mason").setup({
  registries = {
    "github:mason-org/mason-registry",
    "github:crashdummyy/mason-registry",
  },
})

-- mason-lspconfig handles standard LSPs that ship in the main registry.
-- C# does NOT go here — roslyn.nvim manages the Roslyn server itself.
require("mason-lspconfig").setup({
  ensure_installed = { "lua_ls", "bicep" },
  automatic_installation = true,
})

-- Advertise blink.cmp's extended capabilities to every LSP BEFORE we enable
-- any server (previously this lived in blink.lua and raced with the Roslyn
-- attach). Servers attached after this point return richer completion items.
local ok_blink, blink = pcall(require, "blink.cmp")
if ok_blink then
  vim.lsp.config("*", { capabilities = blink.get_lsp_capabilities() })
end

vim.lsp.enable("roslyn_ls")
vim.lsp.enable("bicep")

vim.lsp.config("roslyn_ls", {
  filetypes = { "cs", "razor" },
  settings = {
    -- Decompile NuGet sources on go-to-def (instead of "no source available")
    ["csharp|inlay_hints"] = {
      csharp_enable_inlay_hints_for_implicit_object_creation = true,
      csharp_enable_inlay_hints_for_implicit_variable_types  = true,
      csharp_enable_inlay_hints_for_lambda_parameter_types   = true,
      csharp_enable_inlay_hints_for_types                    = true,
      dotnet_enable_inlay_hints_for_indexer_parameters       = true,
      dotnet_enable_inlay_hints_for_literal_parameters       = true,
      dotnet_enable_inlay_hints_for_object_creation_parameters = true,
      dotnet_enable_inlay_hints_for_other_parameters         = true,
      dotnet_enable_inlay_hints_for_parameters               = true,
    },
    ["csharp|symbol_search"]      = { dotnet_search_reference_assemblies = true },
    ["csharp|code_lens"]          = { dotnet_enable_references_code_lens = true },
    ["csharp|background_analysis"] = {
      dotnet_analyzer_diagnostics_scope = "openFiles",
      dotnet_compiler_diagnostics_scope = "openFiles",
    },
    ["navigation"] = {
      dotnet_navigate_to_decompiled_sources = true, -- the actual decompilation toggle
    },
  },
})

-- LSP keymaps on attach (apply to every server, including Roslyn for .cs files)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local map = function(keys, fn, desc)
      vim.keymap.set("n", keys, fn, { buffer = args.buf, desc = desc })
    end
    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("gr", vim.lsp.buf.references, "References")
    map("K", vim.lsp.buf.hover, "Hover")
    map("<leader>lr", vim.lsp.buf.rename, "Rename")
    map("<leader>la", vim.lsp.buf.code_action, "Code action")
    map("<leader>ld", vim.diagnostic.open_float, "Line diagnostics")
    map("<leader>lh", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = args.buf }), { bufnr = args.buf })
    end, "Toggle inlay hints")

    -- Auto-enable inlay hints if the server supports them
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.server_capabilities and client.server_capabilities.inlayHintProvider then
      vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
    end
  end,
})
