_:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        AddKeysToAgent = "yes";
      };
      # Termux sshd on the phone; Termux has one user, so the login name does not matter
      phone = {
        HostName = "mobile-1";
        Port = 8022;
      };
    };
  };
}
