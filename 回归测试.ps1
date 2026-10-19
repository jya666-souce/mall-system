<#
  商品管理系统 —— 回归测试脚本（改完代码跑一遍，看有没有把别的功能碰坏）
  ------------------------------------------------------------------
  用法：
      1. 先启动服务 —— 双击桌面「启动商品管理系统.vbs」，或手动启动 Tomcat
      2. powershell -NoProfile -ExecutionPolicy Bypass -File "D:\workpace\Calculator\回归测试.ps1"
      3. 看控制台最后一行；明细在 回归测试结果.log

  覆盖范围：
      未登录拦截 / 登录·登出 / 登录错误提示 / 工作台统计 / 列表的搜索·筛选·排序·分页
      商品增删改 / 表单校验 / 批量删除 / 分类·品牌 CRUD（含重名拒绝、被占用删不掉）
      权限隔离（普通用户页面无写按钮 + 直接敲 URL 返回 403）/ 中文编码往返

  说明：
      * 脚本自己创建测试数据，跑完自己清理，结束时数据回到原样
      * 中文全部用 Unicode 码点 [char]0xXXXX 拼出来，不依赖脚本文件编码
      * 用 .NET HttpWebRequest 且 AllowAutoRedirect=$false，是为了能精确断言
        302 的 Location —— 这正是排查「登录后跳错地址」那类问题的关键
#>
$base = "http://localhost:8080/shop"
$out  = "D:\workpace\Calculator\回归测试结果.log"
$L = New-Object System.Collections.Generic.List[string]
function Say([string]$m) { $L.Add($m) }
function CN([int[]]$cp) { $s = ""; foreach ($c in $cp) { $s += [char]$c }; return $s }

$script:pass = 0
$script:fail = 0
function Chk($name, $cond, $detail) {
    if ($cond) { $script:pass++; Say ("PASS  " + $name) }
    else { $script:fail++; Say ("FAIL  " + $name + "   <<  " + $detail) }
}

function Hit($url, $method, $body, $jar) {
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.Method = $method
    $req.AllowAutoRedirect = $false
    $req.CookieContainer = $jar
    $req.Timeout = 25000
    if ($body -ne $null) {
        $sb = ""
        foreach ($k in $body.Keys) {
            $v = $body[$k]
            if ($v -is [array]) {
                foreach ($x in $v) { $sb += [System.Uri]::EscapeDataString($k) + "=" + [System.Uri]::EscapeDataString([string]$x) + "&" }
            } else {
                $sb += [System.Uri]::EscapeDataString($k) + "=" + [System.Uri]::EscapeDataString([string]$v) + "&"
            }
        }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb)
        $req.ContentType = "application/x-www-form-urlencoded; charset=UTF-8"
        $req.ContentLength = $bytes.Length
        $st = $req.GetRequestStream(); $st.Write($bytes, 0, $bytes.Length); $st.Close()
    }
    $resp = $null
    try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response }
    if ($resp -eq $null) { return @{ code = -1; loc = ""; html = "" } }
    $code = [int]$resp.StatusCode
    $loc = ""
    if ($resp.Headers["Location"]) { $loc = $resp.Headers["Location"] }
    $html = ""
    try {
        $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $html = $sr.ReadToEnd(); $sr.Close()
    } catch { }
    $resp.Close()
    return @{ code = $code; loc = $loc; html = $html }
}
function Rows($html, $pat) { return ([regex]::Matches([string]$html, $pat)).Count }

