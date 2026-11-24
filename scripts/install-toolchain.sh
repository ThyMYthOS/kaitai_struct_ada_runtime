#!/bin/bash
# Install the toolchain this repository is built, proven, formatted and
# measured with.  Used by the session hook of Claude Code cloud sessions and
# by the CI; it also works on a Debian or Ubuntu development machine.
#
#   Alire        package manager, fetches everything below it
#   GNAT         native compiler, and through the crates' dependencies the
#                ARM cross compiler with its light and embedded run-time
#                libraries
#   GPRbuild     build tool
#   GNATprove    proof tool for SPARK
#   gnatformat   formatter
#   Renode       simulator for low-end targets
#   Valgrind     counts instructions for the benchmarks
#
# The versions are pinned here.  Changing this file or a crate manifest makes
# the next run install again; otherwise it only sets up the environment and
# finishes at once.
#
# The tools go to ~/.local/bin, ~/.alire and ~/.local/share.  Add
# ~/.local/bin and ~/.alire/bin to PATH and set RENODE_HOME to
# ~/.local/share/renode; in a Claude Code session and in GitHub Actions the
# script does that itself.
set -euo pipefail

cd "$(dirname "$0")/.."

ALR_VERSION=2.1.1
GNAT_VERSION=16.1.0
GPRBUILD_VERSION=26.0.1
GNATPROVE_VERSION=16.1.0
GNATFORMAT_VERSION=26.0.0
RENODE_VERSION=1.16.1

# Crates whose dependencies Alire has to fetch
CRATES=". tests tests/target bench bench/target"

BIN=$HOME/.local/bin
TOOLS=$HOME/.alire                      # prefix used by "alr install"
ALIRE_DATA=$HOME/.local/share/alire     # toolchains and releases
RENODE_HOME=$HOME/.local/share/renode
export PATH="$BIN:$TOOLS/bin:$PATH"
mkdir -p "$BIN"

# Run a command without its progress output; show the end of it on failure
log=$(mktemp)
quiet() {
   if ! "$@" >"$log" 2>&1; then
      echo "session-start: failed: $*" >&2
      tail -n 40 "$log" >&2
      exit 1
   fi
}

# System packages
missing=""
for tool in curl unzip tar valgrind; do
   command -v "$tool" >/dev/null || missing="$missing $tool"
done
if [ -n "$missing" ]; then
   sudo=""
   [ "$(id -u)" = 0 ] || sudo=sudo
   quiet $sudo apt-get update
   # shellcheck disable=SC2086
   quiet $sudo apt-get install -y $missing
fi

# Alire
if [ "$(alr --version 2>/dev/null || true)" != "alr $ALR_VERSION" ]; then
   tmp=$(mktemp -d)
   curl -fsSL -o "$tmp/alr.zip" \
      "https://github.com/alire-project/alire/releases/download/v$ALR_VERSION/alr-$ALR_VERSION-bin-x86_64-linux.zip"
   unzip -q "$tmp/alr.zip" -d "$tmp"
   install -m 755 "$tmp/bin/alr" "$BIN/alr"
   rm -rf "$tmp"
fi

# Renode, with a launcher on PATH
if [ "$(cat "$RENODE_HOME/.version" 2>/dev/null || true)" != "$RENODE_VERSION" ]; then
   rm -rf "$RENODE_HOME"
   mkdir -p "$RENODE_HOME"
   curl -fsSL \
      "https://github.com/renode/renode/releases/download/v$RENODE_VERSION/renode-$RENODE_VERSION.linux-portable-dotnet.tar.gz" |
      tar -xz -C "$RENODE_HOME" --strip-components=1
   echo "$RENODE_VERSION" >"$RENODE_HOME/.version"
fi
printf '#!/bin/sh\nexec "%s/renode" "$@"\n' "$RENODE_HOME" >"$BIN/renode"
chmod +x "$BIN/renode"

# Everything Alire installs.  Run only if this script or a crate manifest has
# changed since the install last succeeded.
hashes=$ALIRE_DATA/.session-start.sha256
if ! sha256sum --check --status "$hashes" 2>/dev/null; then
   # Delete the old hashes first, so that a failed install runs again
   rm -f "$hashes"

   quiet alr -n toolchain --select "gnat_native=$GNAT_VERSION" "gprbuild=$GPRBUILD_VERSION"

   installed=$(alr -n install --info 2>/dev/null || true)
   for tool in "gnatprove=$GNATPROVE_VERSION" "gnatformat_bin=$GNATFORMAT_VERSION"; do
      case "$installed" in
         *"$tool"*) ;;
         *) quiet alr -n install "$tool" ;;
      esac
   done

   # Dependencies of the crates, among them the cross compiler
   manifests=""
   for crate in $CRATES; do
      (cd "$crate" && quiet alr -n update)
      manifests="$manifests $crate/alire.toml"
   done

   mkdir -p "$ALIRE_DATA"
   # shellcheck disable=SC2086
   sha256sum scripts/install-toolchain.sh $manifests >"$hashes" || rm -f "$hashes"
fi

# Make the tools visible to what runs after this script
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
   {
      echo "export PATH=\"$BIN:$TOOLS/bin:\$PATH\""
      echo "export RENODE_HOME=\"$RENODE_HOME\""
   } >>"$CLAUDE_ENV_FILE"
fi
if [ -n "${GITHUB_PATH:-}" ]; then
   echo "$BIN" >>"$GITHUB_PATH"
   echo "$TOOLS/bin" >>"$GITHUB_PATH"
   echo "RENODE_HOME=$RENODE_HOME" >>"$GITHUB_ENV"
fi
