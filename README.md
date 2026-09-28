# Portside

**在菜单栏里看清本机服务。** Portside 是一款面向 macOS 的轻量原生工具，把 Homebrew 服务、Docker 容器和 TCP 监听端口集中呈现，并尽可能显示实际进程名称。打开菜单即可查看运行状态、端口，以及可直接访问的本地网页服务。

Portside 只读取本机状态，不会启动、停止或修改服务，适合快速检查本地开发环境和后台服务。支持 macOS 14 及以上版本。

它会汇总以下信息：

- **Homebrew Services** — `brew services list --json`
- **Docker 容器** — `docker ps --format '{{json .}}'`
- **监听端口** — `lsof -nP -iTCP -sTCP:LISTEN`（按进程聚合端口，并用 `ps` 解析完整命令行显示真实服务名）

原生 SwiftUI（`MenuBarExtra` + Observation），无 Dock 图标（`LSUIElement`）。

## 构建与运行

```bash
# 直接运行（开发用）
swift run Portside

# 打包成 .app 并启动
./Scripts/build-app.sh
open dist/Portside.app
```

菜单栏图标显示运行中的服务总数；有异常时图标变为警示三角。点击图标查看分组明细。

## 命令行自检

```bash
swift run Portside --dump
```

不启动 UI，直接打印四类服务的解析结果，用于验证命令与解析逻辑。

## 说明

- 默认每 15 秒后台刷新一次；打开菜单时也会刷新。
- 只读，不会启动/停止任何服务。
- Docker 已映射到宿主机的端口归入「Docker 容器」分组，不再在「监听端口」中重复显示（按端口号匹配，Colima/Lima 的 SSH 转发进程因此不再出现）。
- 网页服务判定：对候选端口发一次 `GET /`，响应为 HTML 才算网页并给出可点击链接（如 MCP/API 服务不会被误判）。探测**仅在打开菜单时触发**，结果按端口缓存 10 分钟，不在后台轮询。
- 未安装的工具（如 Docker）会在对应分组显示提示，不影响其他分组。
- 刷新间隔可在 `ServiceMonitor(refreshInterval:)` 调整。
