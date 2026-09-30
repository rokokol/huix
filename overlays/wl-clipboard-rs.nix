{ inputs, ... }:
# wl-copy offers one MIME type at a time, and a file manager has to offer two with different
# data; the branch adds --offer, which yazi's clipboard calls by path (see WORKAROUNDS.md)
final: prev: {
  wl-clipboard-rs = prev.wl-clipboard-rs.overrideAttrs (previous: {
    version = "0.9.3-unstable-${inputs.wl-clipboard-rs.lastModifiedDate}";
    src = inputs.wl-clipboard-rs;
    # read from the branch's own lock, so no vendor hash goes stale on an input update
    cargoDeps = final.rustPlatform.importCargoLock {
      lockFile = "${inputs.wl-clipboard-rs}/Cargo.lock";
    };
    # the branch's tests live in the tools package, which a bare `cargo test` skips
    cargoTestFlags = previous.cargoBuildFlags;
  });
}
