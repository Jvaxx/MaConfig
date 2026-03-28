---@diagnostic disable: missing-fields

-- INFO: Options générales
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
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.opt.inccommand = "nosplit"
vim.opt.cursorline = true
vim.opt.colorcolumn = "90"
vim.opt.hlsearch = true
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")
vim.opt.breakindent = true
vim.opt.wrap = false

-- INFO: Formattage par défaut
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
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
    virtual_text = true, -- inline diag
})

vim.cmd.colorscheme("catppuccin")

-- INFO: Formattager et highlighting
vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter" }, { confirm = false })
local required_parsers = { "c", "cpp", "lua", "vim", "vimdoc", "query", "rust", "go", "python" }
local config = require("nvim-treesitter.config")
local missing_parsers = vim.iter(required_parsers)
    :filter(function(parser)
        return not vim.tbl_contains(config.get_installed(), parser)
    end)
    :totable()
if #missing_parsers > 0 then
    require("nvim-treesitter").install(missing_parsers)
end

-- INFO: Autocomplétion
vim.pack.add({ "https://github.com/saghen/blink.cmp" }, { confirm = false })
require("blink.cmp").setup({
    completion = {
        documentation = {
            auto_show = true,
        },
    },
    keymap = {
        ["<C-p>"] = { "select_prev", "fallback_to_mappings" },
        ["<C-n>"] = { "select_next", "fallback_to_mappings" },
        ["<C-y>"] = { "select_and_accept", "fallback" },
        ["<C-e>"] = { "cancel", "fallback" },
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<Tab>"] = { "snippet_forward", "fallback" },
        ["<S-Tab>"] = { "snippet_backward", "fallback" },
        ["<C-b>"] = { "scroll_documentation_up", "fallback" },
        ["<C-f>"] = { "scroll_documentation_down", "fallback" },
        -- ['<leader>k'] = { 'show_signature', 'hide_signature', 'fallback' },
    },
    fuzzy = {
        implementation = "lua",
    },
})

-- INFO: LSP Servers
local lsp_servers = {
    lua_ls = {
        -- [https://luals.github.io/wiki/settings/](https://luals.github.io/wiki/settings/) | `:h nvim_get_runtime_file`
        Lua = { workspace = { library = vim.api.nvim_get_runtime_file("lua", true) } },
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
            },
        },
    },
    ruff = {}, -- Formattage
}

-- INFO: Autopairs (fermeture automatique des délimiteurs)
vim.pack.add({ "https://github.com/windwp/nvim-autopairs" }, { confirm = false })

require("nvim-autopairs").setup({
    check_ts = true,                  -- Utilise Treesitter pour analyser le contexte
    ts_config = {
        lua = { "string", "source" }, -- Ne pas ajouter de paires dans les strings lua
        python = { "string" },        -- Ne pas ajouter de paires dans les strings python
    },
    disable_filetype = { "TelescopePrompt", "vim" },
    fast_wrap = {}, -- Permet d'envelopper rapidement un mot avec <M-e> (Alt+e)
})

-- INFO: Barre des buffers (onglets style LazyVim)
local function harpoon_index(path)
    local ok, harpoon = pcall(require, "harpoon")
    if not ok then
        return nil
    end
    local rel = vim.fn.fnamemodify(path, ":.")
    for i, item in ipairs(harpoon:list().items) do
        if item.value == rel then
            return i
        end
    end
    return nil
end
vim.pack.add({ "https://github.com/akinsho/bufferline.nvim" }, { confirm = false })
require("bufferline").setup({
    options = {
        mode = "buffers",         -- mode par défaut : affiche les buffers ouverts
        -- separator_style = "slant", -- style biseauté, très esthétique (optionnel)
        diagnostics = "nvim_lsp", -- affiche les erreurs LSP directement dans l'onglet
        always_show_bufferline = true,

        -- Affiche l'index harpoon si marqué, rien sinon
        numbers = function(opts)
            local ok, harpoon = pcall(require, "harpoon")
            if not ok then
                return ""
            end

            local list = harpoon:list()
            -- buf_name est absolu, item.value est relatif au cwd
            local buf_name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.id), ":.")

            for i, item in ipairs(list.items) do
                if item.value == buf_name then
                    return tostring(i)
                end
            end
            return ""
        end,
        sort_by = function(a, b)
            local ia = harpoon_index(a.path)
            local ib = harpoon_index(b.path)
            if ia and ib then
                return ia < ib
            end -- deux buffers harpoon : ordre harpoon
            if ia then
                return true
            end -- a est harpoon, b non → a devant
            if ib then
                return false
            end                -- b est harpoon, a non → b devant
            return a.id < b.id -- aucun des deux : ordre naturel
        end,
    },
})

