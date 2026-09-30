_:
# kitty's own copy of GLFW binds no wl_touch, so a finger does nothing in it; the patch
# makes the first finger a click, a scroll or a selection (see WORKAROUNDS.md)
_final: prev: {
  kitty = prev.kitty.overrideAttrs (previous: {
    patches = (previous.patches or [ ]) ++ [ ../patches/kitty-wayland-touch.patch ];
  });
}
