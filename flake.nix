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

      perSystem =
        { system, inputs', pkgs', config, lib, ... }: rec {
          _module.args.pkgs' = import nixpkgs { inherit system; };

          pre-commit = {
            check.enable = true;
            settings.src = ./.;
            settings.hooks = {
              clang-format =
                let
                  # pinpoint a specific version of clang-format
                  llvmPkg = pkgs'.llvmPackages_18.clang-tools;
                  clangFormat = pkgs'.runCommand "clang-format-wrapper" { } ''
                    mkdir -p $out/bin
                    ln -s ${llvmPkg}/bin/clang-format $out/bin/clang-format
                  '';
                in
                {
                  package = clangFormat;
                  enable = true;
                  types_or = pkgs'.lib.mkForce [ "c++" ];
                };
              editorconfig-checker.enable = true;
              nixpkgs-fmt.enable = true;
              black.enable = true;
            };
          };

          # NOTE: to generate python lock file, run:
          #   nix run .#pyprojectMessengerGrpc.lock
          packages = {
            pymessenger-grpc = inputs.dream2nix.lib.evalModules {
              packageSets.nixpkgs = pkgs';
              modules = [
                ./pyproject.nix
                {
                  paths.projectRoot = ./.;
                  paths.projectRootFile = "flake.nix";
                  paths.package = ./.;
                }
              ];
            };
          };

          devShells.default = pkgs'.mkShell {
            name = "messenger-grpc";

            inputsFrom = [ packages.pymessenger-grpc.devShell ];

            # FIXME: workaround for https://github.com/NixOS/nixpkgs/issues/273875
            nativeBuildInputs =
              let
                llvmPkg = pkgs'.llvmPackages.clang-tools;
                clangTools = pkgs'.runCommand "clang-tools-wrapper" { } ''
                  mkdir -p $out/bin
                  ln -s ${llvmPkg}/bin/clang-scan-deps $out/bin/clang-scan-deps
                  ln -s ${llvmPkg}/bin/clangd $out/bin/clangd
                '';
              in
              with pkgs'; [
                cmake
                ninja
                clangTools
              ] ++ config.pre-commit.settings.enabledPackages;

            buildInputs =
              let
                helperB = pkgs'.writeShellScriptBin "B" ''
                  if [ -n "$DIRENV_DIR" ]; then cd ''${DIRENV_DIR:1}; fi
                  cmake --preset debug && cmake --build build/Debug
                '';
                helperD = pkgs'.writeShellScriptBin "D" ''
                  if [ -n "$DIRENV_DIR" ]; then cd ''${DIRENV_DIR:1}; fi
                  cmake --preset debug
                  ${pkgs'.compdb}/bin/compdb -p build/Debug/ list > compile_commands.json
                '';
                helperT = pkgs'.writeShellScriptBin "T" ''
                  if [ -n "$DIRENV_DIR" ]; then cd ''${DIRENV_DIR:1}; fi
                  cmake --preset debug && cmake --build build/Debug
                  ctest --test-dir build/Debug --output-on-failure
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

                debugTools = (with pkgs'; if stdenv.isLinux then [ gdb ] else [ lldb ]);
              in
              with pkgs'; [
                grpc

                helperB
                helperD
                helperT
                helperGP
              ] ++ debugTools;

            hardeningDisable = [ "fortify" ];

            shellHook = ''
              ${config.pre-commit.installationScript}
              export PATH=$(pwd)/build/Debug:$(pwd)/scripts:$PATH
            '';
          };
        };
    });
}
