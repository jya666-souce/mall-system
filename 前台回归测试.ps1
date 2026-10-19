<#
  优选商城 —— 前台 + 订单 回归测试
  ---------------------------------------------------------------
  用法：
      1. 先启动服务（双击桌面「启动商品管理系统.vbs」）
      2. powershell -NoProfile -ExecutionPolicy Bypass -File "D:\workpace\Calculator\前台回归测试.ps1"
      3. 看最后一行；明细在 前台回归测试结果.log

  为什么和「回归测试.ps1」分开？
      后台和前台是两条独立的访问链路：
        后台 = 先登录 + 再看权限码
        前台 = 不登录也能逛，下单才要登录
      混在一个脚本里，任何一处失败都难定位。分开跑，改哪边就测哪边。

  覆盖范围：
      游客浏览（免登录）/ 商品详情 404 兜底 / 购物车增删改清 / 库存上限拦截
      未登录下单被弹去登录 + 登录后回跳 / 换 session 时购物车保留
      开放重定向防护 / 下单扣库存 / 我的订单 / 取消订单回滚库存 / 水平越权拦截
      后台订单管理（列表、状态流转、终态不可改、只读角色看不到按钮）
      订单快照不受后台改价影响
      默认落点与门面：根路径 / 转商城 / 不带 redirect 登录落商城 / 后台入口只给有权限的人

  数据说明：
      * 商品、分类这些会自己造自己删，跑完回到原样
      * 订单没有删除接口，测试产生的订单会留在列表里 ——
        所以订单相关的断言全部用「相对数量」而不是绝对值。
        内存版重启 Tomcat 就清空了。
#>
$base = "http://localhost:8080/shop"
$out  = "D:\workpace\Calculator\前台回归测试结果.log"
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
            $sb += [System.Uri]::EscapeDataString($k) + "=" + [System.Uri]::EscapeDataString([string]$v) + "&"
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
function Stocks($html) { return @([regex]::Matches([string]$html, '<td class="num">(\d+)</td>') | ForEach-Object { [int]$_.Groups[1].Value }) }
function IsAsc($a) { for ($i = 1; $i -lt $a.Count; $i++) { if ($a[$i] -lt $a[$i - 1]) { return $false } } return $true }
function IsDesc($a) { for ($i = 1; $i -lt $a.Count; $i++) { if ($a[$i] -gt $a[$i - 1]) { return $false } } return $true }
function MPrice($html) { return @([regex]::Matches([string]$html, 'm-price"><i>[^<]*</i>([0-9]+\.[0-9]+)') | ForEach-Object { [double]$_.Groups[1].Value }) }
function FirstOrderId($html, $actionPath) {
    $m = [regex]::Match([string]$html, [regex]::Escape($actionPath) + '[\s\S]{0,300}?name="id" value="(\d+)"')
    if ($m.Success) { return $m.Groups[1].Value }
    return ""
}

$T_KELE    = CN @(0x53EF, 0x4E50)                       # 可乐
$T_SHIPPED = CN @(0x5DF2, 0x53D1, 0x8D27)               # 已发货
$T_DONE    = CN @(0x5DF2, 0x5B8C, 0x6210)               # 已完成
$T_FOOD    = CN @(0x98DF, 0x54C1)                       # 食品
$T_ADMIN   = CN @(0x540E, 0x53F0, 0x7BA1, 0x7406)       # 后台管理
$N_FLOW    = "E2E-Flow"
$N_GONE    = "E2E-Gone"

function Login([System.Net.CookieContainer]$jar, $u, $p, $redirect) {
    $b = @{ username = $u; password = $p }
    if ($redirect) { $b["redirect"] = $redirect }
    return Hit "$base/login" "POST" $b $jar
}

function SearchStock($jar, $keyword) {
    $u = "$base/product/list?keyword=" + [System.Uri]::EscapeDataString($keyword)
    $r = Hit $u "GET" $null $jar
    $s = Stocks $r.html
    if ($s.Count -ge 1) { return $s[0] }
    return -1
}
function FindProductId($jar, $keyword) {
    $u = "$base/product/list?keyword=" + [System.Uri]::EscapeDataString($keyword)
    $r = Hit $u "GET" $null $jar
    $m = [regex]::Match($r.html, '/product/edit\?id=(\d+)')
    if ($m.Success) { return $m.Groups[1].Value }
    return ""
}

