#!/usr/bin/env python3

import threading

import grpc

from time import sleep

from messenger_grpc import ChatClient
from messenger_grpc import chat_service_pb2_grpc as cs_service


class Client:
    def __init__(self, ip="localhost", port=23333):
        self.ip = ip
        self.port = port
        self.client = ChatClient()

    def run(self):
        with grpc.insecure_channel(f"{self.ip}:{self.port}") as channel:
            stub = cs_service.ChatServiceStub(channel)

            user = input("Enter your username: ")
            room = input("Enter the chat room: ")

            self.client.connect(stub, user, room)

            threading.Thread(
                target=self.client.sendMessage, args=(stub, user, room)
            ).start()
            threading.Thread(
                target=self.client.receiveMessages, args=(stub, room)
            ).start()

            try:
                while True:
                    sleep(1)
            except KeyboardInterrupt:
                pass
            finally:
                self.client.disconnect(stub, user, room)
                print(f"{user} disconnected from room {room}")


if __name__ == "__main__":
    client = Client()
    client.run()