vim.pack.add({
    "https://github.com/neovim/nvim-lspconfig",                     -- default configs for lsps
    "https://github.com/mason-org/mason.nvim",                      -- package manager
    "https://github.com/mason-org/mason-lspconfig.nvim",            -- lspconfig bridge
    "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim", -- auto installer
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
            vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr, desc = "Definition" })
            vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr, desc = "Declaration" })
            vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, { buffer = bufnr, desc = "Code Format" })
            vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { buffer = bufnr, desc = "Code Action" })
            vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { buffer = bufnr, desc = "Code Rename" })
            vim.keymap.set(
                "n",
                "<leader>cd",
                vim.diagnostic.open_float,
                { buffer = bufnr, desc = "Code Diagnostic float" }
            )

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

-- INFO: Telescope
vim.pack.add({
    "https://github.com/nvim-lua/plenary.nvim",       -- library dependency
    "https://github.com/nvim-tree/nvim-web-devicons", -- icons (nerd font)
    {
        src = "https://github.com/nvim-telescope/telescope.nvim",
        version = "master",
    },
}, { confirm = false })

require("telescope").setup({})

local pickers = require("telescope.builtin")

vim.keymap.set("n", "<leader>fp", pickers.builtin, { desc = "Find Builtin Pickers" })
vim.keymap.set("n", "<leader>fb", pickers.buffers, { desc = "Find Buffers" })
vim.keymap.set("n", "<leader>ff", pickers.find_files, { desc = "Find Files" })
vim.keymap.set("n", "<leader>fw", pickers.grep_string, { desc = "Find Current Word" })
vim.keymap.set("n", "<leader>fg", pickers.live_grep, { desc = "Find by Grep" })
vim.keymap.set("n", "<leader>fr", pickers.resume, { desc = "Find Resume" })
vim.keymap.set("n", "gr", pickers.lsp_references, { desc = "References" })
vim.keymap.set("n", "<leader>cs", pickers.lsp_document_symbols, { desc = "Code Symbols (Doc)" })
vim.keymap.set("n", "<leader>cS", pickers.lsp_workspace_symbols, { desc = "Code Symbols (Proj)" })
vim.keymap.set("n", "<leader>fh", pickers.help_tags, { desc = "Find Help" })
vim.keymap.set("n", "<leader>fm", pickers.man_pages, { desc = "Find Manuals" })

vim.keymap.set("n", "<leader>e", function()
    vim.cmd("Lexplore")
    -- INFO: Répartit équitablement l'espace entre toutes les fenêtres
    -- non verrouillées (donc toutes sauf Netrw)
    vim.cmd("wincmd =")
end, { desc = "Explorer" })
vim.g.netrw_winsize = -35
vim.g.netrw_banner = 0

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
        vim.wo.winfixwidth = true
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
            if filename == "" then
                return
            end

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
    triggers = {
        { "<auto>", mode = "nxso" },
        -- { "m",      mode = { "n", "v" } },
    },
    spec = {
        { "<leader>f", group = "Find", icon = { icon = "󰍉", color = "green" } },
        { "<leader>c", group = "Code", icon = { icon = "󰅩", color = "orange" } },
        { "<leader>b", group = "Buffer", icon = { icon = "󰓩", color = "blue" } },
        { "<leader>h", group = "Harpoon", icon = { icon = "󱡀", color = "yellow" } },
        { "<leader>g", group = "Git", icon = { icon = "󰊢", color = "red" } },
        { "<leader>a", desc = "Build", icon = { icon = "󰑓", color = "blue" } },
        { "s", group = "Surround", icon = { icon = "󰅪", color = "purple" } },
        { "<leader>e", desc = "Explorer", icon = { icon = "󰙅", color = "blue" } },
        -- INFO: Raccourcis pour les marques. Affichage sur which-key non fonctionnel.
        -- { "m", group = "Marks", icon = { icon = "󰃁", color = "blue" } },
        -- { "m,", desc = "Mark prev" }
        -- { "m;", desc = "Mark next" },
        -- { "dm", desc = "Del m + letter" },
        -- { "dm-", desc = "Del m curr line" },
        -- { "dm<space>", desc = "Del m buff" },
    },
})

-- INFO: Barre des buffers (onglets style LazyVim)
vim.pack.add({ "https://github.com/akinsho/bufferline.nvim" }, { confirm = false })

-- INFO: Mise en évidence des tags dans les commentaires
vim.pack.add({ "https://github.com/folke/todo-comments.nvim" }, { confirm = false })
require("todo-comments").setup({
    signs = true,
})
vim.keymap.set("n", "<leader>ft", "<cmd>TodoTelescope<CR>", { desc = "Find Todos" })

