-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

lvim.colorscheme = "tokyonight-night"

lvim.plugins = {
  'nextmn/vim-yaml-jinja',
  'lunarvim/colorschemes',
  'folke/tokyonight.nvim',
  'neovim/nvim-lspconfig',
  'lspcontainers/lspcontainers.nvim'
}

-- LSP
local lspconfig = require("lspconfig")

lspconfig.pyright.setup({
  before_init = function(params)
    params.processId = vim.NIL
  end,
  cmd = require 'lspcontainers'.command('pyright'),
  root_dir = require('lspconfig/util').root_pattern(".git", vim.fn.getcwd()),
})

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'yaml',
  callback = function()
    vim.lsp.start {
      cmd = { 'openapi-language-server' },
      filetypes = { 'yaml' },
      root_dir = vim.fn.getcwd(),
    }
  end,
})

lspconfig.openapi_language_server.setup({
  cmd = { "openapi-language-server" },
  filetypes = { "yaml", "json" },
  root_dir = lspconfig.util.root_pattern(".git", vim.fn.getcwd()),
})

-- Jinja filetypes

lvim.builtin.treesitter.highlight.enable = true
lvim.builtin.treesitter.indent = { enable = true }

local filetypes = {
  ["yaml-jinja"] = {
    "*.jinja.yaml",
    "*.jinja.yml",
    "*.template.yaml",
    "*.template.yml",
    ".yaml.j2",
    "*.yml.j2",
  },
}

for filetype, patterns in pairs(filetypes) do
  for _, pattern in ipairs(patterns) do
    vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
      pattern = pattern,
      callback = function()
        vim.bo.filetype = filetype
      end,
    })

    vim.api.nvim_create_autocmd({ "Syntax" }, {
      pattern = pattern,
      callback = function()
        vim.bo.syntax = filetype
      end,
    })
  end
end

-- Formatters
local formatters = require "lvim.lsp.null-ls.formatters"
formatters.setup {
  {
    name = "yapf",
    filetypes = { "python" }
  },
  {
    name = "goimports",
    filetypes = { "go", "gomods", "goworks", "gotmpl" },
  },
  {
    command = "prettier",
    filetypes = { "json", "yaml", "html" },
  },
  {
    name = "prettier",
    ---@usage arguments to pass to the formatter
    -- these cannot contain whitespace
    -- options such as `--line-width 80` become either `{"--line-width", "80"}` or `{"--line-width=80"}`
    args = { "--print-width", "100" },
    ---@usage only start in these filetypes, by default it will attach to all filetypes it supports
    filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
  },
}

-- local linters = require "lvim.lsp.null-ls.linters"
-- linters.setup {
--   { name = "flake8" },
--   {
--     name = "shellcheck",
--     args = { "--severity", "warning" },
--   },
-- }

-- local code_actions = require "lvim.lsp.null-ls.code_actions"
-- code_actions.setup {
--   {
--     name = "proselint",
--   },
-- }

-- Tab stop

function SET_TABSTOP()
  local ft = vim.bo.filetype

  local config_map = {
    php = {
      expandtab = false,
      tabstop = 4,
      shiftwidth = 4,
      softtabstop = 0,
    },
    make = {
      expandtab = false,
      tabstop = 2,
      shiftwidth = 2,
      softtabstop = 0,
    },
    go = {
      expandtab = false,
      tabstop = 2,
      shiftwidth = 2,
      softtabstop = 0,
    }
  }

  local config = config_map[ft]

  vim.bo.tabstop = 2
  vim.bo.shiftwidth = 2
  vim.bo.expandtab = true
  vim.bo.softtabstop = 0

  if config ~= nil then
    vim.bo.shiftwidth = config.shiftwidth
    vim.bo.tabstop = config.tabstop
    vim.bo.expandtab = config.expandtab
    vim.bo.softtabstop = config.softtabstop
  end
end

SET_TABSTOP()

vim.cmd("autocmd FileType * lua SET_TABSTOP()")
