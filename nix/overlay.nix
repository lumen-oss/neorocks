{neovim-input}: final: prev:
with prev.haskell.lib;
with prev.lib; let
  neovim-nightly = neovim-input.packages.${prev.stdenv.hostPlatform.system}.neovim;

  busted-nlua = final.lua5_1.pkgs.busted.overrideAttrs (oa: {
    propagatedBuildInputs =
      oa.propagatedBuildInputs
      ++ [
        final.lua5_1.pkgs.nlua
      ];
    nativeBuildInputs =
      oa.nativeBuildInputs
      ++ [
        final.makeWrapper
      ];
    postInstall =
      oa.postInstall
      +
      /*
      bash
      */
      ''
        wrapProgram $out/bin/busted --add-flags "--lua=nlua"
      '';
  });

  neorocksTest = {
    src,
    name,
    pname ? name, # The plugin/luarocks package name
    neovim ? neovim-nightly,
    version ? "scm-1",
    luaPackages ? _: [], # e.g. p: with p; [plenary.nvim]
    extraPackages ? [], # Extra dependencies
    ...
  } @ attrs: let
    # This allows us to pass in extra attrs to buildLuarocksPackage
    rest = builtins.removeAttrs attrs [
      "src"
      "name"
      "pname"
      "neovim"
      "version"
      "luaPackages"
      "extraPackages"
    ];
    lua5_1 = prev.lua5_1;
  in (lua5_1.pkgs.buildLuarocksPackage (rest
    // {
      inherit
        src
        version
        pname
        ;
      namePrefix =
        if name == pname
        then ""
        else "${name}-";
      propagatedBuildInputs =
        luaPackages lua5_1.pkgs
        ++ (with lua5_1.pkgs; [
          busted-nlua
          nlua
        ]);
      doCheck = true;
      nativeCheckInputs =
        extraPackages
        ++ (with lua5_1.pkgs; [
          nlua
          busted
          neovim
        ]);
      checkPhase = ''
        runHook preCheck
        export HOME=$(mktemp -d)
        luarocks test
        runHook postCheck
      '';
    }));
in {
  inherit
    neorocksTest
    neovim-nightly
    busted-nlua
    ;
}
