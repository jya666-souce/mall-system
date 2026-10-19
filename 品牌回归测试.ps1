# 商品品牌「其他（自己输入）」—— HTTP 回归测试
# 跑法: powershell -ExecutionPolicy Bypass -File "D:\workpace\Calculator\品牌回归测试.ps1"
#
# 覆盖：走「其他」新增商品、品牌自动登记进品牌库、同一个名字不重复登记、
#       列表的品牌筛选认得出自定义品牌、选了「其他」却不填被拦、
#       编辑页正确回填、下拉优先于手输、用「无品牌」清空、
#       multipart 下的中文品牌、非法品牌名拦截、跑完数据回正
#
# 测试商品名统一用 ASCII（ZZTEST-BRD*），关键字搜索就不用处理中文 URL 编码。
# 品牌名反而故意用中文 —— 顺手把「中文品牌名在 POST body 里往返」也验一遍。
#
# ⚠️ 断言别写成「页面里有没有出现过某个字符串」，那样很容易被两样东西骗过去：
#      · flash 提示条 ——「已修改商品【X】」里就带着商品名
#      · 筛选框回显 —— keyword 输入框会把你的搜索词原样吐回来
#    所以：要判「某件商品在不在结果里」，就数 /product/edit?id=<那个 id>；
#    要判「品牌回填对不对」，就看 option 有没有 selected。
#    比精确的东西，别比「页面里恰好出现过的字」。

$ErrorActionPreference = "Stop"

$BASE = "http://localhost:8080/shop"

$B1   = "ZZBRD-自定义甲"        # 手输进来的品牌
$BX   = "ZZBRD-已有品牌"        # 提前建好的品牌，用来测「下拉选已有」
$LONG = "ZZBRD-这是一个特别特别长的品牌名字用来测试长度上限"

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
        # 必须用 IsNullOrEmpty 判断，不能写 $body -ne $null ——
        # PowerShell 把 $null 传给 [string] 参数时会静默转成空串 ""。
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

# 一段 HTML 里某个模式出现几次
function Rows {
    param($html, $pattern)
    return ([regex]::Matches($html, $pattern)).Count
}

# 某件商品在不在这个结果页里 —— 认编辑链接上的 id，不看名字
function HasItem {
    param($html, [string]$itemId)
    return $html.Contains('/product/edit?id=' + $itemId)
}

# 从商品列表页里找出某个商品名的 id
function FindId {
    param($jar, [string]$keyword)
    $r = Hit "$BASE/product/list?keyword=$keyword" "GET" $null $jar
    # 取结果表里第一个编辑链接（搜索是包含匹配，命中时它就在第一行）
    $ids = [regex]::Matches($r.Text, '/product/edit\?id=(\d+)')
    if ($ids.Count -gt 0) { return $ids[0].Groups[1].Value }
    return ""
}

# 从品牌管理页里按名字反查品牌 id
# 品牌表一行一个品牌，所以先按 <tr> 切成一段段，
# 再在含有这个名字的那一段里捞 bf-<id> —— 比直接跨行正则靠谱
function FindBrandId {
    param($jar, [string]$name)
    $r = Hit "$BASE/brand" "GET" $null $jar
    foreach ($seg in ($r.Text -split '<tr>')) {
        if ($seg.Contains('value="' + $name + '"')) {
            $m = [regex]::Match($seg, 'id="bf-(\d+)"')
            if ($m.Success) { return $m.Groups[1].Value }
        }
    }
    return ""
}

# 品牌表当前有几个人
function BrandRows {
    param($jar)
    $r = Hit "$BASE/brand" "GET" $null $jar
    return (Rows $r.Text 'id="bf-')
}

Write-Host "==== 商品品牌「其他（自己输入）」 回归测试 ====" -ForegroundColor Cyan

# ---------- 0. 登录 ----------
$jar = New-Object System.Net.CookieContainer
$r = Hit "$BASE/login" "POST" "username=admin&password=123456" $jar
Check "admin 登录跳转" $r.Code 302

