# gRPC 生成 `.pyi` 类型信息文件

考虑 `package_name/greet_service.proto`：

```protobuf
syntax = "proto3";

package greet_service;


service Greeter {
  rpc greet (GreetRequest) returns (GreetReply) {}
}

message GreetRequest {
  string name = 1;
}

message GreetReply {
  string message = 1;
}
```

网络常见教程中，生成 Python 接口的方法如下：

```bash
python3 -m grpc_tools.protoc \
    --proto_path=. \
    --python_out=. \
    --grpc_python_out=. \
    ./package_name/greet_service.proto
    # ^上面的文件夹结构是必要的。这是为了能正确地生成 Python import 语句
```

此时会生成如下2个文件：

```
package_name/greet_service_pb2_grpc.py
package_name/greet_service_pb2.py
```

老版本的 gRPC 会把 `messege` 结构体的定义直接明文写入 `messenger_grpc_pb2.py`：

```python
class GreetRequest(_message.Message):
    pass
    # 省略

class GreetReply(_message.Message):
    pass
    # 省略
```

这些定义（类型信息）会被 IDE 等用作代码补全的参考。
新版 [1] [2] 的 gRPC 不再将 **类型信息** 直接写入 `*_pb2.py`，
而是需要通过一个额外的命令行参数生成独立的 `.pyi` 文件：

```bash
python3 -m grpc_tools.protoc \
    --proto_path=. \
    --python_out=. \
    --grpc_python_out=. \
    --pyi_out=. \  # 生成类型信息 .pyi 文件
    ./package_name/greet_service.proto
```


[1]: https://github.com/protocolbuffers/protobuf/releases/tag/v3.20.0
[2]: https://github.com/grpc/grpc/issues/32564
