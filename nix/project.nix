{ CHaP, indexState, pkgs, ... }:

let
  indexTool = { index-state = indexState; };
  fix-libs = { lib, pkgs, ... }: {
    packages.cardano-crypto-praos.components.library.pkgconfig =
      lib.mkForce [ [ pkgs.libsodium-vrf ] ];
    packages.cardano-crypto-class.components.library.pkgconfig =
      lib.mkForce [[ pkgs.libsodium-vrf pkgs.secp256k1 pkgs.libblst ]];
  };
  shell = { pkgs, ... }: {
    tools = {
      cabal = indexTool;
      cabal-fmt = indexTool;
      haskell-language-server = indexTool;
      hoogle = indexTool;
      fourmolu = indexTool;
      hlint = indexTool;
    };
    withHoogle = true;
    buildInputs = [ pkgs.just pkgs.nixfmt-classic pkgs.shellcheck ];
    shellHook = ''
      echo "Entering shell for cardano-mithril-client development"
    '';
  };

  mkProject = ctx@{ lib, pkgs, ... }: {
    name = "cardano-mithril-client";
    src = ./..;
    compiler-nix-name = "ghc984";
    shell = shell { inherit pkgs; };
    modules = [ fix-libs ];
    inputMap = { "https://chap.intersectmbo.org/" = CHaP; };
  };

  project = pkgs.haskell-nix.cabalProject' mkProject;

in {
  devShells.default = project.shell;
  inherit project;
  packages.unit-tests =
    project.hsPkgs.cardano-mithril-client.components.tests.unit-tests;
  packages.cardano-mithril-client =
    project.hsPkgs.cardano-mithril-client.components.library;
}
