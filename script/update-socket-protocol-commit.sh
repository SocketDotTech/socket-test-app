#!/bin/bash

# Check if branch name is provided
if [ -z "$1" ]; then
  echo "Error: No branch name specified."
  echo "Usage: $0 <branch_name>"
  exit 1
fi

BRANCH_NAME=$1

# Check for modified or staged files, but ignore untracked files
if git status --porcelain | grep -q '^[ MRAUCD]'; then
  echo "Error: You have modified or staged files. Commit or stash them before running this script."
  exit 1
fi

# Nuke the submodule
git submodule deinit -f lib/socket-protocol
rm -rf .git/modules/lib/socket-protocol
git rm -rf lib/socket-protocol

# Re-add the submodule with the specified branch
git submodule add -b "$BRANCH_NAME" https://github.com/SocketDotTech/socket-protocol.git lib/socket-protocol
git submodule update --init --recursive

# Commit the update
git commit -m "Update socket-protocol submodule to latest $BRANCH_NAME"
echo "SOCKET Protocol submodule updated successfully to branch $BRANCH_NAME!"
