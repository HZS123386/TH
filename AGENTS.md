# TL 分支约定

- `TL` 独立维护米拉塔罗 H5。塔罗源码、静态素材和项目文档位于 `FATE_spread/`。分支根目录用于维护本约定和 Git 忽略规则。
- 页面入口为 `FATE_spread/dist/index.html`。HTML、CSS、JavaScript 和素材直接在 `FATE_spread/dist/` 维护。本地预览可从分支根目录运行 `python -m http.server 8767 --bind 127.0.0.1 --directory FATE_spread/dist`。
- 后续塔罗改动从 `TL` 工作区开始。用 `git add -- FATE_spread/<文件>` 暂存所需文件，提交前用 `git diff --cached --name-status` 核对路径。
- 推送前运行 `git fetch origin TL` 和 `git log -m --name-status origin/TL..TL`。确认每个待推提交只涉及塔罗项目或 TL 分支维护文件，再运行 `git push origin TL:TL`。
- 环境配置、账号密钥、数据库、日志与部署归档保留在本地。
