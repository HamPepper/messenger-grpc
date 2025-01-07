{ lib, config, dream2nix, ... }:
let
  pyproject = lib.importTOML ../pyproject.toml;
in
{
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  deps = { nixpkgs, ... }: {
    python = nixpkgs.python3;
  };

  inherit (pyproject.project) name version;

  mkDerivation = {
    src = lib.cleanSourceWith {
      src = lib.cleanSource ../.;
      filter = name: type:
        !(builtins.any (x: x) [
          (lib.hasSuffix ".nix" name)
          (lib.hasPrefix "." (builtins.baseNameOf name))
          (lib.hasSuffix "flake.lock" name)
        ]);
    };
  };

  buildPythonPackage = {
    pyproject = true;
    pythonImportsCheck = [
      "messenger_grpc"
      "messenger_grpc.server"
      "messenger_grpc.chat_service_pb2"
      "messenger_grpc.chat_service_pb2_grpc"
    ];
  };

  paths.lockFile = "lock.${config.deps.stdenv.system}.json";
  pip = {
    # Setting editables.$pkg to a relative or absolute path, as a string, will
    # link this path as an editable install to .dream2nix/editables in
    # devShells. The root package is always installed as editable.
    # editables.charset-normalizer = "/home/my-user/src/charset-normalizer";

    requirementsList =
      pyproject.build-system.requires or [ ]
      ++ pyproject.project.dependencies;
    flattenDependencies = true;
  };
}
