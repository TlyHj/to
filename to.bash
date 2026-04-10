# Bash / POSIX 兼容包装
# 优先调用 PATH 中的可执行文件 to，可用 TO_BIN 覆盖具体路径
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
