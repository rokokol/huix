{
  lib,
  btrfs-progs,
  makeWrapper,
  python3,
  rclone,
  stdenvNoCC,
  zstd,
  inputs,
}:

let
  python = python3.withPackages (ps: [ ps.pathspec ]);
  source =
    name:
    builtins.path {
      inherit name;
      path = "${inputs.self}/scripts/${name}";
    };
in
stdenvNoCC.mkDerivation {
  name = "drive-backup";
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm644 ${source "drive-backup.py"} $out/libexec/drive-backup.py
    install -Dm644 ${source "restic-cloud.py"} $out/libexec/restic-cloud.py
    makeWrapper ${lib.getExe python} $out/bin/drive-backup \
      --add-flags $out/libexec/drive-backup.py \
      --prefix PATH : ${
        lib.makeBinPath [
          rclone
          zstd
        ]
      }
    makeWrapper ${lib.getExe python} $out/bin/restic-cloud \
      --add-flags $out/libexec/restic-cloud.py \
      --prefix PATH : ${
        lib.makeBinPath [
          rclone
          btrfs-progs
        ]
      }
    runHook postInstall
  '';

  meta = {
    description = "Store verified cold archives and encrypted restic mirrors on Google Drive";
    license = lib.licenses.mit;
    mainProgram = "drive-backup";
    platforms = lib.platforms.linux;
  };
}
