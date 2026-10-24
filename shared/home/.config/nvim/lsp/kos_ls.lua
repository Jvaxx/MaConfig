-- INFO: kos-ls (~/Projects/kos-ls), fork maintenu de kos-language-server
-- La racine est le dossier Ships/Script du jeu : c'est le volume Archive `0:`,
-- ce qui permet au serveur de résoudre les `runpath("0:/lib/foo.ks")`. Volumes,
-- préchargement et dossiers exclus : ksconfig.json à la racine.

local function script_root(path)
    local dir = vim.fs.dirname(path)
    for parent in vim.fs.parents(path) do
        if vim.fs.basename(parent) == "Script" and vim.fs.basename(vim.fs.dirname(parent)) == "Ships" then
            return parent
        end
    end
    return vim.fs.root(path, { ".git" }) or dir
end

---@type vim.lsp.Config
return {
    cmd = { "kos-ls", "--stdio" },
    filetypes = { "kerboscript" },
    root_dir = function(bufnr, on_dir)
        on_dir(script_root(vim.api.nvim_buf_get_name(bufnr)))
    end,
    settings = {
        ["kos-ls"] = {
            completionCase = "camelcase",
        },
    },
    -- Mêmes raccourcis que les autres serveurs de init.lua
    on_attach = function(client, bufnr)
        vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = bufnr, desc = "Definition" })
        vim.keymap.set("n", "gD", vim.lsp.buf.declaration, { buffer = bufnr, desc = "Declaration" })
        vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { buffer = bufnr, desc = "Code Action" })
        vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { buffer = bufnr, desc = "Code Rename" })
        vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, { buffer = bufnr, desc = "Code Diagnostic float" })
        vim.keymap.set("n", "<leader>cf", vim.lsp.buf.format, { buffer = bufnr, desc = "Code Format" })

        -- Format-on-save, comme les autres serveurs (options : .kos-format ou
        -- la section format de ksconfig.json)
        vim.api.nvim_create_autocmd("BufWritePre", {
            group = vim.api.nvim_create_augroup("LspFormatting_" .. bufnr, { clear = true }),
            buffer = bufnr,
            callback = function()
                vim.lsp.buf.format({ async = false, id = client.id })
            end,
            desc = "LSP Format on save",
        })

        -- Correctif préféré du diagnostic sous le curseur, appliqué sans menu
        -- (au plus un par diagnostic ; s'il n'y en a pas, rien : <leader>ca)
        vim.keymap.set("n", "<leader>cq", function()
            vim.lsp.buf.code_action({
                filter = function(action)
                    return action.isPreferred
                end,
                apply = true,
            })
        end, { buffer = bufnr, desc = "Code Quick fix" })

        -- Place sur le disque du vaisseau : lentille en tête de fichier (taille
        -- sans commentaires, seul et avec tout ce que le script lance). Pas dans
        -- la barre de saisie de :KosTerm.
        if not vim.api.nvim_buf_get_name(bufnr):match("%.kosterm%.ks$") then
            vim.lsp.codelens.enable(true, { bufnr = bufnr })
        end
        -- Le détail fichier par fichier, depuis n'importe quelle ligne
        vim.keymap.set("n", "<leader>cl", function()
            client:exec_cmd({
                title = "Place sur le disque",
                command = "kos-ls.diskUsage",
                arguments = { vim.uri_from_bufnr(bufnr) },
            }, { bufnr = bufnr })
        end, { buffer = bufnr, desc = "Code Lens : place sur le disque" })
    end,
}
