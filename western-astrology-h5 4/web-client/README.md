# FATE Flutter H5

本目录是泰式占星落地页与个人报告的 Flutter Web 源码。入口为 `lib/main.dart`，复用相邻 TH Python 后端。原 APP 的 Flutter 工程在 `../../TH/app`。

在上级项目目录执行 `pnpm dev`、`pnpm test`、`pnpm check` 和 `pnpm build`，以便准备共享翻译、主题目录、媒体和原 HTML/PDF 文档模块。默认发布路径为 `/thai-landing/`，构建输出到上级 `site/`。

完整迁移说明与实测记录见 `../docs/FLUTTER_H5_MIGRATION.md`。字体授权见 `assets/fonts/`。
