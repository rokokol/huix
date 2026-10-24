{ inputs, ... }:
# yazi matches a key by the character it types, so the Russian layout misses every
# binding; the first patch adds a vim-style langmap. The second lets a plugin build chords
# from Lua tables, which the which-delay and which-fold plugins in the yazi module rely on
# (see WORKAROUNDS.md). It applies on top of the langmap
_final: prev: {
  yazi-unwrapped = prev.yazi-unwrapped.overrideAttrs (previous: {
    patches = (previous.patches or [ ]) ++ [
      ../patches/yazi-langmap.patch
      ../patches/yazi-chord-tables.patch
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
