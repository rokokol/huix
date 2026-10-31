{
  config,
  lib,
  pkgs,
  ...
}:

# Shared registries let each agent use tools without an import of another agent's module
let
  cfg = config.rokokol.agents;
  json = pkgs.formats.json { };
  servers = lib.filterAttrs (_: server: server.enabled or null != false) config.programs.mcp.servers;

  forPi =
    name: server:
    lib.hm.mcp.transformMcpServer {
      inherit server;
      exclude = [ "enabled" ];
      extraTransforms = [ (lib.hm.mcp.wrapEnvFilesCommand { inherit pkgs name; }) ];
    };

  groupNames = builtins.attrNames cfg.groups;
  groups = lib.genAttrs groupNames (group: {
    skills = lib.filterAttrs (name: _: (cfg.skillGroups.${name} or "huix") == group) cfg.skills;
    servers = lib.filterAttrs (name: _: (cfg.mcpGroups.${name} or "huix") == group) servers;
  });
  piPackages = lib.mapAttrs (
    name: group:
    let
      groupSkills = pkgs.linkFarm "${name}-pi-skills" group.skills;
      manifest = json.generate "${name}-pi-package.json" {
        name = "@huix/${name}";
        description = cfg.groups.${name};
        pi = {
          skills = [ "./skills" ];
          extensions = [ "./mcp.ts" ];
        };
      };
      mcp = pkgs.writeText "${name}-pi-mcp.ts" ''
        import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

        export default function (pi: ExtensionAPI) {
          const servers = ${builtins.toJSON (lib.mapAttrs forPi (removeAttrs group.servers cfg.pi.exclude))};
          for (const [name, server] of Object.entries(servers)) {
            pi.registerMcpServer(name, server);
          }
        }
      '';
    in
    pkgs.linkFarm "${name}-pi-package" [
      {
        name = "package.json";
        path = manifest;
      }
      {
        name = "skills";
        path = groupSkills;
      }
      {
        name = "mcp.ts";
        path = mcp;
      }
    ]
  ) (lib.filterAttrs (_: group: group.skills != { } || group.servers != { }) groups);
in
{
  options.rokokol.agents = {
    groups = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        research = "Research tools and scientific papers";
      };
      description = "Plugin groups by name, with a description for each group";
    };

    skills = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      example = lib.literalExpression "{ calendar = ./calendar-skill; }";
      description = "Skills every agent of this user loads, as directories with a SKILL.md, by name";
    };

    skillState = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/agent-skills";
      defaultText = lib.literalExpression ''"''${config.xdg.stateHome}/agent-skills"'';
      description = ''
        Where the skills keep what they write: drafts, what was sent, and the notes a permission
        rests on. A home whose directory is carried between hosts points it at that directory
      '';
    };

    skillGroups = lib.mkOption {
      type = lib.types.attrsOf (lib.types.enum groupNames);
      default = { };
      description = "Pi package group for each skill, with huix as the default";
    };

    mcpGroups = lib.mkOption {
      type = lib.types.attrsOf (lib.types.enum groupNames);
      default = { };
      description = "Pi package group for each MCP server, with huix as the default";
    };

    moduleParents = lib.mkOption {
      type = lib.types.attrsOf (lib.types.enum groupNames);
      default = {
        deep-research = "research";
      };
      description = "Pi modules nested under another module, by child module name";
    };

    piPackages = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      readOnly = true;
      default = piPackages;
      description = "Pi packages that enable each group's skills and MCP servers together";
    };

    pi.exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "MCP servers excluded from Pi";
    };
  };

  config = {
    rokokol.agents.groups.huix = "Software development and system configuration";
  };
}
