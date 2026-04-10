#!/usr/bin/env bash
set -euo pipefail

prefix="${PREFIX:-/usr/local}"
bindir="${prefix}/bin"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skip_deps="${SKIP_DEPS:-0}"
skip_updatedb="${SKIP_UPDATEDB:-0}"
selected_shells="auto"
print_init_only=0

SUDO="sudo"
if [ "${EUID:-$(id -u)}" -eq 0 ]; then
  SUDO=""
fi

have_cmd() { command -v "$1" >/dev/null 2>&1; }
log() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
统一安装脚本

用法：
  ./install.sh [选项]

选项：
  --prefix <PATH>         安装前缀，默认 /usr/local
  --shell <LIST>          指定接入哪些 shell
                          可选：auto|bash|zsh|fish|all
                          多个 shell 用逗号分隔，如：bash,zsh
  --skip-deps             跳过依赖安装
  --skip-updatedb         跳过 updatedb
  --print-init <shell>    仅打印对应 shell 的初始化片段，不执行安装
  -h, --help              显示帮助

示例：
  ./install.sh
  ./install.sh --prefix "$HOME/.local"
  ./install.sh --shell bash,zsh
  ./install.sh --shell all --skip-deps
  ./install.sh --print-init zsh
EOF
}

normalize_shell_name() {
  case "$1" in
    bash|zsh|fish|auto|all) printf '%s\n' "$1" ;;
    *) return 1 ;;
  esac
}

detect_current_shell() {
  local sh="${SHELL##*/}"
  case "$sh" in
    bash|zsh|fish) printf '%s\n' "$sh" ;;
    *) printf '%s\n' "bash" ;;
  esac
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --prefix)
        [[ $# -ge 2 ]] || die "--prefix 需要参数"
        prefix="$2"
        bindir="${prefix}/bin"
        shift 2
        ;;
      --shell)
        [[ $# -ge 2 ]] || die "--shell 需要参数"
        selected_shells="$2"
        shift 2
        ;;
      --skip-deps)
        skip_deps=1
        shift
        ;;
      --skip-updatedb)
        skip_updatedb=1
        shift
        ;;
      --print-init)
        [[ $# -ge 2 ]] || die "--print-init 需要参数"
        print_init_only=1
        selected_shells="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "未知参数：$1"
        ;;
    esac
  done
}

detect_pm() {
  if have_cmd apt-get; then echo apt; return; fi
  if have_cmd pacman; then echo pacman; return; fi
  if have_cmd dnf; then echo dnf; return; fi
  if have_cmd zypper; then echo zypper; return; fi
  if have_cmd apk; then echo apk; return; fi
  if have_cmd brew; then echo brew; return; fi
  echo none
}

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
  esac
}

install_deps() {
  local pm
  pm="$(detect_pm)"
  if [[ "$pm" == "none" ]]; then
    log "[!] 未检测到受支持的包管理器，跳过依赖安装。请手动安装：fzf、plocate 或 fd/fdfind"
    return 0
  fi

  log "[+] 安装依赖，包管理器：$pm"
  pm_install "$pm" fzf
  case "$pm" in
    apt|dnf|zypper|pacman)
      pm_install "$pm" plocate
      pm_install "$pm" mlocate
      pm_install "$pm" fd
      pm_install "$pm" fd-find
      ;;
    apk)
      pm_install "$pm" plocate
      pm_install "$pm" mlocate
      pm_install "$pm" fd
      ;;
    brew)
      pm_install "$pm" fd
      ;;
  esac

  log "[i] 当前依赖状态："
  for c in plocate mlocate fd fdfind fzf; do
    if have_cmd "$c"; then
      log "    - $c: OK ($(command -v "$c"))"
    else
      log "    - $c: 未安装"
    fi
  done

  if (( skip_updatedb == 0 )) && have_cmd updatedb; then
    log "[+] 运行 updatedb"
    $SUDO updatedb || true
  else
    log "[i] 跳过 updatedb 或系统无 updatedb"
  fi
}

ensure_line() {
  local file="$1" line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  grep -Fqx "$line" "$file" 2>/dev/null || printf '\n%s\n' "$line" >> "$file"
}

shell_init_line() {
  case "$1" in
    bash) printf '%s\n' '[ -r "$HOME/.to-cd/to.bash" ] && . "$HOME/.to-cd/to.bash"' ;;
    zsh)  printf '%s\n' 'source "$HOME/.to-cd/to.zsh"' ;;
    fish) printf '%s\n' '# fish 自动加载 ~/.config/fish/functions/to.fish，无需额外 init' ;;
    *) return 1 ;;
  esac
}

write_bash_wrapper() {
  local dest="$HOME/.to-cd/to.bash"
  mkdir -p "$(dirname "$dest")"
  cat > "$dest" <<'EOF'
# Bash / POSIX 兼容包装
_to_bin() {
  if [ -n "${TO_BIN:-}" ] && [ -x "${TO_BIN}" ]; then
    printf '%s\n' "$TO_BIN"
    return 0
  fi
  type -P to 2>/dev/null || { [ -x /usr/local/bin/to ] && printf '%s\n' /usr/local/bin/to; } || return 1
}

to() {
  local _bin dir
  _bin="$(_to_bin)" || {
    echo "未找到核心可执行文件 to" >&2
    return 127
  }
  dir=$(command "$_bin" "$@") || return
  builtin cd -- "$dir"
}
EOF
}

