#!/usr/bin/env bash
#
# xboard-node 涓€閿畨瑁呰剼鏈紙甯﹁瘉涔︽寚绾逛笂鎶ヨˉ涓佺増锛?# 浠撳簱: https://github.com/pandanetworkgroup/xboard-node-key
#
# 涓€琛屽懡浠ゅ畨瑁咃紙鎺ㄨ崘锛?
#   curl -fsSL https://raw.githubusercontent.com/pandanetworkgroup/xboard-node-key/main/install.sh \
#     | sudo bash -s -- --mode machine --panel 'https://node.example.com' \
#                          --token 'machine_token_here' --machine-id 1
#
# 浜や簰寮忓畨瑁咃紙鍏堜笅杞借剼鏈級:
#   curl -fsSL https://raw.githubusercontent.com/pandanetworkgroup/xboard-node-key/main/install.sh -o install.sh
#   sudo bash install.sh
#
set -euo pipefail

# ==================== 甯搁噺 ====================
REPO="pandanetworkgroup/xboard-node-key"
INSTALL_DIR="/etc/xboard-node"
BIN_PATH="/usr/local/bin/xboard-node"
SERVICE_FILE="/etc/systemd/system/xboard-node.service"
SCRIPT_VERSION="1.0.0"

DEF_HEALTH_PORT=65530
DEF_KERNEL="singbox"
DEF_LOG_LEVEL="info"

# ==================== 鏃ュ織 ====================
if [ -t 2 ]; then
    C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_OFF=$'\033[0m'
else
    C_GREEN=''; C_YELLOW=''; C_RED=''; C_OFF=''
fi
log()  { printf '%s[install]%s %s\n' "$C_GREEN"  "$C_OFF" "$*"; }
warn() { printf '%s[warn]%s %s\n'    "$C_YELLOW" "$C_OFF" "$*" >&2; }
die()  { printf '%s[error]%s %s\n'   "$C_RED"    "$C_OFF" "$*" >&2; exit 1; }

# ==================== 鍙傛暟 ====================
MODE=""
PANEL_URL=""
TOKEN=""
MACHINE_ID=""
INSTANCE_ID_OVERRIDE=""
HEALTH_PORT=""
KERNEL=""
LOG_LEVEL=""
FORCE=0
SKIP_DOWNLOAD=0

usage() {
    cat <<'EOF'
xboard-node 涓€閿畨瑁呰剼鏈紙甯﹁瘉涔︽寚绾硅ˉ涓佺増锛?
涓€琛屽懡浠ゅ畨瑁?
  curl -fsSL https://raw.githubusercontent.com/pandanetworkgroup/xboard-node-key/main/install.sh \
    | sudo bash -s -- --mode machine --panel 'https://node.example.com' \
                         --token 'xxx' --machine-id 1

浜や簰寮忓畨瑁?
  sudo bash install.sh          # 鑴氭湰浼氶€愰」璇㈤棶
  sudo bash install.sh --help   # 鏄剧ず鏈府鍔?
鍙傛暟:
  --mode machine          閰嶇疆妯″紡锛堝綋鍓嶄粎鏀寔 machine锛?  --panel URL             闈㈡澘璁块棶鍦板潃锛堝 https://node.178278.xyz锛?  --token TOKEN           闈㈡澘瀵煎嚭鐨?machine token
  --machine-id N          闈㈡澘涓殑 machine id锛堟暟瀛楋級
  --instance-id ID        鑷畾涔?instance_id锛堥粯璁ゆ寜瑙勫垯鑷姩鐢熸垚锛?  --health-port PORT      鍋ュ悍妫€鏌ョ鍙ｏ紙榛樿 65530锛?  --kernel TYPE           singbox 鎴?xray锛堥粯璁?singbox锛?  --log-level LEVEL       info / warn / error / debug锛堥粯璁?info锛?  --force                 寮哄埗瑕嗙洊宸插瓨鍦ㄧ殑 config.yml锛堥粯璁ゅ崌绾фā寮忓彧鎹簩杩涘埗锛?  --skip-download         涓嶄笅杞戒簩杩涘埗锛堝鐢ㄥ凡瀛樺湪鐨?/usr/local/bin/xboard-node锛?  -h, --help              鏄剧ず鏈府鍔?EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --mode)          MODE="$2"; shift 2 ;;
        --panel)         PANEL_URL="$2"; shift 2 ;;
        --token)         TOKEN="$2"; shift 2 ;;
        --machine-id)    MACHINE_ID="$2"; shift 2 ;;
        --instance-id)   INSTANCE_ID_OVERRIDE="$2"; shift 2 ;;
        --health-port)   HEALTH_PORT="$2"; shift 2 ;;
        --kernel)        KERNEL="$2"; shift 2 ;;
        --log-level)     LOG_LEVEL="$2"; shift 2 ;;
        --force)         FORCE=1; shift ;;
        --skip-download) SKIP_DOWNLOAD=1; shift ;;
        -h|--help)       usage; exit 0 ;;
        --)              shift; break ;;
        *)               die "鏈煡鍙傛暟: $1锛堢敤 --help 鏌ョ湅鐢ㄦ硶锛? ;;
    esac
