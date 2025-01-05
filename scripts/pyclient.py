#!/usr/bin/env python3

import asyncio
import signal

from grpc import aio

from messenger_grpc import ChatClient
from messenger_grpc import chat_service_pb2_grpc as cs_service


class Client:
    def __init__(self, ip="localhost", port=23333):
        self.ip = ip
        self.port = port

    async def run(self):
        client = ChatClient()

        async with aio.insecure_channel(f"{self.ip}:{self.port}") as channel:
            stub = cs_service.ChatServiceStub(channel)

            user = input("Enter your username: ")
            room = input("Enter the chat room: ")

            await client.connect(stub, user, room)

            send_task = asyncio.create_task(client.sendMessage(stub, user, room))
            receive_task = asyncio.create_task(client.receiveMessages(stub, room))

            stop_event = asyncio.Event()

            loop = asyncio.get_running_loop()
            for sig in (signal.SIGINT, signal.SIGTERM):
                loop.add_signal_handler(sig, lambda: stop_event.set())

            try:
                await stop_event.wait()
            finally:
                send_task.cancel()
                receive_task.cancel()
                await asyncio.gather(send_task, receive_task, return_exceptions=True)
                await client.disconnect(stub, user, room)


if __name__ == "__main__":
    client = Client()

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    try:
        loop.run_until_complete(client.run())
    except KeyboardInterrupt:
        pass
    finally:
        loop.run_until_complete(loop.shutdown_asyncgens())
        loop.close()
