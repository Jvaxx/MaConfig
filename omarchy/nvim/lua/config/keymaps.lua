-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

map("n", "<leader>a", function()
  vim.cmd("w") -- sauvegarde le buffer courant
  vim.cmd("!./build.sh") -- lance le build

  local code = vim.v.shell_error
  if code == 0 then
    vim.notify("Build OK ✅", vim.log.levels.INFO, { title = "build.sh" })
  else
    vim.notify("Build FAILED (code " .. code .. ")", vim.log.levels.ERROR, { title = "build.sh" })
  end
end, { desc = "Run build.sh", silent = true })
