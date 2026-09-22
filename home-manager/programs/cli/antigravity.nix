{ pkgs, ... }:

let
  antigravity-cli-patched = pkgs.antigravity-cli.overrideAttrs (oldAttrs: {
    pname = "antigravity-cli-patched";
    nativeBuildInputs = oldAttrs.nativeBuildInputs ++ (with pkgs; [ perl ]);
    postFixup = (oldAttrs.postFixup or "") + ''
      grep -aq 'ineligible' "$out/bin/agy"
      perl -0pi -e 's/ineligible/inexigible/g' "$out/bin/agy"
      ! grep -aq 'ineligible' "$out/bin/agy"
      grep -aq 'inexigible' "$out/bin/agy"
    '';
  });
in
{
  home.packages = [ antigravity-cli-patched ];
}
