from asyncio import sleep

from . import chat_service_pb2 as cs_structs
from . import chat_service_pb2_grpc as cs_services


class ChatServer(cs_services.ChatServiceServicer):
    def __init__(self):
        self.rooms = {}
        self.clients = {}  # key: room id, val: set of clients in that room

    async def connect(self, request, context):
        """
        client connects to server
        """
        room = request.room
        user = request.user

        if room not in self.rooms:
            self.rooms[room] = []
        if room not in self.clients:
            self.clients[room] = set()

        self.clients[room].add(user)

        return cs_structs.ConnectResponse(message=f"{user} connected to room {room}")

    async def disconnect(self, request, context):
        """
        client disconnects from server
        """
        room = request.room
        user = request.user
        if room in self.clients:
            self.clients[room].discard(user)
        return cs_structs.Empty()

    async def sendMessage(self, request, context):
        """
        client sends a message to server
        """
        room = request.room
        if room not in self.rooms:
            self.rooms[room] = []
        self.rooms[room].append(request)
        return cs_structs.Empty()

    async def receiveMessages(self, request, context):
        """
        client receives messages from server
        """
        room = request.room
        if room not in self.rooms:
            self.rooms[room] = []

        last_index = 0
        while not context.done():
            while len(self.rooms[room]) > last_index:
                message = self.rooms[room][last_index]
                last_index += 1
                yield message
            await sleep(0.01)
