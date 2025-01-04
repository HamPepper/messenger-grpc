#!/usr/bin/env python3

import grpc

from concurrent import futures

from messenger_grpc import ChatServer
from messenger_grpc import chat_service_pb2_grpc as cs_services


class Server:
    def __init__(self, ip="::", port=23333):
        self.server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
        cs_services.add_ChatServiceServicer_to_server(ChatServer(), self.server)

        self.ip = ip
        self.port = port
        self.server.add_insecure_port(f"[{ip}]:{port}")

    def serve(self):
        print(f"Listening on {self.ip} : {self.port}")

        self.server.start()
        self.server.wait_for_termination()


if __name__ == "__main__":
    server = Server()
    server.serve()
