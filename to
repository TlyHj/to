#!/usr/bin/env bash
# 输出：仅打印选中的目录路径到标准输出；由外层 shell 函数执行 cd
set -euo pipefail

CACHE_FILE="${HOME}/.to_recent_dirs"
MAX_CACHE=20

die() { printf '%s\n' "$*" >&2; exit 1; }

update_cache() {
  local dir="$1" tmp
  tmp="$(mktemp "${CACHE_FILE}.XXXX")"
  if [[ -f "$CACHE_FILE" ]]; then
    # 删除与当前 dir 完全相等的行
    grep -F -x -v -- "$dir" "$CACHE_FILE" > "$tmp" || true
  else
    : > "$tmp"
  fi
  printf '%s\n' "$dir" >> "$tmp"
  tail -n "$MAX_CACHE" "$tmp" > "$CACHE_FILE"
  rm -f "$tmp"
}

search_recent() {
  local q="$1"
  [[ -f "$CACHE_FILE" ]] || return 0
  # 不区分大小写、固定字符串匹配
  grep -i -F -- "$q" "$CACHE_FILE" || true
}

search_plocate() {
  local q="$1"
  if command -v plocate >/dev/null 2>&1; then
    # -i 忽略大小写，-b 按 basename 匹配，-0 用 NUL 分隔避免换行问题
    plocate -i -b -0 -- "$q" | \
    while IFS= read -r -d '' p; do
      [[ -d "$p" ]] && printf '%s\n' "$p"
    done
  elif command -v fd >/dev/null 2>&1; then
    fd -t d -i -u -a "$q" / 2>/dev/null || true
  elif command -v fdfind >/dev/null 2>&1; then
    fdfind -t d -i -u -a "$q" / 2>/dev/null || true
  else
    # 兜底（可能较慢）
    find / -type d -iname "*$q*" 2>/dev/null || true
  fi
}

main() {
  [[ $# -ge 1 ]] || die "用法: to <目录名部分或完整名>"
  local q="$1"

  # 去重且保序
  declare -A seen=()
  matches=()

  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if [[ -z "${seen[$line]+x}" ]]; then
      seen["$line"]=1
      matches+=("$line")
    fi
  done < <( { search_recent "$q"; search_plocate "$q"; } )

  if [[ ${#matches[@]} -eq 0 ]]; then
    die "未找到匹配目录：$q"
  fi

  local dir=""
  if [[ ${#matches[@]} -eq 1 ]]; then
    dir="${matches[0]}"
  else
    if command -v fzf >/dev/null 2>&1; then
      dir="$(printf '%s\n' "${matches[@]}" | fzf --prompt="选择目录> " --height=40% --reverse --ansi)" || exit 1
    else
      echo "找到多个匹配目录，请选择："
      local i sel
      for ((i=0; i<${#matches[@]}; i++)); do
        printf '%2d) %s\n' "$((i+1))" "${matches[$i]}"
      done
      while :; do
        read -r -p "请输入编号 (或 0 取消): " sel
        [[ "$sel" =~ ^[0-9]+$ ]] || { echo "请输入数字"; continue; }
        if (( sel == 0 )); then exit 1; fi
        if (( sel >= 1 && sel <= ${#matches[@]} )); then
          dir="${matches[$((sel-1))]}"
          break
        else
          echo "编号无效，请重试"
        fi
      done
    fi
  fi

  update_cache "$dir"
  printf '%s\n' "$dir"
}

main "$@"
