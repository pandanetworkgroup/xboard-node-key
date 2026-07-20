---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '24070195-4c78-4a1e-be94-01c5a2c52a76'
  PropagateID: '24070195-4c78-4a1e-be94-01c5a2c52a76'
  ReservedCode1: '43d7fb4c-c6cd-489b-8a32-e90781b29095'
  ReservedCode2: '43d7fb4c-c6cd-489b-8a32-e90781b29095'
---

# HY2 DNAT Watchdog 部署教程

## 功能说明

自动监控 xboard-node 的 Hysteria2 端口变化，动态生成 DNAT 端口转发规则。

**规则逻辑**：HY2 监听端口 N → 转发 UDP N ~ N+OFFSET 到 N（OFFSET 默认 10000，可调）

例：HY2 端口 40000，OFFSET=10000，则 40000-50000 范围的 UDP 流量全部转发到 40000

偏移量 OFFSET 可在部署时用 `install.sh --offset K` 指定，也可在运行时随时用 `hy2-dnat-watchdog.sh --offset K` 修改并立即生效（见[命令行参数](#命令行参数)）。

---

## 一、快速部署

### 1. 上传脚本到服务器

```bash
# 方式一：scp 上传
scp hy2-dnat-watchdog-install.sh root@你的服务器IP:/root/

# 方式二：服务器上直接从 GitHub 下载
curl -O https://raw.githubusercontent.com/pandanetworkgroup/xboard-node-key/main/hy2-dnat-watchdog/install.sh
curl -O https://raw.githubusercontent.com/pandanetworkgroup/xboard-node-key/main/hy2-dnat-watchdog/uninstall.sh
```

### 2. 执行一键部署

```bash
bash hy2-dnat-watchdog-install.sh
```

脚本会自动：
- 检测对外网卡名（通过默认路由获取，无需手动指定）
- 自动选择防火墙后端（检测到宝塔/aapanel 等面板时用 iptables，否则用 nftables，详见[防火墙后端说明](#二防火墙后端说明双后端自动选择)）
- 没有安装 nftables 时自动在线安装
- 支持 `--offset K` 指定偏移量（默认 10000）
- 部署 watchdog 脚本到 `/usr/local/bin/`
- 首次运行并生成 DNAT 规则
- 自动安装 cron（如缺失）并设置每分钟定时任务
- 写入后验证 cron 是否生效

### 3. 关于网卡名

脚本会通过 `ip route` 自动检测默认路由对应的网卡名（如 eth0、ens3、enp1s0 等），通常无需手动修改。

如果自动检测不正确，可以手动指定：

```bash
# 编辑配置文件
vi /etc/hy2-dnat-watchdog.conf
# 修改 IFACE=你的网卡名
```

---

## 二、防火墙后端说明（双后端自动选择）

watchdog 支持两种后端，install 脚本在部署时根据是否检测到面板自动选择：

| 环境 | 检测条件 | 后端 | 规则所在 |
|------|---------|------|--------|
| 无面板 | `/www/server/panel`、`/usr/local/aapanel`、`/opt/1panel`、`/etc/casaos` 均不存在 | **nftables** | `table inet hysteria_porthopping`（专用表） |
| 有面板 | 检测到上述任一路径 | **iptables** | `iptables/ip6tables -t nat PREROUTING`（带 comment 标记） |

后端选择写入配置文件 `/etc/hy2-dnat-watchdog.conf` 的 `BACKEND` 字段，watchdog 运行时读取该字段决定走哪条路径。用户通常无需手动修改 `BACKEND`，重新跑 install 脚本即可自动重新判定。

### 为什么不强制 nftables

- **nftables 路径优势**：用 `table inet` 双栈表，一条规则同时处理 IPv4+IPv6；专用表 `hysteria_porthopping` 不污染系统 nat 表；声明式 `define` + `nft -f` 加载，可读性好。
- **但**：宝塔/aapanel 等面板自身的防火墙模块依赖 iptables 命令，如果强制改用 nftables 专用表，面板的“端口转发”页面可能与 nft 规则产生优先级冲突或互相覆盖。
- 因此装了面板时改走 iptables 后端，watchdog 只在 `PREROUTING` 链添加带 `comment "hy2-dnat-watchdog"` 标记的规则，绝不触碰面板写的其他规则。

### nftables 后端规则格式（watchdog 跳变时动态生成）
```
define INGRESS_INTERFACE="ens18"
define DNAT_RANGE=40000-50000
define HYSTERIA_SERVER_PORT=40000

table inet hysteria_porthopping {
  chain prerouting {
    type nat hook prerouting priority dstnat; policy accept;
    iifname $INGRESS_INTERFACE udp dport $DNAT_RANGE counter redirect to :$HYSTERIA_SERVER_PORT comment "hy2-dnat-watchdog"
  }
}
```

`define` 的值由 watchdog 运行时从实际检测的网卡和 HY2 端口动态注入；`$VAR` 是 nft 变量引用，由 `nft -f` 加载时替换为字面值。

规则末尾的 `comment "hy2-dnat-watchdog"` 是唯一标记，用于在与其他工具共存时精确识别 watchdog 自己的规则（详见下文“与其他工具共存”）。

### iptables 后端规则格式

iptables 后端在 `iptables` 和 `ip6tables` 各添加一条规则，均带 `-m comment --comment "hy2-dnat-watchdog"` 标记，可用 `iptables -t nat -S PREROUTING` 查看：

```
-A PREROUTING -i ens18 -p udp -m udp --dport 55000:65000 -m comment --comment hy2-dnat-watchdog -j REDIRECT --to-ports 55000
```

- 端口范围用 `start:end` 语法（不同于 nftables 的 `start-end`）
- 目标用 `REDIRECT --to-ports N`（不同于 nftables 的 `redirect to :N`）
- 清理时只删除带 comment 标记的规则，绝不删除链上其他来源的规则

---

## 三、与其他工具共存（重要）

watchdog 设计为只管理自己写的规则，**绝不触碰其他工具的 NAT 规则**。

### 工作机制

- 所有 watchdog 生成的规则都带 `comment "hy2-dnat-watchdog"` 标记
- 清理逻辑只删除带这个 comment 标记的规则
- 对于其他来源的规则（宝塔/aapanel/WAF/docker 的端口转发等），**只检测、不删除**
- 检测到无 comment 标记的 redirect 规则时，日志会写一条 WARN 提示用户手动核查
- 不删除 `table ip nat` / `table ip6 nat` 表本身，即使它们为空（这些表可能被其他工具预留）

### 与宝塔/aapanel/1Panel/CasaOS 共存（自动切换 iptables 后端）

如果 install 检测到你装了面板（通过查找 `/www/server/panel`、`/usr/local/aapanel`、`/opt/1panel`、`/etc/casaos` 等路径），会**自动切换到 iptables 后端**并保留 iptables 不卸载。此时：

- watchdog 在 `iptables/ip6tables -t nat PREROUTING` 链添加带 `comment "hy2-dnat-watchdog"` 标记的规则
- 面板自己配置的端口转发规则也写在 PREROUTING 链，但**不会被 watchdog 触碰**
- uninstall 卸载时只删除带 watchdog comment 标记的规则，面板规则完整保留

如果你安装了宝塔面板，但**未走自动检测流程**（例如手动部署后 later 装了面板，现在还在用 nftables 后端），面板里的端口转发会写在 `table ip nat prerouting` 链里，watchdog 也不会动它们。如果日志里出现类似下面的提示：

```
WARN: ip nat prerouting 检测到 2 条无 comment 标记的 redirect 规则（可能是旧版 watchdog 残留，也可能是宝塔/WAF 等工具的转发规则），未自动删除
```

用下面的命令查看这些规则，确认是不是你自己的转发配置：
```bash
nft -a list chain ip nat prerouting
```

- 如果是宝塔/WAF 等工具的转发规则 → 保持不动，无需处理
- 如果确认是旧版 watchdog 的残留 → 手动删除：
  ```bash
  # 用 handle 删除（替换 handle 号）
  nft delete rule ip nat prerouting handle <handle号>
  ```

### 与 docker/k8s 共存

watchdog 使用独立的 `table inet hysteria_porthopping` 表，与 docker 的 `table ip nat` 表完全隔离，互不影响。

---

## 四、常用运维命令

```bash
# 手动触发一次检测
/usr/local/bin/hy2-dnat-watchdog.sh

# 实时查看日志
tail -f /var/log/hy2-dnat-watchdog.log

# 查看当前 HY2 端口状态
cat /var/run/hy2-dnat-watchdog.state

# 查看当前使用的后端（iptables 或 nftables）
grep BACKEND /etc/hy2-dnat-watchdog.conf

# 查看当前 DNAT 规则（nftables 后端）
nft list table inet hysteria_porthopping

# 查看当前 DNAT 规则（iptables 后端，装了面板时）
iptables -t nat -S PREROUTING | grep hy2-dnat-watchdog
ip6tables -t nat -S PREROUTING | grep hy2-dnat-watchdog

# 查看完整 nftables 规则集（含系统其他规则）
nft list ruleset

# 查看当前状态（偏移量、HY2 端口、DNAT 范围、活动规则）
/usr/local/bin/hy2-dnat-watchdog.sh --show

# 运行时修改偏移量并立即生效（写回 conf + 强制重生成规则）
/usr/local/bin/hy2-dnat-watchdog.sh --offset 20000

# 修改配置（旧方式，需手动删 state 触发重建）
vi /etc/hy2-dnat-watchdog.conf

# 强制刷新规则（删除 state 后下次 cron 自动重建）
rm -f /var/run/hy2-dnat-watchdog.state
```

---

## 命令行参数

### install.sh

```
bash hy2-dnat-watchdog-install.sh [OPTIONS]
```

| 选项 | 说明 |
| --- | --- |
| `--offset K` | 自定义偏移量 K（默认 10000）。语义：HY2 监听端口 N → 转发 UDP N..N+K 到 N。K 必须是 1..65534 之间的整数，超过 65535 自动截断 |
| `--help, -h` | 显示帮助 |

部署后修改 offset **无需重装**，用下面的 watchdog 运行时命令即可。

### hy2-dnat-watchdog.sh

不带参数运行时，watchdog 读取配置、检测 HY2 端口、按需更新 DNAT 规则（cron 每分钟调用）。

| 选项 | 说明 |
| --- | --- |
| `--offset K` | 设置偏移量为 K，写回 `/etc/hy2-dnat-watchdog.conf`，触发强制规则重建。K 必须是 1..65534 的整数 |
| `--show` | 只读打印当前 offset、HY2 端口、DNAT 范围和活动规则，不做任何修改 |
| `--help, -h` | 显示帮助 |

示例：

```bash
# 把偏移量从默认 10000 改成 20000 并立即生效
/usr/local/bin/hy2-dnat-watchdog.sh --offset 20000

# 查看当前状态
/usr/local/bin/hy2-dnat-watchdog.sh --show
```

无效参数（如 `abc`、`0`、`99999`、缺少值、未知选项）会打印错误并以 exit code 2 退出，不修改任何配置或规则。

---

## 五、卸载

```bash
bash hy2-dnat-watchdog-uninstall.sh
```

会交互确认后清除 cron、防火墙规则、脚本和配置文件（脚本/配置/日志/状态/锁）。仅删除带 `comment "hy2-dnat-watchdog"` 标记的规则，不影响面板/docker 等其他来源的 NAT 规则。

---

## 六、文件清单

| 文件 | 说明 |
|---|---|
| `/usr/local/bin/hy2-dnat-watchdog.sh` | 主脚本 |
| `/etc/hy2-dnat-watchdog.conf` | 配置文件 |
| `/var/log/hy2-dnat-watchdog.log` | 运行日志 |
| `/var/run/hy2-dnat-watchdog.state` | 端口状态（上次检测到的 HY2 端口） |

---

## 七、工作原理

1. 每 1 分钟由 cron 触发
2. 从配置文件 `/etc/hy2-dnat-watchdog.conf` 读取 `BACKEND` 字段（iptables 或 nftables）
3. 从 `journalctl` 日志匹配 `[hysteria2:PORT]` 获取 HY2 端口
4. 用 `ss` 验证该端口确实在监听（防止日志过时），日志端口与实际监听不符时回退到实际监听端口
5. 与上次 state 对比，同时验证实际规则是否一致
6. **只有端口变化或规则不匹配时**才执行 cleanup_legacy_rules（避免每分钟无谓清理造成瞬态 UDP 中断）
7. cleanup 只删除带 `comment "hy2-dnat-watchdog"` 标记的规则，绝不触碰其他来源的规则
8. 根据 BACKEND 生成对应格式的规则：
   - **nftables**：声明式 `define` + `nft -f` 规则文件加载，专用 `table inet hysteria_porthopping`
   - **iptables**：`iptables/ip6tables -t nat -A PREROUTING ... -j REDIRECT --to-ports N -m comment --comment "hy2-dnat-watchdog"`
9. 端口范围 N → N+OFFSET（默认 10000），超出 65535 自动截断
10. 更新后立即验证：
    - nftables 后端用 `nft list table` 检查 `redirect to :N`
    - iptables 后端用 `iptables -t nat -S` 检查 `--to-ports N`（注意 grep 时用 `--` 分隔符避免 pattern 以 `--` 开头被当成长选项）
11. 验证失败不写 state，下次 cron 重试

---

## 八、故障排查

### 规则没更新

```bash
# 1. 看 cron 是否在跑
crontab -l | grep watchdog

# 2. 看 cron 服务是否运行
systemctl status cron 2>/dev/null || systemctl status crond 2>/dev/null

# 3. 看最近日志
tail -20 /var/log/hy2-dnat-watchdog.log

# 4. 手动运行看输出
rm -f /var/run/hy2-dnat-watchdog.state
bash -x /usr/local/bin/hy2-dnat-watchdog.sh 2>&1 | tail -30
```

### cron 任务没写入

部署脚本会自动安装 cron（如缺失），但如果手动遇到问题：

```bash
# 安装 cron
apt-get install -y cron      # Ubuntu/Debian
yum install -y cronie        # CentOS/AlmaLinux

# 启动服务
systemctl enable --now cron  # 或 systemctl enable --now crond

# 手动添加任务
crontab -e
# 添加这行：
# * * * * * /usr/local/bin/hy2-dnat-watchdog.sh
```

### 网卡名检测错误

```bash
# 查看自动检测到的网卡
ip route get 1.1.1.1 | grep -oP 'dev \K\S+'

# 手动指定
vi /etc/hy2-dnat-watchdog.conf
# 改 IFACE=ens3 或其他正确的网卡名
```

### nft: command not found

本脚本依赖 nftables，如果系统缺失：
```bash
# Ubuntu/Debian
apt-get update && apt-get install -y nftables

# CentOS/AlmaLinux
yum install -y nftables
```

### 后端切换时的清理

watchdog 的卸载/安装流程会自动处理规则清理：

- install 时若检测到面板，会保留 iptables 不卸载（兼容面板需要），并把后端设为 iptables
- install 时若未检测到面板，会尝试卸载 iptables 并把后端设为 nftables
- uninstall 卸载时只删除带 `comment "hy2-dnat-watchdog"` 标记的规则，绝不 flush 整个 PREROUTING 链，绝不删除 `table ip nat` / `table ip6 nat` 本身（这些表可能被 docker/k8s/WAF 使用）

**已知修复**：早期版本 cleanup_legacy_rules 在脚本开头执行（每次 cron 都跑），会导致 iptables 后端误删自己的规则再重建（每分钟一次瞬态 UDP 中断）。当前版本已修复为只在 `NEED_UPDATE=true`（端口变化或规则不匹配）时执行 cleanup。如运行中发现异常，请检查 watchdog 脚本里 `cleanup_legacy_rules` 的调用位置应该在 `if [ "$NEED_UPDATE" = false ]; then exit 0; fi` **之后**。

### 手动检查残留规则

```bash
# nftables 侧（专用表）
nft list table inet hysteria_porthopping 2>/dev/null

# iptables 侧（带 comment 标记的规则）
iptables -t nat -S PREROUTING | grep hy2-dnat-watchdog
ip6tables -t nat -S PREROUTING | grep hy2-dnat-watchdog

# 如果发现无标记的 redirect 规则残留，先确认不是面板/docker 的规则再手动清理
nft -a list chain ip nat prerouting
```