# --- dictionary of Chinese strings, built from code points ---
$T_DASH   = CN @(0x5DE5, 0x4F5C, 0x53F0)                            # 工作台
$T_PRODCT = CN @(0x5546, 0x54C1, 0x5217, 0x8868)                    # 商品列表
$T_FILTER = CN @(0x7B5B, 0x9009, 0x6761, 0x4EF6)                    # 筛选条件
$T_BULKDEL= CN @(0x6279, 0x91CF, 0x5220, 0x9664)                    # 批量删除
$T_ONLYRD = CN @(0x53EA, 0x8BFB)                                    # 只读
$T_ADDEDP = CN @(0x5DF2, 0x65B0, 0x589E, 0x5546, 0x54C1)            # 已新增商品
$T_ADDEDC = CN @(0x5DF2, 0x65B0, 0x589E, 0x5206, 0x7C7B)            # 已新增分类
$T_SEVERE = CN @(0x4E25, 0x91CD, 0x4E0D, 0x8DB3)                    # 严重不足
$T_NEEDU  = CN @(0x9700, 0x8981, 0x8865, 0x8D27)                    # 需要补货
$T_NOUSER = CN @(0x8BF7, 0x8F93, 0x5165, 0x7528, 0x6237, 0x540D)    # 请输入用户名
$T_NOPASS = CN @(0x8BF7, 0x8F93, 0x5165, 0x5BC6, 0x7801)            # 请输入密码
$T_BADCRED= CN @(0x7528, 0x6237, 0x540D, 0x6216, 0x5BC6, 0x7801, 0x9519, 0x8BEF)  # 用户名或密码错误
$N_PROD   = CN @(0x6D4B, 0x8BD5, 0x5546, 0x54C1, 0x7532)            # 测试商品甲
$N_CAT    = CN @(0x6D4B, 0x8BD5, 0x5206, 0x7C7B)                    # 测试分类
$N_CAT2   = CN @(0x6D4B, 0x8BD5, 0x5206, 0x7C7B, 0x0032)            # 测试分类2
$N_BRD    = CN @(0x6D4B, 0x8BD5, 0x54C1, 0x724C)                    # 测试品牌
$N_BRD2   = CN @(0x6D4B, 0x8BD5, 0x54C1, 0x724C, 0x0032)            # 测试品牌2

Say "############ 1. no-auth ############"
$j0 = New-Object System.Net.CookieContainer
$r = Hit "$base/dashboard" "GET" $null $j0
Chk "no-auth /dashboard -> 302 login?redirect=/dashboard" ($r.code -eq 302 -and $r.loc -eq "/shop/login?redirect=%2Fdashboard") ("code=" + $r.code + " loc=" + $r.loc)
$r = Hit "$base/product/list" "GET" $null $j0
Chk "no-auth /product/list -> 302 login?redirect=/product/list" ($r.code -eq 302 -and $r.loc -eq "/shop/login?redirect=%2Fproduct%2Flist") ("code=" + $r.code + " loc=" + $r.loc)
$r = Hit "$base/css/style.css" "GET" $null $j0
Chk "static css reachable without login" ($r.code -eq 200) ("code=" + $r.code)

Say "############ 2. admin login ############"
$j1 = New-Object System.Net.CookieContainer
$r = Hit "$base/login" "POST" @{ username = "admin"; password = "123456" } $j1
Chk "POST /login -> 302 /shop/mall (default lands on the mall)" ($r.code -eq 302 -and $r.loc -eq "/shop/mall") ("code=" + $r.code + " loc=" + $r.loc)
$r = Hit "$base/dashboard" "GET" $null $j1
$dash = $r.html
Chk "GET /dashboard -> 200" ($r.code -eq 200) ("code=" + $r.code)
Chk "dashboard contains 工作台" ($dash.Contains($T_DASH)) "missing marker"
Chk "dashboard has 12 bar rows" ((Rows $dash "bar-row") -eq 12) ("got " + (Rows $dash "bar-row"))
Chk "dashboard has low-stock warnings" ((Rows $dash "badge-warn") -ge 1) ("got " + (Rows $dash "badge-warn"))
Chk "dashboard stat cards >= 4" ((Rows $dash 'class="stat') -ge 4) ("got " + (Rows $dash 'class="stat'))
$r = Hit "$base/login" "GET" $null $j1
Chk "GET /login while logged in -> 302 /mall" ($r.code -eq 302 -and $r.loc -eq "/shop/mall") ("code=" + $r.code + " loc=" + $r.loc)

