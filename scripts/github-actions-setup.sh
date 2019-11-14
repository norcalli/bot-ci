# See https://github.com/neovim/bot-ci#generated-builds for more information.

lightred() { echo -e "\033[1;31m$*\033[0m"; }
blue() { echo -e "\033[1;34m$*\033[0m"; }
dump() { echo "$SAY_PREFIX$*" >&2; }
say() { echo "$SAY_PREFIX$(blue "$*")" >&2; }
yell() { echo "$SAY_PREFIX$(lightred "$*")" >&2; }
die() { yell "$*"; exit 111; }
try() { "$@" || die "cannot $*"; }
asuser() { sudo su - "$1" -c "${*:2}"; }
need_var() { test -n "${!1}" || die "$1 must be defined"; }
need_vars() { for var in "$@"; do need_var $var; done; }
has_bin() { which "$1" 2>&1 >/dev/null; }
need_exe() { has_bin "$1"|| die "'$1' not found in PATH"; }
need_bin() { need_exe "$1"; }
strictmode() { set -eo pipefail; }
nostrictmode() { set +eo pipefail; }
say_var() { say "$1 = ${!1}"; }
say_vars() { for var in "$@"; do say_var $var; done; }
yell_var() { yell "$1 = ${!1}"; }
yell_vars() { for var in "$@"; do yell_var $var; done; }

export SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

BUILD_DIR=${BUILD_DIR-.}
OS_NAME=${OS_NAME-linux}

nightly_x64() {
  test -d "${BUILD_DIR}/_neovim" || {
    mkdir "${BUILD_DIR}/_neovim"
    curl -sL https://github.com/neovim/neovim/releases/download/nightly/nvim-${OS_NAME}64.tar.gz \
      | tar xzf - --strip-components=1 -C "${BUILD_DIR}/_neovim"
  }

  export PATH="${BUILD_DIR}/_neovim/bin:${PATH}"
  export VIM="${BUILD_DIR}/_neovim/share/nvim/runtime"
  say_vars PATH VIM

  nvim --version
}

_setup_deps() {
  NVIM_DEPS_REPO="${NVIM_DEPS_REPO:-neovim/deps}"
  NVIM_DEPS_BRANCH="${NVIM_DEPS_BRANCH:-master}"
  say "Setting up prebuilt dependencies from ${NVIM_DEPS_REPO}:${NVIM_DEPS_BRANCH}."

  sudo git clone --depth 1 --branch ${NVIM_DEPS_BRANCH} git://github.com/${NVIM_DEPS_REPO} "$(dirname "${1}")"

  export NVIM_DEPS_PREFIX="${1}/usr"
  say_var NVIM_DEPS_PREFIX

  eval "$(${NVIM_DEPS_PREFIX}/bin/luarocks path)"
  say_vars LUA_PATH LUA_CPATH

  export PKG_CONFIG_PATH="${NVIM_DEPS_PREFIX}/lib/pkgconfig"
  export USE_BUNDLED_DEPS=OFF
  export PATH="${NVIM_DEPS_PREFIX}/bin:${PATH}"
  say_vars PKG_CONFIG_PATH USE_BUNDLED_DEPS PATH
}

deps_x64() {
  test "${OS_NAME}" == "osx" || die "Prebuilt dependencies are only supported for OS X."
  _setup_deps "/opt/neovim-deps/osx-x64"
}

usage() {
  cat >&2 <<EOF
Usage: $0 <FUNCNAME>

FUNCNAME	Values: nightly_x64, deps_x64
EOF
  exit 1
}

COMMAND="${COMMAND-$1}"

test "$COMMAND" = --help && usage
test -n "$COMMAND" || usage

# Execute the command with - substituted for _
$(echo "$COMMAND" | tr - _)
