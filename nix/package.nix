{ stdenv
, lib
, zig
, pkg-config
, system
, fetchFromGitHub
, packageDir
}:

let
  target = builtins.replaceStrings ["darwin"] ["macos"] system;
in 
stdenv.mkDerivation rec {
  pname = "llmstxt.zig";
  version = "0.1.0";

  tree-sitter-c-src = fetchFromGitHub {
    name = "tree-sitter-c";
    owner = "tree-sitter";
    repo = "tree-sitter-c";
    rev = "v0.24.1";
    sha256 = "sha256-gmzbdwvrKSo6C1fqTJFGxy8x0+T+vUTswm7F5sojzKc=";
  };

  tree-sitter-python-src = fetchFromGitHub {
    name = "tree-sitter-python";
    owner = "tree-sitter";
    repo = "tree-sitter-python";
    rev = "v0.23.6";
    sha256 = "sha256-71Od4sUsxGEvTwmXX8hBvzqD55hnXkVJublrhp1GICg=";
  };

  tree-sitter-go-src = fetchFromGitHub {
    name = "tree-sitter-go";
    owner = "tree-sitter";
    repo = "tree-sitter-go";
    rev = "v0.23.4";
    sha256 = "sha256-LxhFxOzYfRwj0ENFTgqmf3YFIUifOuow0ex/XJOLKHo=";
  };

  tree-sitter-zig-src = fetchFromGitHub {
    name = "tree-sitter-zig";
    owner = "tree-sitter-grammars";
    repo = "tree-sitter-zig";
    rev = "v1.1.2";
    sha256 = "sha256-lDMmnmeGr2ti9W692ZqySWObzSUa9vY7f+oHZiE8N+U=";
  };

  src = ./..;
  nativeBuildInputs = [ zig pkg-config ];

  buildPhase = ''
    # Necessary for zig cache to work
    export HOME=$TMPDIR

    mkdir -p vendor
    ln -sf ${tree-sitter-c-src} vendor/tree-sitter-c
    ln -sf ${tree-sitter-python-src} vendor/tree-sitter-python
    ln -sf ${tree-sitter-go-src} vendor/tree-sitter-go
    ln -sf ${tree-sitter-zig-src} vendor/tree-sitter-zig
  '';

  installPhase = ''
    runHook preInstall
    PACKAGE_DIR=${packageDir}
    zig build --global-cache-dir $(pwd)/.cache --system $PACKAGE_DIR -Doptimize=ReleaseSafe -Dtarget=${target} --prefix $out install
    runHook postInstall
  '';

  outputs = [ "out" "dev" ];

  meta = with lib; {
    description = "A light, AI-first codebase processor.";
    homepage = "https://github.com/bruvduroiu/llmstxt.zig";
    license = licenses.lgpl2;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
  };
}
