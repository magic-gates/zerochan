{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixgl.url = "github:nix-community/nixGL";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nixgl,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        nixGL = nixgl.packages.${system}.nixGLDefault;

        surfer-wrapped = pkgs.writeShellScriptBin "surfer" ''
          exec ${nixGL}/bin/nixGL ${pkgs.surfer}/bin/surfer "$@"
        '';
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            stdenv.cc.cc.lib

            python313
            uv

            zlib
            verilator
            surfer-wrapped
          ];

          shellHook = ''
            export LD_LIBRARY_PATH=${
              pkgs.lib.makeLibraryPath [
                pkgs.stdenv.cc.cc.lib
                pkgs.zlib
              ]
            };
            if [ ! -d .venv ]; then
              uv venv
            fi
            source .venv/bin/activate
          '';
        };
      }
    );
}
