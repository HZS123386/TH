# TL 分支约定

- `TL` 独立维护米拉塔罗 H5。前端源码、静态素材和项目文档位于 `FATE_spread/`。共用 API 的塔罗模块与测试位于 `TH/backend/app/tarot_readings.py` 和 `TH/backend/tests/test_tarot_readings.py`。
- 页面入口为 `FATE_spread/dist/index.html`。HTML、CSS、JavaScript 和素材直接在 `FATE_spread/dist/` 维护。完整预览使用共用仓库的 `node TH/scripts/dev.mjs --tarot`。
- 后续塔罗改动从 `TL` 工作区开始。用 `git add -- <本次涉及的塔罗文件>` 暂存所需文件，提交前用 `git diff --cached --name-status` 核对路径。
- 推送前运行 `git fetch origin TL` 和 `git log -m --name-status origin/TL..TL`。确认每个待推提交只涉及塔罗项目或 TL 分支维护文件，再运行 `git push origin TL:TL`。
- 环境配置、账号密钥、数据库、日志与部署归档保留在本地。

- 塔罗模块部署到共用 FastAPI 应用。共用入口通过 `tarot_router(TarotReadings(store, settings, model_slots))` 注册，沿用 Roxy 客户端的 `method="GET"` 支持和现有报告模型。分支只跟踪塔罗专用的后端文件。
