{ lib
, stdenv
, fetchFromGitHub
, autoreconfHook
, pkg-config
, libpcap
, libevent
}:

stdenv.mkDerivation rec {
  pname = "addrwatch";
  version = "1.0.2";

  src = fetchFromGitHub {
    owner = "fln";
    repo = "addrwatch";
    rev = "v${version}";
    hash = "sha256-yD0YSwLCa0jaUPMhEphxcqOneW+t09qN2F6dg0cZ9Mw=";
  };

  nativeBuildInputs = [ autoreconfHook pkg-config ];
  buildInputs = [ libpcap libevent ];

  # sqlite3 and mysql are opt-in (--enable-*), so omitting them disables both
  configureFlags = [ ];

  meta = with lib; {
    description = "IPv4/IPv6 address monitoring tool for ethernet networks";
    longDescription = ''
      addrwatch monitors networks and logs ethernet/IP address pairings.
      It supports both IPv4 (ARP) and IPv6 (NDP) address monitoring,
      VLAN tracking, and can output to stdout, syslog, or databases.
      Modern replacement for arpwatch.
    '';
    homepage = "https://github.com/fln/addrwatch";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    mainProgram = "addrwatch";
  };
}
