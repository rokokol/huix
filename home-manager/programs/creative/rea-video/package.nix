{
  lib,
  python3,
  ffmpeg-headless,
  makeWrapper,
  src,
}:

# The upstream CLI is a pip wheel with an optional OCR extra; both are built here, and the
# skill beside this file comes from the same pinned tree
python3.pkgs.buildPythonApplication {
  pname = "rea-video";
  version = (builtins.fromTOML (builtins.readFile "${src}/pyproject.toml")).project.version;
  inherit src;
  pyproject = true;

  build-system = [ python3.pkgs.setuptools ];

  dependencies = with python3.pkgs; [
    numpy
    onnxruntime
    opencv-python-headless
    pillow
    pyyaml
    # The ocr extra: per-line subtitle timing is read off the frames by RapidOCR
    rapidocr-onnxruntime
  ];

  nativeBuildInputs = [ makeWrapper ];

  pythonImportsCheck = [ "rea_video" ];

  # ffmpeg and ffprobe do the cutting, the frame extraction and the audio split. The models
  # the CLI needs beyond that it fetches itself into $REA_VIDEO_MODELS, which the store cannot hold
  postFixup = ''
    wrapProgram $out/bin/rea-video \
      --prefix PATH : ${lib.makeBinPath [ ffmpeg-headless ]}
  '';

  meta = {
    description = "Shot-level forensics of how a video was made, with a remake plan";
    homepage = "https://github.com/JuneYaooo/rea-video";
    license = lib.licenses.asl20;
    mainProgram = "rea-video";
    platforms = lib.platforms.linux;
  };
}
