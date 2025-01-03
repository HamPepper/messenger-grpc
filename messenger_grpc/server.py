import grpc

import messenger_grpc.messenger_grpc_pb2 as mgp_structs
import messenger_grpc.messenger_grpc_pb2_grpc as mgp_services

from concurrent import futures


class Greeter(mgp_services.GreeterServicer):
    def greet(self, request, context):
        message = f"Hello, {request.name}!"
        print(f"Sent: {message}")
        return mgp_structs.GreetReply(message=message)


def serve():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    mgp_services.add_GreeterServicer_to_server(Greeter(), server)
    server.add_insecure_port("[::]:50051")
    server.start()
    print("Server started, listening on port 50051")
    server.wait_for_termination()


if __name__ == "__main__":
    serve()
