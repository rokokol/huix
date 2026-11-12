# The NixOS layer

[![huix](https://img.shields.io/badge/huix-up-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![services](https://img.shields.io/badge/services-services-0E7C7B?style=for-the-badge)](services/README.md)
[![fonts](https://img.shields.io/badge/fonts-fonts-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](fonts/README.md)

Everything about the system itself lives here: the hardware, the boot, the network and the services. The applications and the settings of the desktop live in [Home Manager](../home-manager/README.md)

The composition of the system follows each machine. The services and the fonts have their own pages: [services](services/README.md), [fonts](fonts/README.md)

## How a service reaches a host

Every service module is imported for every host, and each one decides by its own switch whether it turns anything on. A service therefore lives in one file, and the host that wants it names the flag rather than importing anything. Reading a service means reading its module and one line of a host configuration, not a chain of imports

The station keeps the services that outlive a desktop: the backups, the calendar, the monitoring and the agent. A service that only makes sense with a screen stays off there by default

The working environment is there on the desktop PC and the laptop, and the server stays without a graphical session

## The station

The station is a home server without a screen: it keeps the backups, holds the calendar, watches the services and writes when something important breaks. And when a powerful PC is needed, it can wake one

The station installs from a flash drive, even without a network. The commands that build the image and check the install are in the [root README](../README.md#commands)
