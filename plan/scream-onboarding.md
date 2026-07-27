# Scream Code 接入陰陽眼 — 裝設前記錄

## 前 anchor（2026-07-27 16:05 UTC）

此線之後的紀錄才含 Scream。

## 狀態

Scream Code 無 hooks 目錄或 PreToolUse/PostToolUse 接點。
Claude Code 的 hook 在 `~/.claude/hooks/dbp-*`，不可直接複用。

### 待確認

1. Scream Code 是否有對等的 PreToolUse/PostToolUse hook 機制
2. Payload 形狀是否與 Claude Code 相容（樣本暫存於 `/tmp/scream-payload-sample.json`）
3. 註冊路徑與啟用方式

### 裝設前 ledger 狀態

edits: genesis 0
runs: genesis 0