Say "############ 3. product list (the 500 fix) ############"
$r = Hit "$base/product/list" "GET" $null $j1
Chk "GET /product/list -> 200 (was HTTP 500)" ($r.code -eq 200) ("code=" + $r.code)
Chk "list shows 8 rows (PAGE_SIZE)" ((Rows $r.html "/product/edit\?id=") -eq 8) ("got " + (Rows $r.html "/product/edit\?id="))
Chk "list shows 筛选条件" ($r.html.Contains($T_FILTER)) "missing"
Chk "list has pagination pager" ((Rows $r.html "class=.pager.") -ge 1) "no pager"
Chk "list has bulk-delete button for admin" ($r.html.Contains($T_BULKDEL)) "missing"
Chk "all option values present" ($r.html.Contains('value="priceDesc"') -and $r.html.Contains('value="priceAsc"') -and $r.html.Contains('value="stockDesc"')) "missing sort options"

Say "--- pagination & bad params ---"
foreach ($u in @("?page=2", "?page=999", "?page=-3", "?page=abc", "?minPrice=abc", "?maxPrice=zz")) {
    $r = Hit ("$base/product/list" + $u) "GET" $null $j1
    Chk ("list" + $u + " -> 200 no crash") ($r.code -eq 200) ("code=" + $r.code)
}
$r = Hit "$base/product/list?keyword=zzz-no-such" "GET" $null $j1
Chk "empty result -> 200 with 0 rows" ($r.code -eq 200 -and (Rows $r.html "/product/edit\?id=") -eq 0) ("code=" + $r.code + " rows=" + (Rows $r.html "/product/edit\?id="))

Say "--- sorting ---"
function Prices($html) { return @([regex]::Matches($html, 'class="num price">[^0-9]*([0-9]+\.[0-9]+)') | ForEach-Object { [double]$_.Groups[1].Value }) }
function Stocks($html) { return @([regex]::Matches($html, '<td class="num">(\d+)</td>') | ForEach-Object { [int]$_.Groups[1].Value }) }
function IsAsc($a) { for ($i = 1; $i -lt $a.Count; $i++) { if ($a[$i] -lt $a[$i - 1]) { return $false } } return $true }
function IsDesc($a) { for ($i = 1; $i -lt $a.Count; $i++) { if ($a[$i] -gt $a[$i - 1]) { return $false } } return $true }

$r = Hit "$base/product/list?sort=priceAsc" "GET" $null $j1
$p = Prices $r.html
Chk "sort=priceAsc ascending" ((IsAsc $p) -and $p.Count -gt 1) ($p -join ",")
$r = Hit "$base/product/list?sort=priceDesc" "GET" $null $j1
$p = Prices $r.html
Chk "sort=priceDesc descending" ((IsDesc $p) -and $p.Count -gt 1) ($p -join ",")
$r = Hit "$base/product/list?sort=stockDesc" "GET" $null $j1
$s = Stocks $r.html
Chk "sort=stockDesc descending" ((IsDesc $s) -and $s.Count -gt 1) ($s -join ",")
$r = Hit "$base/product/list?minPrice=10&maxPrice=100" "GET" $null $j1
Chk "price range filter works" ($r.code -eq 200 -and (Rows $r.html "/product/edit\?id=") -ge 1) ("rows=" + (Rows $r.html "/product/edit\?id="))

Say "############ 4. product add / edit (Chinese round-trip) ############"
$r = Hit "$base/product/add" "GET" $null $j1
Chk "GET /product/add -> 200" ($r.code -eq 200) ("code=" + $r.code)
$r = Hit "$base/product/add" "POST" @{ name = $N_PROD; price = "88.88"; stock = "666"; category = ""; brandPick = "" } $j1
Chk "POST add -> 302 /product/list" ($r.code -eq 302 -and $r.loc -like "*/product/list") ("code=" + $r.code + " loc=" + $r.loc)
$r = Hit "$base/product/list" "GET" $null $j1
Chk "success flash 已新增商品 shown" ($r.html.Contains($T_ADDEDP)) "missing"
$r2 = Hit "$base/product/list" "GET" $null $j1
Chk "flash consumed after first render" (-not $r2.html.Contains($T_ADDEDP)) "flash leaked twice"