Say "############ 1. guest browsing（游客免登录） ############"
$j4 = New-Object System.Net.CookieContainer
$r = Hit "$base/mall" "GET" $null $j4
Chk "guest GET /mall -> 200 (NOT bounced to login)" ($r.code -eq 200) ("code=" + $r.code + " loc=" + $r.loc)
Chk "guest sees >=8 product cards" ((Rows $r.html 'class="m-card"') -ge 8) ("cards=" + (Rows $r.html 'class="m-card"'))
Chk "guest nav has cart + login link" ($r.html.Contains("/mall/cart") -and $r.html.Contains("/login?redirect")) "missing nav"
Chk "guest nav has NO my-orders link" (-not $r.html.Contains("/mall/order/list")) "order link leaked"
Chk "guest page has its own stylesheet" ($r.html.Contains("/css/mall.css")) "missing mall.css"
Chk "no jsessionid baked into URLs (tracking-mode=COOKIE)" (-not $r.html.Contains("jsessionid")) "URL rewriting still on"

Say "--- detail page ---"
$r = Hit "$base/mall/item?id=1" "GET" $null $j4
Chk "guest GET /mall/item?id=1 -> 200" ($r.code -eq 200) ("code=" + $r.code)
Chk "detail page has add-to-cart form" ($r.html.Contains("/mall/cart/add")) "missing"
Chk "detail page shows related block" ($r.html.Contains("m-section-title")) "no related"
$r = Hit "$base/mall/item?id=999999" "GET" $null $j4
Chk "unknown item -> 404 (not 500)" ($r.code -eq 404) ("code=" + $r.code)
$r = Hit "$base/mall/item?id=abc" "GET" $null $j4
Chk "junk item id -> 404 (not 500)" ($r.code -eq 404) ("code=" + $r.code)

Say "--- filters / sort / paging ---"
foreach ($u in @("?page=2", "?page=999", "?page=-3", "?page=abc", "?minPrice=abc", "?category=zzz", "?sort=bogus")) {
    $r = Hit ("$base/mall" + $u) "GET" $null $j4
    Chk ("mall" + $u + " -> 200 no crash") ($r.code -eq 200) ("code=" + $r.code)
}
$r = Hit "$base/mall?sort=priceAsc" "GET" $null $j4
$p = MPrice $r.html
Chk "mall sort=priceAsc ascending" ((IsAsc $p) -and $p.Count -gt 1) ($p -join ",")
$r = Hit "$base/mall?sort=priceDesc" "GET" $null $j4
$p = MPrice $r.html
Chk "mall sort=priceDesc descending" ((IsDesc $p) -and $p.Count -gt 1) ($p -join ",")
$r = Hit ("$base/mall?category=" + [System.Uri]::EscapeDataString($T_FOOD)) "GET" $null $j4
Chk "category filter -> 200 and fewer cards" ($r.code -eq 200 -and (Rows $r.html 'class="m-card"') -lt 8) ("cards=" + (Rows $r.html 'class="m-card"'))

Say "############ 2. cart（游客也能加购） ############"
$r = Hit "$base/mall/cart" "GET" $null $j4
Chk "guest GET /mall/cart -> 200 empty" ($r.code -eq 200 -and $r.html.Contains("m-empty")) ("code=" + $r.code)
$r = Hit "$base/mall/cart/add" "POST" @{ id = "1"; qty = "2"; back = "/mall" } $j4
Chk "add to cart -> 302" ($r.code -eq 302) ("code=" + $r.code)
Chk "add redirects back to /mall (not cart)" ($r.loc -eq "/shop/mall") ("loc=" + $r.loc)
$r = Hit "$base/mall/cart" "GET" $null $j4
Chk "cart has 1 editable line" ((Rows $r.html "/mall/cart/set") -eq 1) ("got " + (Rows $r.html "/mall/cart/set"))
Chk "header badge shows count" ($r.html.Contains("m-badge")) "no badge"

$r = Hit "$base/mall/cart/set" "POST" @{ id = "1"; qty = "5" } $j4
Chk "set qty -> 302 /mall/cart" ($r.code -eq 302 -and $r.loc -eq "/shop/mall/cart") ("loc=" + $r.loc)
$r = Hit "$base/mall/cart" "GET" $null $j4
Chk "qty updated to 5" ($r.html.Contains('value="5"')) "missing value=5"

$r = Hit "$base/mall/cart/set" "POST" @{ id = "1"; qty = "99999" } $j4
$r = Hit "$base/mall/cart" "GET" $null $j4
Chk "qty over stock rejected with error flash" ($r.html.Contains("m-flash-err")) "no error"
Chk "qty stayed at 5 after rejection" ($r.html.Contains('value="5"')) "qty changed anyway"

