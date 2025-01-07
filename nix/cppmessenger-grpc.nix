{ cmake, ninja, stdenv, grpc, protobuf, openssl }:
stdenv.mkDerivation {
  name = "cppmessenger-grpc";
  src = ../.;

  nativeBuildInputs = [ cmake ninja ];
  buildInputs = [ grpc protobuf openssl ];
}
