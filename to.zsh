# 请在 zsh 中 source 本文件，提供 to 命令
to() {
  local dir
  dir=$(/usr/local/bin/to "$@") || return
  builtin cd -- "$dir"
}
