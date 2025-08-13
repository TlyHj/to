# to

一个快速跳转目录的小工具：结合最近访问缓存 + plocate/fd/find 搜索，支持交互选择（fzf 优先），在 zsh 中提供 `到` 命令。

## 特性
- 最近目录缓存（`~/.to_recent_dirs`），优先匹配
- 支持 `plocate`/`fd`/`find` 多后端，自动兜底
- 多结果时交互选择（安装了 `fzf` 则优先使用）
- 安全处理包含空格或特殊字符的路径

## 依赖
- 必需：`zsh`（用于包装函数）
- 可选：`plocate` 或 `fd/fdfind`（更快的搜索），`fzf`（更好用的交互选择）

## 安装
### 方式一：脚本安装
```bash
sudo install -Dm755 to /usr/local/bin/to
# 将 zsh 包装函数加入 ~/.zshrc
echo 'source "$HOME/.to/shell/to.zsh"' >> ~/.zshrc
```
或者使用仓库提供的一键脚本：
```bash
sudo ./install.sh
```

### 方式二：手动引用
把 `to` 放到 PATH（如 `/usr/local/bin`），然后在 `~/.zshrc` 添加：
```bash
to() {
  local dir
  dir=$(/usr/local/bin/to "$@") || return
  builtin cd -- "$dir"
}
```
然后在当前终端执行：
```bash
source ~/.zshrc
```

## 使用
```bash
to proj      # 跳转到名称包含 proj 的目录（缓存优先）
to fscan     # 只有一个结果时直接进入
to cve       # 多个结果时交互选择；安装 fzf 会用 fzf 界面
```

## 配置与文件
- 缓存文件：`~/.to_recent_dirs`（默认保留最近 20 条，可在 `bin/to` 中修改 `MAX_CACHE`）
- 安装位置：`/usr/local/bin/to`（可自行调整）

## 故障排查
- 修改了 `~/.zshrc` 后，使用 `source ~/.zshrc` 或 `exec zsh` 让其生效
- 确认函数生效：`type -a to`
- 查看脚本输出：`/usr/local/bin/to keyword`

## 注意事项
### 在使用前，或者创建有新的文件夹后，你需要手动更新数据库，以便于to可以找到
```
sudo updatedb
```

### 这是一个简陋的版本，可能会存在很多问题，如果你有更好的方案或建议可以通过下面的方式联系到我，感激不尽
```
1435900886@qq.com
```