$search = "$base/product/list?keyword=" + [System.Uri]::EscapeDataString($N_PROD)
$r = Hit $search "GET" $null $j1
Chk "Chinese keyword search finds the row" ($r.html.Contains($N_PROD)) "not found"
Chk "Chinese name survived POST+GET round-trip" ((Rows $r.html "/product/edit\?id=") -eq 1) ("rows=" + (Rows $r.html "/product/edit\?id="))
$m = [regex]::Match($r.html, "/product/edit\?id=(\d+)")
$newId = ""
if ($m.Success) { $newId = $m.Groups[1].Value }
Say ("     new product id = " + $newId)

if ($newId -ne "") {
    $r = Hit ("$base/product/edit?id=" + $newId) "GET" $null $j1
    Chk "GET /product/edit -> 200 with prefilled name" ($r.code -eq 200 -and $r.html.Contains($N_PROD)) ("code=" + $r.code)
    $r = Hit "$base/product/edit" "POST" @{ id = $newId; name = $N_PROD; price = "99.99"; stock = "5"; category = ""; brandPick = "" } $j1
    Chk "POST edit -> 302 /product/list" ($r.code -eq 302 -and $r.loc -like "*/product/list") ("code=" + $r.code + " loc=" + $r.loc)
    $r = Hit $search "GET" $null $j1
    Chk "edited price 99.99 rendered" ($r.html.Contains("99.99")) "not updated"
    Chk "low stock badge 严重不足 shown" ($r.html.Contains($T_SEVERE)) "missing"

    $r = Hit "$base/product/edit" "POST" @{ id = "999999"; name = "E2E-Ghost"; price = "1"; stock = "1" } $j1
    Chk "edit nonexistent id -> back to the edit form with an error" ($r.code -eq 302 -and $r.loc -like "*product/edit?id=999999") ("code=" + $r.code + " loc=" + $r.loc)
    $r = Hit "$base/product/edit?id=999999" "GET" $null $j1
    Chk "GET edit nonexistent -> 302 /product/list" ($r.code -eq 302 -and $r.loc -like "*/product/list") ("code=" + $r.code)
}

Say "############ 5. validation ############"
$r = Hit "$base/product/add" "POST" @{ name = "E2E-Neg1"; price = "-5"; stock = "3" } $j1
Chk "negative price -> back to /product/add" ($r.code -eq 302 -and $r.loc -like "*/product/add") ("code=" + $r.code + " loc=" + $r.loc)
$r = Hit "$base/product/add" "GET" $null $j1
Chk "error flash on form page" ($r.html.Contains("flash-err")) "missing"
$r = Hit "$base/product/add" "POST" @{ name = "E2E-Neg2"; price = "5"; stock = "-3" } $j1
Chk "negative stock -> back to /product/add" ($r.code -eq 302 -and $r.loc -like "*/product/add") ("code=" + $r.code)
$r = Hit "$base/product/add" "POST" @{ name = $N_PROD; price = "5"; stock = "3" } $j1
Chk "duplicate name -> back to /product/add" ($r.code -eq 302 -and $r.loc -like "*/product/add") ("code=" + $r.code + " loc=" + $r.loc)
$r = Hit "$base/product/add" "POST" @{ name = "  "; price = "5"; stock = "3" } $j1
Chk "blank name -> back to /product/add" ($r.code -eq 302 -and $r.loc -like "*/product/add") ("code=" + $r.code)
$r = Hit "$base/product/add" "POST" @{ name = "E2E-Neg3"; price = "abc"; stock = "3" } $j1
Chk "non-numeric price -> back to /product/add" ($r.code -eq 302 -and $r.loc -like "*/product/add") ("code=" + $r.code)