# ---------- 0.5 清掉上一轮跑残留的数据，让脚本能反复执行 ----------
# 顺序不能反：品牌被商品占用时删不掉（后端会拦），所以先删商品再删品牌
foreach ($kw in @("ZZTEST-BRD1", "ZZTEST-BRD2", "ZZTEST-BRD3", "ZZTEST-BRD9")) {
    $rid = FindId $jar $kw
    if ($rid -ne "") { Hit "$BASE/product/delete" "POST" "id=$rid" $jar | Out-Null }
}
foreach ($bn in @($B1, $BX, $LONG)) {
    $bid = FindBrandId $jar $bn
    if ($bid -ne "") { Hit "$BASE/brand/delete" "POST" "id=$bid" $jar | Out-Null }
}

$brdStart0 = BrandRows $jar
Write-Host ("干净起点：品牌行数 " + $brdStart0)

# 先造一个「下拉里早就有的品牌」，专门用来测「选了具体品牌」那条路。
# 不敢拿真实品牌当靶子 —— 万一测试把它的名字改坏了，那是真数据。
$r = Hit "$BASE/brand/add" "POST" ("name=$BX&remark=回归测试用") $jar
Check "准备：新建测试品牌" $r.Code 302
Check "准备：品牌行数 +1" (BrandRows $jar) ($brdStart0 + 1)

# ---------- 1. 走「其他」新增商品 ----------
Write-Host "`n---- 1. 选「其他」手输品牌，新增商品 ----"
$body = "name=ZZTEST-BRD1&price=10&stock=5&category=&brandPick=__other__&brandCustom=" + $B1
$r = Hit "$BASE/product/add" "POST" $body $jar
Check "选「其他」+手输品牌 -> 302 /product/list" $r.Code 302
CheckTrue "重定向到列表页" ($r.Location -like "*/product/list")

$id1 = FindId $jar "ZZTEST-BRD1"
CheckTrue "商品建出来了" ($id1 -ne "")
Write-Host ("     ZZTEST-BRD1 id = " + $id1)

# ---------- 2. 品牌自动进了品牌库 ----------
Write-Host "`n---- 2. 自定义品牌自动登记进品牌库 ----"
$r = Hit "$BASE/brand" "GET" $null $jar
CheckTrue "品牌管理页能看到这个自定义品牌" ($r.Text.Contains($B1))
Check "品牌行数 +1" (Rows $r.Text 'id="bf-') ($brdStart0 + 2)
CheckTrue "反查得到品牌 id" ((FindBrandId $jar $B1) -ne "")

# ---------- 3. 同一个名字不会重复登记 ----------
Write-Host "`n---- 3. 再用同一个品牌名，不重复入库 ----"
$body = "name=ZZTEST-BRD2&price=20&stock=3&category=&brandPick=__other__&brandCustom=" + $B1
$r = Hit "$BASE/product/add" "POST" $body $jar
Check "第二个商品也建成功" $r.Code 302
$id2 = FindId $jar "ZZTEST-BRD2"
CheckTrue "拿到 BRD2 的 id" ($id2 -ne "")

Check "品牌行数没再涨" (BrandRows $jar) ($brdStart0 + 2)

# ---------- 4. 商品列表的品牌筛选认得出它 ----------
Write-Host "`n---- 4. 列表筛选里有这个品牌 ----"
$r = Hit "$BASE/product/list" "GET" $null $jar
CheckTrue "筛选下拉里有这个自定义品牌" ($r.Text.Contains('value="' + $B1 + '"'))

# 注意这一行的括号：不括起来的话，PowerShell 会把 "a" + b 拆成两个参数
$filterUrl = ("$BASE/product/list?brand=" + [System.Uri]::EscapeDataString($B1))
$r = Hit $filterUrl "GET" $null $jar
Check "按自定义品牌筛选 -> 200" $r.Code 200
Check "筛出 2 件" (Rows $r.Text '/product/edit\?id=') 2
CheckTrue "筛出了 BRD1" (HasItem $r.Text $id1)
CheckTrue "筛出了 BRD2" (HasItem $r.Text $id2)

