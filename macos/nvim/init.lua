---@diagnostic disable: missing-fields

vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.opt.termguicolors = true
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = "a"
vim.opt.clipboard = "unnamedplus"
vim.opt.undofile = true
vim.opt.signcolumn = "yes"
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣", }
vim.opt.inccommand = "nosplit"
vim.opt.cursorline = true
vim.opt.colorcolumn = "90"

-- set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true

vim.opt.breakindent = true
vim.opt.wrap = false

-- formatting
vim.opt.tabstop = 4
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.textwidth = 90

vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN] = " ",
      [vim.diagnostic.severity.INFO] = " ",
      [vim.diagnostic.severity.HINT] = " ",
    },
  },
  virtual_text = true, -- show inline diagnostics
})

vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
vim.cmd.colorscheme("catppuccin")

-- INFO: formatting and syntax highlighting
vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter" }, { confirm = false })
local required_parsers = { "c", "cpp", "lua", "vim", "vimdoc", "query", "rust", "go", "python" }
local config = require("nvim-treesitter.config")
local missing_parsers = vim.iter(required_parsers):filter(function(parser)
  return not vim.tbl_contains(config.get_installed(), parser)
end):totable()
if #missing_parsers > 0 then
  require("nvim-treesitter").install(missing_parsers)
end

-- INFO: completion engine
vim.pack.add({ "https://github.com/saghen/blink.cmp" }, { confirm = false })
require("blink.cmp").setup({
  completion = {
    documentation = {
      auto_show = true,
    },
  },
  keymap = {
    ['<C-p>'] = { 'select_prev', 'fallback_to_mappings' },
    ['<C-n>'] = { 'select_next', 'fallback_to_mappings' },
    ['<C-y>'] = { 'select_and_accept', 'fallback' },
    ['<C-e>'] = { 'cancel', 'fallback' },
    ['<C-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
    ['<Tab>'] = { 'snippet_forward', 'fallback' },
    ['<S-Tab>'] = { 'snippet_backward', 'fallback' },
    ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
    ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
    ['<leader>k'] = { 'show_signature', 'hide_signature', 'fallback' },
  },
  fuzzy = {
    implementation = "lua",
  },
})

-- INFO: lsp server installation and configuration
local lsp_servers = {
  lua_ls = {
    -- [https://luals.github.io/wiki/settings/](https://luals.github.io/wiki/settings/) | `:h nvim_get_runtime_file`
    Lua = { workspace = { library = vim.api.nvim_get_runtime_file("lua", true) }, },
  },
  clangd = {},
  rust_analyzer = {},
  gopls = {},
  pyright = {
    python = {
      analysis = {
        typeCheckingMode = "basic", -- ou "strict" pour typer fortement
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      }
    }
  },
  ruff = {}, -- Formattage
}

-- INFO: Autopairs (fermeture automatique des délimiteurs)
vim.pack.add({ "https://github.com/windwp/nvim-autopairs" }, { confirm = false })

require("nvim-autopairs").setup({
  check_ts = true,                -- Utilise Treesitter pour analyser le contexte
  ts_config = {
    lua = { "string", "source" }, -- Ne pas ajouter de paires dans les strings lua
    python = { "string" },        -- Ne pas ajouter de paires dans les strings python
  },
  disable_filetype = { "TelescopePrompt", "vim" },
  fast_wrap = {}, -- Permet d'envelopper rapidement un mot avec <M-e> (Alt+e)
})

-- INFO: Barre des buffers (onglets style LazyVim)
vim.pack.add({ "https://github.com/akinsho/bufferline.nvim" }, { confirm = false })
require("bufferline").setup({
  options = {
    mode = "buffers",         -- mode par défaut : affiche les buffers ouverts
    -- separator_style = "slant", -- style biseauté, très esthétique (optionnel)
    diagnostics = "nvim_lsp", -- affiche les erreurs LSP directement dans l'onglet
    always_show_bufferline = true,
  }
})


vim.pack.add({
  "https://github.com/neovim/nvim-lspconfig",                    -- default configs for lsps
  "https://github.com/mason-org/mason.nvim",                     -- package manager
  "https://github.com/mason-org/mason-lspconfig.nvim",           -- lspconfig bridge
  "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" -- auto installer
}, { confirm = false })

require("mason").setup()
require("mason-lspconfig").setup()
require("mason-tool-installer").setup({
  ensure_installed = vim.tbl_keys(lsp_servers),
})

-- configure each lsp server on the table
-- to check what clients are attached to the current buffer, use
-- `:checkhealth vim.lsp`. to view default lsp keybindings, use `:h lsp-defaults`.
for server, config_lsp in pairs(lsp_servers) do
  vim.lsp.config(server, {
    settings = config_lsp,

    -- only create the keymaps if the server attaches successfully
    on_attach = function(client, bufnr)
      vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr, desc = "Definition", })
      vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr, desc = "Declaration", })
      vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, { buffer = bufnr, desc = "Code Format", })
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { buffer = bufnr, desc = "Code Action" })
      vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { buffer = bufnr, desc = "Code Rename" })
      vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, { buffer = bufnr, desc = "Code Diagnostic float" })

      -- Activer le format-on-save si le serveur le supporte
      if client and client.server_capabilities.documentFormattingProvider then
        local augroup = vim.api.nvim_create_augroup("LspFormatting_" .. bufnr, { clear = true })
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = augroup,
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.format({ async = false, id = client.id })
          end,
          desc = "LSP Format on save",
        })
      end
    end,
  })
