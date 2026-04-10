# to

`to` 是一个 Linux 终端下的目录快速跳转工具。

它会优先利用最近访问目录缓存，再结合 `plocate` / `fd` / `find` 搜索目录，帮助你更快进入目标路径。

## 优点

- 跳转快，优先命中最近访问目录
- 支持直接路径跳转，如 `to ../project`、`to ~/code/demo`
- 支持 `plocate` / `fd` / `fdfind` / `find` 自动兜底
- 支持 Bash、Zsh、Fish
- 安装和卸载入口统一
- 支持缓存、搜索深度、搜索范围等配置

## 目录结构

```text
.
├── bin/to
├── shell/
├── scripts/
├── LICENSE
└── README.md
```

## 依赖

推荐安装：
- `plocate`
- `fd` 或 `fdfind`
- `fzf`

没有 `fzf` 时会回退到数字菜单；没有 `plocate` / `fd` 时会回退到 `find`。

## 安装

默认安装：

```bash
sudo ./scripts/install.sh
```

安装到当前用户目录：

```bash
./scripts/install.sh --prefix "$HOME/.local"
```

接入多个 shell：

```bash
./scripts/install.sh --shell bash,zsh
./scripts/install.sh --shell all
```

跳过依赖安装：

```bash
./scripts/install.sh --skip-deps
./scripts/install.sh --skip-deps --skip-updatedb
```

## 卸载

```bash
./scripts/uninstall.sh
```

删除缓存：

```bash
./scripts/uninstall.sh --remove-cache
```

## 使用

```bash
to proj
to nginx
to ../my-project
to ~/code/demo
```

缓存管理：

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

## 故障排查

```bash
type -a to
./scripts/install.sh --help
./scripts/uninstall.sh --help
bin/to --help
sudo updatedb
```

## 许可证

MIT