done

# ==================== root 妫€鏌?====================
[ "$(id -u)" -eq 0 ] || die "璇风敤 root 杩愯锛堟垨鍔?sudo锛?

# ==================== 浜や簰寮忚ˉ鍏?====================
NEED_INTERACTIVE=0
[ -z "$MODE" ]        && NEED_INTERACTIVE=1
[ -z "$PANEL_URL" ]   && NEED_INTERACTIVE=1
[ -z "$TOKEN" ]       && NEED_INTERACTIVE=1
[ -z "$MACHINE_ID" ]  && NEED_INTERACTIVE=1

if [ $NEED_INTERACTIVE -eq 1 ]; then
    if [ ! -t 0 ]; then
        die "閫氳繃绠￠亾锛坈url | bash锛夋墽琛屾椂蹇呴』浼犲叏閮ㄥ繀濉弬鏁般€俓n         闇€瑕佷氦浜掓ā寮忚鍏堜笅杞借剼鏈?\n         curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh -o install.sh && sudo bash install.sh"
    fi
    log "杩涘叆浜や簰寮忛棶绛旀ā寮?
    MODE="machine"
    [ -z "$PANEL_URL" ]  && read -rp "闈㈡澘鍦板潃锛堝甫 https://锛? " PANEL_URL
    [ -z "$TOKEN" ]      && read -rp "machine token: " TOKEN
    [ -z "$MACHINE_ID" ] && read -rp "machine id锛堟暟瀛楋級: " MACHINE_ID
fi

[ -z "$HEALTH_PORT" ] && HEALTH_PORT=$DEF_HEALTH_PORT
[ -z "$KERNEL" ]      && KERNEL=$DEF_KERNEL
[ -z "$LOG_LEVEL" ]   && LOG_LEVEL=$DEF_LOG_LEVEL

