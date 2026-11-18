# FATE 首版 iOS 提审准备

首版范围：西洋占星、个人报告、登录和 Apple 内购。当前网页预览可用于核对页面，正式提审需要签名 iOS 包及真实后端能力。

## 1. 注册 App ID

在 Apple Developer 的注册页面填写：

| 字段 | 当前工程对应值 |
| --- | --- |
| 描述 | FATE iOS |
| 捆绑 ID 类型 | 显式 |
| 捆绑 ID | `app.fate.fateApp`，注意大小写 |
| 用苹果登录 | 开启，独立首款 APP 按主 App ID 配置 |
| 应用内购买 | 显式 App ID 默认开启，页面显示灰色已勾选正常 |

本版没有使用 Apple Pay、iCloud、App Groups 或推送通知能力。购买数字报告使用 StoreKit 内购，不需要配置 Apple Pay 商户。

注册成功后，在 App Store Connect 新建 iOS 应用并选择同一个 Bundle ID。内部 SKU 可填写 `FATE-IOS-001`；名称以后台可用性为准，主要语言选择泰语。新建记录后取得数字 Apple ID，它与 Bundle ID、团队 ID 是三个不同字段。

## 2. 暂无 Mac 时的云端构建

根目录的 `codemagic.yaml` 为现有 `TH/app` 提供两个手动流程，Flutter 版本固定为当前工程使用的 `3.47.9`：

1. `ios-compile-check`：在云端 macOS/Xcode 运行分析、测试及无签名编译。不需要 Apple 签名凭据；结果用于查出原生工程或插件编译问题，不是可提交的安装包。
2. `ios-app-store`：读取正式后端能力，运行分析和测试，应用签名配置，构建 IPA 并上传 App Store Connect。此流程不自动提交 App Review，也不自动提交 TestFlight 测试审核。

先在 Codemagic 连接保存当前代码的 Git 仓库，使其能够读取根目录的 YAML。配置文件还需经项目负责人正常提交、推送后，云端才能读取；本次没有推送仓库或运行付费云构建。

在 Codemagic 里添加名为 `FATEAppStoreConnect` 的 Apple 集成，使用本人团队授权的 App Store Connect API 凭据。签名证书和 App Store provisioning profile 必须与 `app.fate.fateApp` 匹配，并包含 Apple 登录能力。上传或配置方式按 Codemagic 签名页面操作。

创建环境变量组 `fate_ios_release`：

| 变量 | 填写内容 |
| --- | --- |
| `FATE_API_BASE_URL` | 可供审核设备访问的正式 HTTPS 后端根地址，不能填本机地址 |
| `APP_STORE_APPLE_ID` | App Store Connect 新建应用后显示的数字 Apple ID |
| `IOS_BUILD_NUMBER` | 正整数构建号，每次上传递增，避免与已上传的同版本构建号重复 |

工作流默认发布版本号为 `1.0.0`，应与 App Store Connect 待提交版本一致。Apple 私钥、证书密码和供应商密钥只能放在对应服务的加密配置里，不写入 Git 或聊天；Roxy 和模型密钥仅放在后端。

云端构建可能产生费用，运行前由账号持有人确认额度和计费。公司团队账号以实际套餐为准。签名包上传并处理完成后，先通过 TestFlight 在 iPhone 验收，再选择用于 App Review 的构建。

## 3. 当前已经确认的提审缺口

以下为 2026-11-16 本地源码核对结果，不代表线上服务器状态：

| 项目 | 当前状态与下一步 |
| --- | --- |
| Apple 登录后端 | 客户端已有原生调用；本地后端尚未实现 `/api/auth/apple`，能力声明固定为关闭，需要补齐身份验证与账号会话 |
| Apple 订单与验单 | 客户端已有 StoreKit 链路；本地后端尚未实现 `/api/orders` 和订单验单接口，需要真实交易校验、幂等、账号权益、退款撤权及恢复机制 |
| 正式 API 地址 | 原生工程缺省连接 `http://127.0.0.1:8000`，签名构建必须通过 `FATE_API_BASE_URL` 指定正式 HTTPS 服务 |
| 账号删除与隐私 | 现有客户端有退出登录；尚需完成正式账号删除、隐私政策入口、数据披露和审核所需说明 |
| iOS 签名与真机 | 当前尚未在 macOS 完成签名构建；需配置证书、描述文件并在 iPhone 验收登录和沙盒购买 |
| 商店素材 | 原生图标已替换为FATE深紫暖金星芒与轨道图案，需继续准备泰语说明、截图、年龄分级、支持网址和审核说明；不得用开发预览代替内购实测 |

`ios_release_preflight.py` 只进行公开配置的只读检查，拒绝本机地址、缺失能力和开发环境解锁标记。它不会创建订单、购买商品或修改服务器，也不能代替原生登录、交易校验、账号删除和真机验收。

APP图标主图位于 `assets/brand/fate-app-icon.png`，生成提示词保存在相邻的 `.prompt.md`。已导出iOS图标集、Android启动图标及APP Web安装图标；源图和导出均为不透明正方形，外部圆角由系统处理。

## 4. 提交流程

注册 App ID → 新建 App Store Connect 记录 → 配置内购商品与签名 → 完成正式后端 → 云端构建并上传 → TestFlight 真机验收 → 填写商店和隐私资料 → 将首个内购商品与 APP 版本加入同一提审草稿 → 提交审核。

首次提交某类内购商品时，Apple 要求与新的 APP 版本一起提交。审核说明应清楚说明游客试读、登录、报告购买、恢复及账号删除路径。占星类产品还需按 Apple 4.3(b) 核对产品差异化和实际功能。

## 官方参考

- [Apple：注册 App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id)
- [Apple：提交内购商品](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)
- [Flutter：构建与发布 iOS](https://docs.flutter.dev/deployment/ios)
- [Codemagic：Flutter 构建](https://docs.codemagic.io/yaml-quick-start/building-a-flutter-app/)
- [Codemagic：上传 App Store Connect](https://docs.codemagic.io/yaml-publishing/app-store-connect/)
