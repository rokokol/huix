{ inputs, ... }:
# yazi matches a key by the character it types, so the Russian layout misses every
# binding, and its which popup lists every chord flat and at once; the patches add a
# vim-style langmap, group labels with `[which] fold`, and `[which] delay`, all of which
# the yazi module sets (see WORKAROUNDS.md). The delay patch applies on top of the groups
_final: prev: {
  yazi-unwrapped = prev.yazi-unwrapped.overrideAttrs (previous: {
    patches = (previous.patches or [ ]) ++ [
      ../patches/yazi-langmap.patch
      ../patches/yazi-which-groups.patch
      ../patches/yazi-which-delay.patch
    ];
    requiredSystemFeatures = (previous.requiredSystemFeatures or [ ]) ++ [ "big-parallel" ];
  });
  yaziPlugins = prev.yaziPlugins // {
    compress = prev.yaziPlugins.compress.overrideAttrs {
      version = "0.6-unstable-${inputs.compress-yazi.lastModifiedDate}";
      src = inputs.compress-yazi;
    };
    relative-motions = prev.yaziPlugins.relative-motions.overrideAttrs (previous: {
      patches = (previous.patches or [ ]) ++ [ ../patches/relative-motions-ya-emit.patch ];
    });
  };
}
