# TinyBar

[中文](README.md) | [English](README.en.md)

把不常用的 macOS 菜单栏图标收起来，点一下再展开。原生小工具，不额外安装运行环境。

## 装上之后

- 一个箭头切换展开/收起；按住 ⌘ 拖动图标，分隔线左侧隐藏、右侧常显。
- 入口找不到时重新打开 TinyBar，就能展开并找回入口；退出时释放隐藏占位。
- 不截图、不联网，不申请辅助功能或屏幕录制权限。没有后台扫描和循环计时器。
- 登录启动默认关闭，手动选择。

## 当前状态与限制

**0.1 原生实验版，可从源码构建和本地安装。** 已完成真实菜单栏图标的重复收起/展开测试；尚不是经过完整兼容性验证的 Ice 替代品。

应用仅用 Swift/AppKit 和系统框架。体积及 CPU、内存实测见[验证记录](docs/validation.md)，测量脚本随源码提供。系统菜单栏仍有空间限制，刘海或应用菜单过长时，展开也不能让所有图标都挤进来；本版没有额外浮动图标栏。

收起机制依赖 macOS 未承诺兼容性的布局行为。启动、唤醒、换屏后优先展开；无法安全收起时保持可见。不要同时运行 Ice、Bartender 等管理器。它们的分组不会自动导入。

## 开始使用

需要 macOS 13+ 和 Apple Command Line Tools。实机验证目前限于 Apple Silicon / macOS 26.4；Intel、其他系统版本和更多显示器场景仍待验证。界面目前为中文。

```bash
git clone https://github.com/Jerryx333/tinybar.git
cd tinybar
bash scripts/build.sh
bash scripts/install.sh
open "$HOME/Applications/TinyBar.app"
```

退出其他管理器后，按住 ⌘ 把不常用图标移到 `│` 左侧，将 TinyBar 箭头留在右侧。点击箭头切换，右键打开设置和退出。

这是本地 ad hoc 签名构建，没有公证。更新、登录启动、恢复和卸载说明见[使用指南](docs/guide.zh-CN.md)。安装脚本保留旧应用备份，不改变其他软件设置。

## 开发与参与

```bash
bash scripts/check.sh
bash scripts/verify.sh
```

[产品范围](docs/scope.md) · [后续验证计划](docs/roadmap.md) · [贡献说明](CONTRIBUTING.md)。反馈时提供系统版本、芯片、屏幕布局和复现步骤，避免提交私人应用清单或完整屏幕截图。

独立实现，不包含 Ice 代码。姊妹项目：[TinyStat](https://github.com/Jerryx333/tinystat)，轻量 CPU/GPU/内存与温度监控。

许可证：[Apache-2.0](LICENSE)，Copyright 2026 Jerry。
