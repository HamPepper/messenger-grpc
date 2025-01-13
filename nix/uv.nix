{ inputs, ... }:

let
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ../.; };
in
{
  config.flake.workspace = workspace;

  # to generate lock, run:
  #  nix run .#uv-lock
  config.flake.overlays.pyproject = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel"; # or sourcePreference = "sdist";
  };

  config.flake.overlays.pyprojectOverrides = _final: _prev: {
    #
  };
}
