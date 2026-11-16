# FATE 项目目录约定

- APP 源码在 `TH/app`，落地页源码在 `western-astrology-h5 4/web-client`，共用后台在 `TH/backend`。
- 在当前总仓库内开发和提交；脚本通过自身位置定位相邻项目，不写死桌面绝对路径。
- 部署准备使用现有 `western-astrology-h5 4/deploy/prepare_release.py`。本地部署包固定为 `output/deploy/latest`，前一份为 `output/deploy/previous`。
- 如确实需要 Git 工作区，放入 `output/worktrees`；备份放入 `output/archive`。不要再在桌面创建带日期的项目副本。
- 环境密钥、数据库、构建产物和归档不提交 Git；源码目录中的 `lib/data` 是业务源码，不能被数据目录忽略规则排除。
- 迁移时保留的旧桌面路径仅有迁移提示，不是源码位置。