Say "############ 6. bulk delete ############"
$ids = @()
foreach ($k in 1..3) {
    $n2 = "E2E-Del-" + $k
    Hit "$base/product/add" "POST" @{ name = $n2; price = "1"; stock = "1" } $j1 | Out-Null
    $rr = Hit ("$base/product/list?keyword=" + $n2) "GET" $null $j1
    $mm = [regex]::Match($rr.html, "/product/edit\?id=(\d+)")
    if ($mm.Success) { $ids += [int]$mm.Groups[1].Value }
}
Chk "3 test products created" ($ids.Count -eq 3) ("ids=" + ($ids -join ","))
Say ("     created ids = " + ($ids -join ","))
if ($ids.Count -eq 3) {
    $r = Hit "$base/product/delete" "POST" @{ id = @($ids[0], $ids[1]) } $j1
    Chk "bulk delete 2 -> 302 /product/list" ($r.code -eq 302 -and $r.loc -like "*/product/list") ("code=" + $r.code)
    $alive = @()
    foreach ($k in 1..3) {
        $n2 = "E2E-Del-" + $k
        $rr = Hit ("$base/product/list?keyword=" + $n2) "GET" $null $j1
        if ((Rows $rr.html "/product/edit\?id=") -gt 0) { $alive += $n2 }
    }
    Chk "exactly the unselected item survived" ($alive.Count -eq 1 -and $alive[0] -eq "E2E-Del-3") ("alive=" + ($alive -join ","))
    $r = Hit "$base/product/delete" "POST" @{ id = $ids[2] } $j1
    $rr = Hit ("$base/product/list?keyword=E2E-Del-3") "GET" $null $j1
    Chk "single delete removes last one" ((Rows $rr.html "/product/edit\?id=") -eq 0) "still there"
}
$r = Hit "$base/product/delete" "POST" @{} $j1
Chk "delete with no id -> 302 no crash" ($r.code -eq 302) ("code=" + $r.code)
$r = Hit "$base/product/delete" "POST" @{ id = "abc" } $j1
Chk "delete with junk id -> 302 no crash" ($r.code -eq 302) ("code=" + $r.code)

