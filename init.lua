-- =============================================================================
-- Neovim 0.12 · single-file config
--   1. Beautiful UI        catppuccin · lualine · snacks · which-key · ui2
--   2. Writing / learning  render-markdown · spell · :Note · zen · REPL (iron)
--   3. Env-only LSP        Python + R servers come ONLY from the active
--                          conda / venv. No Mason, no global servers.
-- Put this at ~/.config/nvim/init.lua, start nvim from a shell where the env
-- is already activated (conda activate foo / source .venv/bin/activate).
-- =============================================================================

if vim.fn.has("nvim-0.12") == 0 then
  vim.notify("This config needs Neovim 0.12+", vim.log.levels.ERROR)
  return
end

vim.loader.enable()
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- ── Options ──────────────────────────────────────────────────────────────────
local o = vim.o
o.number, o.relativenumber = true, true
o.cursorline = true
o.signcolumn = "yes"
o.termguicolors = true
o.winborder = "rounded"
o.laststatus = 3
o.showmode = false
o.scrolloff = 8
o.pumheight = 12
o.splitright, o.splitbelow = true, true
o.ignorecase, o.smartcase = true, true
o.undofile = true
o.updatetime = 250
o.timeoutlen = 300
o.mouse = "a"
o.confirm = true
o.smoothscroll = true
o.clipboard = "unnamedplus"
o.expandtab, o.shiftwidth, o.tabstop = true, 4, 4
o.list = true
o.listchars = "tab:» ,trail:·,nbsp:␣"
o.fillchars = "eob: ,fold: "
o.spelllang = "en_us"
o.spelloptions = "camel"

-- Clipboard: with "unnamedplus", every yank (y, yy, yiw ...) also lands in the
-- system clipboard, and p pastes from it. Locally this needs a clipboard tool
-- (Linux: wl-clipboard or xclip; macOS/Windows work out of the box).
-- Over SSH, use OSC 52 so a yank on the server reaches your local clipboard
-- (needs a terminal that supports it: kitty, wezterm, iTerm2, alacritty, tmux
-- with `set -g set-clipboard on`, ...).
-- TEST MODE: force OSC 52 even when SSH_TTY is missing (as in Herdr).
-- Set to false for terminals that do not support OSC 52 clipboard writes.
vim.g.force_osc52_clipboard = true
if vim.g.force_osc52_clipboard or vim.env.SSH_TTY then
  local osc52 = require("vim.ui.clipboard.osc52")
  local function paste_from_register()
    return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
  end
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = paste_from_register, ["*"] = paste_from_register },
  }
end

vim.diagnostic.config({
  severity_sort = true,
  update_in_insert = false,
  virtual_text = { spacing = 2, prefix = "●" },
  float = { border = "rounded", source = true },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = "✘",
      [vim.diagnostic.severity.WARN] = "▲",
      [vim.diagnostic.severity.INFO] = "●",
      [vim.diagnostic.severity.HINT] = "⚑",
    },
  },
})

-- ── Plugins (built-in vim.pack) ──────────────────────────────────────────────
-- Must be registered BEFORE vim.pack.add so it fires on first install/update.
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    local d = ev.data
    if d.spec.name == "nvim-treesitter" and d.kind == "update" then
      if not d.active then vim.cmd.packadd("nvim-treesitter") end
      pcall(vim.cmd, "TSUpdate")
    end
  end,
})

