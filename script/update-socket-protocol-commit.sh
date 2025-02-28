#!/bin/bash

# Check if there are modified or staged files
if [[ -n $(git status --porcelain) ]]; then
  echo "Error: You have uncommitted changes. Commit or stash them before running this script."
  exit 1
fi

# Nuke the submodule
git submodule deinit -f lib/socket-protocol
rm -rf .git/modules/lib/socket-protocol
git rm -rf lib/socket-protocol

# Re-add the submodule
git submodule add -b staging https://github.com/SocketDotTech/socket-protocol.git lib/socket-protocol
git submodule update --init --recursive

# Commit the update
git commit -m "Update socket-protocol submodule"

echo "SOCKET Protocol submodule updated successfully!"
