# 监听器功能 —— HTTP 回归测试
# 跑法: powershell -ExecutionPolicy Bypass -File "D:\workpace\Calculator\监听器回归测试.ps1"
#
# 覆盖两块：
#   A. AppListener     —— 启动时建图片目录、打启动日志，而且日志要真的落盘
#   B. OnlineListener  —— 在线人数（会话数）的增减与边界
#
# 设计要点：在线人数一律用「相对基线」比对，不写死绝对值。
# 会话要 30 分钟才超时，之前测试留下的会话还占着名额，
# 写成 =1、=2 这种绝对值，脚本第二次跑就会红。

$ErrorActionPreference = "Stop"

$BASE   = "http://localhost:8080/shop"
$TOMCAT = "C:\Users\22415\apache-tomcat-11.0.26"
$UPLOAD = "D:\workpace\Calculator\shop-data\uploads"
$LOGDIR = "$TOMCAT\logs"

$pass  = 0
$fail  = 0
$fails = @()

function Hit {
    param(
        [string]$url,
        [string]$method = "GET",
        [string]$body = $null,
        $jar = $null
    )
    $r = [System.Net.HttpWebRequest]::Create($url)
    $r.Method = $method
    $r.AllowAutoRedirect = $false
    if ($jar) { $r.CookieContainer = $jar }

    # 必须用 IsNullOrEmpty 判断。PowerShell 把 $null 传给 [string] 参数会静默变成 ""，
    # 于是 $body -ne $null 恒为真 —— 连 GET 都去发请求体，.NET 直接抛异常。
    if (-not [string]::IsNullOrEmpty($body)) {
        $r.ContentType = "application/x-www-form-urlencoded"
        $b = [System.Text.Encoding]::UTF8.GetBytes($body)
        $r.ContentLength = $b.Length
        $s = $r.GetRequestStream(); $s.Write($b, 0, $b.Length); $s.Close()
    }

    $code = 0; $loc = ""; $text = ""
    try {
        $resp = $r.GetResponse()
        $code = [int]$resp.StatusCode
        $loc  = [string]$resp.Headers["Location"]
        $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $text = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    } catch [System.Net.WebException] {
        $hr = $_.Exception.Response
        if ($hr) {
            $code = [int]$hr.StatusCode
            $loc  = [string]$hr.Headers["Location"]
            try {
                $sr = New-Object System.IO.StreamReader($hr.GetResponseStream(), [System.Text.Encoding]::UTF8)
                $text = $sr.ReadToEnd(); $sr.Close()
            } catch { }
            $hr.Close()
        } else { $code = -1 }
    }
    return [pscustomobject]@{ Code = $code; Location = $loc; Text = $text }
}

function Check {
    param([string]$name, $actual, $expect)
    if ("$actual" -eq "$expect") {
        $script:pass++
        Write-Host ("  [OK]   " + $name)
    } else {
        $script:fail++
        $script:fails += $name
        Write-Host ("  [FAIL] " + $name + "  期望=[" + $expect + "] 实际=[" + $actual + "]")
    }
}

function CheckTrue {
    param([string]$name, $cond)
    Check $name ([bool]$cond) $true
}

# 从页面里抠出页脚的在线人数。正则只认 ASCII（靠 class="m-online" 定位，
# 用 [^<]* 跳过「当前」两个字），免得在中文编码上栽跟头。抠不到返回 -1。
function Online {
    param([string]$html)
    $m = [regex]::Match($html, 'class="m-online">\s*[^<]*<b>(\d+)</b>')
    if ($m.Success) { return [int]$m.Groups[1].Value }
    return -1
}

Write-Host ""
Write-Host "========== 监听器回归测试 =========="

# ==================== A. 启动日志 ====================
Write-Host ""
Write-Host "--- A. 启动日志（AppListener.contextInitialized）---"

$logFile = Get-ChildItem $LOGDIR -Filter "localhost.*.log" -ErrorAction SilentlyContinue |
           Sort-Object LastWriteTime -Descending | Select-Object -First 1
CheckTrue "A1 找得到 localhost 应用日志（ServletContext.log 的落点）" ($logFile -ne $null)

$logText = ""
if ($logFile) {
    $logText = (Get-Content $logFile.FullName -Encoding UTF8 -Raw)
}

