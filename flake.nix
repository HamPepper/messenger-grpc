{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-parts, git-hooks, ... } @ inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ getSystem, ... }: {
      imports = [
        git-hooks.flakeModule
      ];

      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      perSystem =
        { system, inputs', pkgs', config, lib, ... }: {
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
            };
          };

          devShells.default = pkgs'.mkShell {
            name = "messenger-grpc";

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
                python = pkgs'.python3;
                pythonPackages = with python.pkgs; [
                  grpcio-tools
                ];

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

                debugTools = (with pkgs'; if stdenv.isLinux then [ gdb ] else [ lldb ]);
              in
              with pkgs'; [
                grpc

                helperB
                helperD
                helperT
              ] ++ debugTools ++ pythonPackages;

            hardeningDisable = [ "fortify" ];

            shellHook = ''
              ${config.pre-commit.installationScript}
              export PATH=$(pwd)/build/Debug:$PATH
              export ASAN_OPTIONS=detect_leaks=0
            '';
          };
        };
    });
}
