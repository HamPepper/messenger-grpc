cmake_minimum_required(VERSION 3.30)

project(
    messenger-grpc
    VERSION 0.0.0
    LANGUAGES CXX C
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_EXTENSIONS off)
set(CMAKE_CXX_STANDARD_REQUIRED on)


#################
# 3rd party lib #
#################

find_package(gRPC REQUIRED)
set(gRPC_CPP_PLUGIN_EXECUTABLE $<TARGET_FILE:gRPC::grpc_cpp_plugin>)

find_package(Protobuf REQUIRED)


################
# proto -> cpp #
################

set(PROTO_FILES "proto/messenger_grpc/chat_service.proto")

foreach(proto_file ${PROTO_FILES})
    get_filename_component(proto_name ${proto_file} NAME_WE)
    get_filename_component(proto_path ${proto_file} DIRECTORY)
    set(proto_src "${CMAKE_CURRENT_BINARY_DIR}/${proto_path}/${proto_name}.pb.cc")
    set(proto_hdr "${CMAKE_CURRENT_BINARY_DIR}/${proto_path}/${proto_name}.pb.h")
    set(grpc_src "${CMAKE_CURRENT_BINARY_DIR}/${proto_path}/${proto_name}.grpc.pb.cc")
    set(grpc_hdr "${CMAKE_CURRENT_BINARY_DIR}/${proto_path}/${proto_name}.grpc.pb.h")

    add_custom_command(
        OUTPUT ${proto_src} ${proto_hdr} ${grpc_src} ${grpc_hdr}
        COMMAND ${Protobuf_PROTOC_EXECUTABLE}
        ARGS --grpc_out=${CMAKE_CURRENT_BINARY_DIR}
             --cpp_out=${CMAKE_CURRENT_BINARY_DIR}
             --plugin=protoc-gen-grpc=${gRPC_CPP_PLUGIN_EXECUTABLE}
             -I ${CMAKE_CURRENT_SOURCE_DIR}
             ${proto_file}
        DEPENDS ${proto_file}
    )

    list(APPEND PROTO_SRCS ${proto_src} ${grpc_src})
    list(APPEND PROTO_HDRS ${proto_hdr} ${grpc_hdr})
endforeach()


#############
# libraries #
#############

add_library(messenger-grpc ${PROTO_SRCS} ${PROTO_HDRS})
target_include_directories(messenger-grpc PUBLIC ${CMAKE_CURRENT_BINARY_DIR})
target_link_libraries(messenger-grpc PUBLIC
    gRPC::grpc++
    protobuf::libprotobuf
)


###############
# executables #
###############

add_executable(cppclient "src/cppclient.cpp")
target_link_libraries(cppclient messenger-grpc)
