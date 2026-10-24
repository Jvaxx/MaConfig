-- INFO: kOS (Kerboscript) — détection du type de fichier et activation du LSP
-- La config du serveur est dans lsp/kos_ls.lua, la syntaxe dans syntax/kerboscript.vim.

vim.filetype.add({ extension = { ks = "kerboscript" } })

-- Installation : kos-ls dans le PATH (lien ~/.local/bin/kos-ls → ~/Projects/kos-ls/bin/kos-ls)
if vim.fn.executable("kos-ls") == 1 then
    vim.lsp.enable("kos_ls")
end

-- Coloration sémantique de kos-ls, par-dessus syntax/kerboscript.vim (qui reste pour
-- l'affichage avant que le serveur réponde). Liens pour ce que nvim ne colore pas par
-- défaut ; à reposer après chaque :colorscheme, qui les efface.
local function semantic_links()
    -- ship, kerbin, sas… (les fonctions intégrées ont déjà @function.builtin)
    vim.api.nvim_set_hl(0, "@lsp.typemod.variable.defaultLibrary", { link = "@variable.builtin" })
    -- @lazyglobal, @clobberbuiltins, // #include, // #region (défaut : @constant.macro)
    vim.api.nvim_set_hl(0, "@lsp.type.macro", { link = "@keyword.directive" })
end
semantic_links()
vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("KosSemantic", { clear = true }),
    callback = semantic_links,
})

-- INFO: Console kOS (telnet) dans un buffer, pour lancer les scripts sans quitter nvim.
-- Activer le serveur telnet dans le jeu : bouton kOS de la toolbar → "Telnet".
--
-- kOS édite la ligne côté serveur (mode caractère), donc pas d'autocomplétion dans
-- le terminal. On tape donc dans une barre flottante kerboscript posée en haut du
-- buffer console (kOS écrit en bas) : le LSP (kos-ls) et blink.cmp y fonctionnent.
-- La barre suit le buffer console : elle apparaît quand on y va, disparaît quand on
-- change de buffer. Les lignes envoyées y restent : c'est l'historique (k/↑ pour
-- remonter, <CR> renvoie la ligne), et le LSP connaît les variables déjà déclarées.
--   <CR>      envoyer la ligne courante (ou la sélection, en visuel)
--   <C-c>     interrompre le programme kOS en cours
--   <Esc>     (mode normal) passer au terminal pour taper en direct (menus, TERMINAL:INPUT)
--   <CR>      (terminal, mode normal) revenir à la barre de saisie

-- Dossier Ships/Script (l'archive `0:`) du jeu en cours : celui du fichier ouvert ou du
-- répertoire courant (KSP-Career, KSP-kOS…), sinon KSP-kOS.
local function script_root()
    for _, path in ipairs({ vim.api.nvim_buf_get_name(0), vim.fn.getcwd() .. "/x" }) do
        for parent in vim.fs.parents(path) do
            if vim.fs.basename(parent) == "Script" and vim.fs.basename(vim.fs.dirname(parent)) == "Ships" then
                return parent
            end
        end
    end
    return vim.fn.expand("~/Games/KSP-kOS/Ships/Script")
end
local host, port = "127.0.0.1", 5410
-- host_win : la fenêtre qui affiche la console et porte la barre de saisie
-- root : Ships/Script du jeu au moment de :KosTerm (kos-ls attache la barre à ce projet)
local kos = { term_buf = nil, input_buf = nil, input_win = nil, host_win = nil, job = nil, root = nil }

local function valid(buf)
    return buf ~= nil and vim.api.nvim_buf_is_valid(buf)
end

local function win_valid(win)
    return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function send(text)
    if not kos.job then
        vim.notify("kOS : console déconnectée, relancer :KosTerm", vim.log.levels.WARN)
        return false
    end
    vim.fn.chansend(kos.job, text)
    -- Le terminal ne défile que si son curseur est sur la dernière ligne
    for _, win in ipairs(vim.fn.win_findbuf(kos.term_buf)) do
        vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(kos.term_buf), 0 })
    end
    return true
end

-- Envoie la ligne sous le curseur, puis la range en fin d'historique avec une ligne vide après
local function send_line()
    local buf = kos.input_buf
    local row = vim.api.nvim_win_get_cursor(0)[1]
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1]
    if not send(line .. "\r") then
        return
    end
    if line ~= "" then
        local last = vim.api.nvim_buf_line_count(buf)
        if row == last then
            vim.api.nvim_buf_set_lines(buf, last, last, false, { "" })
        elseif vim.api.nvim_buf_get_lines(buf, last - 1, last, false)[1] == "" then
            vim.api.nvim_buf_set_lines(buf, last - 1, last, false, { line, "" })
        else
            -- Un brouillon est en cours sur la dernière ligne : on le garde
            vim.api.nvim_buf_set_lines(buf, last - 1, last - 1, false, { line })
        end
        vim.bo[buf].modified = false
    end
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(buf), 0 })
end