# ---------- 5. 选了「其他」却不填，必须被拦 ----------
Write-Host "`n---- 5. 选「其他」却空着手 ----"
$body = "name=ZZTEST-BRD9&price=1&stock=1&category=&brandPick=__other__&brandCustom="
$r = Hit "$BASE/product/add" "POST" $body $jar
Check "空品牌名 -> 退回新增页" $r.Code 302
CheckTrue "退回的是 /product/add" ($r.Location -like "*/product/add")

$r = Hit "$BASE/product/list?keyword=ZZTEST-BRD9" "GET" $null $jar
Check "那个商品没被建出来（结果 0 行）" (Rows $r.Text '/product/edit\?id=') 0

# ---------- 6. 编辑页回填 ----------
Write-Host "`n---- 6. 编辑页回填 ----"
$r = Hit ("$BASE/product/edit?id=" + $id1) "GET" $null $jar
Check "编辑页 200" $r.Code 200
CheckTrue "下拉选中了手输的那个品牌" ($r.Text.Contains('value="' + $B1 + '" selected'))
CheckTrue "没被误判成「其他」" (-not $r.Text.Contains('value="__other__" selected'))
CheckTrue "手输框这时是禁用的（品牌已在库，不需要手输）" ($r.Text.Contains('class="brand-custom" disabled'))

# ---------- 7. 下拉优先于手输 ----------
Write-Host "`n---- 7. 下拉选了具体品牌时，手输框的值必须被忽略 ----"
# 模拟「JS 没跑起来」：手输框没被 disable，于是两个值一起提交了。
# 服务端规则是「下拉不是哨兵就用下拉」，所以结果必须是下拉那个品牌。
$body = "id=$id1&name=ZZTEST-BRD1&price=10&stock=5&category=&brandPick=" +
        [System.Uri]::EscapeDataString($BX) + "&brandCustom=" + $B1
$r = Hit "$BASE/product/edit" "POST" $body $jar
Check "编辑 -> 302 /product/list" $r.Code 302

$r = Hit ("$BASE/product/edit?id=" + $id1) "GET" $null $jar
CheckTrue "品牌换成了下拉选的那个" ($r.Text.Contains('value="' + $BX + '" selected'))
CheckTrue "手输框里的旧名字没被采纳" (-not $r.Text.Contains('value="' + $B1 + '" selected'))

# ---------- 8. 用「无品牌」清空 ----------
Write-Host "`n---- 8. 选「无品牌」把品牌清掉 ----"
$body = "id=$id1&name=ZZTEST-BRD1&price=10&stock=5&category=&brandPick=&brandCustom=" + $B1
$r = Hit "$BASE/product/edit" "POST" $body $jar
Check "清空品牌 -> 302 /product/list" $r.Code 302

$filterUrl = ("$BASE/product/list?brand=" + [System.Uri]::EscapeDataString($B1))
$r = Hit $filterUrl "GET" $null $jar
Check "该品牌下只剩 BRD2 一件" (Rows $r.Text '/product/edit\?id=') 1
CheckTrue "BRD1 已经不在这个筛选里" (-not (HasItem $r.Text $id1))
CheckTrue "BRD2 还在" (HasItem $r.Text $id2)

# ---------- 9. 清空商品上的品牌 ≠ 删掉品牌 ----------
# 品牌库里那条记录还好端端待着（要去品牌管理页删才叫删）
Write-Host "`n---- 9. 品牌库里的记录不受影响 ----"
Check "品牌行数没变" (BrandRows $jar) ($brdStart0 + 2)
CheckTrue "品牌名还在" ((FindBrandId $jar $B1) -ne "")

