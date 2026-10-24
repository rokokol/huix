{
  config,
  lib,
  osConfig,
  ...
}:

# The seam to rokokol/telegram-skill's skill: the system's module ships it at the revision of
# the service, and this hands it to the agents of the one user the socket belongs to. A host
# with no service, or a user the socket refuses, gets no skill that could only fail
{
  config = lib.mkIf (
    osConfig.services.tg-agent.enable && osConfig.services.tg-agent.socketUser == config.home.username
  ) { rokokol.agents.skills.telegram = osConfig.services.tg-agent.skill; };
}
