{
  lib,
  stdenvNoCC,
  makeWrapper,
  python3,
  ffmpeg-headless,
  src,
  pyloudnormSrc,
}:

# The upstream scripts use uv; these wrappers supply their dependencies from the Nix closure
let
  pyloudnorm = python3.pkgs.buildPythonPackage {
    pname = "pyloudnorm";
    version = (builtins.fromTOML (builtins.readFile "${pyloudnormSrc}/pyproject.toml")).project.version;
    src = pyloudnormSrc;
    pyproject = true;
    build-system = with python3.pkgs; [ setuptools ];
    dependencies = with python3.pkgs; [
      numpy
      scipy
    ];
    pythonImportsCheck = [ "pyloudnorm" ];
    meta = {
      description = "Loudness measurement with the ITU-R BS.1770 algorithm";
      homepage = "https://github.com/csteinmetz1/pyloudnorm";
      license = lib.licenses.mit;
      platforms = lib.platforms.all;
    };
  };
  python = python3.withPackages (
    ps:
    [ pyloudnorm ]
    ++ (with ps; [
      numpy
      scipy
      soundfile
      matplotlib
    ])
  );
in
stdenvNoCC.mkDerivation {
  pname = "opus-sound-layer";
  version = "0-unstable-${src.lastModifiedDate}";
  inherit src;
  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/opus-sound-layer $out/bin
    cp -r scripts README.md PROMPT.md LICENSE $out/share/opus-sound-layer/
    for script in sfx mix qa; do
      makeWrapper ${lib.getExe python} $out/bin/sound-layer-$script \
        --add-flags "$out/share/opus-sound-layer/scripts/$script.py" \
        --prefix PATH : ${lib.makeBinPath [ ffmpeg-headless ]}
    done
    runHook postInstall
  '';
  meta = {
    description = "Sound effects selection, timeline mixes and audio checks for video";
    homepage = "https://github.com/Bodila51/opus-sound-layer";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
