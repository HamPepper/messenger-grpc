{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";

    dream2nix.url = "github:nix-community/dream2nix";
    dream2nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-parts, git-hooks, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ getSystem, ... }: {
      imports = [
        git-hooks.flakeModule
      ];

      systems = [ "x86_64-linux" /* "x86_64-darwin" */ "aarch64-darwin" ];

      perSystem = { system, inputs', pkgs', config, lib, ... }:
        let
          clangTools18 = pkgs'.llvmPackages_18.clang-tools;
          clang-format = pkgs'.runCommand "clang-format-wrapper" { } ''
            mkdir -p $out/bin
            ln -s ${clangTools18}/bin/clang-format $out/bin/clang-format
          '';

          clangTools = pkgs'.llvmPackages.clang-tools;
          clangd = pkgs'.runCommand "clangd-wrapper" { } ''
            mkdir -p $out/bin
            ln -s ${clangTools}/bin/clangd $out/bin/clangd
          '';
        in
        rec {
          _module.args.pkgs' = import nixpkgs { inherit system; };

          pre-commit = {
            check.enable = true;
            settings.src = ./.;
            settings.hooks = {
              clang-format =
                {
                  package = clang-format;
                  enable = true;
                  types_or = pkgs'.lib.mkForce [ "c++" ];
                };
              editorconfig-checker.enable = true;
              nixpkgs-fmt.enable = true;
              black.enable = true;
            };
          };

          # NOTE: to generate python lock file, run:
          #   nix run .#pymessenger-grpc.lock
          packages = {
            pymessenger-grpc = inputs.dream2nix.lib.evalModules {
              packageSets.nixpkgs = pkgs';
              modules = [
                ./nix/pymessenger-grpc.nix
                {
                  paths.projectRoot = ./.;
                  paths.projectRootFile = "flake.nix";
                  paths.package = ./.;
                }
              ];
            };

            cppmessenger-grpc = pkgs'.callPackage ./nix/cppmessenger-grpc.nix { };
          };

          devShells.default = pkgs'.mkShell {
            name = "messenger-grpc";

            inputsFrom = [
              packages.pymessenger-grpc.devShell
              packages.cppmessenger-grpc
            ];

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
              [ helperB helperD helperGP clangd ] ++ debugTools;

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
                export PATH=$(pwd)/build/Debug:$(pwd)/scripts:$(pwd)/tools:$PATH

                if [ -n "$WSLPATH" ]; then
                  ${pkgs'.jq}/bin/jq --indent 4 -n '${
                    builtins.toJSON vscodeSettings
                  }' > .vscode/settings.json
                fi
              '';
          };
        };
    });
}
