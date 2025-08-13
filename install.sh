#!/usr/bin/env bash
set -euo pipefail

# 说明：
# - 默认自动安装依赖（fzf + plocate 或 fd/fdfind），并在可用时执行 updatedb
# - 可通过 SKIP_DEPS=1 跳过依赖安装；通过 SKIP_UPDATEDB=1 跳过 updatedb
# - 支持自定义 PREFIX（默认 /usr/local）
#
# 例子：
#   ./install.sh                           # 默认自动装依赖（可能需要 sudo）
#   SKIP_DEPS=1 ./install.sh               # 跳过依赖安装
#   PREFIX="$HOME/.local" ./install.sh     # 安装到用户目录（一般无需 sudo）

prefix="${PREFIX:-/usr/local}"
bindir="${prefix}/bin"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skip_deps="${SKIP_DEPS:-0}"
skip_updatedb="${SKIP_UPDATEDB:-0}"

# 选择是否使用 sudo
SUDO="sudo"
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
  SUDO=""
fi

have_cmd() { command -v "$1" >/dev/null 2>&1; }

# 检测包管理器
detect_pm() {
  if have_cmd apt-get; then echo apt; return; fi
  if have_cmd pacman;  then echo pacman; return; fi
  if have_cmd dnf;     then echo dnf; return; fi
  if have_cmd zypper;  then echo zypper; return; fi
  if have_cmd apk;     then echo apk; return; fi
  if have_cmd brew;    then echo brew; return; fi
  echo none
}

# 安装一个包（允许失败，不阻断流程）
pm_install() {
  local pm="$1" pkg="$2"
  case "$pm" in
    apt)
      $SUDO apt-get update -y >/dev/null 2>&1 || true
      $SUDO apt-get install -y "$pkg" || true
      ;;
    pacman)
      $SUDO pacman -Sy --noconfirm "$pkg" || true
      ;;
    dnf)
      $SUDO dnf install -y "$pkg" || true
      ;;
    zypper)
      $SUDO zypper --non-interactive install -y "$pkg" || true
      ;;
    apk)
      $SUDO apk add --no-cache "$pkg" || true
      ;;
    brew)
      brew install "$pkg" || true
      ;;
    *)
      return 1
      ;;
  esac
}

install_deps() {
  local pm; pm="$(detect_pm)"
  if [[ "$pm" == "none" ]]; then
    echo "[!] 未检测到受支持的包管理器，跳过自动安装依赖。请手动安装：fzf、plocate 或 fd/fdfind"
    return 0
  fi

  echo "[+] 使用包管理器安装依赖: $pm"
  echo "[+] 尝试安装 fzf ..."
  pm_install "$pm" "fzf"

  echo "[+] 尝试安装搜索后端（优先 plocate，其次 fd/fdfind）..."
  case "$pm" in
    apt|dnf|zypper|pacman)
      pm_install "$pm" "plocate"
      pm_install "$pm" "mlocate"   # 某些发行版只有 mlocate
      pm_install "$pm" "fd"        # Arch/openSUSE 通常叫 fd
      pm_install "$pm" "fd-find"   # Debian/Ubuntu/Fedora 通常叫 fd-find（命令叫 fdfind）
      ;;
    apk)
      pm_install "$pm" "plocate"
      pm_install "$pm" "mlocate"
      pm_install "$pm" "fd"
      ;;
    brew)
      # macOS 没有 plocate，安装 fd + fzf
      pm_install "$pm" "fd"
      ;;
  esac

  echo "[i] 依赖安装结果："
  for c in plocate mlocate fd fdfind fzf; do
    if have_cmd "$c"; then
      echo "    - $c: OK ($(command -v "$c"))"
    else
      echo "    - $c: 未安装"
    fi
  done

  if (( skip_updatedb == 0 )) && have_cmd updatedb; then
    echo "[+] 运行 updatedb（可能需要一些时间）"
    $SUDO updatedb || true
  else
    echo "[i] 跳过 updatedb 或系统无 updatedb"
  fi
}

