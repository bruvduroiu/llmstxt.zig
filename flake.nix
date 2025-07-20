{
  description = "llmstxt.zig is a library for extracting AI-friendly documentation from complex codebases.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig.url = "github:mitchellh/zig-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs: let
    overlays = [
      # Other overlays
      (final: prev: rec {
        zigpkgs = inputs.zig.packages.${prev.system};
        zig = inputs.zig.packages.${prev.system}."0.14.1";

        # Our package
        llmstxt-zig = prev.callPackage ./nix/package.nix {
          packageDir = prev.callPackage ./deps.nix {};
        };
      })
    ];

  in 
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs { inherit overlays system; };
      in rec {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            zig
          ];
        };

        packages.default = pkgs.llmstxt-zig;
      }
    );
}