Say "############ 7. category ############"
$r = Hit "$base/category" "GET" $null $j1
$catBefore = Rows $r.html 'id="cf-'
Chk "GET /category -> 200" ($r.code -eq 200) ("code=" + $r.code)
Say ("     category rows before = " + $catBefore)
$r = Hit "$base/category/add" "POST" @{ name = $N_CAT; remark = "e2e" } $j1
Chk "POST /category/add -> 302 /category" ($r.code -eq 302 -and $r.loc -like "*/category") ("code=" + $r.code + " loc=" + $r.loc)
$r = Hit "$base/category" "GET" $null $j1
Chk "flash 已新增分类 shown" ($r.html.Contains($T_ADDEDC)) "missing"
Chk "category rows +1" ((Rows $r.html 'id="cf-') -eq ($catBefore + 1)) ("got " + (Rows $r.html 'id="cf-'))
$r2 = Hit "$base/category" "GET" $null $j1
Chk "category flash consumed once" (-not $r2.html.Contains($T_ADDEDC)) "leaked"
$cids = @([regex]::Matches($r2.html, 'id="cf-(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value })
$maxCat = ($cids | Measure-Object -Maximum).Maximum
$r = Hit "$base/category/update" "POST" @{ id = $maxCat; name = $N_CAT2; remark = "e2e2" } $j1
Chk "POST /category/update -> 302" ($r.code -eq 302) ("code=" + $r.code)
$r = Hit "$base/category" "GET" $null $j1
Chk "renamed category visible" ($r.html.Contains($N_CAT2)) "not renamed"
$r = Hit "$base/category/delete" "POST" @{ id = 1 } $j1
Chk "delete occupied category -> 302" ($r.code -eq 302) ("code=" + $r.code)
$r = Hit "$base/category" "GET" $null $j1
Chk "occupied delete blocked with error flash" ($r.html.Contains("flash-err")) "no error flash"
Chk "occupied delete kept row count" ((Rows $r.html 'id="cf-') -eq ($catBefore + 1)) ("got " + (Rows $r.html 'id="cf-'))
$r = Hit "$base/category/delete" "POST" @{ id = $maxCat } $j1
$r = Hit "$base/category" "GET" $null $j1
Chk "delete idle category works" ((Rows $r.html 'id="cf-') -eq $catBefore) ("got " + (Rows $r.html 'id="cf-'))
$r = Hit "$base/category/add" "POST" @{ name = $N_CAT; remark = "dup1" } $j1
Chk "re-add free category name -> 302" ($r.code -eq 302) ("code=" + $r.code)
$r = Hit "$base/category" "GET" $null $j1
$catRows = Rows $r.html 'id="cf-'
$r = Hit "$base/category/add" "POST" @{ name = $N_CAT; remark = "dup2" } $j1
$r = Hit "$base/category" "GET" $null $j1
Chk "duplicate category name rejected (flash-err, no new row)" ($r.html.Contains("flash-err") -and (Rows $r.html 'id="cf-') -eq $catRows) ("rows=" + (Rows $r.html 'id="cf-') + " was " + $catRows)
$cids2 = @([regex]::Matches($r.html, 'id="cf-(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value })
$maxCat2 = ($cids2 | Measure-Object -Maximum).Maximum
Hit "$base/category/delete" "POST" @{ id = $maxCat2 } $j1 | Out-Null
$r = Hit "$base/category" "GET" $null $j1
Chk "category back to baseline" ((Rows $r.html 'id="cf-') -eq $catBefore) ("rows=" + (Rows $r.html 'id="cf-'))

Say "############ 8. brand ############"
$r = Hit "$base/brand" "GET" $null $j1
$brdBefore = Rows $r.html 'id="bf-'
Chk "GET /brand -> 200" ($r.code -eq 200) ("code=" + $r.code)
Say ("     brand rows before = " + $brdBefore)
$r = Hit "$base/brand/add" "POST" @{ name = $N_BRD; remark = "e2e" } $j1
Chk "POST /brand/add -> 302 /brand" ($r.code -eq 302 -and $r.loc -like "*/brand") ("code=" + $r.code)
$r = Hit "$base/brand" "GET" $null $j1
Chk "brand rows +1" ((Rows $r.html 'id="bf-') -eq ($brdBefore + 1)) ("got " + (Rows $r.html 'id="bf-'))
$bids = @([regex]::Matches($r.html, 'id="bf-(\d+)"') | ForEach-Object { [int]$_.Groups[1].Value })
$maxBrd = ($bids | Measure-Object -Maximum).Maximum
$r = Hit "$base/brand/update" "POST" @{ id = $maxBrd; name = $N_BRD2; remark = "e2e2" } $j1
Chk "POST /brand/update -> 302" ($r.code -eq 302) ("code=" + $r.code)
$r = Hit "$base/brand" "GET" $null $j1
Chk "renamed brand visible" ($r.html.Contains($N_BRD2)) "not renamed"
$r = Hit "$base/brand/delete" "POST" @{ id = 1 } $j1
$r = Hit "$base/brand" "GET" $null $j1
Chk "occupied brand delete blocked" ((Rows $r.html 'id="bf-') -eq ($brdBefore + 1) -and $r.html.Contains("flash-err")) ("got " + (Rows $r.html 'id="bf-'))
$r = Hit "$base/brand/delete" "POST" @{ id = $maxBrd } $j1
$r = Hit "$base/brand" "GET" $null $j1
Chk "delete idle brand works" ((Rows $r.html 'id="bf-') -eq $brdBefore) ("got " + (Rows $r.html 'id="bf-'))

Say "############ 9. normal user permissions ############"
$j2 = New-Object System.Net.CookieContainer
$r = Hit "$base/login" "POST" @{ username = "user"; password = "123456" } $j2
Chk "user login -> 302 /shop/mall (no longer /dashboard)" ($r.code -eq 302 -and $r.loc -eq "/shop/mall") ("code=" + $r.code + " loc=" + $r.loc)
$r = Hit "$base/product/list" "GET" $null $j2
Chk "user can open /product/list" ($r.code -eq 200) ("code=" + $r.code)
Chk "user page has NO /product/delete reference" (-not $r.html.Contains("/product/delete")) ("count=" + (Rows $r.html "/product/delete"))
Chk "user page has NO /product/add reference" (-not $r.html.Contains("/product/add")) "found add link"
Chk "user page marks row as 只读" ($r.html.Contains($T_ONLYRD)) "missing"
Chk "user page hides bulk-delete button" (-not $r.html.Contains($T_BULKDEL)) "found bulk button"
$r = Hit "$base/product/add" "GET" $null $j2
Chk "user GET /product/add -> 403" ($r.code -eq 403) ("code=" + $r.code)
$r = Hit "$base/product/edit?id=1" "GET" $null $j2
Chk "user GET /product/edit -> 403" ($r.code -eq 403) ("code=" + $r.code)
$r = Hit "$base/product/delete" "POST" @{ id = 1 } $j2
Chk "user POST /product/delete -> 403" ($r.code -eq 403) ("code=" + $r.code)
$r = Hit "$base/category/add" "POST" @{ name = "x" } $j2
Chk "user POST /category/add -> 403" ($r.code -eq 403) ("code=" + $r.code)
$r = Hit "$base/brand/delete" "POST" @{ id = 1 } $j2
Chk "user POST /brand/delete -> 403" ($r.code -eq 403) ("code=" + $r.code)
$r = Hit "$base/category" "GET" $null $j2
Chk "user GET /category -> 200" ($r.code -eq 200) ("code=" + $r.code)
Chk "user category page has no add form" (-not $r.html.Contains("/category/add")) "found"
Chk "user category page has no delete form" (-not $r.html.Contains("/category/delete")) "found"
$r = Hit "$base/brand" "GET" $null $j2
Chk "user GET /brand -> 200, no add form" ($r.code -eq 200 -and -not $r.html.Contains("/brand/add")) ("code=" + $r.code)
$r = Hit "$base/dashboard" "GET" $null $j2
Chk "user GET /dashboard -> 200" ($r.code -eq 200) ("code=" + $r.code)

Say "############ 10. login errors ############"
$j3 = New-Object System.Net.CookieContainer
$r = Hit "$base/login" "POST" @{ username = ""; password = "123456" } $j3
Chk "empty username -> 请输入用户名" ($r.code -eq 200 -and $r.html.Contains($T_NOUSER)) ("code=" + $r.code)
$r = Hit "$base/login" "POST" @{ username = "admin"; password = "" } $j3
Chk "empty password -> 请输入密码" ($r.html.Contains($T_NOPASS)) "missing"
$r = Hit "$base/login" "POST" @{ username = "admin"; password = "wrong" } $j3
Chk "wrong password -> 用户名或密码错误" ($r.html.Contains($T_BADCRED)) "missing"
$r = Hit "$base/login" "POST" @{ username = "nosuch"; password = "123456" } $j3
Chk "unknown user -> 用户名或密码错误" ($r.html.Contains($T_BADCRED)) "missing"
$r = Hit "$base/login" "GET" $null $j3
Chk "login page 200 and UTF-8 declared" ($r.code -eq 200 -and $r.html.Contains('charset="UTF-8"')) ("code=" + $r.code)

Say "############ 11. logout ############"
$r = Hit "$base/logout" "GET" $null $j2
Chk "logout -> 302 /shop/login" ($r.code -eq 302 -and $r.loc -eq "/shop/login") ("code=" + $r.code + " loc=" + $r.loc)
$r = Hit "$base/product/list" "GET" $null $j2
Chk "after logout -> 302 login?redirect=/product/list" ($r.code -eq 302 -and $r.loc -eq "/shop/login?redirect=%2Fproduct%2Flist") ("code=" + $r.code + " loc=" + $r.loc)

Say "############ 12. cleanup test data ############"
if ($newId -ne "") {
    Hit "$base/product/delete" "POST" @{ id = $newId } $j1 | Out-Null
    $rr = Hit $search "GET" $null $j1
    Chk "Chinese test product removed" ((Rows $rr.html "/product/edit\?id=") -eq 0) "still there"
}
$r = Hit "$base/product/list" "GET" $null $j1
Chk "back to 8 products on page 1" ((Rows $r.html "/product/edit\?id=") -eq 8) ("rows=" + (Rows $r.html "/product/edit\?id="))

Say ""
Say ("################ RESULT: " + $script:pass + " passed, " + $script:fail + " failed ################")

Set-Content -Path $out -Value $L -Encoding UTF8
Write-Output ("verify done " + $script:pass + "/" + ($script:pass + $script:fail))
