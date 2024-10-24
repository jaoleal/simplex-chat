{
  description = "nix flake for simplex-chat";


  inputs.haskellNix.url = "github:input-output-hk/haskell.nix/armv7a";
  inputs.nixpkgs.follows = "haskellNix/nixpkgs-2305";
  inputs.mac2ios.url = "github:zw3rk/mobile-core-tools";
  inputs.hackage = {
    url = "github:input-output-hk/hackage.nix";
    flake = false;
  };
  inputs.haskellNix.inputs.hackage.follows = "hackage";
  inputs.flake-utils.url = "github:numtide/flake-utils";



  outputs = { self, haskellNix, nixpkgs, flake-utils, mac2ios, ... }:


    let

    systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

    buildSimplexLib = { extra-modules ? [], pkgs' ? haskellNix.legacyPackages.x86_64-linux, ... }: pkgs'.haskell-nix.project {
      compiler-nix-name = "ghc963";
      index-state = "2023-12-12T00:00:00Z";
      # We need this, to specify we want the cabal project.
      # If the stack.yaml was dropped, this would not be necessary.
      projectFileName = "cabal.project";

      # J this was calling the pkgs out of the function ??? wtf
      src = pkgs'.haskell-nix.haskellLib.cleanGit {
        name = "simplex-chat";
        src = ./.;
      };
      sha256map = import ./scripts/nix/sha256map.nix;
      modules = [
      ({ pkgs, lib, ...}: lib.mkIf (!pkgs.stdenv.hostPlatform.isWindows) {
        # This patch adds `dl` as an extra-library to direct-sqlciper, which is needed
        # on pretty much all unix platforms, but then blows up on windows m(
        packages.direct-sqlcipher.patches = [ ./scripts/nix/direct-sqlcipher-2.3.27.patch ];
      })
      ({ pkgs,lib, ... }: lib.mkIf (pkgs.stdenv.hostPlatform.isAndroid) {
        packages.simplex-chat.components.library.ghcOptions = [ "-pie" ];
      })] ++ extra-modules;
    };

    in
    flake-utils.lib.eachSystem systems (system:
        {
        packages =
        let
            systemDefinedPkgs = haskellNix.legacyPackages.${system};
            # by default we don't need to pass extra-modules.
            simplexPureBuild = (buildSimplexLib { extra-modules = []; pkgs' = systemDefinedPkgs; });
        in {
            "lib:simplex-chat" = simplexPureBuild.simplex-chat.components.library;
        };
    });
}
