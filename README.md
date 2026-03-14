# Oven_Release

## 脚本说明

### pull_app.sh
自动部署脚本，用于检查并拉取最新代码后运行烤箱应用程序。

### fix_vscode_input.sh
修复 VSCode 无法使用搜狗输入法（fcitx/fcitx5）的问题。

**使用方法：**
```bash
bash fix_vscode_input.sh
```

**功能：**
- 检测并安装 fcitx / fcitx5 相关依赖
- 将 `GTK_IM_MODULE`、`QT_IM_MODULE`、`XMODIFIERS` 等输入法环境变量写入 `~/.xprofile` 和 `~/.profile`
- 自动修改 VSCode 桌面启动项（`code.desktop`），在启动时注入输入法环境变量
- 在 `~/.local/bin/code-im` 创建带输入法支持的 VSCode 启动包装脚本

**修复后使用：**
1. 重新登录系统（或重启）。
2. 启动搜狗输入法。
3. 从桌面启动器或在终端运行 `code-im` 打开 VSCode，即可正常输入中文。