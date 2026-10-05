_:

# The firmware keeps the network card powered when the host is off, but the card ignores a
# magic packet until the operating system sets the wake bit: ethtool reads "Wake-on: d" by default
{
  # NetworkManager sets the bits of each wired connection it brings up, so its default is the
  # one place that reaches the card. 64 is the magic-packet flag of ethernet.wake-on-lan
  networking.networkmanager.connectionConfig."ethernet.wake-on-lan" = 64;
}
