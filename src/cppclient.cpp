#include <csignal>
#include <format>
#include <iostream>
#include <memory>
#include <string>
#include <thread>

#include <grpcpp/client_context.h>
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
std::unique_ptr<ChatClient> gClient;

class ChatClient {
private:
  std::unique_ptr<ChatService::Stub> m_stub;
  std::string m_user;
  std::string m_room;

  ClientContext m_receiveMessagesContext;
  std::unique_ptr<std::thread> m_receiveMessagesThread;

public:
  ChatClient(std::shared_ptr<Channel> channel)
      : m_stub(ChatService::NewStub(channel)), m_user(), m_room(),
        m_receiveMessagesContext(), m_receiveMessagesThread(nullptr) {}

  bool connect() {
    ConnectRequest request;
    request.set_user(m_user);
    request.set_room(m_room);

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

  void disconnect() {
    DisconnectRequest request;
    request.set_user(m_user);
    request.set_room(m_room);

    Empty response;
    ClientContext context;

    Status status = m_stub->disconnect(&context, request, &response);
    if (status.ok()) {
      std::cout << std::format("{} disconnected from {}", m_user, m_room)
                << std::endl;
    } else {
      std::cout << "disconnect RPC failed." << std::endl;
    }
  }

  void sendMessage(const std::string &message) {
    ChatMessage request;
    request.set_room(m_room);
    request.set_user(m_user);
    request.set_message(message);

    Empty response;
    ClientContext context;

    Status status = m_stub->sendMessage(&context, request, &response);
    if (!status.ok()) {
      std::cout << "sendMessage RPC failed." << std::endl;
    }
  }

  void receiveMessages() {
    ChatRoom request;
    request.set_room(m_room);

    std::unique_ptr<ClientReader<ChatMessage>> reader(
        m_stub->receiveMessages(&m_receiveMessagesContext, request));

    ChatMessage message;
    while (reader->Read(&message)) {
      std::cout << std::format("[{} - {}]: {}", message.user(), message.room(),
                               message.message())
                << std::endl;
    }

    Status status = reader->Finish();
    if (!status.ok()) {
      std::cout << "receiveMessages RPC failed." << std::endl;
    }
  }

  void run() {
    std::cout << "Enter your username: ";
    std::getline(std::cin, m_user);
    std::cout << "Enter room name: ";
    std::getline(std::cin, m_room);

    if (!connect()) {
      return;
    }

    m_receiveMessagesThread =
        std::make_unique<std::thread>(&ChatClient::receiveMessages, this);

    std::string message;
    while (true) {
      std::getline(std::cin, message);
      if (message == "/quit") {
        break;
      }
      sendMessage(message);
    }

    stop();
  }

  void stop() {
    disconnect();
    m_receiveMessagesContext.TryCancel();

    if (m_receiveMessagesThread.get() != nullptr) {
      m_receiveMessagesThread->join();
    }
  }
};

void signalHandler(int signum) {
  gClient->stop();
  std::exit(signum);
}

int main() {
  std::signal(SIGINT, signalHandler);

  gClient = std::make_unique<ChatClient>(grpc::CreateChannel(
      std::format("{}:{}", HOST, PORT), grpc::InsecureChannelCredentials()));
  gClient->run();

  return 0;
}