vim.pack.add({
  { src = "https://github.com/catppuccin/nvim", name = "catppuccin" },
  "https://github.com/nvim-tree/nvim-web-devicons",
  "https://github.com/nvim-lualine/lualine.nvim",
  "https://github.com/folke/snacks.nvim",
  "https://github.com/folke/which-key.nvim",
  "https://github.com/lewis6991/gitsigns.nvim",
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
  "https://github.com/MeanderingProgrammer/render-markdown.nvim",
  { src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.*") },
  "https://github.com/Vigemus/iron.nvim",
}, { confirm = false })

-- A plugin that fails to load must not break the rest of the config.
local function setup(mod, opts)
  local ok, m = pcall(require, mod)
  if not ok then
    vim.schedule(function() vim.notify("plugin missing: " .. mod, vim.log.levels.WARN) end)
    return
  end
  m.setup(opts or {})
end

-- ── Environment detection (the core of requirement 3) ────────────────────────
local Env = {}
local is_win = vim.fn.has("win32") == 1

local function detect_env()
  local venv, conda = vim.env.VIRTUAL_ENV, vim.env.CONDA_PREFIX
  if venv and venv ~= "" then
    local name = vim.fs.basename(venv)
    if name == ".venv" or name == "venv" then
      name = vim.fs.basename(vim.fs.dirname(venv))
    end
    return { kind = "venv", prefix = venv, name = name }
  end
  if conda and conda ~= "" then
    return { kind = "conda", prefix = conda, name = vim.env.CONDA_DEFAULT_ENV or vim.fs.basename(conda) }
  end
end

Env.current = detect_env() -- nvim inherits env vars once, at start-up

--- Absolute path of `name` INSIDE the active env, or nil. Never searches $PATH.
function Env.exe(name)
  local env = Env.current
  if not env then return nil end
  local dirs = is_win and { "Scripts", "Library/bin", "" } or { "bin" }
  for _, d in ipairs(dirs) do
    local p = vim.fs.joinpath(env.prefix, d, name .. (is_win and ".exe" or ""))
    if vim.fn.executable(p) == 1 then return p end
  end
end

-- ── UI ───────────────────────────────────────────────────────────────────────
setup("catppuccin", {
  flavour = "mocha",
  integrations = {
    gitsigns = true,
    treesitter = true,
    which_key = true,
    render_markdown = true,
    native_lsp = { enabled = true },
    snacks = { enabled = true },
    blink_cmp = { style = "bordered" },
  },
})
pcall(vim.cmd.colorscheme, "catppuccin")

-- Experimental 0.12 redesign of messages / cmdline. Delete this line if it misbehaves.
pcall(function() require("vim._core.ui2").enable() end)

setup("snacks", {
  dashboard = {
    enabled = true,
    -- no "startup" section: it requires lazy.nvim (we use vim.pack)
    sections = {
      { section = "header" },
      { section = "keys", gap = 1, padding = 1 },
    },
  },
  indent = { enabled = true },
  input = { enabled = true },
  notifier = { enabled = true },
  picker = { enabled = true },
  explorer = { enabled = true },
  scroll = { enabled = true },
  words = { enabled = true },
  zen = { enabled = true },
  quickfile = { enabled = true },
})

setup("gitsigns")
setup("which-key", { preset = "helix" })

local function lsp_names()
  local names = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do names[#names + 1] = c.name end
  return table.concat(names, ",")
end
local function env_label()
  local e = Env.current
  return e and ("env:" .. e.name) or "no-env"
end

setup("lualine", {
  options = {
    theme = "catppuccin-nvim",
    globalstatus = true,
    component_separators = "",
    section_separators = { left = vim.fn.nr2char(0xe0b4), right = vim.fn.nr2char(0xe0b6) },
  },
  sections = {
    lualine_a = { "mode" },
    lualine_b = { "branch", "diff" },
    lualine_c = { { "filename", path = 1 }, "diagnostics" },
    lualine_x = {
      { lsp_names, cond = function() return lsp_names() ~= "" end },
      { env_label, color = function() return { fg = Env.current and "#a6e3a1" or "#f38ba8" } end },
      "filetype",
    },
    lualine_y = { "progress" },
    lualine_z = { "location" },
  },
})

-- ── Treesitter (parsers) + highlighting ──────────────────────────────────────
-- nvim-treesitter is archived (Apr 2026); the `main` branch is the 0.12-era
-- rewrite. It compiles parsers, so it needs the `tree-sitter` CLI and a C compiler.
vim.treesitter.language.register("markdown", { "quarto", "rmd" })
do
  local ok, ts = pcall(require, "nvim-treesitter")
  if ok and vim.fn.executable("tree-sitter") == 1 then
    pcall(ts.install, {
      "python", "r", "markdown", "markdown_inline", "yaml", "json", "toml",
      "bash", "lua", "vim", "vimdoc", "query",
    })
  end
end
vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev) pcall(vim.treesitter.start, ev.buf) end,
})

