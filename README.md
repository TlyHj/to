# to

一个快速跳转目录的小工具：结合“最近访问缓存”与 plocate/fd/find 搜索，支持交互选择（优先用 fzf），在常见 Shell 中提供 `到` 命令完成目录切换。

- 支持的 Shell：Zsh、Bash、Fish（通过各自的包装函数）
- 核心可执行文件：`到`（只输出选中目录路径），由包装函数执行 `cd`

## 特性
- 最近目录缓存（`~/.to_recent_dirs`），命中优先
- 多后端搜索：`plocate` / `fd (fdfind)` / `find`，自动兜底
- 交互筛选：安装 `fzf` 时提供模糊筛选界面（可在界面继续输入过滤）
- 路径安全：正确处理空格/特殊字符
- 多 Shell 支持：Zsh、Bash、Fish 都可用

## 依赖
- 必需：任一 Shell（Zsh/Bash/Fish）；核心 `到` 无其他硬性依赖
- 可选（推荐）：
  - `plocate`（极速，需定期 `updatedb`）
  - `fd` 或 `fdfind`（更快的文件查找）
  - `fzf`（更好用的交互选择）

提示：
- 使用 `plocate` 时，首次使用或新增大量目录后建议更新索引：
  ```bash
  sudo updatedb
  ```

## 安装
### 一键安装（推荐）
在仓库根目录执行：
```bash
# 系统安装（安装到 /usr/local/bin，需要 sudo）
sudo ./install.sh

# 或者仅为当前用户安装（确保 ~/.local/bin 在 PATH 中）
PREFIX="$HOME/.local" ./install.sh
```

高级选项：
```bash
SKIP_DEPS=1 ./install.sh        # 跳过自动安装 fzf 与搜索后端
SKIP_UPDATEDB=1 ./install.sh    # 安装依赖但跳过执行 updatedb
PREFIX="$HOME/.local" ./install.sh  # 安装到用户目录（无需 sudo）
```

安装脚本会：
- 安装核心 `to` 到 `$PREFIX/bin/to`（默认 `/usr/local/bin/to`）
- 安装并接入各 Shell 包装：
  - Zsh：将 `to.zsh` 安装到 `~/.to-cd/to.zsh` 并写入 `~/.zshrc` 的 `source` 行
  - Bash：将 `to.bash` 安装到 `~/.to-cd/to.bash` 并写入 `~/.bashrc` 的 `source` 行（并确保登录 shell 也加载）
  - Fish：将 `to.fish` 安装到 `~/.config/fish/functions/to.fish`
- 自动安装依赖（默认开启，可被 SKIP_DEPS 关闭）：
  - 优先安装 plocate；若不可用则尝试 mlocate、fd/fdfind（在 macOS 使用 Homebrew 安装 fd/fzf）
  - 若系统存在 `updatedb`，会自动执行一次（可被 SKIP_UPDATEDB 关闭）

完成后，重载对应 Shell：
```bash
# Zsh
source ~/.zshrc   # 或 exec zsh

# Bash
source ~/.bashrc  # 或 exec bash

# Fish
exec fish
```


### 手动安装（可选）
把核心可执行文件放到 PATH（如 `/usr/local/bin`），再添加对应的包装函数。

- Zsh（加入到 `~/.zshrc`）：
  ```bash
  to() {
    local dir
    dir=$(/usr/local/bin/to "$@") || return
    builtin cd -- "$dir"
  }
  ```

- Bash（加入到 `~/.bashrc` 或 `~/.profile`）：
  ```bash
  to() {
    local dir
    dir=$(/usr/local/bin/to "$@") || return
    builtin cd -- "$dir"
  }
  ```

- Fish（保存为 `~/.config/fish/functions/to.fish`）：
  ```fish
  function to
    set -l dir (command /usr/local/bin/to $argv)
    if test $status -ne 0
      return
    end
    cd -- $dir
  end
  ```

## 使用
```bash
to proj   # 跳转到名称包含 proj 的目录（缓存优先）
to fscan  # 只有一个结果时直接进入（若安装 fzf 并强制交互版本，会进入筛选界面）
to cve    # 多个结果时进入交互选择；安装 fzf 会使用 fzf 界面
```

- 若使用了 `plocate`，新建或移动大量目录后，建议运行一次：
  ```bash
  sudo updatedb
  ```

## 配置与文件
- 缓存文件：`~/.to_recent_dirs`
  - 默认保留最近 20 条，可在核心脚本 `到` 中修改 `MAX_CACHE`
- 安装位置：
  - 可执行文件：`/usr/local/bin/to`（或 `$HOME/.local/bin/to`）
  - 包装函数：`~/.to-cd/to.{zsh,bash}`、`~/.config/fish/functions/to.fish`

## 缓存相关
- 查看缓存：
  ```bash
  cat -n ~/.to_recent_dirs
  ```
- 清空缓存（当前用户）：
  ```bash
  rm -f ~/.to_recent_dirs
  ```
- 仅删除某一条（示例：移除 ~/tools/fscan）：
  ```bash
  grep -F -x -v -- "$HOME/tools/fscan" "$HOME/.to_recent_dirs" > "$HOME/.to_recent_dirs.tmp" \
    && mv "$HOME/.to_recent_dirs.tmp" "$HOME/.to_recent_dirs"
  ```
- 注意：若在 root 会话中使用过 `到`，root 有独立缓存 `/root/.to_recent_dirs`

（如果你采用了带内置缓存管理的脚本版本，还可使用：`to -l` 列出、`to -c` 清空、`to -r <PATH>` 移除）

## 故障排查
- 修改了 Shell 配置未生效？
  - 运行 `source ~/.zshrc` 或 `source ~/.bashrc`，Fish 执行 `exec fish`
- 确认函数是否生效：
  ```bash
  type -a to     # Zsh/Bash 期望第一行是 “to is a shell function”
  ```
- 核心脚本能否找到目录？
  ```bash
  /usr/local/bin/to keyword
  ```
- plocate 找不到新目录？
  ```bash
  sudo updatedb
  plocate -i -b keyword | head
  ```
- 仍未命中？
  - 检查目录是否在 `updatedb.conf` 的 PRUNEPATHS/PRUNEFS 中被排除
  - 或安装 `fd/fdfind`，让工具在索引缺失时也能回退搜索

## 许可证与反馈
- 许可证：MIT
- 这是一个简陋的小工具，如果你有更好的建议或者方案，可以通过下面的方式来联系：
  ```
  1435900886@qq.com
  ```
  感谢您的反馈！！！
