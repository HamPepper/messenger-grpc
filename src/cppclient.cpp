#include <atomic>
#include <csignal>
#include <format>
#include <iostream>
#include <memory>
#include <string>
#include <thread>

#include <grpcpp/grpcpp.h>

#include "proto/messenger_grpc/chat_service.grpc.pb.h"
#include "proto/messenger_grpc/chat_service.pb.h"

using grpc::Channel;
using grpc::ClientContext;
using grpc::ClientReader;
using grpc::Status;

using chat_service::ChatMessage;
using chat_service::ChatRoom;
using chat_service::ChatService;
using chat_service::ConnectRequest;
using chat_service::ConnectResponse;
using chat_service::DisconnectRequest;
using chat_service::Empty;

// config
constexpr std::string HOST = "127.0.0.1";
constexpr std::string PORT = "23333";

// global variables
class ChatClient;
ChatClient *gClient = nullptr;
std::string gRoom;
std::string gUser;
std::atomic<bool> gRunning = false;

class ChatClient {
public:
  ChatClient(std::shared_ptr<Channel> channel)
      : m_stub(ChatService::NewStub(channel)) {}

  bool connect(const std::string &user, const std::string &room) {
    ConnectRequest request;
    request.set_user(user);
    request.set_room(room);

    ConnectResponse response;
    ClientContext context;

    Status status = m_stub->connect(&context, request, &response);
    if (status.ok()) {
      std::cout << response.message() << std::endl;
      return true;
    } else {
      std::cout << "connect RPC failed." << std::endl;
      return false;
    }
  }

  void disconnect(const std::string &user, const std::string &room) {
    DisconnectRequest request;
    request.set_user(user);
    request.set_room(room);

    Empty response;
    ClientContext context;

    Status status = m_stub->disconnect(&context, request, &response);
    if (status.ok()) {
      std::cout << std::format("{} disconnected from {}", user, room)
                << std::endl;
    } else {
      std::cout << "disconnect RPC failed." << std::endl;
    }
  }

  void sendMessage(const std::string &room, const std::string &user,
                   const std::string &message) {
    ChatMessage request;
    request.set_room(room);
    request.set_user(user);
    request.set_message(message);

    Empty response;
    ClientContext context;

    Status status = m_stub->sendMessage(&context, request, &response);
    if (!status.ok()) {
      std::cout << "sendMessage RPC failed." << std::endl;
    }
  }

  void receiveMessages(const std::string &room) {
    ChatRoom request;
    request.set_room(room);

    ClientContext context;
    std::unique_ptr<ClientReader<ChatMessage>> reader(
        m_stub->receiveMessages(&context, request));

    ChatMessage message;
    while (reader->Read(&message) && gRunning) {
      std::cout << std::format("[{} - {}]: {}", message.user(), message.room(),
                               message.message())
                << std::endl;
    }

    if (!gRunning) {
      context.TryCancel();
    }

    Status status = reader->Finish();
    if (!status.ok() && gRunning) {
      std::cout << "receiveMessages RPC failed." << std::endl;
    }
  }

private:
  std::unique_ptr<ChatService::Stub> m_stub;
};

void signalHandler(int signum) {
  if (gRunning && gClient) {
    gRunning = false;
    gClient->disconnect(gUser, gRoom);
  }
  std::exit(signum);
}

void handleInput(ChatClient &client, const std::string &user,
                 const std::string &room) {
  std::string message;
  while (true) {
    std::getline(std::cin, message);
    if (message == "/quit") {
      break;
    }
    client.sendMessage(room, user, message);
  }
}

int main(int argc, char **argv) {
  std::signal(SIGINT, signalHandler);

  ChatClient client(grpc::CreateChannel(std::format("{}:{}", HOST, PORT),
                                        grpc::InsecureChannelCredentials()));
  gClient = &client;

  std::cout << "Enter your username: ";
  std::getline(std::cin, gUser);
  std::cout << "Enter room name: ";
  std::getline(std::cin, gRoom);

  if (!client.connect(gUser, gRoom)) {
    return 1;
  }

  gRunning = true;
  std::thread receiveThread(&ChatClient::receiveMessages, &client, gRoom);
  handleInput(client, gUser, gRoom);

  gRunning = false;
  client.disconnect(gUser, gRoom);

  receiveThread.join();

  return 0;
}
