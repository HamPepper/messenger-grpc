from . import chat_service_pb2 as cs_structs


class ChatClient:
    def __init__(self, queue):
        self.queue = queue
        self.ok = True

    async def connect(self, stub, user, room):
        connect_request = cs_structs.ConnectRequest(room=room, user=user)
        try:
            response = await stub.connect(connect_request)
            print(response.message)
        except Exception as e:
            print(f"Error: {e}")
            self.ok = False

    async def disconnect(self, stub, user, room):
        disconnect_request = cs_structs.DisconnectRequest(room=room, user=user)
        try:
            await stub.disconnect(disconnect_request)
            print(f"{user} disconnected from {room}")
        except Exception as e:
            print(f"Error: {e}")
            self.ok = False

    async def sendMessage(self, stub, user, room, text):
        try:
            chat_message = cs_structs.ChatMessage(room=room, user=user, message=text)
            await stub.sendMessage(chat_message)
        except Exception as e:
            print(f"Error: {e}")
            self.ok = False

    async def receiveMessages(self, stub, room):
        chat_room = cs_structs.ChatRoom(room=room)
        try:
            # the for loop below represents streaming
            async for message in stub.receiveMessages(chat_room):
                await self.queue.put(message)
        except Exception as e:
            print(f"Error: {e}")
            self.ok = False
