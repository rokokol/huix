{ lib, self }:
# Facts the documentation generator renders into pages. Everything here is computed while the
# flake evaluates, so the renderer never runs `nix eval`: a build sandbox has no daemon, and a
# corpus built outside one could disagree with the configuration it claims to describe
let
  repo = toString self;

  # A declaration path points into the store; the page links the file inside the repository
  relative = path: lib.removePrefix "${repo}/" (toString path);

  # What JSON can carry. A value is dropped rather than forced: an option holding a dashboard
  # function or a submodule tree would otherwise break the page that holds every other option,
  # and the generator renders what is left instead of failing the whole corpus
  plain =
    depth: value:
    let
      attempt = builtins.tryEval (
        if depth > 2 then
          { ok = false; }
        else if value == null then
          {
            ok = true;
            out = null;
          }
        else if
          builtins.isBool value || builtins.isInt value || builtins.isFloat value || builtins.isString value
        then
          {
            ok = true;
            out = value;
          }
        else if builtins.isPath value then
          {
            ok = true;
            out = toString value;
          }
        else if builtins.isList value then
          let
            items = map (plain (depth + 1)) value;
          in
          if lib.all (item: item.ok) items then
            {
              ok = true;
              out = map (item: item.out) items;
            }
          else
            { ok = false; }
        else if builtins.isAttrs value && !(value ? _type) then
          let
            items = lib.mapAttrs (_: plain (depth + 1)) value;
          in
          if lib.all (item: item.ok) (lib.attrValues items) then
            {
              ok = true;
              out = lib.mapAttrs (_: item: item.out) items;
            }
          else
            { ok = false; }
        else
          { ok = false; }
      );
    in
    if attempt.success then attempt.value else { ok = false; };

  # One option tree as a flat list. A node is either an option or another tree of them, which is
  # how the module system distinguishes the two without naming the option type
  describeOptions =
    prefix: options: value:
    if options._type or null == "option" then
      let
        readable = plain 0 value;
      in
      [
        {
          name = lib.removeSuffix "." prefix;
          description = options.description or null;
          type = options.type.description or (options.type.name or null);
          declarations = map relative (options.declarations or [ ]);
          value = if readable.ok then readable.out else null;
        }
      ]
    else if builtins.isAttrs options then
      lib.concatLists (
        lib.mapAttrsToList (
          name: option:
          describeOptions "${prefix}${name}." option (
            if builtins.isAttrs value then value.${name} or null else null
          )
        ) options
      )
    else
      [ ];

  # Options are read from the value the option resolved to, so an option the host leaves alone
  # appears with its default and says nothing false about the machines
  optionFacts =
    config: attrPath:
    describeOptions "rokokol." (lib.attrByPath attrPath { } config.options) (
      lib.attrByPath attrPath { } config.config
    );

  hostFacts =
    name: config:
    let
      # Home Manager exposes the user's configuration without its option tree, so the user
      # options arrive as values alone and the descriptions come from the manual beside it
      users = config.config.home-manager.users;
      user = if users == { } then null else users.${builtins.head (builtins.attrNames users)};
      homeValues = plain 0 (if user == null then { } else user.rokokol);
    in
    {
      inherit name;
      system = config.pkgs.stdenv.hostPlatform.system;
      options = optionFacts config [ "rokokol" ];
      homeValues = if homeValues.ok then homeValues.out else { };
      secrets = builtins.attrNames config.config.sops.secrets;
      services = lib.attrNames config.config.systemd.services;
      timers = lib.attrNames config.config.systemd.timers;
      tailnet = lib.mapAttrs (_: site: {
        inherit (site) port;
        lan = site.lan or false;
      }) config.config.rokokol.tailnet-web.sites;
      # Only the ports the configuration opens, not the whole firewall policy: a page that lists
      # defaults repeats what the reader already has in the manual
      firewall = {
        tcp = config.config.networking.firewall.allowedTCPPorts;
        udp = config.config.networking.firewall.allowedUDPPorts;
      };
      sessionVariables = if user == null then { } else user.home.sessionVariables;
    };

  hosts = lib.mapAttrs hostFacts self.nixosConfigurations;
in
{
  inherit hosts;
}
