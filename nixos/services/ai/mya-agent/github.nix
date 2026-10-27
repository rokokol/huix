{
  config,
  lib,
  pkgs,
  ...
}:

# GitHub for the agent without a token in its session. gh in the session talks to nginx through
# a Unix socket, and nginx sets the token by the path of each request: the classic token for what
# a fine-grained token cannot reach, and the read-only one for everything else. Text that the
# session reads can make it ask the proxy for an allowed request, but no request shows a token
let
  agent = config.rokokol.mya-agent;
  cfg = agent.github;
  dir = "/run/mya-github";
  tokens = config.sops.templates."mya-github-tokens.conf";

  # Paths that take the classic token, as nginx regular expressions: the notifications inbox,
  # repository invitations and deployments, which the owner chose it for
  classicPaths = [
    "^/notifications(/|$)"
    "^/user/repository_invitations(/|$)"
    "^/repos/[^/]+/[^/]+/deployments(/|$)"
  ];

  proxyTo = token: {
    # A variable makes nginx resolve the name per request: a name resolved at load stops all of
    # nginx when the host boots without DNS. The API is a bare origin, so the URI passes unchanged
    proxyPass = "$github_api";
    # The default Host is the API's own, which is what GitHub expects
    recommendedProxySettings = false;
    extraConfig = ''
      set $github_api ${cfg.api};
      proxy_set_header Authorization ${token};
      proxy_ssl_server_name on;
      proxy_ssl_verify on;
      proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
    '';
  };

  # gh reads the socket from its config; it writes nothing there unless asked to log in
  ghConfig = pkgs.writeTextDir "config.yml" "http_unix_socket: ${cfg.socket}\n";
in
{
  options.rokokol.mya-agent.github = {
    enable = lib.mkEnableOption "gh in the agent's session, through a proxy that holds the tokens" // {
      default = agent.enable;
      defaultText = lib.literalExpression "config.rokokol.mya-agent.enable";
    };

    api = lib.mkOption {
      type = lib.types.str;
      default = "https://api.github.com";
      description = "GitHub API that the proxy forwards to";
    };

    socket = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${dir}/api.sock";
      description = "Unix socket of the proxy, which only nginx and the agent's group reach";
    };
  };

  config = lib.mkIf cfg.enable {
    # The fine-grained token reads the owner's repositories and writes nothing. The classic one
    # has the scopes notifications, repo:invite and repo_deployment
    sops.secrets."github-token" = { };
    sops.secrets."github-token-classic" = { };
    sops.templates."mya-github-tokens.conf" = {
      owner = config.services.nginx.user;
      restartUnits = [ "nginx.service" ];
      content = ''
        set $github_read "token ${config.sops.placeholder."github-token"}";
        set $github_classic "token ${config.sops.placeholder."github-token-classic"}";
      '';
    };

    # nginx makes the socket open to all, so the directory decides who reaches it
    systemd.tmpfiles.rules = [ "d ${dir} 0750 ${config.services.nginx.user} ${agent.user} -" ];

    services.nginx = {
      enable = true;
      virtualHosts.mya-github = {
        listen = [ { addr = "unix:${cfg.socket}"; } ];
        extraConfig = ''
          include ${tokens.path};
          # The stub of systemd-resolved, which resolves a name at the time of each request
          resolver 127.0.0.53;
        '';
        locations = {
          "/" = proxyTo "$github_read";
        }
        // lib.genAttrs (map (path: "~ ${path}") classicPaths) (_: proxyTo "$github_classic");
      };
    };

    systemd.services.mya-agent.environment = {
      GH_CONFIG_DIR = "${ghConfig}";
      # gh refuses to run without a token; the proxy replaces this one on every request
      GH_TOKEN = "held-by-the-proxy";
    };
  };
}
