{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  agent = config.rokokol.mya-agent;
  transcribeCpp = pkgs.stdenv.mkDerivation {
    pname = "transcribe-cpp";
    version = "0.4.1";
    src = inputs.transcribe-cpp;
    nativeBuildInputs = with pkgs; [ cmake ];
    cmakeFlags = [
      "-DTRANSCRIBE_BUILD_TESTS=OFF"
      "-DTRANSCRIBE_BUILD_EXAMPLES=ON"
      "-DTRANSCRIBE_BUILD_TOOLS=OFF"
      "-DTRANSCRIBE_USE_SYSTEM_BLAS=OFF"
      "-DGGML_NATIVE=OFF"
    ];
    installPhase = ''
      install -Dm755 bin/transcribe-cli "$out/bin/transcribe-cli"
    '';
    meta = {
      description = "Offline speech transcription for GGUF models";
      homepage = "https://github.com/handy-computer/transcribe.cpp";
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };
  model = pkgs.fetchurl {
    name = "gigaam-v3-e2e-rnnt-Q4_K_M.gguf";
    url = "https://huggingface.co/handy-computer/gigaam-v3-e2e-rnnt-gguf/resolve/ba40c6e9a02d6a29b7a88fcb8736e451e79f4b3e/gigaam-v3-e2e-rnnt-Q4_K_M.gguf";
    hash = "sha256-fWmVL7QxqNeADtmRDcYf6jfYQGv+ltEL8kyL1LfGhiM=";
  };
  transcribe = pkgs.writeShellApplication {
    name = "mya-gigaam-stt";
    runtimeInputs = with pkgs; [
      coreutils
      ffmpeg
      transcribeCpp
    ];
    text = ''
      if (( $# == 1 )) && [[ $1 == --help || $1 == -h ]]; then
        printf 'Usage: mya-gigaam-stt AUDIO_FILE\nTranscribe Russian audio locally with GigaAM-v3 Q4_K_M.\n'
        exit 0
      fi

      if (( $# != 1 )); then
        printf 'Usage: mya-gigaam-stt AUDIO_FILE\n' >&2
        exit 2
      fi

      input=$1
      if [[ ! -r $input || ! -f $input ]]; then
        printf 'Audio file is not readable: %s\n' "$input" >&2
        exit 2
      fi

      threads=''${GIGAAM_THREADS:-2}
      if [[ ! $threads =~ ^[1-9][0-9]*$ ]]; then
        printf 'GIGAAM_THREADS must be a positive integer\n' >&2
        exit 2
      fi

      umask 077
      work=$(mktemp -d)
      trap 'rm -rf "$work"' EXIT
      ffmpeg -nostdin -hide_banner -loglevel error -i "$input" -vn -ar 16000 -ac 1 -c:a pcm_s16le "$work/input.wav"
      if ! transcribe-cli \
          --model ${model} \
          --language ru \
          --backend cpu \
          --threads "$threads" \
          --timestamps none \
          --quiet \
          --output "$work/transcript.txt" \
          "$work/input.wav" >"$work/run.log" 2>&1; then
        cat "$work/run.log" >&2
        exit 1
      fi
      if [[ ! -s $work/transcript.txt ]]; then
        cat "$work/run.log" >&2
        printf 'GigaAM returned an empty transcript\n' >&2
        exit 1
      fi
      cat "$work/transcript.txt"
    '';
  };
in
{
  config = lib.mkIf agent.enable {
    rokokol.mya-agent.packages = [ transcribe ];
  };
}
