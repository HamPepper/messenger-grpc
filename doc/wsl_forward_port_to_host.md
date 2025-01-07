# 将 WSL 中的端口转发到 Windows 主机上

在 **Windows 主机上** 一个带有 **管理员权限** 的命令行中运行：

```shell
netsh interface portproxy add v4tov4 listenport=<host_port> listenaddress=0.0.0.0 connectport=<wsl_port> connectaddress=<wsl_ip>
```

如果想要删除转发规则，可以运行：

```shell
netsh interface portproxy delete v4tov4 listenport=<host_port> listenaddress=0.0.0.0
```