$r = Hit "$base/mall/cart/add" "POST" @{ id = "1"; qty = "99999" } $j4
$r = Hit "$base/mall/cart" "GET" $null $j4
Chk "adding over stock rejected with error flash" ($r.html.Contains("m-flash-err")) "no error"

$r = Hit "$base/mall/cart/remove" "POST" @{ id = "1" } $j4
$r = Hit "$base/mall/cart" "GET" $null $j4
Chk "remove line -> cart empty" ($r.html.Contains("m-empty")) "still has lines"

Hit "$base/mall/cart/add" "POST" @{ id = "1"; qty = "1" } $j4 | Out-Null
$r = Hit "$base/mall/cart/clear" "POST" @{} $j4
$r = Hit "$base/mall/cart" "GET" $null $j4
Chk "clear cart -> empty" ($r.html.Contains("m-empty")) "not empty"

Say "############ 3. login gate + return-to ############"
$r = Hit "$base/mall/order/checkout" "GET" $null $j4
Chk "guest checkout -> 302 login with redirect" ($r.code -eq 302 -and $r.loc -like "*/login?redirect=*") ("code=" + $r.code + " loc=" + $r.loc)
Chk "redirect target is encoded checkout path" ($r.loc.Contains("order%2Fcheckout")) ("loc=" + $r.loc)
$r = Hit "$base/mall/order/list" "GET" $null $j4
Chk "guest my-orders -> 302 login with redirect" ($r.code -eq 302 -and $r.loc -like "*/login?redirect=*") ("loc=" + $r.loc)

Say "--- open redirect guard ---"
$j9 = New-Object System.Net.CookieContainer
$r = Login $j9 "user" "123456" "https://evil.com"
Chk "absolute URL redirect blocked -> /mall" ($r.code -eq 302 -and $r.loc -eq "/shop/mall") ("loc=" + $r.loc)
$j9b = New-Object System.Net.CookieContainer
$r = Login $j9b "user" "123456" "//evil.com/x"
Chk "protocol-relative redirect blocked -> /mall" ($r.code -eq 302 -and $r.loc -eq "/shop/mall") ("loc=" + $r.loc)
$j9c = New-Object System.Net.CookieContainer
$r = Login $j9c "user" "123456" "/mall?category=x"
Chk "in-site redirect allowed" ($r.code -eq 302 -and $r.loc -eq "/shop/mall?category=x") ("loc=" + $r.loc)

Say "--- default landing: the mall ---"
$jz = New-Object System.Net.CookieContainer
$r = Hit "$base/" "GET" $null $jz
Chk "guest GET / -> 302 /shop/mall (root is the mall front door)" ($r.code -eq 302 -and $r.loc -eq "/shop/mall") ("code=" + $r.code + " loc=" + $r.loc)
$jz2 = New-Object System.Net.CookieContainer
$r = Login $jz2 "admin" "123456" ""
Chk "login with no redirect -> 302 /shop/mall" ($r.code -eq 302 -and $r.loc -eq "/shop/mall") ("loc=" + $r.loc)

Say "--- backend entry visibility ---"
$r = Hit "$base/mall" "GET" $null $jz
Chk "guest mall has NO backend entry" (-not $r.html.Contains("/dashboard")) "guest can see a /dashboard link"
$r = Hit "$base/mall" "GET" $null $jz2
Chk "admin mall HAS backend entry" ($r.html.Contains("/dashboard")) "missing /dashboard link"
Chk "admin mall shows 后台管理 label" ($r.html.Contains($T_ADMIN)) "missing label"

Say "--- session switch keeps the cart ---"
$j5 = New-Object System.Net.CookieContainer
Hit "$base/mall/cart/add" "POST" @{ id = "1"; qty = "3"; back = "/mall" } $j5 | Out-Null
$r = Hit "$base/mall/cart" "GET" $null $j5
Chk "guest cart has the item before login" ($r.html.Contains("/mall/cart/set")) "cart empty before login"
$r = Login $j5 "user" "123456" "/mall/order/checkout"
Chk "login with redirect -> 302 back to checkout" ($r.code -eq 302 -and $r.loc -eq "/shop/mall/order/checkout") ("loc=" + $r.loc)
$r = Hit "$base/mall/cart" "GET" $null $j5
Chk "cart SURVIVED the session switch on login" ($r.html.Contains("/mall/cart/set")) "cart lost after login"

