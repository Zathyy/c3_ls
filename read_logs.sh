#!/usr/bin/env sh

printf "$(tail -300 ~/.local/state/nvim/lsp.log | sed -e 's/.*"stderr"\s*.//' | sed -e 's/.$//' | tr -d '\n')"
