from time import sleep

from . import chat_service_pb2 as mgp_structs
from . import chat_service_pb2_grpc as mgp_services


class ChatServer(mgp_services.ChatServiceServicer):
    def __init__(self):
        self.rooms = {}
        self.clients = {}

    def connect(self, request, context):
        room = request.room
        user = request.user
        if room not in self.rooms:
            self.rooms[room] = []
        if room not in self.clients:
            self.clients[room] = set()
        self.clients[room].add(user)
        return mgp_structs.ConnectResponse(message=f"{user} connected to room {room}")

    def disconnect(self, request, context):
        room = request.room
        user = request.user
        if room in self.clients:
            self.clients[room].discard(user)
        return mgp_structs.Empty()

    def sendMessage(self, request, context):
        room = request.room
        if room not in self.rooms:
            self.rooms[room] = []
        self.rooms[room].append(request)
        return mgp_structs.Empty()

    def receiveMessages(self, request, context):
        room = request.room
        if room not in self.rooms:
            self.rooms[room] = []

        last_index = 0
        while True:
            while len(self.rooms[room]) > last_index:
                message = self.rooms[room][last_index]
                last_index += 1
                yield message
            sleep(1)
