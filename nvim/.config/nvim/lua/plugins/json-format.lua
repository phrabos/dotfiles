-- Wire a JSON formatter into conform.
-- lang.json gives JSON LSP/treesitter but does NOT register a formatter;
-- that comes from the formatting.prettier extra. This maps it directly instead.
return {
  "stevearc/conform.nvim",
  opts = {
    formatters_by_ft = {
      json = { "prettier" },
      jsonc = { "prettier" },
    },
  },
}
