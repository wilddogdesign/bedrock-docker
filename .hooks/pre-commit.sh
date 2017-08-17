#!/bin/sh

LOCAL=$(cd templates && git rev-parse HEAD)
REMOTE=$(cd templates && git ls-remote origin -h refs/heads/master | cut -f1)

if [ "$LOCAL" = "$REMOTE" ]; then
  echo "The templates are synced. Carrying on..."
  exit 0
else
  echo "The templates submodule doesn't seem to be synced. Update it, and try to commit again"
  exit 1
fi