CheckTrue "A2 日志含「[启动] 图片目录就绪」" ($logText -match "\[启动\] 图片目录就绪")
CheckTrue "A3 记下的图片目录就是 web.xml 里配的那个" ($logText -match [regex]::Escape($UPLOAD))
CheckTrue "A4 日志含「[启动] 商品管理系统就绪」" ($logText -match "\[启动\] 商品管理系统就绪")
CheckTrue "A5 记下了上下文路径 /shop" ($logText -match "上下文路径 = /shop")
CheckTrue "A6 当前还没有 [关闭]（说明应用正跑着）" (-not ($logText -match "\[关闭\]"))

# ==================== B. 在线人数 ====================
Write-Host ""
Write-Host "--- B. 在线人数（OnlineListener）---"

# 探针会话。它自己也会占一个名额，所以先拿它当基线。
$probe = New-Object System.Net.CookieContainer
$r = Hit "$BASE/mall" "GET" $null $probe
Check "B1 游客访问前台 -> 200" $r.Code 200

$baseline = Online $r.Text
CheckTrue "B2 页脚读得出在线人数（当前 $baseline）" ($baseline -ge 1)

# 新会话 = 新开一个浏览器（没有 Cookie）
$ja = New-Object System.Net.CookieContainer
$r = Hit "$BASE/mall" "GET" $null $ja
Check "B3 新会话 -> 在线数 +1" (Online $r.Text) ($baseline + 1)

$r = Hit "$BASE/mall" "GET" $null $ja
Check "B4 同一会话再访问同一页 -> 不再 +1" (Online $r.Text) ($baseline + 1)

$r = Hit "$BASE/mall/item?id=1" "GET" $null $ja
Check "B5 同一会话换个页面 -> 也不 +1" (Online $r.Text) ($baseline + 1)

# 静态资源不该创建会话（Tomcat 对 css/js 不做会话跟踪）
$jc = New-Object System.Net.CookieContainer
$r = Hit "$BASE/css/mall.css" "GET" $null $jc
Check "B6 取静态资源 -> 200" $r.Code 200
$r = Hit "$BASE/mall" "GET" $null $ja
Check "B7 取静态资源不产生新会话" (Online $r.Text) ($baseline + 1)

$jb = New-Object System.Net.CookieContainer
$r = Hit "$BASE/mall" "GET" $null $jb
Check "B8 再开一个会话 -> 又 +1" (Online $r.Text) ($baseline + 2)

# 退出登录会 invalidate 会话 → sessionDestroyed → -1
$r = Hit "$BASE/logout" "GET" $null $jb
Check "B9 退出登录 -> 302" $r.Code 302
$r = Hit "$BASE/mall" "GET" $null $ja
Check "B10 会话销毁后回落到基线+1" (Online $r.Text) ($baseline + 1)

# 登录会换 session（LoginServlet 里 invalidate 旧的、建新的）—— 净变化应该是 0。
# 这条最能说明「一减一加」是真的成对发生的：如果少扣了一次，这里就会多 1。
$r = Hit "$BASE/mall" "GET" $null $ja
$before = Online $r.Text

$r = Hit "$BASE/login" "POST" "username=user&password=123456" $ja
Check "B11 user 登录 -> 302" $r.Code 302

$r = Hit "$BASE/mall" "GET" $null $ja
Check "B12 登录换 session 后，在线数净变化为 0" (Online $r.Text) $before

# 下限保护：页面上永远不该出现负数
CheckTrue "B13 在线数不为负（下限保护生效）" ((Online $r.Text) -ge 0)

# ==================== C. 既有入口还活着 ====================
Write-Host ""
Write-Host "--- C. 顺手确认既有入口没被监听器带坏 ---"

$js = New-Object System.Net.CookieContainer
$r = Hit "$BASE/login" "POST" "username=admin&password=123456" $js
Check "C1 admin 登录 -> 302" $r.Code 302

foreach ($u in @("/dashboard", "/product/list", "/brand", "/category", "/order")) {
    $r = Hit ("$BASE" + $u) "GET" $null $js
    Check ("C2 " + $u + " -> 200") $r.Code 200
}

# ==================== 汇总 ====================
Write-Host ""
Write-Host "====================================="
$total = $pass + $fail
Write-Host ("通过 " + $pass + " / " + $total)
if ($fail -gt 0) {
    Write-Host ("失败 " + $fail + " 项：")
    foreach ($f in $fails) { Write-Host ("  - " + $f) }
    exit 1
}
exit 0
