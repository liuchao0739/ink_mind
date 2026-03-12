#!/bin/bash
export ANTHROPIC_BASE_URL="https://api.minimaxi.com/anthropic"
export ANTHROPIC_API_KEY="sk-cp-N1YYVST6Xsh-5_u_c1VADtfHufuLFWXKP-3ivwh1KfsZENdGmMMBTkPsNhkawZxbG8Hj3cIIdIsoCwpj6lHoThVZWmQXi0eT_POjVHhnvnx9YN9b1sj6x3I"
npx @anthropic-ai/claude-code --dangerously-skip-permissions "$@"