write_zsh_wrapper() {
  local dest="$HOME/.to-cd/to.zsh"
  mkdir -p "$(dirname "$dest")"
  cat > "$dest" <<'EOF'
# Zsh 包装
_to_bin() {
  if [[ -n "${TO_BIN:-}" && -x "${TO_BIN}" ]]; then
    print -r -- "$TO_BIN"
    return 0
  fi
  whence -p to 2>/dev/null || { [[ -x /usr/local/bin/to ]] && print -r -- /usr/local/bin/to; } || return 1
}

to() {
  local _bin dir
  _bin="$(_to_bin)" || {
    echo "未找到核心可执行文件 to" >&2
    return 127
  }
  dir=$(command "$_bin" "$@") || return
  builtin cd -- "$dir"
}
EOF
}

write_fish_wrapper() {
  local dest="$HOME/.config/fish/functions/to.fish"
  mkdir -p "$(dirname "$dest")"
  cat > "$dest" <<'EOF'
function __to_bin
  if test -n "$TO_BIN"; and test -x "$TO_BIN"
    echo "$TO_BIN"
    return 0
  end
  set -l p (type -p to 2>/dev/null)
  if test -n "$p"
    echo "$p"
    return 0
  end
  if test -x /usr/local/bin/to
    echo /usr/local/bin/to
    return 0
  end
  return 1
end

function to
  set -l _bin (__to_bin)
  if test $status -ne 0
    echo "未找到核心可执行文件 to" >&2
    return 127
  end
  set -l dir (command $_bin $argv)
  if test $status -ne 0
    return
  end
  cd -- $dir
end
EOF
}

install_core() {
  log "[+] 安装核心可执行文件到 ${bindir}/to"
  if mkdir -p "$bindir" 2>/dev/null; then
    install -Dm755 "${script_dir}/to" "${bindir}/to"
  else
    $SUDO install -Dm755 "${script_dir}/to" "${bindir}/to"
  fi
}

resolve_shells() {
  local raw="$1"
  if [[ "$raw" == "auto" ]]; then
    printf '%s\n' "$(detect_current_shell)"
    return 0
  fi
  if [[ "$raw" == "all" ]]; then
    printf '%s\n' bash zsh fish
    return 0
  fi

  local item
  local -a out=()
  IFS=',' read -r -a out <<< "$raw"
  for item in "${out[@]}"; do
    item="$(printf '%s' "$item" | tr '[:upper:]' '[:lower:]')"
    normalize_shell_name "$item" >/dev/null || die "不支持的 shell：$item"
    [[ "$item" == "auto" || "$item" == "all" ]] && die "auto/all 不能和其他 shell 混用"
    printf '%s\n' "$item"
  done
}

install_shell_integration() {
  local sh="$1"
  case "$sh" in
    bash)
      write_bash_wrapper
      ensure_line "$HOME/.bashrc" "$(shell_init_line bash)"
      if [[ ! -f "$HOME/.bash_profile" ]] || ! grep -Eq '(\.|source) +~\/\.bashrc' "$HOME/.bash_profile" 2>/dev/null; then
        {
          echo ''
          echo '# Load ~/.bashrc for login shells'
          echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi'
        } >> "$HOME/.bash_profile"
      fi
      [[ -f "$HOME/.profile" ]] && ensure_line "$HOME/.profile" "$(shell_init_line bash)"
      log "[+] 已接入 Bash"
      ;;
    zsh)
      write_zsh_wrapper
      ensure_line "$HOME/.zshrc" "$(shell_init_line zsh)"
      log "[+] 已接入 Zsh"
      ;;
    fish)
      write_fish_wrapper
      log "[+] 已接入 Fish"
      ;;
  esac
}

print_reload_hint() {
  local shells="$1"
  log "[✓] 安装完成"
  for sh in $shells; do
    case "$sh" in
      bash) log "  Bash: source ~/.bashrc  或  exec bash" ;;
      zsh)  log "  Zsh:  source ~/.zshrc   或  exec zsh" ;;
      fish) log "  Fish: exec fish" ;;
    esac
  done
}

main() {
  parse_args "$@"

  if (( print_init_only == 1 )); then
    selected_shells="$(printf '%s' "$selected_shells" | tr '[:upper:]' '[:lower:]')"
    normalize_shell_name "$selected_shells" >/dev/null || die "不支持的 shell：$selected_shells"
    shell_init_line "$selected_shells"
    exit 0
  fi

  local shells
  shells="$(resolve_shells "$(printf '%s' "$selected_shells" | tr '[:upper:]' '[:lower:]')")"

  install_core

  if (( skip_deps == 0 )); then
    install_deps
  else
    log "[i] 已跳过依赖安装"
  fi

  local sh
  for sh in $shells; do
    install_shell_integration "$sh"
  done

  print_reload_hint "$shells"
}

main "$@"
