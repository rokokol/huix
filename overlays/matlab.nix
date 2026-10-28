{ inputs, system, ... }:

# See WORKAROUNDS.md: upstream Nix recipes use deprecated nixpkgs attributes
_final: _prev:
let
  upstream = inputs.nix-matlab;
  pkgs = upstream.inputs.nixpkgs.legacyPackages.${system}.extend (
    _final: prev: {
      xorg = prev.lib.mapAttrs (_: name: prev.${name}) {
        libSM = "libsm";
        libX11 = "libx11";
        libxcb = "libxcb";
        libXcomposite = "libxcomposite";
        libXcursor = "libxcursor";
        libXdamage = "libxdamage";
        libXext = "libxext";
        libXfixes = "libxfixes";
        libXft = "libxft";
        libXi = "libxi";
        libXinerama = "libxinerama";
        libXrandr = "libxrandr";
        libXrender = "libxrender";
        libXt = "libxt";
        libXtst = "libxtst";
        libXxf86vm = "libxxf86vm";
        libICE = "libice";
      };
    }
  );
  packages =
    ((import "${upstream}/flake.nix").outputs {
      self = upstream;
      inherit (upstream.inputs) flake-compat;
      nixpkgs = upstream.inputs.nixpkgs // {
        legacyPackages.${system} = pkgs;
      };
    }).packages.${system};
in
{
  inherit (packages)
    matlab
    matlab-shell
    matlab-mlint
    matlab-mex
    ;
}