end

-- INFO: fuzzy finder
vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",       -- library dependency
  "https://github.com/nvim-tree/nvim-web-devicons", -- icons (nerd font)
  {
    src = "https://github.com/nvim-telescope/telescope.nvim",
    version = "master"
  },
}, { confirm = false })

require("telescope").setup({})

local pickers = require("telescope.builtin")

vim.keymap.set("n", "<leader>sp", pickers.builtin, { desc = "Search Builtin Pickers", })
vim.keymap.set("n", "<leader>sb", pickers.buffers, { desc = "Search Buffers", })
vim.keymap.set("n", "<leader>sf", pickers.find_files, { desc = "Search Files", })
vim.keymap.set("n", "<leader>sw", pickers.grep_string, { desc = "Search Current Word", })
vim.keymap.set("n", "<leader>sg", pickers.live_grep, { desc = "Search by Grep", })
vim.keymap.set("n", "<leader>sr", pickers.resume, { desc = "Search Resume", })
vim.keymap.set("n", "gr", pickers.lsp_references, { desc = "References" })
vim.keymap.set("n", "<leader>cs", pickers.lsp_document_symbols, { desc = "Code Symbols (Doc)" })
vim.keymap.set("n", "<leader>cS", pickers.lsp_workspace_symbols, { desc = "Code Symbols (Proj)" })
vim.keymap.set("n", "<leader>sh", pickers.help_tags, { desc = "Search Help", })
vim.keymap.set("n", "<leader>sm", pickers.man_pages, { desc = "Search Manuals", })

vim.keymap.set("n", "<leader>e", "<cmd>Lexplore<CR>", { desc = "Explorer" })
vim.g.netrw_winsize = 25

-- Raccourcis pour naviguer entre les fenêtres plus rapidement (style LazyVim)
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Aller à la fenêtre de gauche" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Aller à la fenêtre du bas" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Aller à la fenêtre du haut" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Aller à la fenêtre de droite" })

-- Raccourcis style LazyVim pour les onglets (buffers)
vim.keymap.set("n", "<S-h>", "<cmd>BufferLineCyclePrev<CR>", { desc = "Onglet précédent" })
vim.keymap.set("n", "<S-l>", "<cmd>BufferLineCycleNext<CR>", { desc = "Onglet suivant" })
-- vim.keymap.set("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Buffer Delete" })

-- Quitter le mode terminal avec une double pression sur Échap
vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Sortir du mode terminal" })

vim.keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Déplacer la sélection vers le bas" })
vim.keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Déplacer la sélection vers le haut" })
vim.keymap.set("n", "<A-j>", ":m .+1<CR>==", { desc = "Déplacer la ligne vers le bas" })
vim.keymap.set("n", "<A-k>", ":m .-2<CR>==", { desc = "Déplacer la ligne vers le haut" })

-- Remplacement de :bdelete pour ne pas casser Netrw ou les splits
vim.keymap.set("n", "<leader>bd", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local modified = vim.bo[bufnr].modified

  if modified then
    vim.notify("Le bufferpas sauvegardé !", vim.log.levels.WARN)
    return
  end

  -- Bascule vers le buffer précédent avant de supprimer le courant
  vim.cmd("bprevious")
  -- Supprime l'ancien buffer en tâche de fond pour garder la fenêtre ouverte
  vim.cmd("bdelete " .. bufnr)
end, { desc = "Buffer Delete" })

