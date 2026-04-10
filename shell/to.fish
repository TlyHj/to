# Fish 包装函数（自动加载自 ~/.config/fish/functions/to.fish）
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