-- INFO: Build script execution
vim.keymap.set("n", "<leader>a", function()
    vim.cmd("wa")
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
                vim.notify("Succès du build.", vim.log.levels.INFO)
            else
                -- Échec : on affiche stderr (ou stdout si l'erreur y a été redirigée)
                local err_msg = out.stderr ~= "" and out.stderr or out.stdout
                vim.notify("Échec du build (code " .. out.code .. "):\n" .. err_msg, vim.log.levels.ERROR)
            end
        end)
    end)
end, { desc = "Save & exec ./build.sh" })

-- INFO: Lazygit en fenêtre flottante
vim.keymap.set("n", "<leader>gg", function()
    -- 1. Calcul des dimensions (80% de l'écran)
    local width = math.floor(vim.o.columns * 0.9)
    local height = math.floor(vim.o.lines * 0.9)
    local col = math.floor((vim.o.columns - width) / 2)
    local row = math.floor((vim.o.lines - height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    local win_opts = {
        relative = "editor",
        width = width,
        height = height,
        col = col,
        row = row,
        style = "minimal",  -- Désactive les numéros de ligne et autres éléments de l'UI
        border = "rounded", -- Bordure arrondie (identique à votre which-key)
    }
    vim.api.nvim_open_win(buf, true, win_opts)
    vim.fn.termopen("lazygit", {
        on_exit = function()
            -- Callback exécuté quand on quitte lazygit (avec 'q')
            if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true }) -- Purgé de force en tâche de fond
            end
        end,
    })
    vim.cmd("startinsert")
end, { desc = "Lazygit" })

-- INFO: Affichage visuel des marques dans la marge
vim.pack.add({ "https://github.com/chentoast/marks.nvim" }, { confirm = false })
require("marks").setup({
    signs = true,
    default_mappings = true,
    excluded_filetypes = { "TelescopePrompt", "lazy", "mason", "netrw" },
})

-- INFO: Ajout, suppression et modification des paires (parenthèses, guillemets...)
vim.pack.add({ "https://github.com/nvim-mini/mini.surround" }, { confirm = false })
require("mini.surround").setup({
    -- Les raccourcis par défaut (similaires au standard historique vim-surround) :
    -- sa : Add (Ajouter)
    -- sd : Delete (Supprimer)
    -- sr : Replace (Remplacer)
})

-- INFO: Flash visuel sur le texte yanké
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Flash le texte yanké",
    group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
    callback = function()
        vim.hl.on_yank({ higroup = "Visual", timeout = 150 })
    end,
})

-- INFO: Multicurseurs
-- Ctrl+N — sélectionne le mot sous le curseur et ajoute un curseur au suivant
-- Ctrl+↓ / Ctrl+↑ — ajoute un curseur verticalement ligne par ligne
-- n / N — occurrence suivante/précédente
-- q — skipe l'occurrence courante
-- i, a, I, A — entre en mode insertion sur tous les curseurs simultanément (avec feedback live)
vim.pack.add({ "https://github.com/mg979/vim-visual-multi" }, { confirm = false })

-- INFO: VimBeGood
vim.pack.add({ "https://github.com/ThePrimeagen/vim-be-good" }, { confirm = false })

-- INFO: Harpoon
vim.pack.add({
    { src = "https://github.com/ThePrimeagen/harpoon", version = "harpoon2" },
}, { confirm = false })
local harpoon = require("harpoon")
harpoon:setup()

-- Gestion de la liste
vim.keymap.set("n", "<leader>ha", function()
    harpoon:list():add()
    vim.cmd("redrawtabline")
end, { desc = "Harpoon Add" })
vim.keymap.set("n", "<leader>hd", function()
    harpoon:list():remove()
    vim.cmd("redrawtabline")
end, { desc = "Harpoon Delete" })
vim.keymap.set("n", "<leader>hh", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Harpoon Menu" })

-- Sauts directs AZERTY (&éè' = 1234 sans Shift)
vim.keymap.set("n", "<leader>&", function()
    harpoon:list():select(1)
end, { desc = "Harpoon 1" })
vim.keymap.set("n", "<leader>é", function()
    harpoon:list():select(2)
end, { desc = "Harpoon 2" })
vim.keymap.set("n", '<leader>"', function()
    harpoon:list():select(3)
end, { desc = "Harpoon 3" })
vim.keymap.set("n", "<leader>'", function()
    harpoon:list():select(4)
end, { desc = "Harpoon 4" })

-- uncomment to enable automatic plugin updates
-- vim.pack.update()
