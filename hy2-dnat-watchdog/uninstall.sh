#!/bin/bash
# ============================================================
# HY2 DNAT Watchdog 卸载脚本
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

[ "$(id -u)" -ne 0 ] && error "请使用 root 用户运行"

read -p "确认卸载 HY2 DNAT Watchdog？[y/N] " CONFIRM
[ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ] && { echo "已取消"; exit 0; }

# ---- 移除 cron ----
info "移除 cron 任务..."
if command -v crontab >/dev/null 2>&1; then
    TMP_CRON=$(mktemp)
    crontab -l 2>/dev/null | grep -v 'hy2-dnat-watchdog' > "$TMP_CRON" || true
    crontab "$TMP_CRON" 2>/dev/null || true
    rm -f "$TMP_CRON"
    info "cron 任务已移除"
else
    warn "未找到 crontab 命令，跳过 cron 移除"
fi

# ---- 清除防火墙规则 ----
WATCHDOG_MARK="hy2-dnat-watchdog"

# 读取配置判断后端（如果没有配置则两种后端规则都清理）
BACKEND=""
if [ -f /etc/hy2-dnat-watchdog.conf ]; then
    source /etc/hy2-dnat-watchdog.conf 2>/dev/null
fi

# 如果 BACKEND 未知，两种都清理
if [ -z "$BACKEND" ]; then
    info "未找到 BACKEND 配置，同时清理 nftables 和 iptables 规则"
fi

# ---- nftables 规则清理 ----
if [ -z "$BACKEND" ] || [ "$BACKEND" = "nftables" ]; then
    info "清除 nftables 规则..."
    if command -v nft >/dev/null 2>&1; then
        # 删除 watchdog 专用表（连同里面的规则）
        nft delete table inet hysteria_porthopping 2>/dev/null && info "已删除 inet hysteria_porthopping 表" || true

        # 清理其他 nft 链里的 watchdog 规则（只删带 comment 标记的）
        for fam in ip ip6; do
            for chain_name in prerouting PREROUTING; do
                nft list chain $fam nat $chain_name 2>/dev/null | grep -q . || continue
                nft -a list chain $fam nat $chain_name 2>/dev/null \
                    | grep "$WATCHDOG_MARK" \
                    | grep -oP 'handle \K\d+' \
                    | while read h; do
                        nft delete rule $fam nat $chain_name handle "$h" 2>/dev/null || true
                    done
                info "已清理 $fam nat $chain_name 中 watchdog 标记规则"
                # 注意：不删除 ip/ip6 nat 表本身，可能被其他工具使用
            done
        done
    fi
fi

# ---- iptables 规则清理 ----
if [ -z "$BACKEND" ] || [ "$BACKEND" = "iptables" ]; then
    info "清除 iptables 规则..."
    # 新版 iptables 规则带 comment 标记，可以精确删除（不误伤宝塔规则）
    for cmd in iptables ip6tables; do
        if command -v $cmd >/dev/null 2>&1; then
            $cmd -t nat -S PREROUTING 2>/dev/null | grep "$WATCHDOG_MARK" | while read rule; do
                del_rule=$(echo "$rule" | sed 's/^-A /-D /')
                $cmd -t nat $del_rule 2>/dev/null && info "已清理 $cmd nat PREROUTING 中 watchdog 标记规则"
            done
        fi
    done

    # 兼容非常老的版本：删除无 comment 标记的 REDIRECT 规则
    # 仅删除 REDIRECT 到 40000-65535 范围 UDP 端口的规则（HY2 端口必然在此范围）
    # 若有其他相同特征的转发规则需用户手动处理
    if command -v iptables >/dev/null 2>&1; then
        iptables -t nat -S PREROUTING 2>/dev/null | grep 'REDIRECT.*--to-ports' | grep -v "$WATCHDOG_MARK" | while read rule; do
            port=$(echo "$rule" | grep -oP 'to-ports \K\d+' || true)
            if [ -n "$port" ] && [ "$port" -ge 40000 ] 2>/dev/null && [ "$port" -le 65535 ] 2>/dev/null; then
                iptables -t nat -D PREROUTING $(echo "$rule" | sed 's/^-A //') 2>/dev/null || true
                warn "已删除无标记旧版 watchdog 规则（UDP REDIRECT --to-ports $port），如误删请手动重建"
            fi
        done
    fi
fi

# ---- 删除文件 ----
info "删除文件..."
rm -f /usr/local/bin/hy2-dnat-watchdog.sh
rm -f /etc/hy2-dnat-watchdog.conf
rm -f /var/run/hy2-dnat-watchdog.state
rm -f /var/log/hy2-dnat-watchdog.log
rm -f /tmp/hy2-dnat-watchdog.lock

echo ""
echo "卸载完成"
