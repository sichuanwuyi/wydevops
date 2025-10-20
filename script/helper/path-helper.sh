#!/usr/bin/env bash

# 将 Windows 路径转为 Linux 风格路径
# 用法: linux_path=$(win2linux "$PWD")
function win2linux() {
  local p="${1:-$PWD}"

  if command -v wslpath >/dev/null 2>&1; then
    # 若传入已是类 Unix 路径，wslpath -u 会报错到 stderr
    # 丢弃 stderr，并在失败时回显原值
    wslpath -u "$p" 2>/dev/null || printf '%s\n' "$p"
  elif command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$p" 2>/dev/null || printf '%s\n' "$p"
  else
    # 朴素回退：C:\Users\me -> /mnt/c/Users/me（若没有 /mnt，则输出 /c/...）
    local has_mnt=0; [ -d /mnt ] && has_mnt=1
    printf '%s\n' "$p" | awk -v usemnt="$has_mnt" '
      BEGIN{IGNORECASE=1}
      {
        gsub("\\\\","/")                 # 反斜杠 -> 斜杠
        if ($0 ~ /^[A-Za-z]:\//) {
          d=tolower(substr($0,1,1))
          rest=substr($0,3)              # 去掉 "C:"
          if (usemnt) printf "/mnt/%s%s\n", d, rest;
          else         printf "/%s%s\n",    d, rest;
        } else print                     # 已是类 Unix 路径则原样返回
      }'
  fi
}