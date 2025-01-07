# messenger-grpc

一个基于 gRPC 的简易命令行网络聊天程序。

本项目目前仅支持 Linux 和 macOS 系统。


## 开发环境

```bash
# 非 NixOS 系统需首先安装支持 flake 的 nix：
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

nix develop  # 进入开发环境

# 如下命令需在开发环境中执行：
GP  # 生成 Python gRPC 代码，如只使用 C++ 可跳过
B   # 编译 C++ 客户/服务端，如只使用 Python 可跳过
D   # 可选：生成 C++ 自动补全所需的数据库
```
