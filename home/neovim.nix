{
  inputs,
  config,
  pkgs,
  ...
}: {
  home.activation = {
    # fixes hotpot cannot be found error after updates
    clearHotpotCache = inputs.home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
      HOTPOT_CACHE="${config.xdg.cacheHome}/nvim/hotpot"
      if [[ -d "$HOTPOT_CACHE" ]]; then
        $DRY_RUN_CMD rm -rf "$VERBOSE_ARG" "$HOTPOT_CACHE"
      fi
    '';
  };

  xdg = {
    configFile = with config.lib.meta; {
      "nvim".source = mkMutableSymlink ../neovim;
    };
  };

  editorconfig = {
    enable = true;
    settings = {
      "*" = {
        trim_trailing_whitespace = true;
        insert_final_newline = true;
      };
      "*.yaml" = {
        indent_style = "space";
        indent_size = 2;
      };
    };
  };

  programs.neovim = {
    enable = true;
    package = pkgs.neovim-unwrapped;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs; [
      bashInteractive
      sumneko-lua-language-server
      pyright
      gopls
      fennel
      fnlfmt
      alejandra
      statix
    ];
    plugins = with pkgs.vimPlugins; [
      # highlighting
      nvim-treesitter.withAllGrammars
      nvim-treesitter-context
      playground
      gruvbox-material
      kanagawa-nvim
      lsp_lines-nvim
      heirline-nvim
      gitsigns-nvim
      noice-nvim
      nui-nvim
      vim-helm

      # external
      git-worktree-nvim
      vim-dirvish
      vim-fugitive
      vim-dispatch
      vim-oscyank
      venn-nvim
      gv-vim

      # Coding
      plenary-nvim
      telescope-nvim
      nvim-lspconfig
      null-ls-nvim
      lsp_signature-nvim
      omnisharp-extended-lsp-nvim
      nvim-dap
      nvim-dap-ui
      luasnip
      vim-test
      vim-rest-console
      harpoon

      # cmp
      nvim-cmp
      cmp-cmdline
      cmp-nvim-lsp
      cmp-buffer
      cmp-path
      cmp_luasnip

      # trying out lisp
      conjure
      vim-racket
      nvim-parinfer
      hotpot-nvim
    ];
  };
}
