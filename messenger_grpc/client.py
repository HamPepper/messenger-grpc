import asyncio
import aioconsole

from . import chat_service_pb2 as cs_structs


class ChatClient:
    async def connect(self, stub, user, room):
        connect_request = cs_structs.ConnectRequest(room=room, user=user)
        response = await stub.connect(connect_request)
        print(response.message)

    async def disconnect(self, stub, user, room):
        disconnect_request = cs_structs.DisconnectRequest(room=room, user=user)
        await stub.disconnect(disconnect_request)
        print(f"{user} disconnected from {room}")

    async def sendMessage(self, stub, user, room):
        while True:
            try:
                message = await aioconsole.ainput("> ")
                chat_message = cs_structs.ChatMessage(
                    room=room, user=user, message=message
                )
                await stub.sendMessage(chat_message)
            except asyncio.CancelledError:
                break

    async def receiveMessages(self, stub, room):
        chat_room = cs_structs.ChatRoom(room=room)
        async for message in stub.receiveMessages(chat_room):
            print(f"{message.user} in {message.room}: {message.message}")
