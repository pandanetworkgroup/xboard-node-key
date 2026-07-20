# xboard-node-key

xboard-node **带证书指纹上报补丁版**的一键安装脚本。在官方 xboard-node 基础上新增两处改动：

| 文件 | 改动 |
| --- | --- |
| `internal/cert/cert.go` | 新增 SPKI SHA-256 指纹计算；certMaterial 新增 spkiSha256 字段；新增 `SPKIFingerprint()` 返回 Base64 指纹，`CertPEM()` 返回完整 PEM |
| `internal/service/service.go` | `buildMetrics()` 注入 `cert_fingerprint` 和 `cert_pem`，随每分钟 metrics 上报面板 |

部署到面板后，`v2_server` 表会写入 `cert_fingerprint`（sing-box 用，44 字符 Base64 SPKI）和 `cert_pem`（完整 PEM，PHP 端按客户端类型派生下发），订阅端从此可用证书指纹固定替代 insecure: true。

---

## 一行命令安装（推荐）

```bash
curl -fsSL https://raw.githubusercontent.com/pandanetworkgroup/xboard-node-key/main/install.sh \
  | sudo bash -s -- --mode machine \
                      --panel 'https://node.178278.xyz' \
                      --token '你的_machine_token' \
                      --machine-id 9
```

参数对应面板「节点管理 → 查看配置」中的导出值：

| 参数 | 来源 |
| --- | --- |
| `--panel` | 面板访问域名（HTTPS） |
| `--token` | 面板「节点管理」中导出的 machine token |
| `--machine-id` | 面板中的 machine ID（数字） |

## 交互式安装

先下载脚本，再交互式运行：

```bash
curl -fsSL https://raw.githubusercontent.com/pandanetworkgroup/xboard-node-key/main/install.sh -o install.sh
sudo bash install.sh
```

脚本会逐项询问面板地址、token、machine id。

## 升级现有部署

已存在 `/etc/xboard-node/config.yml` 时，脚本自动进入「升级模式」（仅替换二进制，保留配置）：

```bash
curl -fsSL https://raw.githubusercontent.com/pandanetworkgroup/xboard-node-key/main/install.sh \
  | sudo bash -s -- --mode machine --panel 'https://...' --token '...' --machine-id 1
```

## 完整参数

| 参数 | 默认 | 说明 |
| --- | --- | --- |
| `--mode` | machine | 配置模式（当前仅 machine） |
| `--panel` | - | 面板访问地址 |
| `--token` | - | machine token |
| `--machine-id` | - | 面板 machine ID |
| `--instance-id` | 自动生成 | 自定义 instance_id |
| `--health-port` | 65530 | 健康检查端口 |
| `--kernel` | singbox | singbox / xray |
| `--log-level` | info | info / warn / error / debug |
| `--force` | - | 强制覆盖已存在的 config.yml |
| `--skip-download` | - | 不下载二进制，复用现有 |

## 安装后

- 二进制：`/usr/local/bin/xboard-node`
- 配置：`/etc/xboard-node/config.yml`（600 权限）
- 凭证：`/etc/xboard-node/credentials.env`（600 权限）
- 实例数据：`/etc/xboard-node/instances/<instance_id>/node-<id>/certs/`
- systemd 服务：`xboard-node.service`

验证上报：

```bash
# 1. 节点日志
journalctl -u xboard-node -f

# 2. 面板服务器查 DB（替换容器名）
docker exec xboard-xboard-1 php /www/artisan tinker --execute='
$rows = \DB::table("v2_server")->select("id","name","cert_fingerprint","cert_pem")->get();
foreach ($rows as $r) {
    echo sprintf("id=%d name=%s fp_len=%d pem_len=%d\n",
        $r->id, $r->name,
        $r->cert_fingerprint ? strlen($r->cert_fingerprint) : 0,
        $r->cert_pem ? strlen($r->cert_pem) : 0);
}
'
```

每个已配置证书的节点应有 `fp_len=44`、`pem_len=570-900`。

## 回滚

```bash
sudo systemctl stop xboard-node
sudo cp /usr/local/bin/xboard-node.bak.列出的时间戳 /usr/local/bin/xboard-node
sudo systemctl start xboard-node
```

## 面板侧前置条件

部署 node 侧之前，面板必须已：

1. `v2_server` 表已加 `cert_fingerprint` 和 `cert_pem` 字段
2. `app/Services/ServerService.php` 已部署修改版（updateMetrics 持久化两个字段）
3. `app/Protocols/*.php` 8 个协议生成器已部署修改版
4. 容器已重启清 OPcache

详见部署手册。

## 面板侧 server_ws_url 配置

如果 node 启动后日志出现 `WARN ws disconnected error=dial: malformed ws or wss URL`：

```bash
# 面板服务器执行，注意 scheme 必须是 wss://，路径必须以 /ws 结尾
docker exec xboard-xboard-1 php /www/artisan tinker --execute='
admin_setting(["server_ws_url"=>"wss://你的面板域名/ws"]);
echo admin_setting("server_ws_url");
'
```

## 协议兼容性

- 协议：HY2 / VLESS / VMess / TUIC / anytls / WireGuard 等均支持证书指纹上报
- xhttp 传输：仅 xray 内核支持，若节点用 xhttp，请 `--kernel xray`
- 架构：仅 amd64（x86_64），其他架构暂未编译
