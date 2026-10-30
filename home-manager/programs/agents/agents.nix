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

  forClaude =
    name: server:
    lib.hm.mcp.transformMcpServer {
      inherit server;
      exclude = [ "enabled" ];
      extraTransforms = [
        lib.hm.mcp.addType
        (lib.hm.mcp.wrapEnvFilesCommand { inherit pkgs name; })
      ];
    };

  # OpenCode reads a file itself when a value says {file:PATH}. The shape is the one
  # programs.opencode writes, which Home Manager does not export
  forOpencode =
    _: server:
    let
      remote = server.url or null != null;
      env = lib.hm.mcp.renderEnv (path: "{file:${path}}") (server.env or { });
    in
    {
      type = if remote then "remote" else "local";
      enabled = true;
    }
    // (
      if remote then
        {
          inherit (server) url;
        }
        // lib.optionalAttrs (server.headers or { } != { }) { inherit (server) headers; }
      else
        {
          command = [ server.command ] ++ server.args or [ ];
        }
        // lib.optionalAttrs (env != { }) { environment = env; }
    );

  forPi =
    name: server:
    lib.hm.mcp.transformMcpServer {
      inherit server;
      exclude = [ "enabled" ];
      extraTransforms = [ (lib.hm.mcp.wrapEnvFilesCommand { inherit pkgs name; }) ];
    };

  lspForClaude = _: server: {
    inherit (server) command args;
    extensionToLanguage = server.extensions;
  };
  lspForOpencode = _: server: {
    command = [ server.command ] ++ server.args;
    extensions = lib.attrNames server.extensions;
  };

  skills = pkgs.linkFarm "agent-skills" cfg.skills;
  groupNames = builtins.attrNames cfg.groups;
  groups = lib.genAttrs groupNames (group: {
    skills = lib.filterAttrs (name: _: (cfg.skillGroups.${name} or "huix") == group) cfg.skills;
    servers = lib.filterAttrs (name: _: (cfg.mcpGroups.${name} or "huix") == group) servers;
    lspServers = lib.optionalAttrs (group == "huix") cfg.lspServers;
  });
  plugins =
    lib.mapAttrs
      (
        name: group:
        let
          groupSkills = pkgs.linkFarm "${name}-skills" group.skills;
          manifest = json.generate "${name}-plugin.json" (
            {
              inherit name;
              description = cfg.groups.${name};
            }
            // lib.optionalAttrs (group.lspServers != { }) {
              lspServers = lib.mapAttrs lspForClaude group.lspServers;
            }
          );
          mcpConfig = json.generate "${name}-mcp.json" {
            mcpServers = lib.mapAttrs forClaude group.servers;
          };
        in
        pkgs.runCommandLocal "${name}-agent-plugin" { } ''
          mkdir -p $out/.claude-plugin $out/skills
          cp ${manifest} $out/.claude-plugin/plugin.json
          cp ${mcpConfig} $out/.mcp.json
          cp -rL ${groupSkills}/. $out/skills/
        ''
      )
      (
        lib.filterAttrs (
          _: group: group.skills != { } || group.servers != { } || group.lspServers != { }
        ) groups
      );
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

    skillGroups = lib.mkOption {
      type = lib.types.attrsOf (lib.types.enum groupNames);
      default = { };
      description = "Claude Code plugin group for each skill, with huix as the default";
    };

    mcpGroups = lib.mkOption {
      type = lib.types.attrsOf (lib.types.enum groupNames);
      default = { };
      description = "Claude Code plugin group for each MCP server, with huix as the default";
    };

    claudePlugins = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      readOnly = true;
      default = plugins;
      description = "Claude Code plugins generated from the skill and MCP groups";
    };

    piPackages = lib.mkOption {
      type = lib.types.attrsOf lib.types.package;
      readOnly = true;
      default = piPackages;
      description = "Pi packages that enable each group's skills and MCP servers together";
    };

    pi.exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "opencode" ];
      description = "MCP servers excluded from Pi";
    };

    lspServers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            command = lib.mkOption {
              type = lib.types.str;
              description = "Executable of the server, by name, so that a devShell's own version wins over the one on the user's PATH";
            };
            args = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Arguments of the server";
            };
            extensions = lib.mkOption {
              type = lib.types.attrsOf lib.types.str;
              example = {
                ".py" = "python";
              };
              description = "LSP language identifier of each file extension the server serves, the extension with its dot";
            };
          };
        }
      );
      default = { };
      description = "Language servers every agent of this user starts, by the name OpenCode gives its built-in one, so that the entry replaces it";
    };

    opencode.exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "opencode" ];
      description = "MCP servers that OpenCode leaves out: the one that reaches OpenCode itself";
    };

    claudeConfig = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      default = json.generate "claude-mcp.json" { mcpServers = lib.mapAttrs forClaude servers; };
      defaultText = lib.literalMD "the servers of `programs.mcp.servers`, as Claude Code's `--mcp-config` reads them";
      description = "MCP config file of Claude Code";
    };

    opencodeConfig = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      default = json.generate "opencode-agents.json" (
        {
          "$schema" = "https://opencode.ai/config.json";
          mcp = lib.mapAttrs forOpencode (removeAttrs servers cfg.opencode.exclude);
        }
        // lib.optionalAttrs (cfg.skills != { }) { skills.paths = [ "${skills}" ]; }
        // lib.optionalAttrs (cfg.lspServers != { }) { lsp = lib.mapAttrs lspForOpencode cfg.lspServers; }
      );
      defaultText = lib.literalMD "the MCP servers, the skills and the language servers, as OpenCode's `OPENCODE_CONFIG` reads them";
      description = "Config file of OpenCode with the MCP servers, the skills and the language servers alone, merged over its own";
    };
  };

  config = {
    rokokol.agents.groups.huix = "Software development and system configuration";
  };
}
