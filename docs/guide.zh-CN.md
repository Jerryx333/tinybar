# 使用指南

[返回 README](../README.md) | [English guide](guide.md)

## 安装和使用

需要 macOS 13 或更新版本、Apple Command Line Tools。当前只在 Apple Silicon / macOS 26.4 做过实机验证；Intel 可编译，运行行为待验证。

```bash
bash scripts/check.sh
bash scripts/build.sh
bash scripts/install.sh
open "$HOME/Applications/TinyBar.app"
```

构建只使用系统框架，不安装软件或下载依赖。默认生成本机架构，设置 `TINYBAR_ARCH=arm64` 或 `TINYBAR_ARCH=x86_64` 可交叉编译。应用采用本地 ad hoc 签名，没有 Developer ID 或公证；不要把这个本地构建当作已签名分发包。下载别人构建的版本可能被 Gatekeeper 拦截。

安装到 `~/Applications/TinyBar.app`。更新前先退出 TinyBar；安装脚本会在 `~/Library/Application Support/TinyBar/Backups` 保留旧应用。重复安装相同构建不产生新备份。

1. 先退出 Ice、Bartender 等其他菜单栏管理器。
2. 点击 TinyBar 箭头展开，按住 ⌘ 拖动菜单栏图标。
3. 把不常用的图标放在 `│` 左侧，常用图标放在右侧。TinyBar 箭头也必须在分隔线右侧。
4. 左键点击箭头展开/收起；右键或 Control+点击打开菜单。

系统保管排列位置。TinyBar 不会读取或复制 Ice 分组；初次使用需要重新安排自己的分隔线。第一次启动、重新启动、唤醒和显示器参数变化后保持展开，需要时再点收起。没有悬停展开或自动收起，避免抢走正在使用的图标菜单。

## 恢复和退出

入口找不到时，从 Finder 或 Spotlight 重新打开 TinyBar：它会展开并显示恢复窗口。点“找回入口”只重置 TinyBar 自己的箭头和分隔线位置；不会改其他应用的偏好设置。

右键选择“展开并退出 TinyBar”，或恢复窗口里的“退出”。若应用不响应，可在活动监视器结束 TinyBar；系统会移除它的菜单栏占位。受系统菜单栏空间限制，展开不保证每个图标都能容纳到当前屏幕。刘海或较长的应用菜单仍可能遮挡图标；本版不提供额外浮动图标栏。

要回到原来的管理器，先退出 TinyBar，再打开原应用。TinyBar 不卸载它，也不改变它的登录项和设置。

## 登录启动与卸载

登录启动默认关闭。在右键菜单手动开启，状态直接读取 macOS；“等待系统允许”时使用菜单里的系统设置入口批准，也可再次点击取消。不要从临时构建目录开启登录启动，先安装到 Applications。签名变化可能需要重新允许，升级前建议关闭再开启。

卸载时先关闭登录启动，再退出并把 `~/Applications/TinyBar.app` 移到废纸篓。保留的偏好设置位于 `local.tinybar.app` 域，安装备份在上述 Backups 目录；可按需要保留，应用不会自动删除它们。

## 机制、权限和限制

使用两个原生 `NSStatusItem`。增大分隔线的宽度，让其左侧图标离开可见菜单栏，展开时恢复原宽度。`NSStatusItem` 是公开 API，但这种隐藏行为和首次定位所用的 `NSStatusItem Preferred Position` 键并没有 Apple 的兼容性承诺。收起前检查入口位置和顺序，收起后做一次延迟校验；无法安全隐藏时保持展开。

不请求辅助功能、屏幕录制、管理员权限。不截图、不联网、不保存应用清单。没有常驻扫描、全局鼠标监听、辅助进程或循环计时器。只在启动/点击时临时比较运行进程的 bundle ID，并响应应用启动/退出通知。

冲突检查只覆盖代码里的已知 ID，并不穷尽所有管理器。Ice ID 来自应用 bundle 验证；Bartender、Hidden Bar、Dozer 的候选 ID 未经本项目实机兼容性验证。请主动退出其他管理器。折叠时新启动应用的图标也可能落进隐藏组。

横向桌面跨度超过 4488 点时会拒绝收起，以免超宽占位受系统限制造成图标落到另一块屏幕。显示器插拔、主屏切换、自动隐藏菜单栏、全屏、真实睡眠唤醒等仍需扩大实机覆盖，详见[验证记录](validation.md)。

## 开发检查

```bash
bash scripts/verify.sh
# 在本机已登录的桌面运行；先退出 TinyBar 和其他管理器
bash scripts/verify.sh --integration
bash scripts/recovery.sh
# 对正在运行的 TinyBar 外部采样，关闭说明窗口后保持空闲
bash scripts/benchmark.sh 300 reports/idle.json
```

集成测试用独立 bundle/defaults 域创建测试图标，直接调用生产逻辑；并不模拟 Command 拖动或证明所有显示器配置兼容。测试中的截图/报告均不进入 Git。资源采样器校验 CPU 时间单位，按进程启动时间防止 PID 重用误测，输出物理内存占用、RSS、CPU 和 package idle wakeups。采样程序不打包进 TinyBar。
