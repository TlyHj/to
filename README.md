# to

一个 Linux 下快速跳转目录的小工具：结合“最近访问缓存”与 `plocate` / `fd` / `find` 搜索，支持交互选择（优先用 `fzf`），在常见 Shell 中提供统一的 `to` 目录跳转体验。

- 支持的 Shell：Zsh、Bash、Fish
- 核心可执行文件：`to`（只输出选中目录路径），由 shell 包装函数执行 `cd`
- 安装入口：统一使用 `install.sh`
- 卸载入口：统一使用 `uninstall.sh`

## 这次重构解决了什么

之前安装方式对不同终端不够统一：
- Bash / Zsh / Fish 的接入方式分散
- 用户需要理解不同 shell 的配置文件差异
- 安装脚本职责太多、路径也不够统一

现在改成：
- **统一入口：安装跑 `install.sh`，卸载跑 `uninstall.sh`**
- **默认自动识别当前 shell** 并完成接入
- 也支持一次接入多个 shell
- 支持仅打印初始化片段，方便手动安装或二次集成
- 包装函数与安装器解耦，后续维护更直接

## 特性
- 最近目录缓存（`~/.to_recent_dirs`），命中优先
- 多后端搜索：`plocate` / `fd (fdfind)` / `find`，自动兜底
- 搜索默认优先用户常用目录，避免直接粗暴扫整个 `/`
- 默认排除 `/proc`、`/sys`、`/dev`、`/run`、`/tmp` 等无意义目录
- 命中结果会按 basename 精确度、是否位于用户目录、路径长度做排序
- 交互筛选：安装 `fzf` 时提供模糊筛选界面
- 路径安全：正确处理空格/特殊字符
- 多 Shell 支持：Zsh、Bash、Fish
- 内置缓存管理：支持列出 / 清空 / 删除缓存项
- 直接路径跳转：`to ../project`、`to ~/code/demo`
- 包装函数支持 `TO_BIN` 覆盖核心可执行文件路径
- 安装 / 卸载支持多 shell 统一管理

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

## 卸载

### 1）默认卸载

```bash
./uninstall.sh
```

行为：
- 删除核心可执行文件
- 删除 Bash / Zsh / Fish 的接入包装文件
- 清理对应 shell 配置中的接入行
- 默认保留缓存文件 `~/.to_recent_dirs`

### 2）卸载指定安装前缀

```bash
./uninstall.sh --prefix "$HOME/.local"
```

### 3）只卸载部分 shell 接入

```bash
./uninstall.sh --shell bash
./uninstall.sh --shell zsh,fish
```

### 4）连缓存一起删掉

```bash
./uninstall.sh --remove-cache
```

## 命令行参数

### install.sh

```bash
./install.sh --prefix <PATH>
./install.sh --shell <auto|bash|zsh|fish|all>
./install.sh --skip-deps
./install.sh --skip-updatedb
./install.sh --print-init <bash|zsh|fish>
```

### uninstall.sh

```bash
./uninstall.sh --prefix <PATH>
./uninstall.sh --shell <bash|zsh|fish|all>
./uninstall.sh --remove-cache
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
export TO_SEARCH_MAX_DEPTH=6
export TO_SEARCH_ROOTS="$HOME /opt /srv /usr/local /var/www"
export TO_SEARCH_EXCLUDES="/proc /sys /dev /run /tmp /mnt /media /var/tmp /snap"
```

## 工作方式
- 若参数本身就是已存在目录：直接输出该目录绝对路径并写入缓存
- 否则先查最近缓存，再查系统搜索结果
- 系统搜索优先走 `plocate`
- 若没有合适结果，再走 `fd` / `fdfind` / `find`
- `fd/find` 默认只扫常用根目录，不直接粗扫整个根文件系统
- 命中结果会优先考虑：
  - basename 精确命中
  - basename 前缀命中
  - 用户目录下的结果
  - 更短、更浅的路径
- 命中 1 个结果时直接输出
- 命中多个结果时：
  - 有 `fzf`：进入模糊选择
  - 无 `fzf`：进入数字菜单

## 为什么需要 shell 包装

`cd` 是 shell 内建命令，外部可执行文件不能直接修改你当前终端的工作目录。
所以这里拆成两层：

1. 核心程序 `to`
   - 只负责找目录
   - 只向标准输出打印最终目录路径
2. shell 包装函数
   - 调用核心程序
   - 读取输出结果
   - 在当前 shell 里执行 `cd`

这也是为什么安装时除了放置可执行文件，还需要把包装函数接入 Bash / Zsh / Fish。

## 安装后接入位置
- Bash：`~/.bashrc`
- Zsh：`~/.zshrc`
- Fish：`~/.config/fish/functions/to.fish`

包装文件位置：
- `~/.to-cd/to.bash`
- `~/.to-cd/to.zsh`
- `~/.config/fish/functions/to.fish`

## 常见场景

### 安装到用户目录并手动接入

```bash
./install.sh --prefix "$HOME/.local" --skip-deps
./install.sh --print-init zsh
```

然后把输出的初始化片段写入你自己的 shell 配置。

### 只想给 Bash 和 Zsh 接入

```bash
./install.sh --shell bash,zsh
```

### 自定义搜索范围

```bash
export TO_SEARCH_ROOTS="$HOME ~/work /srv/projects"
export TO_SEARCH_MAX_DEPTH=5
```

### 重装

```bash
./uninstall.sh
./install.sh
```

## 故障排查

查看当前 `to` 是否已生效：

```bash
type -a to
```

查看安装脚本帮助：

```bash
./install.sh --help
./uninstall.sh --help
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
