{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, alsa-lib
, openssl
}:

rustPlatform.buildRustPackage rec {
  pname = "qobine";
  # Upstream ships date-stamped releases rather than semver tags; the Cargo
  # workspace version (1.0.0) is not bumped per release.
  version = "2026-07-21";

  src = fetchFromGitHub {
    owner = "SofusA";
    repo = "qobine";
    tag = "v${version}";
    hash = "sha256-xBMoKHOXyybsn/QaFGqDTGZT4uI/fH4Mqoofna5Prn4=";
  };

  cargoHash = "sha256-FVyWhQNgMCQXa/JqV9S8V6cVwHFCvQ0DE5eQ7vzwetI=";

  patches = [
    # A track's CMAF segment count is held in a u8 all the way from the API
    # model down through the FLAC segment downloader, so any track with more
    # than 255 segments fails to deserialize with "invalid value: integer `N`,
    # expected u8", and the segment table length silently wraps on the way in.
    # Segments run about 10 seconds, so this bites above roughly 42 minutes.
    # Widen the count and the segment indices to u32. Sent upstream as
    # SofusA/qobine#473; drop this patch once it lands in a release.
    ./widen-segment-count.patch
  ];

  # The workspace also carries the GTK, web, RFID and Qobuz Connect front-ends.
  # Building only the terminal player keeps gtk4/libadwaita/webkitgtk, the
  # embedded web assets and the Raspberry Pi GPIO stack out of the closure.
  cargoBuildFlags = [ "--package" "tui-module" ];
  cargoTestFlags = [ "--package" "tui-module" ];

  # sqlx verifies its query! macros against a database at compile time. The
  # repository ships the offline metadata in player-module/.sqlx, so no live
  # sqlite instance is needed during the build.
  env.SQLX_OFFLINE = "true";

  nativeBuildInputs = [ pkg-config ];

  # alsa-lib: rodio's audio output. openssl: reqwest keeps its default
  # native-tls backend alongside rustls.
  buildInputs = [ alsa-lib openssl ];

  meta = with lib; {
    description = "Terminal player for the Qobuz high resolution streaming service";
    longDescription = ''
      qobine is a third-party player for Qobuz, requiring a paid Qobuz
      subscription. This package builds the terminal UI front-end, which
      exposes playback over MPRIS and stores its credentials and queue in a
      local sqlite database under $XDG_DATA_HOME/qobine.
    '';
    homepage = "https://github.com/SofusA/qobine";
    changelog = "https://github.com/SofusA/qobine/releases/tag/v${version}";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    mainProgram = "qobine-tui";
  };
}