local function send_selection()
    local first, last = vim.fn.line("v"), vim.fn.line(".")
    if first > last then
        first, last = last, first
    end
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    for _, line in ipairs(vim.api.nvim_buf_get_lines(kos.input_buf, first - 1, last, false)) do
        if not send(line .. "\r") then
            return
        end
    end
end

local function close_input()
    if win_valid(kos.input_win) then
        vim.api.nvim_win_close(kos.input_win, true)
    end
    kos.input_win = nil
end

local function focus_terminal()
    if win_valid(kos.host_win) then
        vim.cmd.nohlsearch()
        vim.api.nvim_set_current_win(kos.host_win)
    end
end

-- Le buffer doit avoir un nom de fichier sous Ships/Script et un buftype vide pour
-- que kos-ls s'y attache ; il n'est jamais écrit sur le disque.
local function setup_input_buffer(buf)
    vim.api.nvim_buf_set_name(buf, kos.root .. "/.kosterm.ks")
    vim.bo[buf].swapfile = false
    vim.bo[buf].bufhidden = "hide"
    local group = vim.api.nvim_create_augroup("KosTermInput", { clear = true })
    vim.api.nvim_create_autocmd({ "BufWriteCmd", "TextChanged", "TextChangedI" }, {
        group = group,
        buffer = buf,
        callback = function()
            vim.bo[buf].modified = false
        end,
    })
    local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc })
    end
    map({ "n", "i" }, "<CR>", send_line, "kOS : envoyer la ligne")
    map("x", "<CR>", send_selection, "kOS : envoyer la sélection")
    map({ "n", "i" }, "<C-c>", function()
        send("\3")
    end, "kOS : interrompre le programme")
    map("n", "<Esc>", focus_terminal, "kOS : passer au terminal")
    vim.bo[buf].filetype = "kerboscript"
    -- Une ligne seule est rarement un script valide : pas de diagnostics ici
    vim.diagnostic.enable(false, { bufnr = buf })
end

-- Barre d'une ligne collée en haut de la fenêtre console, séparée par un trait
local function input_config(win)
    return {
        relative = "win",
        win = win,
        row = 0,
        col = 0,
        width = vim.api.nvim_win_get_width(win),
        height = 1,
        style = "minimal",
        border = { "", "", "", "", "─", "─", "─", "" },
        footer = " kOS ",
        footer_pos = "right",
    }
end

local function open_input(win)
    kos.host_win = win
    if win_valid(kos.input_win) then
        vim.api.nvim_win_set_config(kos.input_win, input_config(win))
        vim.api.nvim_set_current_win(kos.input_win)
    else
        local new_buf = not valid(kos.input_buf)
        if new_buf then
            kos.input_buf = vim.api.nvim_create_buf(false, false)
        end
        kos.input_win = vim.api.nvim_open_win(kos.input_buf, true, input_config(win))
        if new_buf then
            setup_input_buffer(kos.input_buf)
        end
    end
    vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(kos.input_buf), 0 })
    vim.cmd.startinsert({ bang = true })
end

-- La barre suit la fenêtre console : redimensionnement, fermeture, et si on change
-- de buffer depuis la barre (ex. <S-l>), le buffer s'ouvre dans la fenêtre console.
local group = vim.api.nvim_create_augroup("KosTerm", { clear = true })
vim.api.nvim_create_autocmd("WinResized", {
    group = group,
    callback = function()
        if win_valid(kos.input_win) and win_valid(kos.host_win) then
            vim.api.nvim_win_set_config(kos.input_win, input_config(kos.host_win))
        end
    end,
})
vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
        if tonumber(args.match) == kos.host_win then
            vim.schedule(close_input)
        end
    end,
})
vim.api.nvim_create_autocmd("BufWinEnter", {
    group = group,
    callback = function(args)
        local win = vim.api.nvim_get_current_win()
        if win == kos.input_win and args.buf ~= kos.input_buf then
            vim.schedule(function()
                if not win_valid(kos.host_win) then
                    close_input()
                elseif args.buf == kos.term_buf then
                    -- On est retombé sur la console elle-même : on remet juste la barre
                    vim.api.nvim_win_set_buf(win, kos.input_buf)
                    open_input(kos.host_win)
                else
                    close_input()
                    vim.api.nvim_set_current_win(kos.host_win)
                    vim.api.nvim_win_set_buf(kos.host_win, args.buf)
                end
            end)
        end
    end,
})