-- ── Completion ───────────────────────────────────────────────────────────────
setup("blink.cmp", {
  -- VS Code / Zed style: <Tab> accepts the selected item (and jumps through snippet
  -- fields), <S-Tab> goes back, <C-space> opens, <C-e> closes, <C-n>/<C-p> or arrows move.
  keymap = { preset = "super-tab" },
  appearance = { nerd_font_variant = "mono" },
  completion = {
    menu = { border = "rounded" },
    documentation = { auto_show = true, window = { border = "rounded" } },
  },
  signature = { enabled = true, window = { border = "rounded" } },
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
})
pcall(function()
  vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
end)

-- ── LSP: servers resolved from the ACTIVE ENV only ───────────────────────────
-- Servers are never taken from $PATH or a global install. On the first buffer
-- of a matching filetype we look inside $VIRTUAL_ENV / $CONDA_PREFIX; if the
-- server is not there we tell you what to install INTO THAT ENV and do nothing.
local servers = {
  pyright = {
    exe = "pyright-langserver",
    args = { "--stdio" },
    filetypes = { "python" },
    root_markers = { "pyrightconfig.json", "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
    hint = "conda install -c conda-forge pyright    (or: pip install pyright)",
    config = function()
      return {
        settings = {
          python = {
            pythonPath = Env.exe("python"), -- analyse against THIS env's packages
            analysis = {
              typeCheckingMode = "standard",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "openFilesOnly",
            },
          },
        },
      }
    end,
  },
  ruff = {
    exe = "ruff",
    args = { "server" },
    filetypes = { "python" },
    root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
    hint = "conda install -c conda-forge ruff    (or: pip install ruff)",
    config = function()
      return {
        on_attach = function(client) client.server_capabilities.hoverProvider = false end,
      }
    end,
  },
  r_language_server = {
    exe = "R",
    args = { "--no-echo", "-e", "languageserver::run()" },
    filetypes = { "r", "rmd", "quarto" },
    root_markers = { "DESCRIPTION", "renv.lock", ".Rproj.user", ".git" },
    -- async probe: is the `languageserver` R package installed in this env's R?
    check = function(exe)
      return { exe, "--no-echo", "-e", "cat(requireNamespace('languageserver', quietly = TRUE))" }
    end,
    hint = "conda install -c conda-forge r-languageserver    (or, in this env's R: install.packages('languageserver'))",
  },
}

local resolved = {}
local function warn(msg) vim.notify(msg, vim.log.levels.WARN, { title = "Env LSP" }) end

local function activate(name, spec)
  if resolved[name] then return end
  resolved[name] = true

  local env = Env.current
  if not env then
    warn(("No conda/venv is active, so `%s` was not started.\nActivate an env, then restart nvim."):format(name))
    return
  end
  local exe = Env.exe(spec.exe)
  if not exe then
    warn(("`%s` is not installed in env '%s'.\nInstall it there:\n  %s"):format(spec.exe, env.name, spec.hint))
    return
  end

  local function start()
    vim.lsp.config(name, vim.tbl_deep_extend("force", {
      cmd = vim.list_extend({ exe }, spec.args),
      filetypes = spec.filetypes,
      root_markers = spec.root_markers,
      workspace_required = false, -- single files / notes folders work too
    }, spec.config and spec.config() or {}))
    vim.lsp.enable(name)
  end

  if spec.check then
    vim.system(spec.check(exe), { text = true }, vim.schedule_wrap(function(res)
      if res.code == 0 and (res.stdout or ""):find("TRUE", 1, true) then
        start()
      else
        warn(("R package for `%s` is missing in env '%s'.\nInstall it there:\n  %s"):format(name, env.name, spec.hint))
      end
    end))
  else
    start()
  end
end

do
  local fts = {}
  for _, spec in pairs(servers) do vim.list_extend(fts, spec.filetypes) end
  vim.api.nvim_create_autocmd("FileType", {
    pattern = fts,
    callback = function(ev)
      for name, spec in pairs(servers) do
        if vim.tbl_contains(spec.filetypes, ev.match) then activate(name, spec) end
      end
    end,
  })
end

-- ── Black (Python formatter), taken from the ACTIVE ENV only ─────────────────
-- Install into the env:  conda install -c conda-forge black   (or: pip install black)
-- Respects pyproject.toml via --stdin-filename. Set vim.g.black_on_save = false to disable.
vim.g.black_on_save = true

local function black_format(buf, silent)
  local exe = Env.exe("black")
  if not exe then
    if not silent then
      warn(("`black` is not installed in env '%s'.\nInstall it there:\n  conda install -c conda-forge black    (or: pip install black)")
        :format(Env.current and Env.current.name or "none"))
    end
    return
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local res = vim.system(
    { exe, "-q", "--stdin-filename", name ~= "" and name or "stdin.py", "-" },
    { stdin = table.concat(lines, "\n") .. "\n", text = true }
  ):wait()
  if res.code ~= 0 then
    if not silent then warn("black: " .. vim.trim(res.stderr or "failed")) end
    return
  end
  local out = vim.split((res.stdout:gsub("\n$", "")), "\n", { plain = true })
  if not vim.deep_equal(out, lines) then
    local view = vim.fn.winsaveview()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, out)
    vim.fn.winrestview(view)
  end
