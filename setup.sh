#!/bin/bash

PYTHON_BIN=python3.10
REQUIRED_VERSION="3.10"

# Check installed Python version
check_version() {
  version_output=$($PYTHON_BIN --version 2>&1)
  if [[ $version_output == *"$REQUIRED_VERSION"* ]]; then
    return 0
  else
    return 1
  fi
}

# Install Python on macOS if missing
if ! command -v $PYTHON_BIN &>/dev/null; then
  echo "$PYTHON_BIN not found."
  OS=$(uname)
  if [ "$OS" = "Darwin" ]; then
    echo "macOS detected. Installing Python 3.10 via Homebrew..."
    if ! command -v brew &>/dev/null; then
      echo "Homebrew not found. Please install it first."
      exit 1
    fi
    brew install python@3.10
  else
    echo "Please install Python 3.10 ($REQUIRED_VERSION) manually and rerun this script."
    exit 1
  fi
fi

# Verify version
if ! check_version; then
  echo "$PYTHON_BIN is not version $REQUIRED_VERSION."
  echo "Please update your Python installation."
  exit 1
fi

echo "$PYTHON_BIN version $REQUIRED_VERSION confirmed."

# Identify the shell and corresponding RC file
shell="$(ps -p $PPID | grep -v "PID" | awk '{print $4}')"
[[ ! "$shell" =~ ^(sh|bash|zsh|dash|fish)$ ]] && shell="$(basename "$SHELL")"

if [[ "$shell" == "bash" ]]; then
  rcfile=~/.bashrc
elif [[ "$shell" == "zsh" ]]; then
  rcfile=~/.zshrc
else
  rcfile=~/.profile
fi

[ ! -f "$rcfile" ] && echo "# FLITSR setup" > "$rcfile"
line_num="$(wc -l < "$rcfile")"

# Remove any existing FLITSR_HOME block
if grep -q "FLITSR_HOME" "$rcfile"; then
  read -r first_line last_line <<< $(grep -n "FLITSR_HOME" "$rcfile" | awk -F: 'NR==1{f=$1}{l=$1}END{print f,l}')
  if sed --version &>/dev/null; then
    sed -i.bak "${first_line},${last_line}d" "$rcfile"
  else
    sed -i '' "${first_line},${last_line}d" "$rcfile"
  fi
  line_num=$((first_line - 1))
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export FLITSR_HOME="$SCRIPT_DIR"

# Sed insert wrapper
insert_line() {
  local linenum="$1"
  local text="$2"
  if sed --version &>/dev/null; then
    sed -i "${linenum}a\\
${text}" "$rcfile"
  else
    sed -i '' "${linenum}a\\
${text}
" "$rcfile"
  fi
}

# Insert environment setup lines
insert_line "$line_num" "eval \"\$(${FLITSR_HOME}/.venv/bin/register-python-argcomplete percent_at_n)\""
insert_line "$line_num" "eval \"\$(${FLITSR_HOME}/.venv/bin/register-python-argcomplete merge)\""
insert_line "$line_num" "eval \"\$(${FLITSR_HOME}/.venv/bin/register-python-argcomplete flitsr)\""
insert_line "$line_num" "export PATH=\"\${PATH:+\$PATH:}${FLITSR_HOME}/bin\""
insert_line "$line_num" "export PYTHONPATH=\"\${PYTHONPATH:+\$PYTHONPATH:}${FLITSR_HOME}\""
insert_line "$line_num" "export FLITSR_HOME=\"$SCRIPT_DIR\""

echo "✅ $rcfile has been updated."

# Create virtual environment and install dependencies
$PYTHON_BIN -m venv "$FLITSR_HOME/.venv"
source "$FLITSR_HOME/.venv/bin/activate"
pip install -r "$FLITSR_HOME/requirements.txt"
deactivate

# Reload shell
echo "🔁 Reloading shell to apply changes..."
exec "$SHELL" -l
