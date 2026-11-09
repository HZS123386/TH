# ASTRO AI / TH

本仓库保存本地项目的前端、后端、测试和运行素材。两个应用沿用相邻目录结构，后端可以直接定位落地页的构建目录。

| 目录 | 内容 |
| --- | --- |
| `western-astrology-h5 4/` | React 18 + TypeScript + Tailwind CSS 的移动落地页、免费试读、完整报告和 PDF 导出 |
| `TH/` | FastAPI 后端、泰式排盘、报告生成与持久化，以及原有 TH 前端 |

## 已包含的报告流程

- 点击生成时，只生成免费报告，播放动画并显示摘要与三个特点的内容进度；校验保存后达到 100%，打开独立报告页。
- 点击解锁后才生成完整内容，使用另一段 0–100% 进度；主题正文、示例、提醒与行动步骤的生成量会计入进度。
- 当前 ¥300 为内容体验标价，点击直接解锁，无实际收款流程。
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

启动后端和原 TH 前端：

```powershell
pnpm dev
```

另开终端，在仓库根目录启动落地页开发服务：

```powershell
cd "western-astrology-h5 4"
pnpm dev
```

- 落地页开发入口：<http://127.0.0.1:8765/?lang=zh>
- 已构建落地页：<http://127.0.0.1:8000/thai-landing/?lang=zh>
- 原 TH 前端：<http://127.0.0.1:5173/>

`western-astrology-h5 4/dist/` 是页面生效源文件与运行素材，构建产物输出到 `site/`。该 `dist/` 目录需要保留在版本库中。后端可以使用 `THAI_LANDING_DIR` 指定其他构建目录。

## 检查

```powershell
cd "western-astrology-h5 4"
pnpm test
pnpm build
pnpm test:e2e
cd ../TH
pnpm test:api
```

更多接口和模型配置说明见 [TH 项目说明](TH/README.md) 与 [落地页说明](western-astrology-h5%204/README.md)。

## 本地配置和数据

仓库提供空白的 `.env.example`。实际密钥、依赖目录、用户数据库、生成的个人报告、测试截图和构建输出保留在本机。新环境按以上步骤安装依赖、配置模型并生成地点索引。

第三方依赖及素材授权说明保留在 `TH/public/licenses/`、`TH/backend/vendor/` 和落地页的字体目录中。