Say "############ 4. place order ############"
$ja = New-Object System.Net.CookieContainer
Login $ja "admin" "123456" "" | Out-Null
$r = Hit "$base/dashboard" "GET" $null $ja
Chk "admin logged in for stock checks" ($r.code -eq 200) ("code=" + $r.code)

$stockBefore = SearchStock $ja $T_KELE
Say ("     KELE stock before = " + $stockBefore)
Chk "baseline stock read" ($stockBefore -gt 0) ("stock=" + $stockBefore)

$r = Hit "$base/mall/order/checkout" "GET" $null $j5
Chk "GET checkout logged in -> 200" ($r.code -eq 200) ("code=" + $r.code)
Chk "checkout shows shipping form" ($r.html.Contains('name="receiver"')) "missing form"

$r = Hit "$base/mall/order/checkout" "POST" @{ receiver = ""; phone = "13800000000"; address = "E2E Street" } $j5
Chk "missing receiver -> form back with error" ($r.code -eq 200 -and $r.html.Contains("m-flash-err")) ("code=" + $r.code)
Chk "typed phone preserved after failure" ($r.html.Contains('value="13800000000"')) "form lost input"

$r = Hit "$base/mall/order/checkout" "GET" $null $j5
$ordersBefore = Rows (Hit "$base/mall/order/list" "GET" $null $j5).html "m-order-no"

$r = Hit "$base/mall/order/checkout" "POST" @{ receiver = "E2E Buyer"; phone = "13800000000"; address = "E2E Street 1" } $j5
Chk "place order -> 302 /mall/order/list" ($r.code -eq 302 -and $r.loc -eq "/shop/mall/order/list") ("code=" + $r.code + " loc=" + $r.loc)

$stockAfter = SearchStock $ja $T_KELE
Chk "stock decreased by 3" ($stockAfter -eq ($stockBefore - 3)) ("before=$stockBefore after=$stockAfter")

$r = Hit "$base/mall/order/list" "GET" $null $j5
Chk "my orders -> 200" ($r.code -eq 200) ("code=" + $r.code)
Chk "order count +1" ((Rows $r.html "m-order-no") -eq ($ordersBefore + 1)) ("before=$ordersBefore after=" + (Rows $r.html "m-order-no"))
Chk "new order is 待发货 (warn)" ($r.html.Contains("m-status warn")) "missing warn status"
Chk "pending order has cancel button" ($r.html.Contains("/mall/order/cancel")) "no cancel"

$r = Hit "$base/mall/cart" "GET" $null $j5
Chk "cart cleared after order" ($r.html.Contains("m-empty")) "cart not cleared"

Say "############ 5. cancel order restores stock ############"
$r = Hit "$base/mall/order/list" "GET" $null $j5
$pendingId = FirstOrderId $r.html "/mall/order/cancel"
Say ("     pending order id = " + $pendingId)
Chk "captured pending order id" ($pendingId -ne "") "not found"
if ($pendingId -ne "") {
    $r = Hit "$base/mall/order/cancel" "POST" @{ id = $pendingId } $j5
    Chk "cancel own order -> 302" ($r.code -eq 302) ("code=" + $r.code)
    $r = Hit "$base/mall/order/list" "GET" $null $j5
    Chk "order now 已取消 (gray)" ($r.html.Contains("m-status gray")) "missing gray status"
    Chk "canceled order hides cancel button" (-not $r.html.Contains("/mall/order/cancel")) "button still there"
    $stockBack = SearchStock $ja $T_KELE
    Chk "stock restored after cancel" ($stockBack -eq $stockBefore) ("expected=$stockBefore got=$stockBack")

    $r = Hit "$base/mall/order/cancel" "POST" @{ id = $pendingId } $j5
    $r = Hit "$base/mall/order/list" "GET" $null $j5
    Chk "second cancel rejected with error" ($r.html.Contains("m-flash-err")) "no error"
}

Say "############ 6. horizontal privilege (someone else's order) ############"
$jB = New-Object System.Net.CookieContainer
Login $jB "admin" "123456" "" | Out-Null
Hit "$base/mall/cart/add" "POST" @{ id = "1"; qty = "1" } $jB | Out-Null
$r = Hit "$base/mall/order/checkout" "POST" @{ receiver = "Admin"; phone = "13900000000"; address = "Admin St" } $jB
$r = Hit "$base/mall/order/list" "GET" $null $jB
$adminOrderId = FirstOrderId $r.html "/mall/order/cancel"
Say ("     admin order id = " + $adminOrderId)
Chk "admin placed an order" ($adminOrderId -ne "") "not found"

