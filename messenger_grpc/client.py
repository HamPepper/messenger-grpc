import grpc

import messenger_grpc.messenger_grpc_pb2 as mgp_structs
import messenger_grpc.messenger_grpc_pb2_grpc as mgp_services


def run():
    with grpc.insecure_channel("localhost:50051") as channel:
        stub = mgp_services.GreeterStub(channel)
        response = stub.greet(mgp_structs.GreetRequest(name="World"))
    print(f"Greeter client received: {response.message}")


if __name__ == "__main__":
    run()
