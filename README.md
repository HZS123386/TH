# FATE 统一工作区

APP、落地页和共用后台统一位于本仓库。当前本机目录为 `D:/desktop/FATE`；脚本根据自身位置寻找项目，换电脑时可整体移动。原桌面项目的配置、数据库、依赖和构建均已迁入，旧工作区与备份保存在 `output/`。

| 目录 | 内容 |
| --- | --- |
| `TH/app/` | Flutter APP，含星盘、报告、游客及账号流程和原生购买接入代码 |
| `TH/backend/` | 共用 FastAPI、Roxy 排盘、报告和数据服务 |
| `western-astrology-h5 4/web-client/` | Flutter Web 落地页、试读、报告和解锁页面 |
| `western-astrology-h5 4/deploy/` | 现有部署脚本和容器配置 |
| `output/deploy/latest/` | 固定的最新部署包；`previous/` 仅保留上一份 |
| `output/worktrees/`、`output/archive/` | 已归档的开发工作区和备份，不参与当前运行 |

## 从总目录启动

在本目录执行 `pnpm dev`，构建并启动共用后台、APP 和落地页。已有构建时执行 `pnpm dev:ready`，直接复用构建快速启动。

- APP：`http://127.0.0.1:5174/`
- 落地页：`http://127.0.0.1:8765/thai-landing/?lang=zh`
- 后台健康检查：`http://127.0.0.1:8000/health`

分别构建可使用 `pnpm build:app` 和 `pnpm build:h5`。Node 依赖仍在两个子项目中维护，分别在 `TH` 和 `western-astrology-h5 4` 执行 `pnpm install --frozen-lockfile`；Python 依赖在 `TH/.venv`。不要同时启动总目录和子目录的同一端口服务。

## 固定部署输出

执行 `pnpm deploy:prepare` 构建落地页并准备服务器发布包。该命令仅在本地打包，不上传、不重启服务器。打包结果固定为 `output/deploy/latest/application.tar.gz`，版本号记录在 `manifest.json`，`runtime.env` 单独存放且不进入压缩包。再次打包轮换到 `previous/`，不在桌面复制新项目。

首次打包及轮换安全检查：`pnpm test:deployment`。服务器仍使用现有版本目录与共享数据完成回滚，操作见 `western-astrology-h5 4/deploy/README.md`。

迁移记录在 `output/organization/`。旧桌面路径若仍有迁移提示，是旧 Codex 会话占用的目录；后续应将 Codex 项目目录选择为本仓库。关闭旧会话／终端后，在本仓库执行 `pnpm cleanup:legacy` 可删除仅剩迁移提示的旧目录；命令不会递归删除，也不会删除含其他文件的目录。

## 已包含的报告流程

- 点击生成时，只生成免费报告，播放动画并显示摘要与三个特点的内容进度；校验保存后达到 100%，打开独立报告页。
- 点击解锁后才生成完整内容，使用另一段 0–100% 进度；主题正文、示例、提醒与行动步骤的生成量会计入进度。
- 收银台演示价格为人生报告 ฿50、职业专题 ฿99。确认模拟付款后解锁，无实际收款。
- 支持中文／泰语、中国／泰国出生地点联动、未知出生时间估算、历史报告、网页保存与 PDF 导出。

## 本地启动

需要 Node.js、pnpm 和 Python 3.12 或更新版本。以下命令在仓库根目录开始执行。

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
Copy-Item .env.example .env
```

在 `TH/.env` 中填写本地使用的服务端模型配置。人生报告使用 `FORTUNE_PROVIDER` 选择提供商及相应的提供商配置；未配置时接口会说明生成服务不可用。地点索引命令会下载 GeoNames 的公开数据并在本机生成数据库。

在 `TH` 目录执行以下命令，也会一并启动 APP、后台及相邻落地页：

```powershell
pnpm dev
```

- 落地页开发入口：<http://127.0.0.1:8765/thai-landing/?lang=zh>
- 已构建落地页：<http://127.0.0.1:8000/thai-landing/?lang=zh>
- APP 预览：<http://127.0.0.1:5174/>

当前落地页源码在 `western-astrology-h5 4/web-client/lib/`，构建输出到 `site/`。`dist/` 中仍有构建所需的字体和文档素材，应保留。后端可以使用 `THAI_LANDING_DIR` 指定其他构建目录。

## 检查

```powershell
cd "western-astrology-h5 4"
pnpm test
pnpm build
pnpm check
cd ../TH
pnpm test:api
```

更多接口和模型配置说明见 [TH 项目说明](TH/README.md) 与 [落地页说明](western-astrology-h5%204/README.md)。

## 本地配置和数据

仓库提供空白的 `TH/.env.example`。实际密钥、依赖目录、用户数据库、生成的个人报告、测试截图和构建输出保留在本机。新环境按以上步骤安装依赖、配置模型并生成地点索引。

第三方依赖及素材授权说明保留在 `TH/public/licenses/`、`TH/backend/vendor/` 和落地页的字体目录中。
