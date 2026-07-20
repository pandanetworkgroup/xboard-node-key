# xboard-node-key

xboard-node **甯﹁瘉涔︽寚绾逛笂鎶ヨˉ涓佺増**鐨勪竴閿畨瑁呰剼鏈€傚湪瀹樻柟 xboard-node 鍩虹涓婃柊澧炰袱澶勬敼鍔細

| 鏂囦欢 | 鏀瑰姩 |
| --- | --- |
| `internal/cert/cert.go` | 鏂板 SPKI SHA-256 鎸囩汗璁＄畻锛沜ertMaterial 鏂板 spkiSha256 瀛楁锛涙柊澧?`SPKIFingerprint()` 杩斿洖 Base64 鎸囩汗锛宍CertPEM()` 杩斿洖瀹屾暣 PEM |
| `internal/service/service.go` | `buildMetrics()` 娉ㄥ叆 `cert_fingerprint` 鍜?`cert_pem`锛岄殢姣忓垎閽?metrics 涓婃姤闈㈡澘 |

閮ㄧ讲鍒伴潰鏉垮悗锛宍v2_server` 琛ㄤ細鍐欏叆 `cert_fingerprint`锛坰ing-box 鐢紝44 瀛楃 Base64 SPKI锛夊拰 `cert_pem`锛堝畬鏁?PEM锛孭HP 绔寜瀹㈡埛绔被鍨嬫淳鐢熶笅鍙戯級锛岃闃呯浠庢鍙敤璇佷功鎸囩汗鍥哄畾鏇夸唬 insecure: true銆?
---

## 涓€琛屽懡浠ゅ畨瑁咃紙鎺ㄨ崘锛?
```bash
curl -fsSL https://raw.githubusercontent.com/pandanetworkgroup/xboard-node-key/main/install.sh \
  | sudo bash -s -- --mode machine \
                      --panel 'https://node.178278.xyz' \
                      --token '浣犵殑_machine_token' \
                      --machine-id 9
```

鍙傛暟瀵瑰簲闈㈡澘銆岃妭鐐圭鐞?鈫?鏌ョ湅閰嶇疆銆嶄腑鐨勫鍑哄€硷細

| 鍙傛暟 | 鏉ユ簮 |
| --- | --- |
| `--panel` | 闈㈡澘璁块棶鍩熷悕锛圚TTPS锛?|
| `--token` | 闈㈡澘銆岃妭鐐圭鐞嗐€嶄腑瀵煎嚭鐨?machine token |
| `--machine-id` | 闈㈡澘涓殑 machine ID锛堟暟瀛楋級 |

## 浜や簰寮忓畨瑁?
鍏堜笅杞借剼鏈紝鍐嶄氦浜掑紡杩愯锛?
```bash
curl -fsSL https://raw.githubusercontent.com/pandanetworkgroup/xboard-node-key/main/install.sh -o install.sh
sudo bash install.sh
```

鑴氭湰浼氶€愰」璇㈤棶闈㈡澘鍦板潃銆乼oken銆乵achine id銆?
## 鍗囩骇鐜版湁閮ㄧ讲

宸插瓨鍦?`/etc/xboard-node/config.yml` 鏃讹紝鑴氭湰鑷姩杩涘叆銆屽崌绾фā寮忋€嶏紙浠呮浛鎹簩杩涘埗锛屼繚鐣欓厤缃級锛?
```bash
curl -fsSL https://raw.githubusercontent.com/pandanetworkgroup/xboard-node-key/main/install.sh \
  | sudo bash -s -- --mode machine --panel 'https://...' --token '...' --machine-id 1
```

## 瀹屾暣鍙傛暟

| 鍙傛暟 | 榛樿 | 璇存槑 |
| --- | --- | --- |
| `--mode` | machine | 閰嶇疆妯″紡锛堝綋鍓嶄粎 machine锛?|
| `--panel` | - | 闈㈡澘璁块棶鍦板潃 |
| `--token` | - | machine token |
| `--machine-id` | - | 闈㈡澘 machine ID |
| `--instance-id` | 鑷姩鐢熸垚 | 鑷畾涔?instance_id |
| `--health-port` | 65530 | 鍋ュ悍妫€鏌ョ鍙?|
| `--kernel` | singbox | singbox / xray |
| `--log-level` | info | info / warn / error / debug |
| `--force` | - | 寮哄埗瑕嗙洊宸插瓨鍦ㄧ殑 config.yml |
| `--skip-download` | - | 涓嶄笅杞戒簩杩涘埗锛屽鐢ㄧ幇鏈?|