if ($adminOrderId -ne "") {
    $r = Hit "$base/mall/order/cancel" "POST" @{ id = $adminOrderId } $j5
    $r = Hit "$base/mall/order/list" "GET" $null $j5
    Chk "user CANNOT cancel admin's order" ($r.html.Contains("m-flash-err")) "no error raised"
    $r = Hit "$base/mall/order/list" "GET" $null $jB
    Chk "admin's order still 待发货" ($r.html.Contains("m-status warn")) "status changed!"

    $r = Hit "$base/mall/order/cancel" "POST" @{ id = $adminOrderId } $jB
    Chk "admin cancels own order for cleanup -> 302" ($r.code -eq 302) ("code=" + $r.code)
}
$r = Hit "$base/mall/order/list" "GET" $null $j4
Chk "guest still cannot see orders" ($r.code -eq 302) ("code=" + $r.code)

Say "############ 7. delisted item blocks checkout ############"
$r = Hit "$base/product/add" "POST" @{ name = $N_GONE; price = "9.90"; stock = "5" } $ja
Chk "created a throwaway product" ($r.code -eq 302) ("code=" + $r.code)
$goneId = FindProductId $ja $N_GONE
Say ("     throwaway product id = " + $goneId)

if ($goneId -ne "") {
    Hit "$base/mall/cart/add" "POST" @{ id = $goneId; qty = "1" } $j5 | Out-Null
    $r = Hit "$base/mall/cart" "GET" $null $j5
    Chk "cart has the throwaway item" ($r.html.Contains("/mall/cart/set")) "not added"

    Hit "$base/product/delete" "POST" @{ id = $goneId } $ja | Out-Null
    $r = Hit "$base/mall/cart" "GET" $null $j5
    Chk "delisted item flagged in cart" ($r.html.Contains("m-warn-box")) "no warning box"
    Chk "checkout button disabled while cart has a problem" ($r.html.Contains("disabled")) "still clickable"

    $r = Hit "$base/mall/order/checkout" "POST" @{ receiver = "X"; phone = "1"; address = "Y" } $j5
    Chk "checkout with delisted item -> rejected" ($r.code -eq 200 -and $r.html.Contains("m-flash-err")) ("code=" + $r.code)

    Hit "$base/mall/cart/clear" "POST" @{} $j5 | Out-Null
    $r = Hit "$base/mall/cart" "GET" $null $j5
    Chk "cart cleared of the delisted item" ($r.html.Contains("m-empty")) "not empty"
}

Say "############ 8. admin order management ############"
$r = Hit "$base/order" "GET" $null $ja
Chk "admin GET /order -> 200" ($r.code -eq 200) ("code=" + $r.code)
Chk "order page has status filter chips" ($r.html.Contains("/order?status=")) "no filter"
# 此刻历史订单全是「已取消」这类终态，所以一个操作按钮都不该有。
# 「有待发货单时按钮出现」留到下面真造出一张单之后再验 —— 顺序错了断言就是假的。
Chk "final-state orders expose no action buttons" ((Rows $r.html "/order/status") -eq 0) ("got " + (Rows $r.html "/order/status"))

$r = Hit "$base/order" "GET" $null $j5
Chk "read-only user GET /order -> 200" ($r.code -eq 200) ("code=" + $r.code)
Chk "read-only user sees NO action buttons" ((Rows $r.html "/order/status") -eq 0) ("got " + (Rows $r.html "/order/status"))
$r = Hit "$base/order/status" "POST" @{ id = "1"; status = $T_SHIPPED } $j5
Chk "read-only user POST /order/status -> 403" ($r.code -eq 403) ("code=" + $r.code)

$jz = New-Object System.Net.CookieContainer
$r = Hit "$base/order" "GET" $null $jz
Chk "guest GET /order -> 302 login" ($r.code -eq 302 -and $r.loc -like "*/login?redirect=*") ("code=" + $r.code)

Say "--- status machine: 待发货 -> 已发货 -> 已完成 ---"
Hit "$base/product/add" "POST" @{ name = $N_FLOW; price = "19.90"; stock = "10" } $ja | Out-Null
$flowId = FindProductId $ja $N_FLOW
Say ("     flow product id = " + $flowId)
Chk "flow product created" ($flowId -ne "") "not found"

