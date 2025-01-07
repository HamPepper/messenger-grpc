{ lib
, cmake
, ninja
, clang-tools
, stdenv
, grpc
, protobuf
, openssl
, runCommand
}:

let
  clang-scan-deps = runCommand "clang-scan-deps-wrapper" { } ''
    mkdir -p $out/bin
    ln -s ${clang-tools}/bin/clang-scan-deps $out/bin/clang-scan-deps
  '';
in

stdenv.mkDerivation {
  name = "cppmessenger-grpc";
  src = ../.;

  nativeBuildInputs = [ cmake ninja ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ clang-scan-deps ];
  buildInputs = [ grpc protobuf openssl ];
}