# ---------- 10. multipart 下的中文品牌 ----------
Write-Host "`n---- 10. multipart 形式提交中文品牌 ----"
$mp = Multipart @{ name="ZZTEST-BRD3"; price="7"; stock="9"; category=""; brandPick=$BX } "" "" $null
$r = Hit "$BASE/product/add" "POST" $null $jar ("multipart/form-data; boundary=" + $mp.Boundary) $mp.Bytes
Check "multipart 新增 -> 302" $r.Code 302

$id3 = FindId $jar "ZZTEST-BRD3"
CheckTrue "商品建出来了" ($id3 -ne "")
$r = Hit ("$BASE/product/edit?id=" + $id3) "GET" $null $jar
CheckTrue "multipart 里的中文品牌名没乱码" ($r.Text.Contains('value="' + $BX + '" selected'))

# ---------- 11. 非法品牌名拦下来 ----------
Write-Host "`n---- 11. 非法品牌名 ----"
$bad = "name=ZZTEST-BRD9&price=1&stock=1&category=&brandPick=__other__&brandCustom="

$r = Hit "$BASE/product/add" "POST" ($bad + [System.Uri]::EscapeDataString("<script>alert(1)</script>")) $jar
Check "带尖括号的品牌名 -> 退回新增页" $r.Code 302
CheckTrue "退回的是 /product/add" ($r.Location -like "*/product/add")

$r = Hit "$BASE/product/add" "POST" ($bad + [System.Uri]::EscapeDataString($LONG)) $jar
Check "超长品牌名 -> 退回新增页" $r.Code 302
CheckTrue "退回的是 /product/add" ($r.Location -like "*/product/add")

$r = Hit "$BASE/product/add" "POST" ($bad + "__other__") $jar
Check "拿保留字当品牌名 -> 退回新增页" $r.Code 302

$r = Hit "$BASE/product/list?keyword=ZZTEST-BRD9" "GET" $null $jar
Check "这些非法请求一个商品都没建成（结果 0 行）" (Rows $r.Text '/product/edit\?id=') 0

$r = Hit "$BASE/brand" "GET" $null $jar
CheckTrue "非法品牌名也没混进品牌库" (-not $r.Text.Contains($LONG))
Check "品牌行数没被这些失败请求改过" (Rows $r.Text 'id="bf-') ($brdStart0 + 2)

# ---------- 12. 前台看得到这个品牌 ----------
Write-Host "`n---- 12. 前台商城显示 ----"
# 不带 cookie：游客视角
$r = Hit ("$BASE/mall/item?id=" + $id2) "GET" $null $null
Check "游客访问商品详情 -> 200" $r.Code 200
CheckTrue "详情页显示自定义品牌" ($r.Text.Contains($B1))

# ---------- 13. 收尾：把测试数据清干净 ----------
Write-Host "`n---- 13. 清理 ----"
foreach ($kw in @("ZZTEST-BRD1", "ZZTEST-BRD2", "ZZTEST-BRD3")) {
    $rid = FindId $jar $kw
    if ($rid -ne "") { Hit "$BASE/product/delete" "POST" "id=$rid" $jar | Out-Null }
}
foreach ($bn in @($B1, $BX, $LONG)) {
    $bid = FindBrandId $jar $bn
    if ($bid -ne "") { Hit "$BASE/brand/delete" "POST" "id=$bid" $jar | Out-Null }
}

Check "品牌行数回到干净起点" (BrandRows $jar) $brdStart0
$r = Hit "$BASE/product/list?keyword=ZZTEST-BRD" "GET" $null $jar
Check "测试商品已清空（结果 0 行）" (Rows $r.Text '/product/edit\?id=') 0

# ---------- 结果 ----------
Write-Host ""
Write-Host ("==== 通过 " + $pass + " / 失败 " + $fail + " ====") -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })
if ($fail -gt 0) {
    Write-Host "失败的项:" -ForegroundColor Yellow
    $fails | ForEach-Object { Write-Host ("  - " + $_) }
    exit 1
}
exit 0
