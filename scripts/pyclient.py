#!/usr/bin/env python3

import asyncio
import aioconsole
import signal

from grpc import aio

from messenger_grpc import ChatClient
from messenger_grpc import chat_service_pb2_grpc as cs_service


class Client:
    def __init__(self, ip="localhost", port=23333):
        self.ip = ip
        self.port = port

        self.incoming_messages = asyncio.Queue()
        self.stop_event = asyncio.Event()

    async def handleInput(self, client, stub, user, room):
        while not self.stop_event.is_set():
            user_input = await aioconsole.ainput()
            await client.sendMessage(stub, user, room, user_input)

    async def handleOutput(self, stub, user, room):
        while not self.stop_event.is_set():
            message = await self.incoming_messages.get()
            print(f"[{message.user} - {message.room}]: {message.message}")

    async def run(self):
        client = ChatClient(self.incoming_messages)
        user = input("Enter your username: ")
        room = input("Enter room name: ")

        async with aio.insecure_channel(f"{self.ip}:{self.port}") as channel:
            stub = cs_service.ChatServiceStub(channel)

            await client.connect(stub, user, room)
            if not (client.ok):
                return

            receive_task = asyncio.create_task(client.receiveMessages(stub, room))
            input_task = asyncio.create_task(self.handleInput(client, stub, user, room))
            output_task = asyncio.create_task(self.handleOutput(stub, user, room))

            loop = asyncio.get_running_loop()
            for sig in (signal.SIGINT, signal.SIGTERM):
                loop.add_signal_handler(sig, lambda: self.stop_event.set())

            try:
                await self.stop_event.wait()
            finally:
                receive_task.cancel()
                input_task.cancel()
                output_task.cancel()
                await asyncio.gather(
                    receive_task, input_task, output_task, return_exceptions=True
                )
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
