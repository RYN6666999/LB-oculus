# dbp-preexec.sh — 被 install-shell-hook.sh 注入 ~/.zshrc 的 shell 指令帳。
#
# 每條指令執行前（preexec）記下指令文字與時間戳，
# 執行後（precmd）記下退出碼，透過 dbp _chain-append 寫進 ledger/_runs.jsonl。
#
# 為什麼不直接寫 JSONL（要繞一圈給 dbp）：
#   鐵律一與凍結核心 K。prev 雜湊算式只存在 bin/dbp 內。
#   hook 若自算 prev 就破壞了「四函式唯一位址化」。（見 redteam 012）
#
# 效能：
#   preexec 用 $EPOCHREALTIME（zsh 內建），不啟動子行程，<0.1ms。
#   precmd 的 dbp 呼叫放背景（2>/dev/null &），不阻塞提示出現。
#
# 缺點（已知）：
#   - 背景寫入有 race condition：快速連續兩條指令可能共用同一個 prev。
#     鏈在極罕見情形下可能中斷。這是用效能換的取捨，記錄在案。
#   - dbp 不在 PATH 或壞掉時，靜默跳過，不影響 shell 操作。

if [ -n "$ZSH_VERSION" ]; then
  zmodload zsh/datetime 2>/dev/null

  __dbp_preexec() {
    __dbp_last_cmd="$1"
    __dbp_last_ts=$EPOCHREALTIME
  }

  __dbp_precmd() {
    local code=$?
    [ -n "${__dbp_last_cmd:-}" ] && {
      # 背景子 shell 寫入，不阻塞 shell，不怕 SIGHUP
      ( printf '{"ts":%s,"cmd":"%s","code":%d}\n' \
          "${__dbp_last_ts:-0}" \
          "${__dbp_last_cmd//\"/\\\"}" \
          "$code" \
        | ~/.local/bin/dbp _chain-append runs 2>/dev/null ) &
      unset __dbp_last_cmd
    }
  }

  autoload -Uz add-zsh-hook
  add-zsh-hook preexec __dbp_preexec
  add-zsh-hook precmd __dbp_precmd
fi