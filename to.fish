# Fish 包装函数（自动加载自 ~/.config/fish/functions/to.fish）
function to
  set -l dir (command /usr/local/bin/to $argv)
  if test $status -ne 0
    return
  end
  cd -- $dir
end
