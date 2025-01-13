{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-parts, git-hooks, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ ... }: {
      imports = [
        git-hooks.flakeModule
        ./nix/uv.nix
      ];

      debug = true;
      systems = [ "x86_64-linux" /* "x86_64-darwin" */ "aarch64-darwin" ];

      perSystem = { config, system, pkgs', lib, ... }:
        let
          clang-tools-18 = pkgs'.llvmPackages_18.clang-tools;
          clang-format = pkgs'.runCommand "clang-format-wrapper" { } ''
            mkdir -p $out/bin
            ln -s ${clang-tools-18}/bin/clang-format $out/bin/clang-format
          '';

          clang-tools = pkgs'.llvmPackages.clang-tools;
          clangd = pkgs'.runCommand "clangd-wrapper" { } ''
            mkdir -p $out/bin
            ln -s ${clang-tools}/bin/clangd $out/bin/clangd
          '';

          python = pkgs'.python3;
          pythonSet = (pkgs'.callPackage inputs.pyproject-nix.build.packages {
            inherit python;
          }).overrideScope
            (
              lib.composeManyExtensions [
                inputs.pyproject-build-systems.overlays.default
                self.overlays.pyproject
                self.overlays.pyprojectOverrides
              ]
            );
        in
        rec {
          _module.args.pkgs' = import nixpkgs { inherit system; };

          pre-commit = {
            check.enable = true;
            settings.src = ./.;
            settings.hooks = {
              clang-format = {
                package = clang-format;
                enable = true;
                types_or = pkgs'.lib.mkForce [ "c++" ];
              };
              editorconfig-checker.enable = true;
              nixpkgs-fmt.enable = true;
              black.enable = true;
            };
          };

          devShells.default =
            let
              editableOverlay = self.workspace.mkEditablePyprojectOverlay {
                root = "$REPO_ROOT";
                #members = [ "messenger_grpc" "grpcio-tools" "grpcio" ];
              };
              editablePythonSet = pythonSet.overrideScope editableOverlay;
              virtualenv = editablePythonSet.mkVirtualEnv "messenger-grpc-dev-env" self.workspace.deps.all;
            in
            pkgs'.mkShell {
              name = "messenger-grpc";

              inputsFrom = [ packages.cppmessenger-grpc ];
              packages = [ virtualenv ];

              nativeBuildInputs = config.pre-commit.settings.enabledPackages;

              buildInputs =
                let
                  helperB = pkgs'.writeShellScriptBin "B" ''
                    if [ -n "$DIRENV_DIR" ]; then cd ''${DIRENV_DIR:1}; fi
                    cmake --preset debug && cmake --build build/Debug
                  '';
                  helperD = pkgs'.writeShellScriptBin "D" ''
                    if [ -n "$DIRENV_DIR" ]; then cd ''${DIRENV_DIR:1}; fi
                    cmake --preset debug && cmake --build build/Debug
                    ${pkgs'.compdb}/bin/compdb -p build/Debug/ list > compile_commands.json
                    strip-flags.py
                  '';
                  helperGP = pkgs'.writeShellScriptBin "GP" ''
                    if [ -n "$DIRENV_DIR" ]; then cd ''${DIRENV_DIR:1}; fi
                    python3 -m grpc_tools.protoc \
                      --proto_path=proto \
                      --python_out=. \
                      --grpc_python_out=. \
                      --pyi_out=. \
                      proto/messenger_grpc/*.proto
                  '';

                  debugTools = (with pkgs';
                    if stdenv.hostPlatform.isLinux
                    then [ gdb ] else [ lldb ]
                  );
                in
                [ helperB helperD helperGP clangd pkgs'.uv ] ++ debugTools;

              hardeningDisable = [ "fortify" ];

              shellHook =
                let
                  vscodeSettings = {
                    clangd.path = "${clangd}/bin/clangd";
                    clang-format.executable = "${clang-format}/bin/clang-format";
                  };
                in
                ''
                  ${config.pre-commit.installationScript}
                  unset PYTHONPATH
                  export REPO_ROOT=$(git rev-parse --show-toplevel)
                  export PATH=$REPO_ROOT/build/Debug:$REPO_ROOT/scripts:$(pwd)/tools:$PATH

                  if [ -n "$WSLPATH" ]; then
                    ${pkgs'.jq}/bin/jq --indent 4 -n '${
                      builtins.toJSON vscodeSettings
                    }' > .vscode/settings.json
                  fi
                '';

              env = {
                UV_NO_SYNC = "1";
                UV_PYTHON_DOWNLOADS = "never";
                UV_PYTHON = "${virtualenv}/bin/python";
              };
            };

          packages = {
            uv-lock = pkgs'.writeShellScriptBin "uv-lock" ''
              export UV_PYTHON="${pkgs'.python3}/bin/python";
              export UV_PYTHON_DOWNLOADS="never";
              ${pkgs'.uv}/bin/uv lock
            '';

            pymessenger-grpc = pythonSet.mkVirtualEnv "py-messenger-grpc"
              self.workspace.deps.default;

            cppmessenger-grpc = pkgs'.callPackage ./nix/cppmessenger-grpc.nix { };
          };
        };
    });
}