end

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.py",
  callback = function(ev)
    if vim.g.black_on_save then black_format(ev.buf, true) end
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    local function map(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc }) end
    -- 0.11+ already gives: K hover · grn rename · gra action · grr refs · gri impl · gO symbols
    map("gd", vim.lsp.buf.definition, "Go to definition")
    map("<leader>cf", function()
      if vim.bo[ev.buf].filetype == "python" then
        black_format(ev.buf)
      else
        vim.lsp.buf.format({ async = true })
      end
    end, "Format (black for Python)")
    map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
    if client and client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
    end
  end,
})

-- :EnvLsp -> shows which binary each running server was launched from.
vim.api.nvim_create_user_command("EnvLsp", function()
  local e = Env.current
  local lines = { e and ("env: %s [%s] %s"):format(e.name, e.kind, e.prefix) or "env: none active" }
  for _, c in ipairs(vim.lsp.get_clients()) do
    local cmd = type(c.config.cmd) == "table" and c.config.cmd[1] or "<function>"
    lines[#lines + 1] = ("%s -> %s"):format(c.name, cmd)
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "EnvLsp" })
end, {})

-- ── Writing / learning ───────────────────────────────────────────────────────
setup("render-markdown", {
  file_types = { "markdown", "quarto", "rmd" },
  latex = { enabled = false },
  heading = { sign = false },
  code = { sign = false, width = "block", right_pad = 1, border = "thin" },
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "quarto", "rmd", "text", "gitcommit" },
  callback = function(ev)
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
    vim.opt_local.breakindent = true
    vim.opt_local.spell = true
    vim.opt_local.conceallevel = 2
    vim.opt_local.colorcolumn = ""
    local opts = { buffer = ev.buf, expr = true }
    vim.keymap.set("n", "j", "v:count == 0 ? 'gj' : 'j'", opts)
    vim.keymap.set("n", "k", "v:count == 0 ? 'gk' : 'k'", opts)
  end,
})

