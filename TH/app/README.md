# FATE Flutter APP

本目录是 APP 主工程。当前首版业务范围为西洋占星、报告、Apple 内购和登录；文档中泰式占星、七字数字、塔罗与聊天属于后续功能批次。客户端采用功能目录、ViewModel、Repository、独立 HTTP 与凭证存储，并使用 go_router 和四语言 ARB。

从仓库根目录启动：

```powershell
pnpm dev
```

单独运行 APP 浏览器预览（已有 FastAPI 8000 服务时）：

```powershell
pnpm dev:app
```

该预览在 5174 端口运行同一份 Flutter 页面，以同源开发服务器转发 API。它不代替 iOS 真机与 StoreKit 沙箱验收。完整启动、架构边界、保留项和发布依赖见 [APP_ARCHITECTURE.md](../docs/APP_ARCHITECTURE.md)。

```powershell
pnpm check:app
pnpm test:app
```

原生 iOS 在安装 Xcode 的 macOS 上运行。使用实际 HTTPS API 地址、开发者团队、Bundle ID 和已审核商品配置，例如：

```sh
flutter run -d <ios-device-id> --dart-define=FATE_API_BASE_URL=https://<your-api-host>
```

当前机器使用 Flutter 3.47.9，依赖已写入 pubspec.lock。仓库提供 app/.fvmrc；自备 SDK 时可设置 FATE_FLUTTER_BIN。不要把 Roxy、模型、商店私钥写入 Dart 或 ARB。
