# 请在 zsh 中 source 本文件，提供 to 命令
# 优先调用 PATH 中的可执行文件 to，可用 TO_BIN 覆盖具体路径
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
