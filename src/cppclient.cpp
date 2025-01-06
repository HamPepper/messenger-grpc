#include <iostream>
#include <memory>
#include <string>

#include "proto/messenger_grpc/chat_service.grpc.pb.h"
#include "proto/messenger_grpc/chat_service.pb.h"
#include <grpcpp/grpcpp.h>

using grpc::Channel;
using grpc::ClientContext;
using grpc::Status;

using chat_service::ChatMessage;
using chat_service::ChatService;
using chat_service::Empty;

// config
constexpr std::string HOST = "127.0.0.1";
constexpr std::string PORT = "23333";

class ChatClient {
public:
  ChatClient(std::shared_ptr<Channel> channel)
      : stub_(ChatService::NewStub(channel)) {}

  void sendMessage(const std::string &room, const std::string &user,
                   const std::string &message) {
    ChatMessage request;
    request.set_room(room);
    request.set_user(user);
    request.set_message(message);

    Empty reply;

    ClientContext context;
    Status status = stub_->sendMessage(&context, request, &reply);

    if (!status.ok()) {
      std::cout << "RPC failed" << std::endl;
    }
  }

private:
  std::unique_ptr<ChatService::Stub> stub_;
};

int main(int argc, char **argv) {
  ChatClient client(grpc::CreateChannel(HOST + ":" + PORT,
                                        grpc::InsecureChannelCredentials()));

  std::string room{"1"};
  std::string user{"user1"};
  std::string message{"Hello, world! from basic C++ client!"};

  client.sendMessage(room, user, message);

  return 0;
}
