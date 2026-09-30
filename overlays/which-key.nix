{ inputs, ... }:
# which-key reads the keys after a prefix itself, so 'langmap' never reaches them and a
# Russian key finds only langmapper's hidden twins; the branch applies it (see WORKAROUNDS.md)
_final: prev: {
  vimPlugins = prev.vimPlugins.extend (
    _: previous: {
      which-key-nvim = previous.which-key-nvim.overrideAttrs { src = inputs.which-key-nvim; };
    }
  );
}