local function start_console(win)
    local old = kos.term_buf
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(win, buf)
    kos.job = vim.fn.jobstart({ "telnet", host, tostring(port) }, { term = true })
    kos.term_buf = buf
    if valid(old) then
        vim.api.nvim_buf_delete(old, { force = true })
    end
    vim.api.nvim_buf_set_name(buf, "kOS")

    vim.api.nvim_create_autocmd("BufWinEnter", {
        buffer = buf,
        callback = function()
            local host_win = vim.api.nvim_get_current_win()
            if host_win == kos.input_win then
                return -- affiché dans la barre par erreur : géré par l'autocmd KosTerm
            end
            vim.schedule(function()
                if kos.job and win_valid(host_win) and vim.api.nvim_win_get_buf(host_win) == buf then
                    open_input(host_win)
                end
            end)
        end,
    })
    vim.api.nvim_create_autocmd("BufWinLeave", {
        buffer = buf,
        callback = function()
            vim.schedule(function()
                -- Une ancienne console remplacée par une nouvelle ne ferme pas sa barre
                if kos.term_buf == buf then
                    close_input()
                end
            end)
        end,
    })
    vim.api.nvim_create_autocmd("TermClose", {
        buffer = buf,
        once = true,
        callback = function()
            kos.job = nil
            vim.schedule(close_input)
            vim.notify("kOS : connexion telnet fermée", vim.log.levels.INFO)
        end,
    })
    vim.keymap.set("n", "<CR>", function()
        if kos.job then
            open_input(vim.api.nvim_get_current_win())
        end
    end, { buffer = buf, desc = "kOS : barre de saisie" })

    open_input(win)
end

vim.api.nvim_create_user_command("KosTerm", function()
    local win = vim.api.nvim_get_current_win()
    if win == kos.input_win then
        vim.cmd.startinsert({ bang = true })
        return
    end
    if kos.job then
        if vim.api.nvim_win_get_buf(win) == kos.term_buf then
            open_input(win)
        else
            vim.api.nvim_win_set_buf(win, kos.term_buf) -- BufWinEnter ouvre la barre
        end
        return
    end
    kos.root = script_root()
    -- On vérifie que le serveur répond avant de créer quoi que ce soit
    local tcp = vim.uv.new_tcp()
    tcp:connect(host, port, function(err)
        tcp:close()
        vim.schedule(function()
            if err then
                vim.notify(
                    ("kOS : pas de serveur telnet sur %s:%d (bouton kOS de la toolbar → Telnet)"):format(host, port),
                    vim.log.levels.WARN
                )
                return
            end
            start_console(win_valid(win) and win or vim.api.nvim_get_current_win())
        end)
    end)
end, { desc = "Ouvrir la console kOS (telnet + saisie avec autocomplétion)" })

-- INFO: Copies de vol (tools/kbuild.py dans Ships/Script : commentaires retirés,
-- "0:/src/" → "1:/", manifeste .deps par mission). Reconstruites à chaque écriture
-- d'un fichier de src/ ; :KosBuild affiche en plus la place prise sur le disque du vaisseau.
local function build(root, report)
    local tool = root .. "/tools/kbuild.py"
    if vim.fn.filereadable(tool) == 0 then
        return
    end
    local cmd = { "python3", tool, report and "--report" or "--quiet" }
    vim.system(cmd, { text = true }, function(res)
        vim.schedule(function()
            local out = vim.trim((res.stdout or "") .. "\n" .. (res.stderr or ""))
            if res.code ~= 0 then
                vim.notify("kOS build :\n" .. out, vim.log.levels.ERROR)
            elseif report and out ~= "" then
                vim.notify(out, vim.log.levels.INFO)
            end
        end)
    end)
end

vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*/Ships/Script/src/*.ks",
    callback = function(args)
        -- args.file peut être relatif au répertoire courant (ex. lib/std.ks)
        for parent in vim.fs.parents(vim.fn.fnamemodify(args.file, ":p")) do
            if vim.fs.basename(parent) == "src" then
                build(vim.fs.dirname(parent), false)
                return
            end
        end
    end,
})

vim.api.nvim_create_user_command("KosBuild", function()
    build(script_root(), true)
end, { desc = "Construire les copies de vol kOS et afficher la place sur le disque" })