-- Buffer force delete mais safe
vim.keymap.set("n", "<leader>bD", function()
  local bufnr = vim.api.nvim_get_current_buf()
  -- Bascule vers le buffer précédent avant de supprimer le courant
  vim.cmd("bprevious")
  -- Supprime l'ancien buffer en tâche de fond pour garder la fenêtre ouverte
  vim.cmd("bdelete! " .. bufnr)
end, { desc = "Buffer Force Delete" })

-- Corriger le problème de bascule vers la droite depuis Netrw
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    -- Supprime le raccourci local de Netrw pour laisser passer votre <C-l> global
    pcall(vim.api.nvim_buf_del_keymap, 0, "n", "<C-L>")
  end,
})

-- Corriger le bug des buffers vides [No Name] générés par Lexplore
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function()
    -- Empêche Netrw de créer des buffers fantômes persistants
    vim.bo.bufhidden = "wipe"
  end,
  desc = "Wipe netrw buffers when hidden to avoid [No Name] pollution",
})

-- INFO: Ouvrir Netrw en panneau latéral au lancement sur un dossier
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    local current_file = vim.fn.expand("%:p")
    if vim.fn.isdirectory(current_file) == 1 then
      vim.cmd("enew")
      vim.cmd("bwipeout #")
      vim.cmd("cd " .. vim.fn.fnameescape(current_file))
      vim.cmd("Lexplore")
    end
  end,
  desc = "Ouvre Netrw comme panneau latéral si nvim est lancé dans un dossier",
})

-- Corriger l'ouverture des nouveaux fichiers (%) dans la barre latérale Netrw
vim.api.nvim_create_autocmd("FileType", {
  pattern = "netrw",
  callback = function(opts)
    vim.keymap.set("n", "%", function()
      -- Demande le nom du fichier à l'utilisateur
      local filename = vim.fn.input("Nouveau fichier : ")
      if filename == "" then return end

      -- Récupère le dossier actuellement affiché par Netrw
      local netrw_dir = vim.b.netrw_curdir or vim.fn.expand("%:p:h")

      -- Si Netrw a une fenêtre "cible" d'origine (généralement le cas avec Lexplore), on y va
      if vim.g.netrw_chgwin then
        vim.cmd(vim.g.netrw_chgwin .. "wincmd w")
      else
        -- Sinon, on force le saut vers la fenêtre de droite
        vim.cmd("wincmd l")
      end

      -- Ouvre/crée le fichier avec son chemin complet
      vim.cmd("edit " .. netrw_dir .. "/" .. filename)
    end, { buffer = opts.buf, desc = "Créer un fichier dans la fenêtre principale" })
  end,
})

vim.pack.add({ "https://github.com/folke/which-key.nvim" }, { confirm = false })
require("which-key").setup({
  preset = "modern", -- Change l'affichage en un rectangle flottant
  win = {
    row = math.huge,
    col = math.huge,
    width = { max = 50 },
    border = "rounded",
    padding = { 1, 2 },
  },
  spec = {
    { "<leader>s", group = "Search", icon = { icon = "", color = "green", }, },
    { "<leader>c", group = "Code", icon = { icon = "", color = "green", }, },
  }
})

-- INFO: Barre des buffers (onglets style LazyVim)
vim.pack.add({ "https://github.com/akinsho/bufferline.nvim" }, { confirm = false })

-- INFO: Build script execution
vim.keymap.set("n", "<leader>a", function()
  -- Vérifie si le fichier "./build" existe et est exécutable
  if vim.fn.executable("./build.sh") == 0 then
    vim.notify("Script 'build.sh' exécutable pas trouvé", vim.log.levels.ERROR)
    return
  end
  vim.notify("Exec de ./build.sh...", vim.log.levels.INFO)

  -- Exécute la commande de façon asynchrone pour ne pas bloquer Neovim
  vim.system({ "./build.sh" }, { text = true }, function(out)
    vim.schedule(function() -- vim.schedule est requis pour modifier l'UI depuis un thread asynchrone
      if out.code == 0 then
        -- Succès : on affiche stdout
        local msg = out.stdout ~= "" and out.stdout or "Build successfull (sans sortie)."
        vim.notify(msg, vim.log.levels.INFO)
      else
        -- Échec : on affiche stderr (ou stdout si l'erreur y a été redirigée)
        local err_msg = out.stderr ~= "" and out.stderr or out.stdout
        vim.notify("Échec du build (code " .. out.code .. "):\n" .. err_msg, vim.log.levels.ERROR)
      end
    end)
  end)
end, { desc = "Exec ./build.sh" })

-- uncomment to enable automatic plugin updates
-- vim.pack.update()
