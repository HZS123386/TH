# FATE 海外玄学

本项目的唯一开发和启动目录是 `C:\Users\32668\Desktop\海外-玄学`。2026-11-13 已迁入合并远端更新后的 H5、App、共用后端、支付数据和 Git 历史，基准提交为 `e3a262e`。原 `TH-H` 目录仅保留迁移说明，旧独立原型保存在备份目录。

在本目录执行 `node TH/scripts/dev.mjs`，会构建并启动 H5、App 网页预览和共用后端。构建完成后再次启动可用 `node TH/scripts/dev.mjs --skip-build`。配置统一读取 `TH/.env`；本机 Flutter SDK 路径由其中的 `FATE_FLUTTER_BIN` 指定。退出启动终端时按 Ctrl+C 可停止这三个服务。

| 目录 | 内容 |
| --- | --- |
| `western-astrology-h5 4/web-client/` | 实际运行的 Flutter H5，包含资料表单、免费试读、收银台、完整报告和导出 |
| `TH/app/` | Flutter App，包含首页、星盘、报告、账户和原生平台工程 |
| `TH/backend/app/` | 共用 FastAPI 后端、排盘、报告、支付确认和持久化 |
| `TH/data/` | 本地数据库与出生地索引，保留在本机且不提交 Git |

## 已包含的报告流程

- 点击生成时，只生成免费报告，播放动画并显示摘要与三个特点的内容进度；校验保存后达到 100%，打开独立报告页。
- 当前尚德流程先用手机号创建订单，再打开官方收银台；后台查询并核对订单、金额、币种及到账状态后，才允许解锁并生成完整内容。
- 当前 H5 商品价格为 ฿30。按钮点击、收银台跳转或未经查单确认的通知都不能直接解锁。旧支付测试分支不参与当前尚德配置。
- 支持中文／泰语、中国／泰国出生地点联动、未知出生时间估算、历史报告、网页保存与 PDF 导出。

## 本地启动

需要 Node.js 22.21 或更新版本、pnpm、Python 3.12 或更新版本及 Flutter SDK。以下安装命令在首次准备环境时执行，日常启动使用上面的统一命令。

先构建落地页：

```powershell
cd "western-astrology-h5 4"
pnpm install
pnpm build
cd ../TH
```

配置后端依赖与地点索引：

```powershell
pnpm install
python -m venv .venv
pnpm setup:api
pnpm setup:locations
if (!(Test-Path .env)) { Copy-Item .env.example .env }
```

在 `TH/.env` 中填写本地使用的服务端模型配置。人生报告使用 `FORTUNE_PROVIDER` 选择提供商及相应的提供商配置；未配置时接口会说明生成服务不可用。地点索引命令会下载 GeoNames 的公开数据并在本机生成数据库。

在 `TH/.env` 中保留正在使用的 `DATABASE_PATH`。本机已设为 `data/sunlands-order-only-20261112.db`，其中含当前订单、到账记录和解锁状态；不要随意切换为新空库。

回到仓库根目录启动所有服务：

```powershell
cd ..
node TH/scripts/dev.mjs
```

- 落地页开发入口：<http://127.0.0.1:8765/?lang=zh>
- 已构建落地页：<http://127.0.0.1:8000/thai-landing/?lang=zh>
- App 网页预览：<http://127.0.0.1:5176/>
- 共用后端健康检查：<http://127.0.0.1:8000/health>

H5 的真实入口是 `western-astrology-h5 4/web-client/lib/main.dart`，构建输出为 `western-astrology-h5 4/site/`。`dist/` 保留原有素材；修改页面请沿用 `web-client/` 的实际调用链。后端默认定位本仓库内的 `site/`，无需引用旧目录。

## 检查

```powershell
cd "western-astrology-h5 4"
pnpm test
pnpm build
cd ../TH
pnpm test:api
pnpm test:app
```

更多接口和模型配置说明见 [TH 项目说明](TH/README.md) 与 [落地页说明](western-astrology-h5%204/README.md)。

## 本地配置和数据

仓库提供空白的 `.env.example`。实际密钥、依赖目录、用户数据库、生成的个人报告、测试截图和构建输出保留在本机。新环境按以上步骤安装依赖、配置模型并生成地点索引。

第三方依赖及素材授权说明保留在 `TH/public/licenses/`、`TH/backend/vendor/` 和落地页的字体目录中。

## 迁移备份

迁移前的两份源码快照、三份 SQLite 数据库和校验清单位于 `D:\Backups\FATE-unification-20261113`。旧独立原型的完整目录归档位于 `C:\Users\32668\Desktop\git\backups\FATE-unification-20261113\original-prototype`。备份只用于核查和恢复，后续开发统一在本目录进行。

本次迁移、完整流程检查和未验收事项见 [代码统一及流程测试报告](outputs/海外玄学代码统一及流程测试报告.docx)。
