# 商品图片功能 —— HTTP 回归测试
# 跑法: powershell -ExecutionPolicy Bypass -File "D:\workpace\Calculator\图片回归测试.ps1"
#
# 覆盖：上传成功、换图删旧图、三态更新（保留/替换/删除）、伪装扩展名拦截、
#       超大文件拦截、路径穿越拦截、前台免登录取图、删商品清图、无图商品退回首字色块
#
# 测试商品名统一用 ASCII（ZZTEST-*），这样关键字搜索不用处理中文 URL 编码。

$ErrorActionPreference = "Stop"

$BASE    = "http://localhost:8080/shop"
$IMG_DIR = "D:\workpace\Calculator\shop-data\uploads"
$TMP     = "D:\workpace\Calculator\_imgtest"

$pass = 0
$fail = 0
$fails = @()

function Hit {
    param(
        [string]$url,
        [string]$method = "GET",
        [string]$body = $null,
        $jar = $null,
        [string]$ctype = "application/x-www-form-urlencoded",
        [byte[]]$bytes = $null
    )
    $r = [System.Net.HttpWebRequest]::Create($url)
    $r.Method = $method
    $r.AllowAutoRedirect = $false
    if ($jar) { $r.CookieContainer = $jar }

    if ($bytes -ne $null) {
        $r.ContentType = $ctype
        $r.ContentLength = $bytes.Length
        $s = $r.GetRequestStream(); $s.Write($bytes, 0, $bytes.Length); $s.Close()
    } elseif (-not [string]::IsNullOrEmpty($body)) {
        # 这里必须用 IsNullOrEmpty 判断，不能写 $body -ne $null ——
        # PowerShell 把 $null 传给 [string] 类型的参数时，会静默转成空串 ""。
        # 于是判断恒为真，连 GET 都去发请求体，
        # .NET 直接抛「无法发送具有此谓词类型的请求正文」。
        $r.ContentType = $ctype
        $b = [System.Text.Encoding]::UTF8.GetBytes($body)
        $r.ContentLength = $b.Length
        $s = $r.GetRequestStream(); $s.Write($b, 0, $b.Length); $s.Close()
    }

    $code = 0; $loc = ""; $text = ""; $ct = ""
    try {
        $resp = $r.GetResponse()
        $code = [int]$resp.StatusCode
        $loc  = [string]$resp.Headers["Location"]
        $ct   = [string]$resp.ContentType
        $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $text = $sr.ReadToEnd(); $sr.Close(); $resp.Close()
    } catch [System.Net.WebException] {
        $hr = $_.Exception.Response
        if ($hr) {
            $code = [int]$hr.StatusCode
            $loc  = [string]$hr.Headers["Location"]
            $ct   = [string]$hr.ContentType
            try {
                $sr = New-Object System.IO.StreamReader($hr.GetResponseStream(), [System.Text.Encoding]::UTF8)
                $text = $sr.ReadToEnd(); $sr.Close()
            } catch { }
            $hr.Close()
        } else { $code = -1 }
    }
    return [pscustomobject]@{ Code = $code; Location = $loc; Text = $text; CType = $ct }
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

# 组装 multipart/form-data 请求体
function Multipart {
    param([hashtable]$fields, [string]$fileField, [string]$fileName, [byte[]]$fileBytes)
    $b  = [System.Guid]::NewGuid().ToString("N")
    $ms = New-Object System.IO.MemoryStream
    $enc = [System.Text.Encoding]::UTF8
    $lf = "`r`n"

    foreach ($k in $fields.Keys) {
        $h  = "--$b$lf" + "Content-Disposition: form-data; name=`"$k`"$lf$lf"
        $hb = $enc.GetBytes($h); $ms.Write($hb, 0, $hb.Length)
        $vb = $enc.GetBytes([string]$fields[$k] + $lf); $ms.Write($vb, 0, $vb.Length)
    }
    if ($fileName -ne "") {
        $h = "--$b$lf" +
             "Content-Disposition: form-data; name=`"$fileField`"; filename=`"$fileName`"$lf" +
             "Content-Type: application/octet-stream$lf$lf"
        $hb = $enc.GetBytes($h); $ms.Write($hb, 0, $hb.Length)
        $ms.Write($fileBytes, 0, $fileBytes.Length)
        $eb = $enc.GetBytes($lf); $ms.Write($eb, 0, $eb.Length)
    }
    $fb = $enc.GetBytes("--$b--$lf"); $ms.Write($fb, 0, $fb.Length)

    return @{ Bytes = $ms.ToArray(); Boundary = $b }
}

function ImgNames {
    return @(Get-ChildItem $IMG_DIR -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
}
function ImgCount { return (ImgNames).Count }

# 从商品列表页里找出某个商品名的 id
function FindId {
    param($jar, [string]$keyword)
    $r = Hit "$BASE/product/list?keyword=$keyword" "GET" $null $jar
    if ($r.Text -match "product/edit\?id=(\d+)") { return $Matches[1] }
    return ""
}

# 商品列表页里这个商品用的图片文件名
function FindImg {
    param($jar, [string]$keyword)
    $r = Hit "$BASE/product/list?keyword=$keyword" "GET" $null $jar
    if ($r.Text -match "img\?name=([A-Za-z0-9]+\.\w+)") { return $Matches[1] }
    return ""
}

Write-Host "==== 商品图片功能 回归测试 ====" -ForegroundColor Cyan

# ---------- 0. 准备测试素材 ----------
New-Item -ItemType Directory -Force -Path $TMP | Out-Null

Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap(64, 64)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::Coral)
$g.FillEllipse([System.Drawing.Brushes]::White, 12, 12, 40, 40)
$g.Dispose()
$bmp.Save("$TMP\ok.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save("$TMP\ok.jpg", [System.Drawing.Imaging.ImageFormat]::Jpeg)
$bmp.Dispose()

# 伪装货：内容纯文本，扩展名却是 .jpg
[System.IO.File]::WriteAllText("$TMP\fake.jpg", "这不是图片，只是一段文本。绝对不要把它当图存下来。")
# 超大货：4MB，超过 3MB 上限
$big = New-Object byte[] (4 * 1024 * 1024)
[System.IO.File]::WriteAllBytes("$TMP\big.png", $big)

$pngBytes  = [System.IO.File]::ReadAllBytes("$TMP\ok.png")
$jpgBytes  = [System.IO.File]::ReadAllBytes("$TMP\ok.jpg")
$fakeBytes = [System.IO.File]::ReadAllBytes("$TMP\fake.jpg")
$bigBytes  = [System.IO.File]::ReadAllBytes("$TMP\big.png")

$base0 = ImgCount
Write-Host ("起始图片文件数: " + $base0)

# ---------- 1. 登录 ----------
$jar = New-Object System.Net.CookieContainer
$r = Hit "$BASE/login" "POST" "username=admin&password=123456" $jar
Check "admin 登录跳转" $r.Code 302

# ---------- 1.5 清掉上一轮跑残留的测试商品，让脚本可以反复执行 ----------
# 注意：只删名字带 ZZTEST- 前缀的，绝不动别的商品；
# 上传目录也不整个清空 —— 万一这里存着真实商品图，清空了就是事故。
foreach ($kw in @("ZZTEST-IMG1", "ZZTEST-NOIMG", "ZZTEST-FAKE", "ZZTEST-BIG", "ZZTEST-DEL")) {
    $rid = FindId $jar $kw
    if ($rid -ne "") { Hit "$BASE/product/delete" "POST" "id=$rid" $jar | Out-Null }
}
$base0 = ImgCount
Write-Host ("清理后起始图片文件数: " + $base0)

# ---------- 2. 新增带图商品（PNG）----------
$mp = Multipart @{ name="ZZTEST-IMG1"; price="88"; stock="30"; category="食品"; brandPick="" } "imageFile" "ok.png" $pngBytes
$r = Hit "$BASE/product/add" "POST" $null $jar ("multipart/form-data; boundary=" + $mp.Boundary) $mp.Bytes
Check "带图新增商品 -> 302" $r.Code 302
Check "新增后图片文件数 +1" (ImgCount) ($base0 + 1)

$newNames = @(ImgNames) | Where-Object { $_.EndsWith(".png") }
CheckTrue "落盘的是 .png（按内容嗅探定的，不是照抄原文件名）" ($newNames.Count -ge 1)

$id1 = FindId $jar "ZZTEST-IMG1"
CheckTrue "能在列表里找到新商品" ($id1 -ne "")
$img1 = FindImg $jar "ZZTEST-IMG1"
CheckTrue "列表页显示出了商品图" ($img1 -ne "")

# ---------- 3. 图片能取回来 ----------
$r = Hit "$BASE/img?name=$img1" "GET" $null $null
Check "取图 -> 200" $r.Code 200
CheckTrue "content-type 是 image/png" ($r.CType -like "image/png*")

# ---------- 4. 前台游客免登录也能取图 ----------
$guest = New-Object System.Net.CookieContainer
$r = Hit "$BASE/img?name=$img1" "GET" $null $guest
Check "未登录取图 -> 200（图片在白名单里）" $r.Code 200

# ---------- 5. 换图：新图进来、旧图要删掉 ----------
$cntBefore = ImgCount
$mp = Multipart @{ id="$id1"; name="ZZTEST-IMG1"; price="88"; stock="30"; category="食品"; brandPick="" } "imageFile" "ok.jpg" $jpgBytes
$r = Hit "$BASE/product/edit" "POST" $null $jar ("multipart/form-data; boundary=" + $mp.Boundary) $mp.Bytes
Check "换图 -> 302" $r.Code 302
Check "换图后总数不变（新图 +1、旧图 -1）" (ImgCount) $cntBefore

$img1b = FindImg $jar "ZZTEST-IMG1"
CheckTrue "图片名换成了新的" ($img1b -ne "" -and $img1b -ne $img1)
$r = Hit "$BASE/img?name=$img1" "GET" $null $null
Check "旧图已经取不到了 -> 404" $r.Code 404
$r = Hit "$BASE/img?name=$img1b" "GET" $null $null
Check "新图能取 -> 200" $r.Code 200
CheckTrue "content-type 是 image/jpeg" ($r.CType -like "image/jpeg*")

# ---------- 6. 三态之「保留」：只改价格，不碰图片 ----------
$r = Hit "$BASE/product/edit" "POST" "id=$id1&name=ZZTEST-IMG1&price=99&stock=30&category=食品&brand=康师傅" $jar
Check "普通表单改价格 -> 302（非 multipart 也照常能用）" $r.Code 302
Check "图片文件数没变" (ImgCount) $cntBefore
Check "图片还是那一张（没被顺手抹掉）" (FindImg $jar "ZZTEST-IMG1") $img1b

# ---------- 7. 三态之「删除」：勾删除图片 ----------
$r = Hit "$BASE/product/edit" "POST" "id=$id1&name=ZZTEST-IMG1&price=99&stock=30&category=食品&brand=康师傅&removeImage=1" $jar
Check "勾删除图片 -> 302" $r.Code 302
Check "图片文件被删 -> 数量 -1" (ImgCount) ($cntBefore - 1)
Check "商品已经没有图了" (FindImg $jar "ZZTEST-IMG1") ""

# ---------- 8. 伪装扩展名：内容不是图片 ----------
$cntBefore = ImgCount
$mp = Multipart @{ name="ZZTEST-FAKE"; price="10"; stock="5" } "imageFile" "fake.jpg" $fakeBytes
$r = Hit "$BASE/product/add" "POST" $null $jar ("multipart/form-data; boundary=" + $mp.Boundary) $mp.Bytes
Check "伪装成 jpg 的文本 -> 302（退回表单页而不是 500）" $r.Code 302
Check "被拒了，没有留下垃圾文件" (ImgCount) $cntBefore

# 顺着重定向看一眼提示语
$r = Hit "$BASE/product/add" "GET" $null $jar
CheckTrue "提示语点明了原因（不像图片）" ($r.Text -match "不像图片")

# ---------- 9. 超大文件 ----------
$cntBefore = ImgCount
$mp = Multipart @{ name="ZZTEST-BIG"; price="10"; stock="5" } "imageFile" "big.png" $bigBytes
$r = Hit "$BASE/product/add" "POST" $null $jar ("multipart/form-data; boundary=" + $mp.Boundary) $mp.Bytes
Check "4MB 图片 -> 302（不是 500）" $r.Code 302
Check "被拒了，没有留下垃圾文件" (ImgCount) $cntBefore
$r = Hit "$BASE/product/add" "GET" $null $jar
CheckTrue "提示语说的是太大了" ($r.Text -match "太大")

# ---------- 10. 路径穿越 ----------
foreach ($bad in @("..%2Fweb.xml", "..%2F..%2F..%2Fwindows%2Fwin.ini", ".htaccess", "%2Fetc%2Fpasswd")) {
    $r = Hit "$BASE/img?name=$bad" "GET" $null $null
    Check "穿越/非法名字被挡: $bad -> 404" $r.Code 404
}

# ---------- 11. 无图商品：前台退回首字色块 ----------
$mp = Multipart @{ name="ZZTEST-NOIMG"; price="12"; stock="9"; category="数码" } "imageFile" "" ([byte[]]@())
$r = Hit "$BASE/product/add" "POST" $null $jar ("multipart/form-data; boundary=" + $mp.Boundary) $mp.Bytes
Check "新增无图商品 -> 302" $r.Code 302
$id3 = FindId $jar "ZZTEST-NOIMG"
CheckTrue "找到无图商品" ($id3 -ne "")
$r = Hit "$BASE/mall/item?id=$id3" "GET" $null $null
Check "前台详情页 -> 200" $r.Code 200
CheckTrue "前台用的是首字色块（没有 img 标签）" ($r.Text -notmatch "img\?name=")
CheckTrue "色块里有商品名首字" ($r.Text -match ">Z<")

# ---------- 12. 删商品要把图片一起带走 ----------
$mp = Multipart @{ name="ZZTEST-DEL"; price="7"; stock="3" } "imageFile" "ok.png" $pngBytes
$r = Hit "$BASE/product/add" "POST" $null $jar ("multipart/form-data; boundary=" + $mp.Boundary) $mp.Bytes
Check "为删除测试新增带图商品 -> 302" $r.Code 302
$cntBefore = ImgCount
$id4 = FindId $jar "ZZTEST-DEL"
CheckTrue "找到待删商品" ($id4 -ne "")
$r = Hit "$BASE/product/delete" "POST" "id=$id4" $jar
Check "删除商品 -> 302" $r.Code 302
Check "商品没了，图片也跟着删了" (ImgCount) ($cntBefore - 1)

# ---------- 13. 清理，让数据回到起始状态 ----------
foreach ($kw in @("ZZTEST-IMG1", "ZZTEST-NOIMG")) {
    $pid2 = FindId $jar $kw
    if ($pid2 -ne "") { Hit "$BASE/product/delete" "POST" "id=$pid2" $jar | Out-Null }
}
Check "数据回到起始状态（图片文件数）" (ImgCount) $base0

# ---------- 汇总 ----------
Write-Host ""
Write-Host ("==== 通过 " + $pass + " / 共 " + ($pass + $fail) + " ====") -ForegroundColor Cyan
if ($fail -gt 0) {
    Write-Host "失败项：" -ForegroundColor Red
    foreach ($f in $fails) { Write-Host ("  - " + $f) -ForegroundColor Red }
    exit 1
}
exit 0
