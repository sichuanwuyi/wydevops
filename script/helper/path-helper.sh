#!/usr/bin/env bash

# 将 Windows 路径转为 Linux 风格路径
# 用法: linux_path=$(win2linux "$PWD")
function win2linux() {
  local p="${1:-$PWD}"

  if command -v wslpath >/dev/null 2>&1; then
    # 如果已经是 WSL 路径（wslpath -w 能成功），则直接输出
    # 否则，认为是 Windows 路径，尝试用 wslpath -u 转换
    if wslpath -w "$p" >/dev/null 2>&1; then
      printf '%s\n' "$p"
    else
      wslpath -u "$p" 2>/dev/null || printf '%s\n' "$p"
    fi
  elif command -v cygpath >/dev/null 2>&1; then
    # Cygwin/MSYS/Gita_Bash 环境处理逻辑类似
    if cygpath -w "$p" >/dev/null 2>&1; then
      printf '%s\n' "$p"
    else
      cygpath -u "$p" 2>/dev/null || printf '%s\n' "$p"
    fi
  else
    # 朴素回退：C:\Users\me -> /mnt/c/Users/me（若没有 /mnt，则输出 /c/...）
    local has_mnt=0; [ -d /mnt ] && has_mnt=1
    printf '%s\n' "$p" | awk -v usemnt="$has_mnt" '
      BEGIN{IGNORECASE=1}
      {
        gsub("\\","/")
        if ($0 ~ /^[A-Za-z]:\//) {
          d=tolower(substr($0,1,1))
          rest=substr($0,3)
          if (usemnt) printf "/mnt/%s%s\n", d, rest;
          else         printf "/%s%s\n",    d, rest;
        } else {
          print
        }
      }'
  fi
}