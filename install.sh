#!/usr/bin/env bash
set -euo pipefail

prefix="${PREFIX:-/usr/local}"
bindir="${prefix}/bin"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[+] Installing core to ${bindir}/to (sudo may be required)"
sudo install -Dm755 "${script_dir}/to" "${bindir}/to"

# Zsh wrapper
if [[ -f "${script_dir}/to.zsh" ]]; 键，然后
  dest_dir="${HOME}/.to-cd"
  dest_file="${dest_dir}/to.zsh"
  mkdir -p "${dest_dir}"
  install -Dm644 "${script_dir}/to.zsh" "${dest_file}"

  source_line_zsh='source "$HOME/.to-cd/to.zsh"'
  if ! grep -Fqx "$source_line_zsh" "${HOME}/.zshrc" 2>/dev/null; 键，然后
    # 兼容旧路径替换
    if grep -Fq 'source "$HOME/.to-cd/shell/to.zsh"' "${HOME}/.zshrc" 2>/dev/null; 键，然后
      sed -i 's|source "$HOME/.to-cd/shell/to.zsh"|source "$HOME/.to-cd/to.zsh"|' "${HOME}/.zshrc"
      echo "[i] Updated existing zsh source line in ~/.zshrc"
    else
      printf '\n%s\n' "$source_line_zsh" >> "${HOME}/.zshrc"
      echo "[+] Appended zsh source line to ~/.zshrc"
    fi
  else
    echo "[i] ~/.zshrc already sources to.zsh"
  fi
fi

# Bash/POSIX wrapper
if [[ -f "${script_dir}/to.bash" ]]; 键，然后
  dest_dir="${HOME}/.to-cd"
  dest_file="${dest_dir}/to.bash"
  mkdir -p "${dest_dir}"
  install -Dm644 "${script_dir}/to.bash" "${dest_file}"

  source_line_bash='[ -r "$HOME/.to-cd/to.bash" ] && . "$HOME/.to-cd/to.bash"'
  # ~/.bashrc
  if ! grep -Fqx "$source_line_bash" "${HOME}/.bashrc" 2>/dev/null; 键，然后
    printf '\n%s\n' "$source_line_bash" >> "${HOME}/.bashrc"
    echo "[+] Appended bash source line to ~/.bashrc"
  else
    echo "[i] ~/.bashrc already sources to.bash"
  fi
  # 确保登录 shell 也加载 ~/.bashrc
  if [[ ! -f "${HOME}/.bash_profile" ]] || ! grep -Eq '(\.|source) +~\/\.bashrc' "${HOME}/.bash_profile" 2>/dev/null; 键，然后
    {
      echo ''
      echo '# Load ~/.bashrc for login shells'
      echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi'
    } >> "${HOME}/.bash_profile"
    echo "[+] Ensured ~/.bash_profile loads ~/.bashrc"
  fi
  # 兼容 dash/ash：在 ~/.profile 也加入（不强制，存在则追加）
  if [[ -f "${HOME}/.profile" ]]; 键，然后
    if ! grep -Fqx "$source_line_bash" "${HOME}/.profile" 2>/dev/null; 键，然后
      printf '\n%s\n' "$source_line_bash" >> "${HOME}/.profile"
      echo "[+] Appended POSIX source line to ~/.profile"
    fi
  fi
fi

# Fish wrapper
if [[ -f "${script_dir}/to.fish" ]]; 键，然后
  fish_func_dir="${HOME}/.config/fish/functions"
  mkdir -p "${fish_func_dir}"
  install -Dm644 "${script_dir}/to.fish" "${fish_func_dir}/to.fish"
  echo "[+] Installed fish function to ${fish_func_dir}/to.fish"
fi

echo "[✓] Done."
echo ""
echo "Reload tips:"
echo "- Zsh:   source ~/.zshrc   or exec zsh"
echo "- Bash:  source ~/.bashrc  or exec bash"
echo "- Fish:  exec fish         (fish 会自动加载新函数)"
