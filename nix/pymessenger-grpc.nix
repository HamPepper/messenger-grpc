{ lib, dream2nix, ... }:
{
  imports = [
    dream2nix.modules.dream2nix.WIP-python-pdm
  ];

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

  pdm.useUvResolver = true;
  pdm.lockfile = ../pdm.lock;
  pdm.pyproject = ../pyproject.toml;
}
