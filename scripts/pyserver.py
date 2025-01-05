#!/usr/bin/env python3

import asyncio
import signal

from grpc import aio

from messenger_grpc import ChatServer
from messenger_grpc import chat_service_pb2_grpc as cs_services


class Server:
    def __init__(self, ip="0.0.0.0", port=23333):
        self.ip = ip
        self.port = port

    async def serve(self):
        server = aio.server()
        cs_services.add_ChatServiceServicer_to_server(ChatServer(), server)
        server.add_insecure_port(f"{self.ip}:{self.port}")

        loop = asyncio.get_event_loop()
        for sig in [signal.SIGINT, signal.SIGTERM]:
            loop.add_signal_handler(sig, lambda: asyncio.create_task(server.stop(2)))

        print(f"Listening on {self.ip}:{self.port}")
        await server.start()
        await server.wait_for_termination()


if __name__ == "__main__":
    server = Server()

    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

    loop.run_until_complete(server.serve())
    loop.run_until_complete(loop.shutdown_asyncgens())
    # ^ensure all async generators are closed
    loop.close()
