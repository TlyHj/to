#!/usr/bin/env bash
set -euo pipefail

prefix="${PREFIX:-/usr/local}"
bindir="${prefix}/bin"
remove_cache=0
selected_shells="all"

usage() {
  cat <<'EOF'
统一卸载脚本

用法：
  ./uninstall.sh [选项]

选项：
  --prefix <PATH>      卸载前缀，默认 /usr/local
  --shell <LIST>       卸载哪些 shell 的接入
                       可选：bash|zsh|fish|all
                       多个 shell 用逗号分隔，如：bash,zsh
  --remove-cache       同时删除缓存文件 ~/.to_recent_dirs
  -h, --help           显示帮助

示例：
  ./uninstall.sh
  ./uninstall.sh --prefix "$HOME/.local"
  ./uninstall.sh --shell bash,zsh
  ./uninstall.sh --remove-cache
EOF
}

log() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

normalize_shell_name() {
  case "$1" in
    bash|zsh|fish|all) printf '%s\n' "$1" ;;
    *) return 1 ;;
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
      --remove-cache)
        remove_cache=1
        shift
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

resolve_shells() {
  local raw
  raw="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
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
    [[ "$item" == "all" ]] && die "all 不能和其他 shell 混用"
    printf '%s\n' "$item"
  done
}

remove_file_if_exists() {
  local file="$1"
  if [[ -e "$file" ]]; then
    rm -f "$file"
    log "[+] 已删除：$file"
  else
    log "[i] 文件不存在，跳过：$file"
  fi
}

remove_line_exact() {
  local file="$1" line="$2"
  [[ -f "$file" ]] || return 0
  python3 - "$file" "$line" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
needle = sys.argv[2]
text = path.read_text(encoding='utf-8')
lines = text.splitlines()
new_lines = [line for line in lines if line != needle]
path.write_text("\n".join(new_lines) + ("\n" if new_lines else ""), encoding='utf-8')
PY
}

cleanup_empty_dir() {
  local dir="$1"
  if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
    rmdir "$dir" 2>/dev/null || true
  fi
}

shell_init_line() {
  case "$1" in
    bash) printf '%s\n' '[ -r "$HOME/.to-cd/to.bash" ] && . "$HOME/.to-cd/to.bash"' ;;
    zsh)  printf '%s\n' '[ -r "$HOME/.to-cd/to.zsh" ] && source "$HOME/.to-cd/to.zsh"' ;;
    *) return 1 ;;
  esac
}

uninstall_shell_integration() {
  local sh="$1"
  case "$sh" in
    bash)
      remove_file_if_exists "$HOME/.to-cd/to.bash"
      remove_line_exact "$HOME/.bashrc" "$(shell_init_line bash)"
      remove_line_exact "$HOME/.profile" "$(shell_init_line bash)"
      log "[+] 已卸载 Bash 接入"
      ;;
    zsh)
      remove_file_if_exists "$HOME/.to-cd/to.zsh"
      remove_line_exact "$HOME/.zshrc" "$(shell_init_line zsh)"
      log "[+] 已卸载 Zsh 接入"
      ;;
    fish)
      remove_file_if_exists "$HOME/.config/fish/functions/to.fish"
      log "[+] 已卸载 Fish 接入"
      ;;
  esac
}

main() {
  parse_args "$@"

  local shells
  shells="$(resolve_shells "$selected_shells")"

  remove_file_if_exists "${bindir}/to"

  local sh
  for sh in $shells; do
    uninstall_shell_integration "$sh"
  done

  cleanup_empty_dir "$HOME/.to-cd"
  cleanup_empty_dir "$HOME/.config/fish/functions"

  if (( remove_cache == 1 )); then
    remove_file_if_exists "$HOME/.to_recent_dirs"
  else
    log "[i] 保留缓存文件：$HOME/.to_recent_dirs"
  fi

  log "[✓] 卸载完成"
}

main "$@"
