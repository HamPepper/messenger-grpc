from . import chat_service_pb2 as cs_structs
from . import chat_service_pb2_grpc as cs_services


class ChatClient:
    def connect(self, stub, user, room):
        connect_request = cs_structs.ConnectRequest(room=room, user=user)
        response = stub.connect(connect_request)
        print(response.message)

    def disconnect(self, stub, user, room):
        disconnect_request = cs_structs.DisconnectRequest(room=room, user=user)
        stub.disconnect(disconnect_request)

    def sendMessage(self, stub, user, room):
        while True:
            message = input("> ")
            chat_message = cs_structs.ChatMessage(room=room, user=user, message=message)
            stub.sendMessage(chat_message)

    def receiveMessages(self, stub, room):
        chat_room = cs_structs.ChatRoom(room=room)
        for message in stub.receiveMessages(chat_room):
            print(f"{message.user} in {message.room}: {message.message}")
