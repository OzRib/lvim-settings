-- Read the docs: https://www.lunarvim.org/docs/configuration
-- Video Tutorials: https://www.youtube.com/watch?v=sFA9kX-Ud_c&list=PLhoH5vyxr6QqGu0i7tt_XoVK9v-KvZ3m6
-- Forum: https://www.reddit.com/r/lunarvim/
-- Discord: https://discord.com/invite/Xb9B4Ny

lvim.colorscheme = "tokyonight-night"

lvim.plugins = {
  'sheerun/vim-polyglot',
  'lepture/vim-jinja',
  'nextmn/vim-yaml-jinja',
  'lunarvim/colorschemes',
  'folke/tokyonight.nvim',
  'neovim/nvim-lspconfig',
  'lspcontainers/lspcontainers.nvim',
  {
    'HiPhish/rainbow-delimiters.nvim',
    lazy = false,
    opts = {
      log = {
        level = vim.log.levels.DEBUG,
      },
    },
    main = "rainbow-delimiters.setup",
  },
  {
    'windwp/nvim-ts-autotag',
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require('nvim-ts-autotag').setup({
        opts = {
          enable_close = true,
          enable_rename = true,
        }
      })
    end
  },
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

-- vim.api.nvim_create_autocmd('FileType', {
--   pattern = 'yaml',
--   callback = function()
--     vim.lsp.start {
--       cmd = { 'openapi-language-server' },
--       filetypes = { 'yaml' },
--       root_dir = vim.fn.getcwd(),
--     }
--   end,
-- })

-- lspconfig.openapi_language_server.setup({
--   cmd = { "openapi-language-server" },
--   filetypes = { "yaml", "json" },
--   root_dir = lspconfig.util.root_pattern(".git", vim.fn.getcwd()),
-- })

-- Jinja filetypes

lvim.builtin.treesitter.highlight.enable = true

local filetypes = {
  ["yaml-jinja"] = {
    "*.jinja.yaml",
    "*.jinja.yml",
    "*.template.yaml",
    "*.template.yml",
    ".yaml.j2",
    "*.yml.j2",
  },
  ["jinja"] = {
    "*.j2",
    "*.jinja",
  },
  ["wit"] = { "*.wit" },
  ["wat"] = { "*.wat" }
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

-- LINTERS


-- WIT diagnostics
local function wit_root(bufnr)
  local file = vim.api.nvim_buf_get_name(bufnr)

  if file == "" then
    return nil
  end

  local dir = vim.fs.dirname(file)

  -- Look for the conventional WIT package directory.
  local wit_dir = vim.fs.find("wit", {
    path = dir,
    upward = true,
    type = "directory",
  })[1]

  if wit_dir then
    return wit_dir
  end

  -- Fall back to the directory containing the current .wit file.
  return dir
end

local function wit_check(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local file = vim.api.nvim_buf_get_name(bufnr)

  if file == "" or vim.bo[bufnr].filetype ~= "wit" then
    return
  end

  local root = wit_root(bufnr)

  if not root then
    return
  end

  -- Make sure the current buffer is saved before validating.
  if vim.bo[bufnr].modified then
    vim.cmd("write")
  end

  local output = {}
  local stderr = {}

  local job = vim.fn.jobstart({
    "wasm-tools",
    "component",
    "wit",
    root,
  }, {
    stdout_buffered = true,
    stderr_buffered = true,

    on_stdout = function(_, data)
      if data then
        vim.list_extend(output, data)
      end
    end,

    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr, data)
      end
    end,

    on_exit = function(_, exit_code)
      vim.schedule(function()
        local diagnostics = {}

        local lines = {}

        for _, line in ipairs(output) do
          if line ~= "" then
            table.insert(lines, line)
          end
        end

        for _, line in ipairs(stderr) do
          if line ~= "" then
            table.insert(lines, line)
          end
        end

        if exit_code ~= 0 then
          -- WIT tooling reports diagnostics in human-readable form.
          -- Attach the error to the current WIT buffer when we cannot
          -- reliably extract a source position.
          local message = table.concat(lines, "\n")

          table.insert(diagnostics, {
            lnum = 0,
            col = 0,
            end_lnum = 0,
            end_col = 0,
            severity = vim.diagnostic.severity.ERROR,
            source = "wasm-tools",
            message = message ~= "" and message or "WIT validation failed",
          })
        end

        vim.diagnostic.set(
          vim.api.nvim_create_namespace("wit"),
          bufnr,
          diagnostics,
          {}
        )

        if exit_code == 0 then
          vim.notify(
            "WIT validation successful",
            vim.log.levels.INFO,
            { title = "WIT" }
          )
        end
      end)
    end,
  })

  if job <= 0 then
    vim.notify(
      "Unable to start wasm-tools. Is it installed?",
      vim.log.levels.ERROR,
      { title = "WIT" }
    )
  end
end

vim.api.nvim_create_user_command("WitCheck", function()
  wit_check(0)
end, {
  desc = "Validate current WIT package",
})

vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = "*.wit",
  callback = function(args)
    wit_check(args.buf)
  end,
})

local linters = require "lvim.lsp.null-ls.linters"
linters.setup {
  {
    name = "shellcheck",
    args = { "--severity", "warning", "--exclude=SC2269" },
    filetypes = { "bash" },
  },
}

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
    },
    python = {
      expandtab = true,
      tabstop = 2,
      shiftwidth = 2,
      softtabstop = 0,
    },
    yaml = {
      expandtab = true,
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
