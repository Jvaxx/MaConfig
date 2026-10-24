-- INFO: Réglages pour les scripts kOS (*.ks)
vim.bo.commentstring = "// %s"
vim.bo.comments = "://"
-- Le langage est à accolades : smartindent suffit pour l'indentation
vim.bo.smartindent = true
vim.bo.cindent = false

vim.b.undo_ftplugin = "setlocal commentstring< comments< smartindent< cindent<"
