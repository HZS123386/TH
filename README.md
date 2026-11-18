# FATE 统一工作区

`main` 包含 Flutter APP、Flutter Web 落地页和共用 FastAPI 后台。可以将仓库拉取到任意工作目录，构建和启动脚本按相对路径定位子项目。现有站点的应用与网关版本记录见[部署说明](western-astrology-h5%204/deploy/README.md)。

## 目录与当前行为

| 目录 | 内容 |
| --- | --- |
| `TH/app/` | Flutter APP、星盘、报告和账号流程 |
| `western-astrology-h5 4/web-client/` | Flutter Web 落地页、出生资料、免费试读、报告和支付入口 |
| `western-astrology-h5 4/src/` | 多语言文案及 HTML/PDF 文档工具 |
| `western-astrology-h5 4/deploy/` | 发布打包、容器、IP HTTPS 和域名网关配置 |
| `TH/backend/` | 共用 FastAPI、排盘、报告、支付核验及测试 |
| `TH/scripts/`、`TH/src/content/`、`TH/src/locales/`、`TH/src/data/` | 后端运行与构建所需脚本和公开业务资源 |

落地页默认泰语，支持泰语、英语、简体中文、越南语、缅甸语、高棉语、老挝语、马来语和印尼语。出生地点保留国家、省府、市区联动，用户可以选择预设问题或填写问题；报告页返回首页时保留已填写资料。

启用 Roxy 后，新免费报告包含感情里的卡点、星盘关键词、个人特点和近期机会。付款核验后生成六个完整主题；「感情姻缘」承接免费解读里的相处信号。历史报告可按已保存的正文和计算依据继续查看。

Sunlands 支付沿用手机号建单、官方收银台、服务端查单、订单与金额核对及报告解锁链路。金额和可用支付方式由服务端返回，点击按钮、跳转或返回页面均不代表支付成功。生产环境仅允许正式网关，开发环境的模拟支付及 Payso Demo 不用于线上收款。

## 本地准备与验证

需要 Node.js 22.21 或更新版本、pnpm、Python 3.12 或更新版本，以及 Flutter SDK。两个 Node 子项目分别安装锁定依赖；Flutter SDK 可通过 `FATE_FLUTTER_BIN` 指定。

```powershell
pnpm --dir TH install --frozen-lockfile
pnpm --dir "western-astrology-h5 4" install --frozen-lockfile
python -m venv TH/.venv
pnpm --dir TH setup:api
pnpm --dir TH setup:locations
if (!(Test-Path TH/.env)) { Copy-Item TH/.env.example TH/.env }
```

`TH/.env.example` 仅提供配置字段。实际提供商与商户凭据只写入私有环境文件；不要覆盖已有 `DATABASE_PATH` 或把本机用户数据库上传到服务器。

```powershell
pnpm build:h5
pnpm --dir "western-astrology-h5 4" test
pnpm --dir "western-astrology-h5 4" check
pnpm --dir TH test:api
pnpm test:deployment
```

H5 构建输出到 `western-astrology-h5 4/site/`，默认部署路径为 `/thai-landing/`。`dist/` 保留字体等构建输入，实际页面由 Flutter 实现。自动检查使用合成报告、隔离数据库和外部服务替身，不创建真实订单或调用付费生成服务。

## 发布与数据保留

执行 `pnpm deploy:prepare` 只在本地准备发布包，不上传或重启服务器。输出固定在 `output/deploy/latest/`，前一份在 `output/deploy/previous/`；`runtime.env` 单独保存，不进入应用压缩包或 Git。

换电脑时先拉取 `main`，按上面的步骤安装依赖、准备地点索引并填写该环境的私有配置。本机联调可以在仓库根目录执行 `pnpm dev`。如果目标服务器不安装 Flutter，也可以在开发机执行 `pnpm deploy:prepare`，把 `application.tar.gz` 和 `manifest.json` 交给服务器管理员，首次部署另准备地点索引 `TH/data/birth-locations.sqlite3`。

`127.0.0.1` 只用于访问当前机器的本地服务。目标服务器的访问地址由自己的 IP、DNS 和反向代理配置决定。仓库中的 Caddy 示例针对现有站点；新服务器应按自己的域名和 Docker 网络配置网关，将 `/thai-landing/` 和报告 API 转发到同一后台。需要在服务器单独配置模型及支付凭据。

服务器沿用 `/opt/astro-life-report/current`、共享配置和 `/opt/astro-life-report/shared/data/`。更新时保留线上模型配置、报告、订单和地点索引。域名配置仅增加落地页及其接口路由，保留原站首页、管理后台和 `/api/v1/`；原 IP 入口继续供历史访客使用。

完整操作及回退要求见[部署说明](western-astrology-h5%204/deploy/README.md)。报告内容结构见[落地页报告说明](TH/docs/LANDING_REPORT_OUTLINE_20261116.md)，支付来源及合并记录见[JY 支付链路说明](TH/docs/JY_MERGE_20261116.md)。原站网关部署回执及私有运行配置保留在服务器，不随源码提交。
