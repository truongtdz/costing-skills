#!/usr/bin/env bash
# Chụp toàn bộ working tree của một repo (kể cả thay đổi chưa commit và file chưa track,
# trừ file bị .gitignore) thành một tree SHA. Không đụng index, working tree, stash hay nhánh.
#
# Dùng:
#   snapshot.sh <đường dẫn repo>            → in tree SHA
#
# Diff của task = git -C <repo> diff <baseline> $(snapshot.sh <repo>)
set -euo pipefail

repo="${1:?Thiếu đường dẫn repo}"
git -C "$repo" rev-parse --git-dir >/dev/null

tmp_index="$(mktemp)"
trap 'rm -f "$tmp_index"' EXIT

# Bắt đầu từ index thật để giữ nguyên cờ và nội dung đã stage
cp "$(git -C "$repo" rev-parse --absolute-git-dir)/index" "$tmp_index" 2>/dev/null || rm -f "$tmp_index"

GIT_INDEX_FILE="$tmp_index" git -C "$repo" add -A
GIT_INDEX_FILE="$tmp_index" git -C "$repo" write-tree