if ($flowId -ne "") {
    Hit "$base/mall/cart/add" "POST" @{ id = $flowId; qty = "1" } $jB | Out-Null
    Hit "$base/mall/order/checkout" "POST" @{ receiver = "Flow"; phone = "1"; address = "F" } $jB | Out-Null
    $r = Hit "$base/mall/order/list" "GET" $null $jB
    $flowOrder = FirstOrderId $r.html "/mall/order/cancel"
    Say ("     flow order id = " + $flowOrder)
    Chk "flow order created" ($flowOrder -ne "") "not found"

    # 现在真有一张待发货单了，这条断言才有意义
    $r = Hit "$base/order" "GET" $null $ja
    Chk "pending order exposes ship + cancel buttons" ((Rows $r.html "/order/status") -ge 2) ("got " + (Rows $r.html "/order/status"))

    if ($flowOrder -ne "") {
        $r = Hit "$base/order/status" "POST" @{ id = $flowOrder; status = $T_SHIPPED } $ja
        Chk "ship order -> 302" ($r.code -eq 302) ("code=" + $r.code)
        $r = Hit "$base/order" "GET" $null $ja
        Chk "shipped order shows info status" ($r.html.Contains("badge-info")) "missing badge-info"

        $r = Hit "$base/order/status" "POST" @{ id = $flowOrder; status = $T_DONE } $ja
        Chk "complete order -> 302" ($r.code -eq 302) ("code=" + $r.code)
        $r = Hit "$base/order" "GET" $null $ja
        Chk "completed order shows ok status" ($r.html.Contains("badge-ok")) "missing badge-ok"

        $r = Hit "$base/order/status" "POST" @{ id = $flowOrder; status = $T_SHIPPED } $ja
        $r = Hit "$base/order" "GET" $null $ja
        Chk "final order cannot be changed again" ($r.html.Contains("flash-err")) "no error"

        $r = Hit "$base/order/status" "POST" @{ id = "999999"; status = $T_SHIPPED } $ja
        $r = Hit "$base/order" "GET" $null $ja
        Chk "unknown order id rejected gracefully" ($r.html.Contains("flash-err")) "no error"

        $r = Hit "$base/order/status" "POST" @{ id = $flowOrder; status = "BOGUS" } $ja
        $r = Hit "$base/order" "GET" $null $ja
        Chk "bogus status rejected" ($r.html.Contains("flash-err")) "no error"
    }

    Say "--- order snapshot survives product deletion ---"
    Hit "$base/product/delete" "POST" @{ id = $flowId } $ja | Out-Null
    $r = Hit "$base/order" "GET" $null $ja
    Chk "order still shows the deleted product's name" ($r.html.Contains($N_FLOW)) "snapshot lost"
}

Say "############ 9. status filter ############"
$r = Hit ("$base/order?status=" + [System.Uri]::EscapeDataString($T_DONE)) "GET" $null $ja
Chk "filter by 已完成 -> 200" ($r.code -eq 200) ("code=" + $r.code)
Chk "filter result only shows 已完成" ((Rows $r.html "badge-ok") -ge 1 -and (Rows $r.html "badge-warn") -eq 0) ("ok=" + (Rows $r.html "badge-ok") + " warn=" + (Rows $r.html "badge-warn"))

Say "############ 10. baseline check ############"
$r = Hit "$base/mall" "GET" $null $j4
Chk "mall still reachable for guests" ($r.code -eq 200) ("code=" + $r.code)
$r = Hit "$base/product/list" "GET" $null $ja
Chk "product list back to 8 rows on page 1" ((Rows $r.html "/product/edit\?id=") -eq 8) ("rows=" + (Rows $r.html "/product/edit\?id="))
$r = Hit ("$base/product/list?keyword=" + [System.Uri]::EscapeDataString($N_FLOW)) "GET" $null $ja
Chk "flow product fully removed" ((Rows $r.html "/product/edit\?id=") -eq 0) "still there"
$r = Hit ("$base/product/list?keyword=" + [System.Uri]::EscapeDataString($N_GONE)) "GET" $null $ja
Chk "throwaway product fully removed" ((Rows $r.html "/product/edit\?id=") -eq 0) "still there"
$finalStock = SearchStock $ja $T_KELE
Chk "KELE stock back to baseline" ($finalStock -eq $stockBefore) ("expected=$stockBefore got=$finalStock")

Say ""
Say ("################ RESULT: " + $script:pass + " passed, " + $script:fail + " failed ################")

Set-Content -Path $out -Value $L -Encoding UTF8
Write-Output ("mall verify done " + $script:pass + "/" + ($script:pass + $script:fail))