-- REPL: send lines/selections from a script to a Python/R REPL. The REPL is
-- launched from $PATH, which is the activated env's bin dir when an env is active.
local iron_ok, iron_view = pcall(require, "iron.view")
setup("iron.core", {
  config = {
    scratch_repl = true,
    -- iron.nvim errors out if no default repl_open_cmd is given
    repl_open_cmd = iron_ok and iron_view.split.vertical.rightbelow("40%") or "vertical botright 80 split",
  },
  keymaps = {
    toggle_repl = "<leader>rr",
    restart_repl = "<leader>rR",
    send_line = "<leader>rl",
    send_paragraph = "<leader>rp",
    send_file = "<leader>rf",
    send_motion = "<leader>rc",
    visual_send = "<leader>rc",
    interrupt = "<leader>rx",
    exit = "<leader>rq",
    clear = "<leader>rk",
  },
  ignore_blank_lines = true,
})

-- :Note [title]  ->  ~/notes/YYYY-MM-DD-title.md with a learning template
local notes_dir = vim.fn.expand("~/notes")
vim.api.nvim_create_user_command("Note", function(cmd)
  vim.fn.mkdir(notes_dir, "p")
  local slug = cmd.args ~= "" and ("-" .. cmd.args:gsub("%s+", "-"):lower()) or ""
  vim.cmd.edit(vim.fn.fnameescape(("%s/%s%s.md"):format(notes_dir, os.date("%Y-%m-%d"), slug)))
  if vim.api.nvim_buf_line_count(0) == 1 and vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "" then
    local title = cmd.args ~= "" and cmd.args or os.date("%Y-%m-%d")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {
      "# " .. title, "",
      "## In my own words", "", "",
      "## Example", "", "",
      "## Questions", "", "",
      "## Links", "",
    })
    vim.api.nvim_win_set_cursor(0, { 4, 0 })
  end
end, { nargs = "*" })

-- ── Keymaps ──────────────────────────────────────────────────────────────────
local map = vim.keymap.set
map("n", "<Esc>", "<cmd>nohlsearch<CR>")
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save" })
map({ "n", "v" }, "<leader>y", '"+y', { desc = "Copy to system clipboard" })
map("v", "<", "<gv")
map("v", ">", ">gv")

map("n", "<leader><space>", function() Snacks.picker.files() end, { desc = "Files" })
map("n", "<leader>,", function() Snacks.picker.buffers() end, { desc = "Buffers" })
map("n", "<leader>/", function() Snacks.picker.grep() end, { desc = "Grep" })
map("n", "<leader>e", function() Snacks.explorer() end, { desc = "Explorer" })
map("n", "<leader>z", function() Snacks.zen() end, { desc = "Zen mode" })
map("n", "<leader>ff", function() Snacks.picker.files() end, { desc = "Files" })
map("n", "<leader>fr", function() Snacks.picker.recent() end, { desc = "Recent" })
map("n", "<leader>fh", function() Snacks.picker.help() end, { desc = "Help" })
map("n", "<leader>fk", function() Snacks.picker.keymaps() end, { desc = "Keymaps" })
map("n", "<leader>fd", function() Snacks.picker.diagnostics() end, { desc = "Diagnostics" })
map("n", "<leader>fs", function() Snacks.picker.lsp_symbols() end, { desc = "Symbols" })
map("n", "<leader>nn", ":Note ", { desc = "New note" })
map("n", "<leader>nf", function() Snacks.picker.files({ cwd = notes_dir }) end, { desc = "Find note" })
map("n", "<leader>ng", function() Snacks.picker.grep({ cwd = notes_dir }) end, { desc = "Grep notes" })

pcall(function()
  require("which-key").add({
    { "<leader>f", group = "find" },
    { "<leader>c", group = "code" },
    { "<leader>n", group = "notes" },
    { "<leader>r", group = "repl", mode = { "n", "v" } },
  })
end)

vim.api.nvim_create_autocmd("TextYankPost", { callback = function() vim.hl.on_yank() end })

