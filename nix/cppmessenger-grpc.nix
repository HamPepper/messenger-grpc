{ lib
, cmake
, ninja
, clang-tools
, stdenv
, grpc
, protobuf
, openssl
}:

stdenv.mkDerivation {
  name = "cppmessenger-grpc";
  src = ../.;

  nativeBuildInputs = [ cmake ninja ]
    ++ lib.optionals stdenv.hostPlatform.isDarwin [ clang-tools ];
  buildInputs = [ grpc protobuf openssl ];
}
