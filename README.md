# to

一个 Linux 下快速跳转目录的小工具：结合“最近访问缓存”与 `plocate` / `fd` / `find` 搜索，支持交互选择（优先用 `fzf`），在常见 Shell 中提供 `to` / `到` 风格的目录切换能力。

- 支持的 Shell：Zsh、Bash、Fish
- 核心可执行文件：`to`（只输出选中目录路径），由包装函数执行 `cd`

## 特性
- 最近目录缓存（`~/.to_recent_dirs`），命中优先
- 多后端搜索：`plocate` / `fd (fdfind)` / `find`，自动兜底
- 交互筛选：安装 `fzf` 时提供模糊筛选界面
- 路径安全：正确处理空格/特殊字符
- 多 Shell 支持：Zsh、Bash、Fish
- 内置缓存管理：支持列出 / 清空 / 删除缓存项
- 直接路径跳转：`to ../project`、`to ~/code/demo` 可直接进入
- 包装函数支持 `TO_BIN` 覆盖核心可执行文件路径，不再写死 `/usr/local/bin/to`

## 依赖
- 必需：任一 Shell（Zsh/Bash/Fish）；核心 `to` 无其他硬性依赖
- 可选（推荐）：
  - `plocate`（极速，需定期 `updatedb`）
  - `fd` 或 `fdfind`
  - `fzf`

## 安装
### 一键安装（推荐）
在仓库根目录执行：

```bash
# 系统安装（安装到 /usr/local/bin，需要 sudo）
sudo ./install.sh

# 仅为当前用户安装（确保 ~/.local/bin 在 PATH 中）
PREFIX="$HOME/.local" ./install.sh
```

高级选项：

```bash
SKIP_DEPS=1 ./install.sh
SKIP_UPDATEDB=1 ./install.sh
PREFIX="$HOME/.local" ./install.sh
```

安装脚本会：
- 安装核心 `to` 到 `$PREFIX/bin/to`
- 安装并接入各 Shell 包装
- 默认尝试安装 `fzf` 与搜索后端
- 若系统存在 `updatedb`，默认执行一次

## 使用

```bash
to proj
to ../my-project
to ~/code/demo
```

### 缓存管理

```bash
to -l              # 列出缓存
to -c              # 清空缓存
to -r ~/code/demo  # 从缓存移除指定目录
```

### 环境变量

```bash
export TO_MAX_CACHE=50                 # 修改缓存保留数量
export TO_BIN="$HOME/.local/bin/to"  # 指定包装函数调用的核心程序路径
```

## 工作方式
- 若参数本身就是已存在目录：直接输出该目录绝对路径并写入缓存
- 否则先查最近缓存，再查 `plocate` / `fd` / `find`
- 命中 1 个结果时直接输出
- 命中多个结果时：
  - 有 `fzf`：进入模糊选择
  - 无 `fzf`：进入数字菜单

## 配置与文件
- 缓存文件：`~/.to_recent_dirs`
- 可执行文件：`/usr/local/bin/to`（或 `$PREFIX/bin/to`）
- Shell 包装：
  - `~/.to-cd/to.zsh`
  - `~/.to-cd/to.bash`
  - `~/.config/fish/functions/to.fish`

## 故障排查
- 查看包装函数是否生效：

```bash
type -a to
```

- 单独测试核心脚本：

```bash
to --help
/usr/local/bin/to keyword
```

- `plocate` 找不到新目录：

```bash
sudo updatedb
```

## 许可证
- MIT
