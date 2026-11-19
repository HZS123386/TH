# FATE Flutter APP

本目录是 APP 主工程。当前页面包括神殿、四神明陪聊、占卜工具、羁绊、账号，以及原有出生资料、星盘和报告。Apple 登录、内购和生产陪聊仍受服务能力限制。客户端继续使用现有功能目录、ViewModel、Repository、独立 HTTP 与凭证存储、go_router 和四语言 ARB。

从仓库根目录启动：

```powershell
node TH/scripts/dev.mjs
```

统一命令从 `C:\Users\32668\Desktop\海外-玄学` 启动现有 App、H5 和 FastAPI。只重建 App 浏览器预览时使用：

```powershell
node TH/scripts/flutter-app.mjs build-preview
```

默认 App 端口为 5176，可通过 `SABAI_WEB_PORT` 指定；本次隔离验收使用 5196。预览运行同一份 Flutter 页面，不代替 iOS/Android 真机和商店验收。完整设计、架构边界和发布依赖见 [APP_ARCHITECTURE.md](../docs/APP_ARCHITECTURE.md)。

```powershell
node TH/scripts/flutter-app.mjs analyze
node TH/scripts/flutter-app.mjs test test/app_flow_test.dart test/companion_test.dart
```

原生 iOS 在安装 Xcode 的 macOS 上运行。使用实际 HTTPS API 地址、开发者团队、Bundle ID 和已审核商品配置，例如：

```sh
flutter run -d <ios-device-id> --dart-define=FATE_API_BASE_URL=https://<your-api-host>
```

当前机器使用 Flutter 3.47.9，依赖已写入 pubspec.lock。仓库提供 app/.fvmrc；自备 SDK 时可设置 FATE_FLUTTER_BIN。不要把 Roxy、模型、商店私钥写入 Dart 或 ARB。

## 2026-11-15 上架前端补齐

新增 `/privacy`、`/support`、`/delete-account`、`/purchases`；继续使用原 App 入口、主题、动效、账号和服务调用链。账号中心、登录页、聊天回复和个人报告均已接入对应入口。首页顺序未改。

- 陪聊发送前明确说明第三方 AI 接收方和数据用途。授权按账号、告知版本和接收方保存在本机，换账号或接收方变化需重新确认。拒绝不发送，撤回阻止后续发送。报告仍使用原 `/api/privacy/consents` 服务端记录。
- 聊天记录清除连接既有 `DELETE /api/history`，与删除记忆、清除本机出生资料、删除账号分别说明。
- 删除账号有两步确认；举报含原因、选填说明、草稿放弃确认、失败保留和回执。两项新服务尚不存在，能力开关缺失时禁用提交，不生成成功消息。
- 购买与恢复页面替代原“购买记录 → 购买弹窗”。原生 Apple / Google 共用购买状态和服务端核验，Google 使用 `obfuscatedAccountId` 绑定订单账号；收到商店事件或恢复结束都不会直接解锁。
- Android 禁止云备份及设备迁移复制本机凭证和资料；原正式签名规则保留。未生成签名包。
- 本轮只修改 App 前端、原生配置及相关文档，没有修改后端或 H5，也没有新建真实订单、付款、发布或提交商店。

### 发布配置

通过既有 Flutter 构建传入真实 HTTPS 地址：`FATE_API_BASE_URL`、`FATE_PRIVACY_URL`、`FATE_TERMS_URL`、`FATE_SUPPORT_URL`。后三项不填时不展示虚假外链；隐私页会显示公开政策尚不可用。客服邮箱读取现有 `GET /api/landing/config.support_email`，请求失败可重试；邮件操作仅打开用户的邮件应用。

内置“使用说明”和数据说明不替代运营主体正式发布的法律文件。正式发布前应把这些 HTTPS 页面部署好，并由产品方确认实际处理者、保存期限和权利请求方式。新增依赖仅为官方 `url_launcher`；Google Play 依赖原来已由 `in_app_purchase` 引入，本轮改为直接声明以使用平台类型。

### 等待服务端接入的前端合同

以下是已经由前端及隔离替身测试消费的合同，**不是现有后端已实现的接口**。现有 `/api/config.app_capabilities` 未返回这些开关，前端默认关闭。

| 能力 | 服务端开关 / 请求 | 前端确认条件 |
| --- | --- | --- |
| 账号删除 | `account_deletion: true`；`DELETE /api/account`，Bearer 会话，`Idempotency-Key`，JSON `{"confirmation":"delete_account"}` | HTTP 成功且 JSON `{"status":"deleted","user_id":"当前账号 ID"}`；才清理该账号本机数据、退出会话。`pending`、空响应、其他账号 ID 不算完成。服务端必须完成关联数据删除和登录凭证撤销。 |
| AI 内容举报 | `content_reporting: true`；`POST /api/content-reports`，Bearer、幂等键；字段 `content_type`（`chat` 或 `western_report`）、`content_id`、`reason`、`details`、`locale` | HTTP 成功且 `{"status":"received","report_id":"真实回执"}` 才显示成功。服务端校验内容归属、持久化并对接审核处理。前端不附带完整聊天或资料。 |
| Google Play | `google_play_billing: true`（同时需要 `western_reports`）；沿用 `POST /api/orders`，`store: google_play`，仍由服务端返回商品 ID、订单 ID、UUID `app_account_ref` | 原 `POST /api/orders/{id}/verify` 接收 `store: google_play`、`product_id`、`purchase_token`。只有服务端返回 `state: paid` 才 acknowledge，服务端须向 Google 校验应用、商品、交易、归属并下发报告权益。不能信任客户端字段本身。 |

