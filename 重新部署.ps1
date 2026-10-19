<#
  商品管理系统 —— 一键重新部署（打完包之后跑这个）
  ------------------------------------------------------------------
  用法：
      cd D:\workpace\Calculator
      mvn clean package
      powershell -NoProfile -ExecutionPolicy Bypass -File "D:\workpace\Calculator\重新部署.ps1"
      然后双击桌面「启动商品管理系统.vbs」

  它做了 4 件事（顺序不能变）：
      1. 杀掉正在跑的 Tomcat（文件句柄要先释放）
      2. 清掉 webapps\shop、webapps\shop.war、work\Catalina\localhost\shop
      3. 用 jar xf **自己**把 war 解开成 webapps\shop 目录
         —— 关键：不放 war 进去。让 Tomcat 自己解压会踩两个坑：
            * war 和目录同时存在时它比时间戳，偶尔删目录重解，容易出岔子
            * 上一条命令刚 kill 完，句柄没释放，目录只删掉内容留下空壳，
              Tomcat 见目录已存在就当部署目录用，**不再解压** → 空目录部署 → 访问 404
      4. 打印校验信息（文件数 / 依赖 jar 数 / class 里是不是新代码）

  注意：**启动 Tomcat 不要传 -D 参数** —— PowerShell 会把 `-Dcatalina.home=...`
        拆坏（传到 JVM 变成主类 `.home=...` → ClassNotFoundException）。
        正解是 Set-Location 到 Tomcat 目录再跑，让它自己从 user.dir 推出 catalina.home。
#>
$tomcat = "C:\Users\22415\apache-tomcat-11.0.26"
$dest   = "$tomcat\webapps\shop"
$war    = "D:\workpace\Calculator\target\shop.war"
$o      = "D:\workpace\Calculator\重新部署结果.log"
$lines  = New-Object System.Collections.Generic.List[string]

Get-CimInstance Win32_Process -Filter "Name='java.exe'" | Where-Object { $_.CommandLine -like "*bootstrap*" } | ForEach-Object {
    $lines.Add("kill pid " + $_.ProcessId)
    Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 3

if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
if (Test-Path "$tomcat\webapps\shop.war") { Remove-Item "$tomcat\webapps\shop.war" -Force }
if (Test-Path "$tomcat\work\Catalina\localhost\shop") { Remove-Item "$tomcat\work\Catalina\localhost\shop" -Recurse -Force }
Get-ChildItem "$tomcat\logs" -Filter "localhost.*.log" | Remove-Item -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $dest -Force | Out-Null

Push-Location $dest
& "C:\Users\22415\jdk-17\bin\jar.exe" xf $war
Pop-Location

$lines.Add("files=" + (Get-ChildItem $dest -Recurse -File).Count)
$lines.Add("libjars=" + (Get-ChildItem "$dest\WEB-INF\lib" -Filter *.jar).Count)
$cls = "$dest\WEB-INF\classes\com\cn\web\LoginServlet.class"
$t = [System.IO.File]::ReadAllText($cls, [System.Text.Encoding]::GetEncoding("ISO-8859-1"))
$lines.Add("class has /products = " + $t.Contains("/products"))
$jsp = "$dest\WEB-INF\views\product-list.jsp"
$lines.Add("jsp has page.total>0 = " + ([System.IO.File]::ReadAllText($jsp)).Contains("page.total > 0"))
$lines | Set-Content $o
Get-Content $o
