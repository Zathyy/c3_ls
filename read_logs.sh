#!/usr/bin/env sh

printf "$(cat ~/.local/state/nvim/lsp.log | sed -e 's/.*"stderr"\s*.//' | sed -e 's/.$//' | tr -d '\n')" | less
