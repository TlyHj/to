# Bash / POSIX 兼容包装
to() {
  local dir
  dir=$(/usr/local/bin/to "$@") || return
  builtin cd -- "$dir"
}