# ==================== 鍩烘湰鏍￠獙 ====================
[ "$MODE" = "machine" ] || die "褰撳墠浠呮敮鎸?--mode machine"
[[ "$PANEL_URL" =~ ^https?://[a-zA-Z0-9.:-]+ ]] || die "panel URL 鏃犳晥锛堥』 http(s):// 寮€澶达級"
[[ "$MACHINE_ID" =~ ^[0-9]+$ ]] || die "machine-id 蹇呴』鏄暟瀛?
[ -n "$TOKEN" ] || die "token 涓嶈兘涓虹┖"

# ==================== 鑷姩鐢熸垚 instance_id ====================
if [ -z "$INSTANCE_ID_OVERRIDE" ]; then
    panel_host=$(echo "$PANEL_URL" | sed -E 's#^https?://##; s#/.*$##; s#:.*$##')
    clean_host=$(echo "$panel_host" | tr '.' '-')
    hash_input="${MACHINE_ID}|${PANEL_URL}|${TOKEN}"
    if command -v sha256sum >/dev/null 2>&1; then
        h=$(printf '%s' "$hash_input" | sha256sum | cut -c1-6)
    elif command -v shasum >/dev/null 2>&1; then
        h=$(printf '%s' "$hash_input" | shasum -a 256 | cut -c1-6)
    else
        h=$(printf '%s' "$hash_input" | openssl dgst -sha256 -hex 2>/dev/null | grep -oE '[0-9a-f]{6}' | head -1)
    fi
    [ -n "$h" ] || die "鏃犳硶璁＄畻 instance hash锛堢己 sha256sum / shasum / openssl锛?
    INSTANCE_ID="node-${clean_host}-machine-${MACHINE_ID}-${h}"
else
    INSTANCE_ID="$INSTANCE_ID_OVERRIDE"
fi
TOKEN_ENV_NAME="INSTANCE_$(echo "$INSTANCE_ID" | tr '[:lower:]' '[:upper:]' | tr '-' '_')_MACHINE_TOKEN"

log "instance_id:  $INSTANCE_ID"
log "token_env:    $TOKEN_ENV_NAME"

# ==================== 鐜版湁閮ㄧ讲妫€娴?====================
SKIP_CONFIG=0
if [ -f "$INSTALL_DIR/config.yml" ] && [ $FORCE -eq 0 ]; then
    log "妫€娴嬪埌宸叉湁 config.yml锛堝崌绾фā寮忥細浠呮浛鎹簩杩涘埗锛屼繚鐣欓厤缃級"
    SKIP_CONFIG=1
else
    log "鍏ㄦ柊閮ㄧ讲"
fi

# ==================== 鍒涘缓鐩綍 ====================
mkdir -p "$INSTALL_DIR/instances" "$INSTALL_DIR/backups"
chmod 700 "$INSTALL_DIR"

# ==================== 涓嬭浇浜岃繘鍒?====================
TS=$(date +%Y%m%d%H%M%S)
if [ $SKIP_DOWNLOAD -eq 0 ]; then
    log "鏌ヨ鏈€鏂?Release..."
    REL_JSON=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || true)
    ASSET_URL=$(echo "$REL_JSON" | grep -oE '"browser_download_url":[[:space:]]*"[^"]+"' \
                | grep -E 'linux-amd64' | head -1 | sed -E 's/.*"([^"]+)"$/\1/')
    [ -n "$ASSET_URL" ] || die "鏈壘鍒?Release 涓殑 linux-amd64 璧勪骇銆俓n         璇峰厛鍦?$REPO 浠撳簱鍒涘缓 Release 骞朵笂浼犱簩杩涘埗銆?

    log "涓嬭浇: $ASSET_URL"
    tmp_dl=$(mktemp)
    curl -fL -o "$tmp_dl" "$ASSET_URL"
    chmod +x "$tmp_dl"

    if ! file "$tmp_dl" 2>/dev/null | grep -q 'ELF'; then
        rm -f "$tmp_dl"
        die "涓嬭浇鐨勬枃浠朵笉鏄?ELF 浜岃繘鍒?
    fi

    if [ -f "$BIN_PATH" ]; then
        log "澶囦唤鏃т簩杩涘埗 -> $BIN_PATH.bak.$TS"
        cp -a "$BIN_PATH" "$BIN_PATH.bak.$TS"
    fi

    log "瀹夎浜岃繘鍒跺埌 $BIN_PATH"
    mv -f "$tmp_dl" "$BIN_PATH"
    chmod +x "$BIN_PATH"
    log "浜岃繘鍒跺ぇ灏? $(wc -c < "$BIN_PATH") 瀛楄妭"
else
    log "璺宠繃涓嬭浇锛屽鐢ㄥ凡鏈?$BIN_PATH"
    [ -f "$BIN_PATH" ] || die "--skip-download 鎸囧畾浜嗕絾 $BIN_PATH 涓嶅瓨鍦?
fi

# ==================== 鐢熸垚閰嶇疆 ====================
if [ $SKIP_CONFIG -eq 0 ]; then
    CONFIG_DIR="$INSTALL_DIR/instances/$INSTANCE_ID"
    mkdir -p "$CONFIG_DIR"

    log "鐢熸垚 config.yml"
    cat > "$INSTALL_DIR/config.yml" <<EOF
instances:
    - id: $INSTANCE_ID
      panel:
        url: $PANEL_URL
      kernel:
        type: $KERNEL
        config_dir: $CONFIG_DIR
        log_level: warn
      log:
        level: $LOG_LEVEL
        output: stdout
      health_port: $HEALTH_PORT
      machine:
        machine_id: $MACHINE_ID
        token_env: $TOKEN_ENV_NAME
EOF
    chmod 600 "$INSTALL_DIR/config.yml"

    log "鐢熸垚 credentials.env"
    printf '%s=%s\n' "$TOKEN_ENV_NAME" "$TOKEN" > "$INSTALL_DIR/credentials.env"
    chmod 600 "$INSTALL_DIR/credentials.env"

    log "鐢熸垚 install-meta.json"
    cat > "$INSTALL_DIR/install-meta.json" <<EOF
{
  "config_mode": "instances",
  "version": "latest",
  "latest_instance_id": "$INSTANCE_ID",
  "instance_count": 1,
  "instances": [
    {
      "id": "$INSTANCE_ID",
      "panel_url": "$PANEL_URL",
      "mode": "machine",
      "node_id": null,
      "machine_id": $MACHINE_ID,
      "health_port": $HEALTH_PORT
    }
  ],
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    chmod 600 "$INSTALL_DIR/install-meta.json"
else
    log "淇濈暀鐜版湁 config.yml / credentials.env / install-meta.json"
fi

# ==================== systemd 鍗曞厓 ====================
log "鍐欏叆 systemd service unit"
cat > "$SERVICE_FILE" <<'EOF'
[Unit]
Description=Xboard Node Backend (cert-pin patched)
Documentation=https://github.com/pandanetworkgroup/xboard-node-key
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/etc/xboard-node
EnvironmentFile=-/etc/xboard-node/credentials.env
ExecStart=/usr/local/bin/xboard-node -c /etc/xboard-node/config.yml
Restart=always
RestartSec=5
LimitNOFILE=1048576
NoNewPrivileges=true
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xboard-node 2>/dev/null || true

# ==================== 鍚姩 ====================
log "閲嶅惎 xboard-node 鏈嶅姟"
systemctl restart xboard-node
sleep 3

if systemctl is-active --quiet xboard-node; then
    log "鏈嶅姟鐘舵€? active"
else
    warn "鏈嶅姟鏈?active锛屼笅闈㈡槸鏈€杩戞棩蹇楋細"
    journalctl -u xboard-node -n 30 --no-pager || true
    die "閮ㄧ讲澶辫触"
fi

# ==================== 瀹屾垚 ====================
echo
log "============ 閮ㄧ讲瀹屾垚 ============"
log "instance_id: $INSTANCE_ID"
log "machine_id:  $MACHINE_ID"
log "panel_url:   $PANEL_URL"
log "binary:      $BIN_PATH ($(wc -c < "$BIN_PATH") bytes)"
log "config:      $INSTALL_DIR/config.yml"
echo
log "鏌ョ湅鏃ュ織: journalctl -u xboard-node -f"
log "楠岃瘉涓婃姤: 绛?60-90s 鍚庡湪闈㈡澘 DB 鏌?v2_server.cert_fingerprint / cert_pem"
log "鍥炴粴:     sudo cp $BIN_PATH.bak.* $BIN_PATH && sudo systemctl restart xboard-node"
