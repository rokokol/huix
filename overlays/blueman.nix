_:
# blueman connects a device on a raw double-click event, which a touchscreen never
# produces; the patch moves that to the tree view's own activation (see WORKAROUNDS.md)
_final: prev: {
  blueman = prev.blueman.overrideAttrs (previous: {
    patches = (previous.patches or [ ]) ++ [ ../patches/blueman-row-activated.patch ];
  });
}
