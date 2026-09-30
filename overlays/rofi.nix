{ inputs, ... }:
# rofi from its development branch (see WORKAROUNDS.md). The wrapper and every plugin
# take the unwrapped package from the overlay, so nothing else changes
_final: prev: {
  rofi-unwrapped = prev.rofi-unwrapped.overrideAttrs {
    version = "2.0.0-unstable-${inputs.rofi.lastModifiedDate}";
    src = inputs.rofi;
    # The branch reports itself as 2.0.0-dev, not by the date the lock gives it
    preVersionCheck = "version=2.0.0-dev";
  };
}
