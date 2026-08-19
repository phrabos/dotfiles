return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.bashls = opts.servers.bashls or {}

      -- Override root_dir to prevent bashls from attaching to .env files
      local util = require("lspconfig.util")
      local default_root = util.root_pattern(".git")

      opts.servers.bashls.root_dir = function(fname)
        local filename = vim.fn.fnamemodify(fname, ":t")
        -- Don't attach to .env files
        if filename:match("^%.env") or filename:match("%.env$") or filename:match("%.env%.") then
          return nil
        end
        return default_root(fname) or vim.fn.getcwd()
      end

      return opts
    end,
  },
}