## 瀹夎鍚?
- 浜岃繘鍒讹細`/usr/local/bin/xboard-node`
- 閰嶇疆锛歚/etc/xboard-node/config.yml`锛?00 鏉冮檺锛?- 鍑瘉锛歚/etc/xboard-node/credentials.env`锛?00 鏉冮檺锛?- 瀹炰緥鏁版嵁锛歚/etc/xboard-node/instances/<instance_id>/node-<id>/certs/`
- systemd 鏈嶅姟锛歚xboard-node.service`

楠岃瘉涓婃姤锛?
```bash
# 1. 鑺傜偣鏃ュ織
journalctl -u xboard-node -f

# 2. 闈㈡澘鏈嶅姟鍣ㄦ煡 DB锛堟浛鎹㈠鍣ㄥ悕锛?docker exec xboard-xboard-1 php /www/artisan tinker --execute='
$rows = \DB::table("v2_server")->select("id","name","cert_fingerprint","cert_pem")->get();
foreach ($rows as $r) {
    echo sprintf("id=%d name=%s fp_len=%d pem_len=%d\n",
        $r->id, $r->name,
        $r->cert_fingerprint ? strlen($r->cert_fingerprint) : 0,
        $r->cert_pem ? strlen($r->cert_pem) : 0);
}
'
```

姣忎釜宸查厤缃瘉涔︾殑鑺傜偣搴旀湁 `fp_len=44`銆乣pem_len=570-900`銆?
## 鍥炴粴

```bash
sudo systemctl stop xboard-node
sudo cp /usr/local/bin/xboard-node.bak.鍒楀嚭鐨勬椂闂存埑 /usr/local/bin/xboard-node
sudo systemctl start xboard-node
```

## 闈㈡澘渚у墠缃潯浠?
閮ㄧ讲 node 渚т箣鍓嶏紝闈㈡澘蹇呴』宸诧細

1. `v2_server` 琛ㄥ凡鍔?`cert_fingerprint` 鍜?`cert_pem` 瀛楁
2. `app/Services/ServerService.php` 宸查儴缃蹭慨鏀圭増锛坲pdateMetrics 鎸佷箙鍖栦袱涓瓧娈碉級
3. `app/Protocols/*.php` 8 涓崗璁敓鎴愬櫒宸查儴缃蹭慨鏀圭増
4. 瀹瑰櫒宸查噸鍚竻 OPcache

璇﹁閮ㄧ讲鎵嬪唽銆?
## 闈㈡澘渚?server_ws_url 閰嶇疆

濡傛灉 node 鍚姩鍚庢棩蹇楀嚭鐜?`WARN ws disconnected error=dial: malformed ws or wss URL`锛?
```bash
# 闈㈡澘鏈嶅姟鍣ㄦ墽琛岋紝娉ㄦ剰 scheme 蹇呴』鏄?wss://锛岃矾寰勫繀椤讳互 /ws 缁撳熬
docker exec xboard-xboard-1 php /www/artisan tinker --execute='
admin_setting(["server_ws_url"=>"wss://浣犵殑闈㈡澘鍩熷悕/ws"]);
echo admin_setting("server_ws_url");
'
```

## 鍗忚鍏煎鎬?
- 鍗忚锛欻Y2 / VLESS / VMess / TUIC / anytls / WireGuard 绛夊潎鏀寔璇佷功鎸囩汗涓婃姤
- xhttp 浼犺緭锛氫粎 xray 鍐呮牳鏀寔锛岃嫢鑺傜偣鐢?xhttp锛岃 `--kernel xray`
- 鏋舵瀯锛氫粎 amd64锛坸86_64锛夛紝鍏朵粬鏋舵瀯鏆傛湭缂栬瘧