举报 `reason`：`harmful`、`sexual`、`hate`、`privacy`、`misleading`、`other`。说明上限 1000 字符。账号删除与举报操作不重定向到邮件来冒充完成。

商店商品当前沿用原非消耗型报告商品模式。若业务定义为每份报告重复付费，需要后端订单与商品设计一并确认，不能只修改客户端消费交易。原购买恢复依赖当前账号报告库与本机待核验订单；跨设备恢复、退款同步仍需服务端及原生沙盒验收。

### 本轮验收与交付边界

定向覆盖：拒绝/允许 AI 授权后发送、撤回、接收方变更、举报失败和回执、账号删除失败保留与按账号清理、320×640 举报表单，以及 Apple / Google 的账号绑定和核验后确认交易。所有请求使用隔离替身；没有使用真实交易。

正式上架仍需要：生产陪聊开放与验收、上述服务端合同、Android 正式登录、公开政策和支持地址、商店账号/商品/签名、Android SDK 构建和 iOS Xcode 真机验收。当前交付是可预览的前端实现，不是已通过商店审核的安装包。

本轮最终结果：App `analyze` 无问题，release/Wasm 预览构建通过；四个定向测试文件共 13 个不同用例均已通过，修正后仅复测受影响用例。举报草稿修改后会使用新幂等键，原内容重试沿用原键。四语言消息键无缺项，新 Android XML 解析和修改差异空白检查通过。中文隐私/删除/购买状态及泰语帮助折叠交互已在实际预览检查。没有进行原生沙盒交易或真机验收。

本轮修改前备份：`D:/Backups/FATE-app-release-front-20261115-105006`。最终本地预览继续由根目录统一服务提供，地址 `http://127.0.0.1:5196/#/more`。

## 完整占星日历（2026-11-15）

首页上方原「今日泰历」及工具页增加「查看月历」，进入现有路由下的 `/fortune/calendar`；原星盘入口、每日运势和首页顺序保留。月历含佛历/公历、前后月份、回到今天、选中日期及五类图例。下方依次展示日期/小历、四种 Kalayok 日类、月相/枕席日、白昼乌巴空吉时、27 宿详情；点选、换月和内容联动使用现有动效时长，并遵循系统减少动画设置。

现有后端只提供今日接口。本页读取 App 自带的 `assets/calendar/2025.json` 至 `2030.json`，按年加载和缓存，原首页今日卡仍使用现有接口及曼谷午夜刷新逻辑。资源由 `node TH/app/tool/build_calendar.mjs` 直接复用 `TH/scripts/thai-engine.mjs` 的既有日历计算及固定版本 `thai-astrology 0.3.2` 生成；没有新增后端接口，也没有复制一套日历计算引擎。生成范围与 `ThaiCalendarRepository.firstDate/lastDate` 必须同步更新。失败可重试，超出数据范围不能继续翻月。

`source.json` 记录引擎版本、参考时刻和资料来源。日类沿用现有小历公式；若吉凶并存则同时显示。佛日依据泰历初八、十五及小月最后一个亏月日；枕席日采用盈月 7/10/13、亏月 4/8/10/14 的传统规则，不代表综合婚嫁吉日；27 宿取曼谷正午快照，不冒充全天不变。乌巴空只展示现有白昼时段，不外推夜间时辰。

截图日期 2026-11-09 的引擎结果为：佛历 2569、小历 1388、亏月十四/月十一、佛日、枕席日、第 16 宿第二足，吉时 08:24–10:48 与 15:36–18:00；日类同时有胜旗和灾厄。泰国参考资料：[枕席日规则](https://myhora.com/calendar/thai-05-2414-R09.aspx)、[乌巴空时段](https://www.maneedee.com/yam-ubakong/)。

本次修改前备份：`D:/Backups/FATE-app-calendar-20261115-212240`。仅修改 App 前端、资源和文档；支付、服务端数据和 H5 源码未改动。

验收结果：`analyze` 无问题，最终 release/Wasm 构建通过；日历 4 个不同用例与既有首页导航回归 1 个用例通过，修正后只复测受影响项。覆盖参考日期、曼谷跨日、闰日、月底切换、年份边界、加载失败重试、320 宽度泰文放大文字及减少动画。旧导航用例的购买按钮定位同步为现有 `storeBuy` 文案，购买行为未修改。390×844 实际预览已检查泰文/中文月历、换月、回到今天、五卡联动及首页入口；泰文日期使用佛历且保留实际星期，浏览器未记录错误。预览：`http://127.0.0.1:5196/#/fortune/calendar`。本地前端验证不等于原生签名包、线上服务或商店审核已完成。
