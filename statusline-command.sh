#!/usr/bin/env bash

input=$(cat)
echo "$input" > /tmp/claude_status.json

used_raw=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
[ -n "$used_raw" ] && used=$(printf "%.0f" "$used_raw") || used=""
model=$(echo "$input" | jq -r '.model.display_name // empty')

# Rate limit percentages from JSON
pct_5h_raw=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
[ -n "$pct_5h_raw" ] && pct_5h=$(printf "%.0f" "$pct_5h_raw") || pct_5h=""
pct_7d_raw=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
[ -n "$pct_7d_raw" ] && pct_7d=$(printf "%.0f" "$pct_7d_raw") || pct_7d=""


resets_at_5h=$(echo "$input" | jq -r 'if .rate_limits.five_hour.resets_at then (.rate_limits.five_hour.resets_at | floor | tostring) else empty end')
if [ -n "$resets_at_5h" ]; then
  now=$(date +%s)
  diff=$(( resets_at_5h - now ))
  [ "$diff" -gt 0 ] && reset_5h_secs="$diff" || reset_5h_secs=""
else
  reset_5h_secs=""
fi

resets_at_7d=$(echo "$input" | jq -r 'if .rate_limits.seven_day.resets_at then (.rate_limits.seven_day.resets_at | floor | tostring) else empty end')
if [ -n "$resets_at_7d" ]; then
  now=$(date +%s)
  diff=$(( resets_at_7d - now ))
  [ "$diff" -gt 0 ] && reset_7d_secs="$diff" || reset_7d_secs=""
else
  reset_7d_secs=""
fi

# Format 5h reset time (always hh:mm)
if [ -n "$reset_5h_secs" ] && [ "$reset_5h_secs" != "null" ]; then
  h5=$((reset_5h_secs / 3600))
  m5=$(( (reset_5h_secs % 3600) / 60 ))
  reset_5h_str=$(printf -- " .. %02d:%02d" "$h5" "$m5")
else
  reset_5h_str=""
fi

# Format 7d reset time: days when >=24h, else hh:mm
if [ -n "$reset_7d_secs" ] && [ "$reset_7d_secs" != "null" ]; then
  if [ "$reset_7d_secs" -gt 86400 ] 2>/dev/null; then
    days_7d=$((reset_7d_secs / 86400))
    reset_7d_str=" .. ${days_7d}d"
  else
    h7=$((reset_7d_secs / 3600))
    m7=$(( (reset_7d_secs % 3600) / 60 ))
    reset_7d_str=$(printf -- " .. %02d:%02d" "$h7" "$m7")
  fi
else
  reset_7d_str=""
fi

# Model + context percentage
if [ -n "$used" ]; then
  context_str="${model}  🧠  ${used}%"
else
  context_str="${model}  🧠  --%"
fi

# Rate limit strings
if [ -n "$pct_5h" ] && [ "$pct_5h" != "null" ]; then
  rate_5h_str="🕰️ ${pct_5h}%${reset_5h_str}"
else
  rate_5h_str=""
fi

if [ -n "$pct_7d" ] && [ "$pct_7d" != "null" ]; then
  rate_7d_str="📆 ${pct_7d}%${reset_7d_str}"
else
  rate_7d_str=""
fi

# Build output, skipping empty rate limit sections
parts=("$context_str")
[ -n "$rate_5h_str" ] && parts+=("$rate_5h_str")
[ -n "$rate_7d_str" ] && parts+=("$rate_7d_str")

separator="   "
result=""
for part in "${parts[@]}"; do
  [ -z "$result" ] && result="$part" || result="${result}${separator}${part}"
done
printf "%s" "$result"
