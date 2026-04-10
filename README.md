# to

一个 Linux 下快速跳转目录的小工具：结合“最近访问缓存”与 `plocate` / `fd` / `find` 搜索，支持交互选择（优先用 `fzf`），在常见 Shell 中提供统一的 `to` 目录跳转体验。

- 支持的 Shell：Zsh、Bash、Fish
- 核心可执行文件：`to`（只输出选中目录路径），由 shell 包装函数执行 `cd`
- 安装入口：统一使用 `install.sh`

## 这次重构解决了什么

之前安装方式对不同终端不够统一：
- Bash / Zsh / Fish 的接入方式分散
- 用户需要理解不同 shell 的配置文件差异
- 安装脚本职责太多、路径也不够统一

现在改成：
- **统一入口：只跑一个 `install.sh`**
- **默认自动识别当前 shell** 并完成接入
- 也支持一次接入多个 shell
- 支持仅打印初始化片段，方便手动安装或二次集成

## 特性
- 最近目录缓存（`~/.to_recent_dirs`），命中优先
- 多后端搜索：`plocate` / `fd (fdfind)` / `find`，自动兜底
- 交互筛选：安装 `fzf` 时提供模糊筛选界面
- 路径安全：正确处理空格/特殊字符
- 多 Shell 支持：Zsh、Bash、Fish
- 内置缓存管理：支持列出 / 清空 / 删除缓存项
- 直接路径跳转：`to ../project`、`to ~/code/demo`
- 包装函数支持 `TO_BIN` 覆盖核心可执行文件路径

## 依赖
- 必需：任一 Shell（Zsh/Bash/Fish）
- 可选（推荐）：
  - `plocate`
  - `fd` 或 `fdfind`
  - `fzf`

## 安装

### 1）默认安装（推荐）

直接执行：

```bash
sudo ./install.sh
```

行为：
- 安装核心程序到 `/usr/local/bin/to`
- 自动识别当前 shell
- 自动把对应 shell 的初始化接入写入配置文件
- 自动尝试安装依赖

### 2）安装到当前用户目录

```bash
./install.sh --prefix "$HOME/.local"
```

适合不想写入 `/usr/local/bin` 的情况。

### 3）一次接入多个 shell

```bash
./install.sh --shell bash,zsh
./install.sh --shell all
```

### 4）跳过依赖安装

```bash
./install.sh --skip-deps
./install.sh --skip-deps --skip-updatedb
```

### 5）只打印初始化片段，不执行安装

```bash
./install.sh --print-init bash
./install.sh --print-init zsh
./install.sh --print-init fish
```

适合：
- 手动集成
- dotfiles 管理
- 自定义安装流程

## 命令行参数

```bash
./install.sh --prefix <PATH>
./install.sh --shell <auto|bash|zsh|fish|all>
./install.sh --skip-deps
./install.sh --skip-updatedb
./install.sh --print-init <bash|zsh|fish>
```

## 使用

```bash
to proj
to ../my-project
to ~/code/demo
```

## 缓存管理

```bash
to -l
to -c
to -r ~/code/demo
```

## 环境变量

```bash
export TO_MAX_CACHE=50
export TO_BIN="$HOME/.local/bin/to"
```

## 工作方式
- 若参数本身就是已存在目录：直接输出该目录绝对路径并写入缓存
- 否则先查最近缓存，再查 `plocate` / `fd` / `find`
- 命中 1 个结果时直接输出
- 命中多个结果时：
  - 有 `fzf`：进入模糊选择
  - 无 `fzf`：进入数字菜单

## 安装后接入位置
- Bash：`~/.bashrc`
- Zsh：`~/.zshrc`
- Fish：`~/.config/fish/functions/to.fish`

包装文件位置：
- `~/.to-cd/to.bash`
- `~/.to-cd/to.zsh`
- `~/.config/fish/functions/to.fish`

## 故障排查

查看当前 `to` 是否已生效：

```bash
type -a to
```

查看安装脚本帮助：

```bash
./install.sh --help
```

单独测试核心脚本：

```bash
to --help
/usr/local/bin/to keyword
```

`plocate` 没更新时：

```bash
sudo updatedb
```

## 许可证
- MIT