# ---------- 安装核心可执行文件 ----------
echo "[+] 安装核心可执行文件到 ${bindir}/to"
# 尝试无 sudo 创建 bindir；失败则用 sudo
if mkdir -p "$bindir" 2>/dev/null; then
  install -Dm755 "${script_dir}/to" "${bindir}/to"
else
  $SUDO install -Dm755 "${script_dir}/to" "${bindir}/to"
fi

# ---------- 可选：安装依赖 ----------
if (( skip_deps == 0 )); then
  install_deps
else
  echo "[i] 已按 SKIP_DEPS=1 跳过依赖安装"
fi

# ---------- Zsh 包装 ----------
if [[ -f "${script_dir}/to.zsh" ]]; then
  dest_dir="${HOME}/.to-cd"
  dest_file="${dest_dir}/to.zsh"
  mkdir -p "${dest_dir}"
  install -Dm644 "${script_dir}/to.zsh" "${dest_file}"

  source_line_zsh='source "$HOME/.to-cd/to.zsh"'
  if ! grep -Fqx "$source_line_zsh" "${HOME}/.zshrc" 2>/dev/null; then
    # 兼容旧路径替换
    if grep -Fq 'source "$HOME/.to-cd/shell/to.zsh"' "${HOME}/.zshrc" 2>/dev/null; then
      sed -i 's|source "$HOME/.to-cd/shell/to.zsh"|source "$HOME/.to-cd/to.zsh"|' "${HOME}/.zshrc"
      echo "[i] 已更新 ~/.zshrc 中旧的 source 路径"
    else
      printf '\n%s\n' "$source_line_zsh" >> "${HOME}/.zshrc"
      echo "[+] 已写入 Zsh 包装 source 到 ~/.zshrc"
    fi
  else
    echo "[i] ~/.zshrc 已包含 Zsh 包装 source"
  fi
fi

# ---------- Bash/POSIX 包装 ----------
if [[ -f "${script_dir}/to.bash" ]]; then
  dest_dir="${HOME}/.to-cd"
  dest_file="${dest_dir}/to.bash"
  mkdir -p "${dest_dir}"
  install -Dm644 "${script_dir}/to.bash" "${dest_file}"

  source_line_bash='[ -r "$HOME/.to-cd/to.bash" ] && . "$HOME/.to-cd/to.bash"'
  if ! grep -Fqx "$source_line_bash" "${HOME}/.bashrc" 2>/dev/null; then
    printf '\n%s\n' "$source_line_bash" >> "${HOME}/.bashrc"
    echo "[+] 已写入 Bash 包装 source 到 ~/.bashrc"
  else
    echo "[i] ~/.bashrc 已包含 Bash 包装 source"
  fi
  # 确保登录 shell 也加载 ~/.bashrc
  if [[ ! -f "${HOME}/.bash_profile" ]] || ! grep -Eq '(\.|source) +~\/\.bashrc' "${HOME}/.bash_profile" 2>/dev/null; then
    {
      echo ''
      echo '# Load ~/.bashrc for login shells'
      echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi'
    } >> "${HOME}/.bash_profile"
    echo "[+] 已确保登录 Shell 通过 ~/.bash_profile 加载 ~/.bashrc"
  fi
  # 兼容 dash/ash：若有 ~/.profile 则也加入一行
  if [[ -f "${HOME}/.profile" ]] && ! grep -Fqx "$source_line_bash" "${HOME}/.profile" 2>/dev/null; then
    printf '\n%s\n' "$source_line_bash" >> "${HOME}/.profile"
    echo "[+] 已在 ~/.profile 追加 POSIX 包装 source"
  fi
fi

# ---------- Fish 包装 ----------
if [[ -f "${script_dir}/to.fish" ]]; then
  fish_func_dir="${HOME}/.config/fish/functions"
  mkdir -p "${fish_func_dir}"
  install -Dm644 "${script_dir}/to.fish" "${fish_func_dir}/to.fish"
  echo "[+] 已安装 Fish 函数到 ${fish_func_dir}/to.fish"
fi

echo "[✓] 完成安装。请重载你的 Shell："
echo "  Zsh:  source ~/.zshrc   或  exec zsh"
echo "  Bash: source ~/.bashrc  或  exec bash"
echo "  Fish: exec fish"
