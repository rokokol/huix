{ pkgs, inputs, ... }:

{
  home.packages = with pkgs; [ uv ];

  rokokol.agents = {
    skills.geo-sleuth = "${inputs.geo-sleuth}/skills/geo-sleuth";
    skillGroups.geo-sleuth = "deep-research";
  };
}
