# FATE 海外玄学

APP、落地页和共用后台统一位于本仓库。当前本机目录为 `D:/desktop/FATE`；脚本根据自身位置寻找项目，换电脑时可整体移动。原桌面项目的配置、数据库、依赖和构建均已迁入，旧工作区与备份保存在 `output/`。

在仓库根目录执行 `pnpm dev` 或 `node TH/scripts/dev.mjs`，会构建并启动 H5、App 网页预览和共用后端。构建完成后再次启动可用 `pnpm dev:ready`。配置统一读取 `TH/.env`；本机 Flutter SDK 路径由其中的 `FATE_FLUTTER_BIN` 指定。退出启动终端时按 Ctrl+C 可停止这三个服务。

| 目录 | 内容 |
| --- | --- |
| `western-astrology-h5 4/web-client/` | 实际运行的 Flutter H5，包含资料表单、免费试读、收银台、完整报告和导出 |
| `TH/app/` | Flutter App，包含首页、星盘、报告、账户和原生平台工程 |
| `TH/backend/app/` | 共用 FastAPI 后端、排盘、报告、支付确认和持久化 |
| `TH/data/` | 本机只读出生地索引及运行资源，保留在本机且不提交 Git |

## 已包含的报告流程

- 点击生成时，只生成免费报告，播放动画并显示摘要与三个特点的内容进度；校验保存后达到 100%，打开独立报告页。
- 当前尚德流程先用手机号创建订单，再打开官方收银台；后台查询并核对订单、金额、币种及到账状态后，才允许解锁并生成完整内容。
- H5 价格由当前支付配置和报告币种决定。按钮点击、收银台跳转或未经查单确认的通知都不能直接解锁。旧支付测试分支不参与当前尚德配置。
- 支持已配置的九种语言、中国／泰国出生地点联动、未知出生时间估算、历史报告、网页保存与 PDF 导出。

## 本地启动

需要 Node.js 22.21 或更新版本、pnpm、Python 3.12 或更新版本、Flutter SDK 和 PostgreSQL 16。以下安装命令在首次准备环境时执行，日常启动使用上面的统一命令。

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

在 `TH/.env` 中设置 `DATABASE_URL` 指向已迁移的 PostgreSQL 业务库。通过 Docker 启动数据库时可配置 `FATE_POSTGRES_CONTAINER`，统一启动命令会等待这个数据库实例就绪。

首次初始化已确认的 PostgreSQL 目标库，在 `TH/` 中执行 `node scripts/python.mjs -m alembic -c backend/alembic.ini upgrade head`。现有业务迁移须先备份和核对数据，再切换连接。后端启动时会检查数据库迁移版本。

回到仓库根目录启动所有服务：

```powershell
cd ..
node TH/scripts/dev.mjs
```

- 落地页开发入口：<http://127.0.0.1:8765/?lang=zh>
- 已构建落地页：<http://127.0.0.1:8000/thai-landing/?lang=zh>
- App 网页预览：<http://127.0.0.1:5176/>
- 共用后端健康检查：<http://127.0.0.1:8000/health>
- H5 运营后台：<http://127.0.0.1:8000/admin/>，页面、接口、测试和资料统一在 `TH/h5_admin/`，配置与数据口径见 [后台说明](TH/h5_admin/README.md)。

H5 的真实入口是 `western-astrology-h5 4/web-client/lib/main.dart`，构建输出为 `western-astrology-h5 4/site/`。`dist/` 保留原有素材；修改页面请沿用 `web-client/` 的实际调用链。后端默认定位本仓库内的 `site/`，无需引用旧目录。

## 固定部署输出

配置目标库的 `FATE_DEPLOY_DATABASE_URL` 后，执行 `pnpm deploy:prepare` 构建落地页并准备服务器发布包。该命令仅在本地打包，不上传、不重启服务器。打包结果固定为 `output/deploy/latest/application.tar.gz`，版本号记录在 `manifest.json`，`runtime.env` 单独存放且不进入压缩包。再次打包轮换到 `previous/`，不在桌面复制新项目。

首次打包及轮换安全检查：`pnpm test:deployment`。服务器仍使用现有版本目录与共享数据完成回滚，操作见 `western-astrology-h5 4/deploy/README.md`。

迁移记录在 `output/organization/`。旧桌面路径若仍有迁移提示，是旧 Codex 会话占用的目录；后续应将 Codex 项目目录选择为本仓库。关闭旧会话／终端后，在本仓库执行 `pnpm cleanup:legacy` 可删除仅剩迁移提示的旧目录；命令不会递归删除，也不会删除含其他文件的目录。

## 检查

```powershell
cd "western-astrology-h5 4"
pnpm test
pnpm build
cd ../TH
pnpm test:api
pnpm test:app
```

后端测试通过 `FATE_TEST_DATABASE_URL` 使用单独的 `fate_test` PostgreSQL 库，在每个用例独立建表。此电脑的测试配置在忽略提交的 `TH/data/.postgres-test.env`。

更多接口和模型配置说明见 [TH 项目说明](TH/README.md) 与 [落地页说明](western-astrology-h5%204/README.md)。

## 本地配置和数据

仓库提供空白的 `.env.example`。实际密钥、依赖目录、用户数据库、生成的个人报告、测试截图和构建输出保留在本机。新环境按以上步骤安装依赖、配置模型并生成地点索引。

第三方依赖及素材授权说明保留在 `TH/public/licenses/`、`TH/backend/vendor/` 和落地页的字体目录中。

## 迁移备份

2026-11-16 PostgreSQL 迁移的源码与数据库备份位于 `D:/Backups/FATE-postgresql-20261116-105559`。源库是原启动配置指定的 `sunlands-order-only-20261112.db`，迁移涵盖 32 张表、232 条记录。旧原型与历史数据库的副本保留作恢复资料。

一次性导入使用 `TH/scripts/migrate-sqlite-to-postgres.py --source <SQLite备份>`，要求目标已应用上述迁移且未写入业务数据。加 `--verify-only` 可只读逐行比对，适用于切换前对账。切换后如果已产生新数据，应先备份最新 PostgreSQL 数据及核对新增业务记录，再决定回退；直接恢复旧 SQLite 文件会丢掉后续写入。

迁移前的两份源码快照、三份 SQLite 数据库和校验清单位于 `D:\Backups\FATE-unification-20261113`。旧独立原型的完整目录归档位于 `C:\Users\32668\Desktop\git\backups\FATE-unification-20261113\original-prototype`。备份只用于核查和恢复，后续开发统一在本目录进行。

本次迁移、完整流程检查和未验收事项见 [代码统一及流程测试报告](outputs/海外玄学代码统一及流程测试报告.docx)。
