-- Single source of truth for which tree-sitter parsers we install.
-- Consumed by:
--   * lua/plugins/treesitter.lua    — for `nvim-treesitter`'s install() at startup
--   * bootstrap.sh                  — read via inline lua to mirror the list
return {
    "c_sharp", "lua", "bash", "json", "yaml",
    "vim", "vimdoc", "markdown", "markdown_inline",
    "html", "css", "javascript", "typescript", "tsx",
    "python", "go", "rust", "toml", "xml", "sql",
    "dockerfile", "regex", "query", "bicep",
}
