#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prefix="${PREFIX:-/usr/local}"
bindir="${prefix}/bin"
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

to_lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

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
  sh="$(to_lower "$sh")"
  case "$sh" in
    bash|zsh|fish) printf '%s\n' "$sh" ;;
    *) printf '%s\n' bash ;;
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

shell_init_line() {
  case "$1" in
    bash) printf '%s\n' '[ -r "$HOME/.to-cd/to.bash" ] && . "$HOME/.to-cd/to.bash"' ;;
    zsh)  printf '%s\n' '[ -r "$HOME/.to-cd/to.zsh" ] && source "$HOME/.to-cd/to.zsh"' ;;
    fish) printf '%s\n' '# fish 自动加载 ~/.config/fish/functions/to.fish，无需额外 init' ;;
    *) return 1 ;;
  esac
}

shell_wrapper_source() {
  case "$1" in
    bash) printf '%s\n' "${script_dir}/to.bash" ;;
    zsh)  printf '%s\n' "${script_dir}/to.zsh" ;;
    fish) printf '%s\n' "${script_dir}/to.fish" ;;
    *) return 1 ;;
  esac
}

shell_wrapper_dest() {
  case "$1" in
    bash) printf '%s\n' "$HOME/.to-cd/to.bash" ;;
    zsh)  printf '%s\n' "$HOME/.to-cd/to.zsh" ;;
    fish) printf '%s\n' "$HOME/.config/fish/functions/to.fish" ;;
    *) return 1 ;;
  esac
}

shell_rc_file() {
  case "$1" in
    bash) printf '%s\n' "$HOME/.bashrc" ;;
    zsh)  printf '%s\n' "$HOME/.zshrc" ;;
    *) return 1 ;;
  esac
}

resolve_shells() {
  local raw="$1"
  raw="$(to_lower "$raw")"

  case "$raw" in
    auto)
      printf '%s\n' "$(detect_current_shell)"
      return 0
      ;;
    all)
      printf '%s\n' bash zsh fish
      return 0
      ;;
  esac

  local item
  local -a out=()
  IFS=',' read -r -a out <<< "$raw"
  for item in "${out[@]}"; do
    item="$(to_lower "$item")"
    normalize_shell_name "$item" >/dev/null || die "不支持的 shell：$item"
    [[ "$item" == "auto" || "$item" == "all" ]] && die "auto/all 不能和其他 shell 混用"
    printf '%s\n' "$item"
  done
}

ensure_line() {
  local file="$1" line="$2"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  grep -Fqx "$line" "$file" 2>/dev/null || printf '\n%s\n' "$line" >> "$file"
}

ensure_bash_profile_loads_bashrc() {
  local profile="$HOME/.bash_profile"
  if [[ ! -f "$profile" ]] || ! grep -Eq '(\.|source) +~\/\.bashrc' "$profile" 2>/dev/null; then
    {
      echo ''
      echo '# Load ~/.bashrc for login shells'
      echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi'
    } >> "$profile"
  fi
}

install_file() {
  local src="$1" dest="$2" mode="${3:-755}"
  if mkdir -p "$(dirname "$dest")" 2>/dev/null; then
    install -Dm"$mode" "$src" "$dest"
  else
    $SUDO install -Dm"$mode" "$src" "$dest"
  fi
}

install_core() {
  log "[+] 安装核心可执行文件到 ${bindir}/to"
  install_file "${script_dir}/to" "${bindir}/to" 755
}

install_shell_wrapper() {
  local sh="$1"
  install_file "$(shell_wrapper_source "$sh")" "$(shell_wrapper_dest "$sh")" 644
}

integrate_bash() {
  install_shell_wrapper bash
  ensure_line "$(shell_rc_file bash)" "$(shell_init_line bash)"
  ensure_bash_profile_loads_bashrc
  [[ -f "$HOME/.profile" ]] && ensure_line "$HOME/.profile" "$(shell_init_line bash)"
  log "[+] 已接入 Bash"
}

integrate_zsh() {
  install_shell_wrapper zsh
  ensure_line "$(shell_rc_file zsh)" "$(shell_init_line zsh)"
  log "[+] 已接入 Zsh"
}

integrate_fish() {
  install_shell_wrapper fish
  log "[+] 已接入 Fish"
}

install_shell_integration() {
  case "$1" in
    bash) integrate_bash ;;
    zsh)  integrate_zsh ;;
    fish) integrate_fish ;;
    *) die "不支持的 shell：$1" ;;
  esac
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

install_packages() {
  local pm="$1"
  local pkg
  for pkg in "$@"; do
    [[ "$pkg" == "$pm" ]] && continue
    pm_install "$pm" "$pkg"
  done
}

print_dependency_status() {
  log "[i] 当前依赖状态："
  local c
  for c in plocate mlocate fd fdfind fzf; do
    if have_cmd "$c"; then
      log "    - $c: OK ($(command -v "$c"))"
    else
      log "    - $c: 未安装"
    fi
  done
}

run_updatedb_if_needed() {
  if (( skip_updatedb == 0 )) && have_cmd updatedb; then
    log "[+] 运行 updatedb"
    $SUDO updatedb || true
  else
    log "[i] 跳过 updatedb 或系统无 updatedb"
  fi
}

install_deps() {
  local pm
  pm="$(detect_pm)"
  if [[ "$pm" == "none" ]]; then
    log "[!] 未检测到受支持的包管理器，跳过依赖安装。请手动安装：fzf、plocate 或 fd/fdfind"
    return 0
  fi

  log "[+] 安装依赖，包管理器：$pm"
  case "$pm" in
    apt|dnf|zypper|pacman)
      install_packages "$pm" fzf plocate mlocate fd fd-find
      ;;
    apk)
      install_packages "$pm" fzf plocate mlocate fd
      ;;
    brew)
      install_packages "$pm" fzf fd
      ;;
  esac

  print_dependency_status
  run_updatedb_if_needed
}

print_reload_hint() {
  local shells="$1"
  log "[✓] 安装完成"
  local sh
  for sh in $shells; do
    case "$sh" in
      bash) log "  Bash: source ~/.bashrc  或  exec bash" ;;
      zsh)  log "  Zsh:  source ~/.zshrc   或  exec zsh" ;;
      fish) log "  Fish: exec fish" ;;
    esac
  done
}

print_init() {
  local sh
  sh="$(to_lower "$1")"
  normalize_shell_name "$sh" >/dev/null || die "不支持的 shell：$sh"
  [[ "$sh" == "auto" || "$sh" == "all" ]] && die "--print-init 只支持 bash|zsh|fish"
  shell_init_line "$sh"
}

main() {
  parse_args "$@"

  if (( print_init_only == 1 )); then
    print_init "$selected_shells"
    exit 0
  fi

  local shells
  shells="$(resolve_shells "$selected_shells")"

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
