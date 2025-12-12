return {
  -- 1. Installer et configurer le plugin Catppuccin
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "frappe",
      transparent_background = false,
    },
  },

  -- 2. Dire à LazyVim d'utiliser ce schéma de couleurs
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
