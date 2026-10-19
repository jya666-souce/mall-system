# 商品管理系统 —— Servlet 版学习笔记

> 位置：`D:\workpace\Calculator`
> 部署环境：本机 Tomcat 11.0.26（`C:\Users\22415\apache-tomcat-11.0.26`）
> 访问地址：<http://localhost:8080/shop/> = **前台商城**（根路径就是这个门面，登录后也落这儿）
> 后台管理：<http://localhost:8080/shop/dashboard>（登录后商城顶栏有「后台管理」入口）
> 商品图片：存在 `D:\workpace\Calculator\shop-data\uploads\`，**在 war 外面**（原因见第十节 10.6）
> 测试账号：`admin` / `123456`（管理员）　`user` / `123456`（普通用户）

---

## 一、和控制台版的区别

| | 控制台版 `ShopMain` | Servlet 版 |
|---|---|---|
| 入口 | `public static void main` | **没有 main**，交给 Tomcat 启动 |
| 交互 | `Scanner` 读键盘 | 浏览器发 HTTP 请求 |
| 输入 | `nextLine()` | `req.getParameter("name")` |
| 输出 | `System.out.println` | 转发到 JSP 渲染 HTML |
| 打包 | jar | **war** |
| 线程 | 单线程 | **多线程**（Tomcat 每个请求开一个线程） |
| 数据存活 | 程序一关就没了 | 跟着 Tomcat 进程活着，所有用户共享 |

`DataStore` 那套增删改查和三种排序的代码**原样搬过来了**，只是把 `HashMap/HashSet` 换成了 `ConcurrentHashMap`（因为并发访问），把 `Scanner` 换成了 `getParameter`。

---

## 二、工程结构

```
D:\workpace\Calculator
├── pom.xml                       ★ packaging = war
├── 回归测试.ps1                     后台的 HTTP 回归脚本（97 项）
├── 前台回归测试.ps1                 前台的 HTTP 回归脚本（102 项）
├── 图片回归测试.ps1                 图片功能的 HTTP 回归脚本（41 项）
├── 品牌回归测试.ps1                 品牌「其他」的 HTTP 回归脚本（48 项）
├── 监听器回归测试.ps1           ★ 监听器：启动日志 + 在线人数（25 项）
├── shop-data/uploads/           ★ 商品图片实际存在这儿
│                                   故意放在 war 外面 —— 重新部署不会丢（见 10.6）
└── src/main
    ├── java/com/cn
    │   ├── StoreItem.java            商品实体（priceText、initial、【新】image）
    │   ├── Category.java / Brand.java 分类、品牌（id + name + remark）
    │   ├── User / Role / Permission / UserRole / Person
    │   ├── Cart.java             【新】购物车本体（LinkedHashMap，只存 id→数量）
    │   ├── CartLine.java         【新】购物车里的一行（【改】多了 getImage）
    │   ├── Order.java            【新】订单（状态机 + 状态→样式类）
    │   ├── OrderItem.java        【新】订单项快照（下单时的名字和价格）
    │   └── web                     ← Servlet 层
    │       ├── DataStore.java           数据仓库（单例 + 线程安全 + 权限表）
    │       │                            【新】placeOrder 下单（加锁防超卖）
    │       │                            【新】ordersOf / allOrders / updateOrderStatus
    │       │                            【改】add 重载出带 image 的版本
    │       │                            【改】update 变八参 —— 图片走「三态」更新
    │       │                            【新】checkBrandName / ensureBrand（品牌「其他」用）
    │       ├── AuthFilter.java          权限过滤器（@WebFilter("/*")）
    │       │                            【改】前台放行 + 未登录带 redirect 回登录页
    │       │                            【改】/img 进白名单（游客要看得见图）
    │       ├── Page.java                分页封装（泛型，页码越界自动夹回来）
    │       ├── Stat.java                工作台柱状图的一行（名字 + 数量 + 百分比）
    │       ├── Flash.java               一次性提示条（session → request → 用完删）
    │       ├── Params.java              参数解析工具（【新】safePath 防开放重定向）
    │       ├── Uploads.java      【新】图片的存/取/删 —— 类型嗅探、改名、防穿越
    │       ├── ImageServlet.java 【新】/img?name=xxx   把磁盘上的图发给浏览器
    │       ├── LoginServlet.java        /login（【改】默认落点改商城 + 迁购物车 + 回跳）
    │       ├── LogoutServlet.java       /logout（【改】退出后回跳）
    │       ├── DashboardServlet.java    /dashboard          工作台
    │       ├── ProductListServlet.java  /product/list       搜索+筛选+排序+分页
    │       ├── ProductFormServlet.java  /product/add、/product/edit
    │       │                            【改】加 @MultipartConfig，接收图片上传
    │       │                            【改】品牌变成 brandPick + brandCustom 两个参数
    │       ├── ProductDeleteServlet.java/product/delete     单删 + 批量删（同一段代码）
    │       │                            【改】删商品时顺手把图片文件也清掉
    │       ├── CategoryServlet.java     /category{,/add,/update,/delete}
    │       ├── BrandServlet.java        /brand{,/add,/update,/delete}
    │       ├── CartService.java   【新】购物车与商品的拼装/session 取放
    │       ├── MallServlet.java   【新】/mall、/mall/list       前台首页 + 列表
    │       ├── MallItemServlet.java【新】/mall/item            商品详情（含相关推荐）
    │       ├── CartServlet.java   【新】/mall/cart{,/add,/set,/remove,/clear}
    │       ├── OrderServlet.java  【新】/mall/order/checkout、/list、/cancel
    │       ├── AdminOrderServlet.java【新】/order、/order/status   后台订单管理
    │       ├── AppListener.java   【新】@WebListener 启动/关闭：建目录 + 打日志
    │       └── OnlineListener.java【新】@WebListener 会话增减 → 在线人数
    └── webapp                      ← 网页资源，只有这里有
        ├── index.jsp                  根路径跳板，直接转 /mall（【改】原来转 /dashboard）
        ├── css/style.css              后台样式（【改】缩略图、图片预览、手输品牌框）
        ├── css/mall.css           【新】前台商城样式（浅色 + 京东红）
        ├── js/product-edit.js     【新】商品表单里「品牌」那块的小联动
        └── WEB-INF
            ├── web.xml                【改】tracking-mode=COOKIE（见坑 12）
            │                          【改】多了 uploadDir：图片存哪个目录
            └── views
                ├── login.jsp              【改】多了 redirect 隐藏域
                ├── dashboard.jsp          工作台：统计卡 + 两组柱状图 + 库存预警表
                ├── product-list.jsp       商品列表（【改】缩略图列、品牌输出转义）
                ├── product-edit.jsp       新增/编辑共用一套表单
                │                          【改】多了图片字段；品牌多了「其他 + 手输」
                ├── category-list.jsp      分类管理（行内编辑）
                ├── brand-list.jsp         品牌管理（行内编辑；自定义进来的品牌也在这儿）
                ├── order-list.jsp     【新】后台订单管理：状态筛选 + 发货/完成/取消
                ├── 403.jsp
                ├── common                  ← 后台被静态包含的片段
                │   ├── layout-head.jsp    侧边栏 + 顶栏（【改】多了「订单管理」）
                │   ├── layout-foot.jsp
                │   └── flash.jsp          提示条
                └── mall               【新】前台一套独立片段
                    ├── layout-head.jsp    顶栏 + 搜索框 + 购物车角标
                    │                      【改】有后台权限的人多一个「后台管理」入口
                    ├── layout-foot.jsp    【改】页脚多了「当前 N 人在逛」
                    ├── flash.jsp
                    ├── card.jsp           商品卡片（【改】有图用图、没图用首字色块）
                    ├── list.jsp           商品网格 + 筛选 + 分页
                    ├── item.jsp           商品详情 + 相关推荐（【改】大图）
                    ├── cart.jsp           购物车（空/异常/正常三态，【改】缩略图）
                    ├── checkout.jsp       填收货信息 + 确认下单（【改】缩略图）
                    └── orders.jsp         我的订单（含取消按钮）
```

**关于 `common/` 下的三个片段**：后台每个页面都有侧边栏和顶栏，写 6 遍纯属复制粘贴。
把它们抽成片段，用 `<%@ include file="..." %>`（**静态包含**：编译期就把内容并进主页面）引进来，
每个页面就只管写「中间那一段内容」。代价见**坑 10**。

**关键点**：`java` 目录放 Java 代码，`webapp` 目录放网页资源，两个是平级的，都在 `src/main` 下。JSP 放在 `WEB-INF/views/` 里，**浏览器直接访问不到**，只能由 Servlet 转发过去 —— 这是故意的安全设计。

---

## 三、WAR 包的内部结构

`mvn package` 之后，`target/shop.war` 解开是这样：

```
shop.war
├── index.jsp                        ← 浏览器能直接访问的
├── css/style.css
└── WEB-INF                          ← 浏览器永远访问不到
    ├── web.xml                         Web 应用"户口本"
    ├── classes/                        你的 .class 文件
    │   └── com/cn/web/*.class
    ├── lib/                            第三方 jar
    │   ├── jakarta.servlet.jsp.jstl-api-3.0.0.jar
    │   └── jakarta.servlet.jsp.jstl-3.0.1.jar
    └── views/*.jsp                     页面模板
```

`WEB-INF` 是 Servlet 规范里"受保护目录"的意思：**外部请求物理上到不了这里**。所以 JSP 放进去，用户就不能靠猜地址直接打开没有数据的页面。

**注意 lib 里没有 `servlet-api.jar`** —— 那是 Tomcat 提供的，写进 pom 时必须标 `<scope>provided</scope>`，否则会冲突。

---

## 四、一个请求走完的路

以"管理员点删除"为例：

```
浏览器 POST /shop/product/delete  (id=3)
        ↓
【AuthFilter】拦下所有请求（@WebFilter("/*")）
   ① setCharacterEncoding("UTF-8")      ← 必须在取参数之前
   ② /product/delete 不在白名单
   ③ session 里有没有 user？没有 → 302 跳 /login
   ④ 有 → 查这个角色的权限表，需要 prod:del
        没有 → response 状态设 403，转发到 403.jsp
        有   → 放行
        ↓
【ProductDeleteServlet】doPost()
   收参数 id → 调 DataStore.delete(3) → 结果塞进 session
        ↓
   302 重定向到 /shop/products        ← 不是 forward！
        ↓
【ProductListServlet】doGet()
   查数据 → 塞进 request → forward 到 products.jsp
        ↓
【products.jsp】用 EL + JSTL 把数据铺成 HTML
        ↓
浏览器收到 HTML
```

三个容易混的点：

**1. forward 和 redirect 的区别**

| | forward | redirect |
|---|---|---|
| 谁在转发 | 服务器内部 | 服务器发 302，让浏览器**再发一次请求** |
| 地址栏 | 不变 | 改变 |
| request 里的数据 | 还在 | 没了（是新请求） |
| 按 F5 | 重复提交表单 | 只刷新页面 |

所以：**表单处理完用 redirect，展示数据用 forward**。

**2. 为什么增删改之后要 redirect 而不是直接 forward 到列表页？**

这叫 PRG（Post-Redirect-Get）。如果直接 forward，浏览器地址栏还停在 `/product/delete`，用户按 F5 会**再删一次**。redirect 之后地址栏变成 `/products`，F5 就是安全的刷新。

**3. 结果提示怎么跨过 redirect 传递？**

redirect 会丢掉 request 数据，所以提示信息先塞进 session，到了列表页再取出来**顺便删掉**（只显示一次）。这就是 `flash` 消息。

---

## 五、六个类各干什么

| 类 | 职责 | 一句话 |
|---|---|---|
| `DataStore` | 数据 + 业务 | 单例，三容器存商品，提供登录/权限/增删改查/排序 |
| `AuthFilter` | 横切关注点 | 所有请求的统一关卡：编码 → 登录 → 权限 |
| `LoginServlet` | 认证 | 校验账号密码，成功就 `session.setAttribute("user", u)` |
| `LogoutServlet` | 登出 | `session.invalidate()` |
| `ProductListServlet` | 读 | 取参数 → 查数据 → 塞 request → forward |
| `ProductSaveServlet` | 写 | 处理 add/update，完事 redirect |
| `ProductDeleteServlet` | 写 | 删完 redirect |

**Servlet 的职责边界**：Servlet 只负责"取参数、调业务、选页面"，**不拼 HTML**。拼 HTML 是 JSP 的活。

---

## 六、踩过的二十四个坑（这部分最值钱）

### 坑 1：`doDelete` 不能自己起这个名字

我一开始写了个 `private void doDelete(...)` 当内部工具方法，编译直接报错：

```
无法覆盖 HttpServlet 中的 doDelete(...)；正在尝试分配更低的访问权限
```

`HttpServlet` 里已经有 `protected void doDelete()`，那是留给 HTTP 的 DELETE 方法的（跟 `doGet`、`doPost` 同辈）。自己再定义一个同名的，等于把父类方法盖住还降了权限。

→ **改名叫 `handleDelete()`**。起名前避开规范已经占用的方法名。

### 坑 2：`servlet-api` 必须标 provided

Tomcat 的 `lib/servlet-api.jar` 里已经有 Servlet 的类。如果项目里再打一份进 `WEB-INF/lib/`，同一个类会被两个类加载器加载，行为不可预测。

→ pom 里写：

```xml
<dependency>
    <groupId>jakarta.servlet</groupId>
    <artifactId>jakarta.servlet-api</artifactId>
    <version>6.1.0</version>
    <scope>provided</scope>   <!-- 编译要用，但别打进 war -->
</dependency>
```

### 坑 3：`el-api` 的传递依赖偷偷进了 war

打包后检查 `WEB-INF/lib`，发现多了一个 `jakarta.el-api-5.0.0.jar`，而 Tomcat 11 自带的是 EL 6.0。查依赖树才知道它不是从 JSTL 实现 jar 来的，而是从 **JSTL API jar** 传进来的：

```
+- jakarta.servlet.jsp.jstl:jakarta.servlet.jsp.jstl-api:3.0.0:compile
|  \- jakarta.el:jakarta.el-api:5.0.0:compile      ← 就是它
```

**教训**：传递依赖要顺着源头排，排错地方等于没排。最终做法是直接声明一份 `provided` 顶掉它。

### 坑 4：JSTL 3.0 的 `fmt` 标签在 Tomcat 11 上属性失效 ★

写 `<fmt:formatNumber value="${it.price}" minFractionDigits="2" maxFractionDigits="2"/>`，页面上输出的是 `3.5` 而不是 `3.50`。

做了个对照实验，七种写法全试一遍：

| 写法 | 输出 |
|---|---|
| `value="12.3" minFractionDigits="2" maxFractionDigits="2"` | `12.3` ❌ |
| 加 `type="number"` | `12.3` ❌ |
| `pattern="#0.00"` | `12.3` ❌ |
| `minFractionDigits="2"` 单独用 | `12.3` ❌ |

**所有属性都被忽略**，标签本身被识别了（不然会原样输出 XML），但属性一个都没传进去。

根因：JSTL 3.0.1 是面向 EL 5.0 编译的，而 Tomcat 11 用的是 EL 6.0，属性解析对不上。`c:` 标签库（`c:forEach` / `c:if` / `c:set`）**实测完全正常**，只有 `fmt` 有问题。

→ **解决办法：格式化挪到 Java 侧**。给 `StoreItem` 加一个：

```java
public String getPriceText() {
    return String.format("%.2f", price);
}
```

JSP 里直接写 `${it.priceText}`。零依赖、零风险，还更好调试。

### 坑 5：`setCharacterEncoding` 的位置

浏览器 POST 表单上来的中文，默认按 ISO-8859-1 解码。**一旦有人调用 `getParameter()`，Tomcat 就会用当时的编码把请求体解析掉**，之后再设 UTF-8 就晚了、无效了。

→ 所以必须放在过滤器的**第一行**，抢在所有 `getParameter` 之前：

```java
public void doFilter(...) {
    req.setCharacterEncoding("UTF-8");   // ← 第一行
    resp.setCharacterEncoding("UTF-8");
    ...
}
```

实测下来"巧克力""德芙"这些中文全都没乱码。

### 坑 6：新增和修改拆成两个 URL

一开始想用一个 `/product/save`，靠隐藏字段 `action=update` 区分。但这样 Filter 为了判断权限，就必须去读请求体里的 `action` —— 而读请求体就会提前触发编码解析（见坑 5）。

→ 改成两个地址：

```java
@WebServlet({"/product/add", "/product/update"})
```

Filter 只看路径就够了：

```java
case "/product/add":    return DataStore.PERM_ADD;
case "/product/update": return DataStore.PERM_UPD;
```

干净，而且不会踩编码的坑。

### 坑 7：别把真实密码写成 placeholder ★

登录页密码框一开始是这么写的：

```html
<input type="password" name="password" placeholder="123456">
```

本意是"顺手提示一下测试密码"，结果打开页面看到框里有灰色的 `123456`，**以为密码已经填好了**，直接点登录 —— 实际提交上去的密码是空字符串，页面回一句"用户名或密码错误"。

placeholder 是**提示**，不是**值**：

| | placeholder | 真实输入 |
|---|---|---|
| 颜色 | 浅灰 | 正常深色 |
| 用户一打字 | 立刻消失 | 保留 |
| 提交表单时 | **不会发送** | 发送 |

→ 三处一起改：

**① 提示语就该是提示语**

```html
<input type="password" name="password" placeholder="请输入密码">
```

**② 后端区分"没填"和"填错"**（`LoginServlet.doPost`）

```java
String error = null;
if (username.isEmpty())      error = "请输入用户名";
else if (password.isEmpty()) error = "请输入密码";

User user = null;
if (error == null) {                        // 都填了才去查账号
    user = DataStore.get().login(username, password);
    if (user == null) error = "用户名或密码错误";
}
```

不区分的话，"漏填"和"填错"看到的是同一句提示，排查方向完全是反的。

**③ 测试账号点一下自动填入**

```html
<span class="fill" data-user="admin" data-pass="123456">admin / 123456</span>
```

```javascript
document.querySelectorAll('.fill').forEach(function (el) {
    el.addEventListener('click', function () {
        document.getElementById('username').value = el.dataset.user;
        document.getElementById('password').value = el.dataset.pass;
    });
});
```

这段 JS 跑在浏览器里，跟 Servlet 无关 —— 用 `data-*` 属性挂数据、用 `dataset` 读出来，是"HTML 存数据、JS 取数据"的标准做法。

> 这个坑的价值不在技术，而在于：**写页面的人知道那是提示，用页面的人不知道。**

### 坑 8：Tomcat 看到空的部署目录，就不解压 war 了

重新部署时按老流程走：

```bash
rm -rf webapps/shop webapps/shop.war
cp target/shop.war webapps/
# 启动 Tomcat
```

结果 `/shop/login` 返回 **404**，可日志里明明白白写着"部署已在 **318ms** 内完成"（正常要 1400ms 左右）。

打开 `webapps/shop/` 一看 —— **空的，一个文件都没有**。

原因：上一个 Tomcat 进程刚被 kill，Windows 的文件句柄还没完全释放，`rm -rf` 只删掉了目录里的内容、留下一个空目录壳。Tomcat 启动时看到 `webapps/shop` 目录**已经存在**，就直接把它当成部署目录，不再去解压 war —— 部署一个空目录，318ms 当然够。

**诊断口诀**：日志说部署成功、但访问 404 → **先看 `webapps/你的应用名/` 是不是空的**。

→ 修法：别依赖 Tomcat 的判断，自己解压，而且**只留目录、不放 war**：

```bash
# 1) 先停 Tomcat，等文件句柄释放
# 2) 清干净
rm -rf webapps/shop webapps/shop.war
# 3) 手动解开
mkdir -p webapps/shop
cd webapps/shop && jar xf D:/workpace/Calculator/target/shop.war
# 4) 再启动 Tomcat —— 它会走 deployDirectory 部署这个目录
```

顺带记一个判断依据：`webapps/` 下**同时有 `shop.war` 和 `shop/` 目录**时，Tomcat 会拿两者的时间戳比对，不一致就删目录重新解压。这个过程偶尔会出岔子，手动解压反而更可控。

### 坑 9：`${not page.empty}` —— `empty` 是 EL 的保留字，不能当属性名 ★★

做完分页后，列表页 `/product/list` 一访问就 500，日志里是：

```
org.apache.jasper.JasperException: /WEB-INF/views/product-list.jsp (行.: [171], 列: [0])
  [${not page.empty}] 包含无效表达式：
  [jakarta.el.ELException: 解析表达式 [${not page.empty}] 失败]
```

`Page` 类里明明写了：

```java
public boolean isEmpty() { return total == 0; }   // 按 JavaBean 规范就是属性 empty
```

照理 `${page.empty}` 应该能取到。但 EL 的**词法分析器**把 `empty` 认成了**运算符**
（`empty` 是一元运算符，用来判空集合，比如 `${empty page.rows}`），
而属性访问 `.` 后面要求跟一个「标识符」，解析器拿到的是运算符 token，直接报**解析失败**。

> 注意报的是「解析失败」而不是「找不到属性」—— 这一点很有用：
> 前者说明是**语法**层面的问题（关键字冲突），后者才是拼错名字。

**两个正确的写法**（`Page` 里本来就有 `getTotal()`）：

```jsp
<c:if test="${page.total > 0}">      <%-- 推荐：直白，不依赖命名规范的边角 --%>
<c:if test="${not page.isEmpty()}">  <%-- 也行：显式调方法，但 EL 方法调用对版本有要求 --%>
```

**顺带记住 EL 的保留字**，它们都不能出现在 `.` 后面：
`and or not eq ne lt gt le ge div mod empty instanceof true false null`
（比如你想写 `${user.class}`、`${item.empty}`、`${obj.new}`，都会炸。）

**排查手法**：遇到 JSP 500，别在页面上瞎猜，直接看 Tomcat 的 `logs\localhost.<日期>.log`，
异常信息会把**行号、列号、原始表达式**全打出来，一眼定位。

### 坑 10：静态包含的片段文件，必须自己声明 `pageEncoding` ★★★

抽完 `layout-head.jsp` 之后，页面出现了很诡异的现象 —— **同一行里，一半正常一半乱码**：

```html
<title>工作台 Â· ååç®¡çç³»ç»</title>
<!--     ↑正常            ↑乱码 -->
```

规律是：

| 中文来自哪里 | 结果 |
|---|---|
| `${pageTitle}` 这种 **EL 表达式**（运行时拼进去的数据） | ✅ 正常 |
| 直接**写在 `layout-head.jsp` 里的字面量**（`· 商品管理系统`） | ❌ 乱码 |
| 写在**主页面**（`dashboard.jsp`）里的字面量（`库存总价值`） | ✅ 正常 |

原因：Tomcat 编译 JSP 时，**对静态包含进来的文件是按「单独一个文件」去判定源码编码的**，
判定顺序是：

```
① 文件开头有没有 BOM（UTF-8 BOM）
② 这个文件的 page 指令里有没有 pageEncoding
③ contentType 里有没有 charset
④ 都没有 → 默认 ISO-8859-1   ← 片段文件掉到这里
```

它**不会**继承主页面第一行 `<%@ page pageEncoding="UTF-8" %>` 那一份。
片段文件里只有 ISO-8859-1 能表示的内容（ASCII）时看不出问题，
一旦写了中文，就被按 ISO-8859-1 读进来 → 乱码。

EL 出来的中文为什么没事？因为它压根不从 JSP 源码里读 ——
是 Servlet 在内存里生成的字符串，走的是**响应编码**（`response.setCharacterEncoding("UTF-8")`），
跟源码编码是两条完全独立的链路。所以症状才会那么分裂。

**修法**：给每个片段文件自己加一行（内容一致不冲突）：

```jsp
<%-- 片段文件必须自己声明 pageEncoding，否则里面的中文会被按 ISO-8859-1 读 --%>
<%@ page pageEncoding="UTF-8" %>
```

**一句话总结**：**凡是会被 `<%@ include %>` 进来的 JSP 片段，第一件事就是声明 `pageEncoding`。**

### 坑 11：改完源码 ≠ 跑起来的是新代码 ★★

这一轮最耗时间的一个坑。我把登录成功后的跳转从 `/products` 改成了 `/dashboard`，
重新 `mvn package`、重新部署、重启 Tomcat —— 结果一登录还是 **404**。

访问日志给出了铁证：

```
POST /shop/login   302
GET  /shop/products 404     ← 还在往旧地址跳
```

也就是说，**实际运行的 class 里还是旧字符串**。遇到这种情况不要瞎改代码，按顺序验三件事：

```powershell
# ① 源码里到底改没改（别相信"我明明改过了"）
Select-String -Path src\main\java\com\cn\web\LoginServlet.java -Pattern '/products|/dashboard'

# ② 打出来的 war 里是新是旧（时间戳 + 直接翻 class 里的字符串常量）
Get-Item target\shop.war | Select-Object Name,Length,LastWriteTime
$txt = [System.IO.File]::ReadAllText('<部署目录>\WEB-INF\classes\com\cn\web\LoginServlet.class',
        [System.Text.Encoding]::GetEncoding('ISO-8859-1'))
$txt.Contains('/products')     # False 才说明是新代码

# ③ 部署目录里的文件是不是刚更新的那份
Get-Item <部署目录>\WEB-INF\classes\com\cn\web\LoginServlet.class | Select-Object LastWriteTime
```

最后查明的原因是**同一次里对同一个文件做的两处修改，只有一处生效了** ——
两个编辑各自基于同一份旧内容去写，后写的把先写的盖掉了（典型的**丢失更新**）。

> 教训不止于 Java：**提交/修改之后一定要回头验证「改动真的落地了」**，
> 而且要验证到**离运行最近的那一层**（class 文件 / 部署目录），
> 不是只看源码编辑器里的那一屏。这次如果只看源码，会一直以为是 Tomcat 缓存问题。

**顺带一个排查利器**：Tomcat 的 `logs\localhost_access_log.<日期>.txt`
会逐条记录 `方法 路径 状态码`。上面那个 404 就是从这里一眼看出来的 ——
「302 之后跟的那个路径是什么」，比任何猜测都直接。

---

### 坑 12：`<c:url>` 会往链接里塞 jsessionid ★★

前台做完之后抓了一下首页 HTML，看到这么一行：

```html
<a href="/shop/login;jsessionid=FDCC15D2F2E172E1B1ECBA05277F2C09?redirect=%2Fmall">登录</a>
```

罪魁是 `<c:url>`。它内部会调 `response.encodeURL()`，
而 Tomcat 在**「客户端还没证明自己支持 Cookie」**的时候，
会走「URL 重写」这套兜底方案 —— 把 session id 拼进页面里的每一个链接。

为什么必须关掉？看着只是难看，其实有两个真问题：

1. 用户把这串链接复制发给别人，等于**把会话一起送出去了**
2. 地址栏、浏览器历史、`Referer` 请求头里都会留下 session id

关掉只要在 `web.xml` 里加一行：

```xml
<session-config>
    <session-timeout>30</session-timeout>
    <tracking-mode>COOKIE</tracking-mode>   <!-- 只用 Cookie，不往 URL 里写 -->
</session-config>
```

代价是：万一用户禁用了 Cookie，会话就维持不住。
现代浏览器默认都开着，这个代价可以接受。

> 判断方法很简单：**抓页面搜 `jsessionid`**。回归测试里也留了这么一条断言，
> 以后谁不小心把 `tracking-mode` 删了，测试会立刻报警。

---

### 坑 13：登录换了 session，游客的购物车就没了 ★★

这个不是"报错"，是**功能悄悄失效**，比报错更难发现。

`LoginServlet` 里必须保留这么一段（防会话固定攻击）：

```java
HttpSession old = req.getSession(false);
if (old != null) old.invalidate();      // ← 购物车存在旧 session 里，跟着一起没了
HttpSession session = req.getSession(true);
```

于是就撞出这么一个场景：

```
游客挑好东西 → 点结算 → 被弹去登录 → 登录成功换了新 session
→ 回到结算页，发现购物车空了
```

用户只会觉得"这网站有毛病"，而且过程里**不报任何错**。

修法是标准套路：**换 session 之前，先把要留下的数据捞出来，换完再放回去**。

```java
Cart cart = (old == null) ? null : (Cart) old.getAttribute("cart");
if (old != null) old.invalidate();
HttpSession session = req.getSession(true);
session.setAttribute("user", user);
if (cart != null) session.setAttribute("cart", cart);   // ← 放回去
```

> 这条值得记一辈子：**只要用了 `invalidate()`，就得先问自己一句
> "里面有没有我还想留的东西"**。它清的不是登录状态，是整个 session。
> 「数据存在哪」和「它的生命周期」是绑在一起的。

---

### 坑 14：multipart 的解析时机 —— 超限的异常不是从 `getPart()` 抛出来的 ★★

给商品表单加图片上传时踩的。表单的 `enctype` 换成 `multipart/form-data` 之后，
我第一版代码是这么写的：

```java
// ❌ 第一版：只把 getPart 包在 try 里
Long id   = Params.toLong(req.getParameter("id"));   // ← 真正的爆点在这儿
String name = Params.trim(req.getParameter("name"));
// ... 其他字段 ...
try {
    filePart = req.getPart("imageFile");
} catch (IllegalStateException e) {
    // 以为「图片超限」能被这里接住
}
```

**症状**：传一张 5MB 的图（上限设的 3MB），用户看到的是一个 Tomcat 的 500 错误页，
而不是我精心写的「图片太大了，请压到 3MB 以内」。

**根因**：容器解析 `multipart` 请求体是**懒加载**的 —— 第一次调用
`getParameter()` 或 `getPart()` 的那一刻才真正去切分请求体。
图片超限是**切分时**就发现的，而 `getParameter("id")` 排在 `getPart()` 前面，
所以异常从第一行就飞出去了，`getPart()` 那圈的 `try` 根本没机会执行。

**修法**：把**整段取参数**的代码包起来，而不是只包 `getPart()`：

```java
// ✅ 第二版：从第一个 getParameter 就开始防
Long id = null; String name = ""; /* ... */ Part filePart = null;
try {
    id          = Params.toLong(req.getParameter("id"));
    name        = Params.trim(req.getParameter("name"));
    // ... 其他字段 ...
    filePart    = req.getPart("imageFile");
} catch (IllegalStateException e) {
    backWithError(req, resp, editing, id, "图片太大了，请压到 3MB 以内再传");
    return;
}
```

> **记住这条：`multipart` 请求里，"第一个 `getParameter`" 才是解析入口。**
> 凡是跟请求体解析相关的异常（大小超限、格式不对），都可能从那里冒出来。
> 要防就得从头防，不能在中间拦。

---

### 坑 15：PowerShell 把 `$null` 塞进 `[string]` 参数，会变成空字符串 ★

写图片回归脚本时踩的。我写了个发请求的辅助函数：

```powershell
function Hit {
    param([string]$url, [string]$method = "GET", [string]$body = $null, $jar)
    # ...
    if ($bytes -ne $null) {
        # 发二进制（上传用）
    } elseif ($body -ne $null) {        # ❌ 这个判断永远为真
        $r.ContentType = $ctype
        $s = $r.GetRequestStream(); ...  # ← GET 请求也来发请求体
    }
}
```

然后所有 GET 都炸了：

```
使用"0"个参数调用"GetRequestStream"时发生异常:
"无法发送具有此谓词类型的请求正文。"
```

**根因**：PowerShell 在给 `[string]` 类型的参数赋 `$null` 时，**会静默转换成空串 `""`**。
于是 `$body -ne $null` 恒为真，连 GET 都会去 `GetRequestStream()`
（GET 不允许带请求体），.NET 直接抛 `ProtocolViolationException`。

**修法**：判断「有没有内容」要用 `IsNullOrEmpty`，不要跟 `$null` 比：

```powershell
} elseif (-not [string]::IsNullOrEmpty($body)) {   // ✅
```

> 顺带一个通用教训：**PowerShell 的参数类型转换会骗人。**
> `[string]$x = $null` 得到的是 `""`，`[int]$x = "abc"` 会直接抛异常，
> `[bool]$x = "false"` 得到的是 `$true`（非空字符串即真）。
> 写脚本时凡是拿 `$null` 做过判断的地方，都该停下来想一下这里被转换过没有。

---

### 坑 16：断言别写「页面里有没有出现过某个字」 ★★

写品牌回归测试时，一上来 5 条红。逐条查下来**没有一条是应用的问题** —— 全是断言写得太宽。

宽到什么程度？比如这条，想验证「这个商品没被建出来」：

```powershell
# ❌ 页面里不该出现这个商品名
CheckTrue "那个商品没被建出来" (-not $r.Text.Contains("ZZTEST-BRD9"))
```

它挂了。页面里**确实有** `ZZTEST-BRD9`，但它出现在**筛选框的回显**里：

```html
<input type="text" name="keyword" value="ZZTEST-BRD9">
```

同类的还有一条，商品名出现在 **flash 提示条**里：

```html
<div class="flash flash-ok">已修改商品【ZZTEST-BRD1】</div>
```

这两处都只是「页面里恰好出现了这几个字」，跟「这件商品在不在筛选结果里」毫无关系。

**正确姿势：认唯一的东西，别认名字。**

```powershell
# ✅ 认编辑链接上的 id —— 每件商品只有一个，也不受提示语干扰
function HasItem { param($html, $itemId) $html.Contains('/product/edit?id=' + $itemId) }

# ✅ 或者干脆数结果行数
Check "结果 0 行" (Rows $r.Text '/product/edit\?id=') 0
```

同理，「品牌有没有回填对」也不能看「页面里有没有这个品牌名」—— 筛选下拉里**永远列着全部品牌名**。得看那一行有没有 `selected`：

```powershell
CheckTrue "下拉选中了手输的那个品牌" ($r.Text.Contains('value="' + $B1 + '" selected'))
```

---

### 坑 17：改「默认值」是最容易只改一半的活 ★★

需求就一句话：**登录之后直接跳转到前台商城。**

看着是一行的事 —— 把 `LoginServlet.safeRedirect()` 的默认值从 `/dashboard` 改成 `/mall`。
改完打开登录页试，成了。**但只要你是从 `http://localhost:8080/shop/` 进来的，它还是把你送进后台。**

因为那条链路是这样的：

```text
游客敲 /shop/
  → AuthFilter 不认识 / ，当成后台路径 → 踢去 /login?redirect=%2F
  → 登录成功，redirect 有值（"/"）→ 默认值压根没被用到
  → 回 /shop/ → index.jsp → 302 /dashboard
  → 落在后台工作台
```

**默认值只在「用户没说要哪」的时候才生效。他没说，但系统替他说了。**
`index.jsp` 那句 `sendRedirect("/dashboard")` 就是那个"替他说"的人 ——
它把每一次根路径访问，都变成了一个明确的"我要去后台"。

所以这类需求要问的不是「默认值改成哪个」，而是：

> **还有没有别的地方，也在悄悄指定同一个目的地？**

全局搜一次 `/dashboard`，想要这个落点的、和不想给这个落点却给了的，都会亮出来。
这次一共两处：`LoginServlet` 的默认值、`index.jsp`。**漏掉任何一处，需求都不算完成。**

#### 第二个问题：改完落点，人可能回不去了

登录后落到商城，而商城顶栏原本**没有任何回后台的入口** ——
管理员想管理商品，只能自己去敲 URL。一个跳转改动，顺手造了一个死胡同。

所以商城顶栏补了一条，判据用权限码而不是"登录没登录"：

```jsp
<c:if test="${can['dash:view']}">
    <a class="m-admin-link" href="${ctx}/dashboard">后台管理</a>
</c:if>
```

（`can` 是 `AuthFilter` 注入的权限查表 Map。前台路径也走完了整段注入，所以这里取得到。）

**「把人送到 A，就得保证他从 A 能走到 B」** —— 改跳转的时候，顺手想一下这句话。

#### 第三件事：老断言会红，而且它们红得有道理

5 条断言写死了旧落点（后台 3 条，前台那组开放重定向 2 条）。
要能分清这两种红：

| 红的种类 | 判断 | 怎么处理 |
|---|---|---|
| **需求变了** | 断言挂掉的原因，正是你这次要改的行为 | 改断言，改完在备注里写清是需求变更 |
| **真回归** | 断言挂掉的原因，跟这次需求**无关** | 别碰断言，回去找代码的问题 |

分不清就会干出两件蠢事：把真 bug 当需求变更、改断言蒙过去；
或者把需求变更当 bug，绕着它写一堆兼容代码。

> 教训：**UI 测试的断言，要挑「唯一的锚点」，别挑「碰巧出现的字」。**
> 页面上一句无关的提示、一个回显框，就足以让测试永远红、或者永远绿。
>
> 后半句更可怕：**宽断言会给假阳性。** 早期有条「按品牌筛选能筛出商品」的断言，
> 即使筛选功能完全没生效（查询被忽略、返回了全部商品），它照样会通过 ——
> 因为商品名当然在页面里。后来加了一条「筛出 2 件」数行数的断言，才真正锁住行为。
>
> 一句话：**断言要能因为「功能坏了」而变红，否则它就不是断言，是装饰。**

### 坑 18：Tomcat 日志「消失」了 —— 少了 `-Djava.util.logging.config.file` ★★★

这轮加了个启动日志（`ServletContext.log(...)`），兴冲冲去 `logs` 目录里找，**一个字都没有**。
更诡异的是：**日志文件的时间戳停在好几个小时前**，像是根本没启动过 ——
可页面明明能访问，功能也全对。

排查路线是这样的：

1. 先确认跑的是不是新进程 —— `Get-NetTCPConnection -LocalPort 8080` 拿到 pid，
   再看 `Get-Process java` 的启动时间。是新的，没错。
2. 那问题就只剩一个可能：**日志写到别的地方去了。**
3. 打开桌面启动器 `.vbs` 一看，真相大白 —— 它启动 Tomcat 时带了全套参数：

```text
-Djava.util.logging.config.file=<tomcat>\conf\logging.properties
-Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager
-Dcatalina.home=...   -Dcatalina.base=...   -Dfile.encoding=UTF-8
```

而我图省事，一直用的是：

```powershell
java -cp "bin\bootstrap.jar;bin\tomcat-juli.jar" org.apache.catalina.startup.Bootstrap start
```

**少了 `-Djava.util.logging.config.file`，Tomcat 就找不到 `conf\logging.properties`。**
找不到会怎样？它**不报错**，直接退回 JDK 的默认日志配置 ——
而默认配置里**没有文件 handler**，只有控制台。
于是日志全喷到控制台，一个字节都不落盘。

> 教训：**「没报错」和「干对了」是两件事。**
> 日志没写出来，不一定是没执行 —— 很可能是写去了你没想到的地方。
> 排查顺序永远是：先证明代码跑了（进程/端口/页面），再去找它的输出。

顺带纠正一条我之前记**反了**的经验：不是「启动 Tomcat 不能传 `-D` 参数」，
而是「PowerShell 里 `-Dxxx` 直接写在命令行上容易被拆成多个参数」。
正确姿势是把参数放进数组再展开，一个元素就是一个独立参数，绝不会被拆：

```powershell
$jvm = @(
  "-Dcatalina.home=$tomcat",
  "-Dcatalina.base=$tomcat",
  "-Djava.util.logging.config.file=$tomcat\conf\logging.properties",
  "-cp", "$tomcat\bin\bootstrap.jar;$tomcat\bin\tomcat-juli.jar",
  "org.apache.catalina.startup.Bootstrap", "start"
)
& "$javaHome\bin\java.exe" @jvm      # @jvm 展开数组，逐个当独立参数传过去
```

#### 顺便记住 `ServletContext.log()` 写到哪

| 谁写的 | 落到哪个文件 |
|---|---|
| 你的 `sc.log("...")` | `logs\localhost.<日期>.log` |
| Tomcat 自己的启停信息 | `logs\catalina.<日期>.log` |
| 每个 HTTP 请求一行 | `logs\localhost_access_log.<日期>.txt` |

排查问题时**先看 `localhost_access_log`** —— 它有逐条的「方法 路径 状态码」，
「那个 302 之后到底跳到哪了」这种问题，一条记录就说明白，比猜快得多。

---

### 坑 19：PowerShell 的变量名**不区分大小写** ★★

监听器回归脚本第一版，A 组 6 条全绿，B 组刚跑到第 3 条就整个崩了：

```text
无效的 URI: 未能确定 URI 的格式。
```

可代码看着完全正常，请求的就是 `"$BASE/mall"`。它实际发出去的是 `1/mall`。

原因：脚本顶上定义了

```powershell
$BASE = "http://localhost:8080/shop"
```

B 组里我想记一个「基线人数」，顺手写了

```powershell
$baseline = Online $r.Text      # 第一版这里写的是 $base
```

**PowerShell 变量名大小写不敏感**，`$base` 和 `$BASE` 是**同一个变量**。
这一行把 URL 字符串整个覆盖成了整数 `1`，后面所有请求全废。

> 教训：**给「全局常量」和「临时变量」用不同风格的命名，不要只靠大小写区分。**
> 现在的习惯：常量全大写、而且名字要「不像局部变量」（`$BASE`、`$LOGDIR`），
> 临时值带语义（`$baseline`、`$probe`、`$logText`）。
>
> 这个坑在 PowerShell 里特别阴，因为**换个语言就完全没事** ——
> Java、JavaScript、C 里 `base` 和 `BASE` 是两回事。
> **语言之间的默认规则不一样，别把自己的习惯直接搬过去。**

---

### 坑 20：`overflow: hidden` 会把溢出的内容**静默裁掉** ★★

手机视口下打开购物车（见第十三节），商品行看着正常，
但**「操作」那一列连同删除按钮整列不见了** —— 页面不报错、没有滚动条，
就像那列本来就没写。

量一下就很清楚：

| 元素 | 数值 |
|---|---|
| `table.m-tbl` 的 `scrollWidth` | 418px（它的最小宽度） |
| 外层 `div.m-panel` 的 `clientWidth` | 354px |
| `div.m-panel` 的 `overflow-x` | **hidden** |

`<table>` 的宽度压不下去：表头文字不换行、数量输入框固定 58px、金额不能断行，
418px 是它的底线。而 `.m-panel` 当初为了让 `border-radius` 能裁掉内部表格的直角背景，
写了 `overflow: hidden` —— 于是超出的 64px 被直接裁掉。

**真正阴的地方在于**：当初若写的是 `overflow-x: auto`，用户至少能拖着看；
写了 `hidden`，内容就是凭空消失。页面上看不出任何异常，
你只会觉得"这功能好像没做"。

> 排查手法：**量 `scrollWidth` 和 `clientWidth`。**
> 两者不相等，说明这个盒子里的内容被压住了或被裁了；
> 再看 `overflow-x` 是 `hidden`、`auto` 还是 `visible`，就能区分"静默丢失"和"可以滚动"。
> 这条检查比肉眼找快得多，而且能批量做 —— 第十三节的体检脚本就是这么遍历所有元素的。

> 教训：**圆角裁剪和内容溢出是两件事，别用一个 `overflow` 顺手一起管。**
> 圆角可以靠每层元素自己的圆角解决，或者交给一个专门的包装层，
> 不要让"内容容器"兼任"裁剪器"。

---

### 坑 21：加了覆盖样式却没生效 —— 多半是**选择器特异性不够** ★★★

做移动端适配时（第十三节），给购物车表格写了一段"卡片化"的样式，
其中有一句想放开"操作"列的宽度。改完一量，**删除按钮还是跑到屏幕外**：

```
td.col-act   内容 56px / 盒子 1px      ← 格子被压成 1px
其内的 button 宽 56px，右边界 418px
外层 .m-panel overflow-x: hidden        ← 再把它裁掉
```

我明明写了 `.m-tbl-cart td { width: auto; }`，为什么没用？**因为特异性比不过桌面版那条**：

| 规则 | 选择器 | 特异性 |
|---|---|---|
| 桌面版（在文件更前面） | `.m-tbl .col-act` | **(0, 2, 0)** —— 两个类 |
| 我写的（**输了**） | `.m-tbl-cart td` | (0, 1, 1) —— 一个类 + 一个元素 |
| 改成这样（**赢了**） | `.m-tbl-cart td.col-act` | (0, 2, 1) —— 两个类 + 一个元素 |

**关键认知：CSS 里「写在后面」只在特异性相同时才管用。** 特异性低的那条，写多后面都会被忽略。

而且这条规则**为什么被违反**也很值得记：`.col-act { width: 1% }` 本来是桌面版用来把"操作"列压窄的。
`td` 变成网格单元后，网格轨道在算自身宽度时解析不了子项的 `width: 1%`，就按 0 处理 ——
**格子塌成 1px，里面的按钮溢出去**。等于绕了一圈，问题又回到"操作列看不见"。

> 排查手法：**不要靠"看"，要靠"量"。** 在控制台里打
> `document.querySelector('td.col-act').getBoundingClientRect()`，
> 看到 `width: 1` 就一眼明白了 —— 页面本身不报错、控制台不警告，
> 光看截图只会以为"样式没生效"，然后开始瞎试。
> 量完之后再去 DevTools 的「样式」面板里看是哪条规则赢了（被划掉的那条就是输家）。

> 教训：**写覆盖样式时，先看一眼对方的选择器有几个类。**
> 如果自己是"一个类 + 一个元素"（(0,1,1)），而对方是"两个类"（(0,2,0)），
> 那就必须把自己也写具体到两个类 —— 而不是去加 `!important` 硬压。
> `!important` 能解决眼前这一条，但它会让**下一次**改样式变得更难猜。

> 这类失败和坑 20 是同一个毛病家族：**CSS 不会因为你写错了就报错，它只会当没看见。**
> 所以前端改动一定要有"量"的手段 —— 见第十三节的体检脚本。

---

### 坑 22：Apifox 挂的两条红，其实是它**用自己的默认文档定义**比你 ★★

用 Apifox 调登录接口，界面上冒出两条红：

```
① 接口实际返回的"状态码"：302   接口定义的"状态码"：200
② 返回的数据格式不是 JSON
```

第一反应通常是"我接口写错了"。**不是。** 去命令行敲一遍：

```bash
curl -i -X POST http://localhost:8080/shop/login \
  -d "username=admin&password=123456&redirect=/mall"

# HTTP/1.1 302
# Set-Cookie: JSESSIONID=...; Path=/shop; HttpOnly
# Location: /shop/mall
# Content-Length: 0
```

302 跳转、Set-Cookie 带回新会话、Location 指向 /mall —— **登录成功该有的全有，一个不多一个不少。**

#### 那两条红是哪来的

Apifox 有个功能叫「**校验响应**」（它自己叫契约测试），**默认是开的**。
它干的事是：拿**接口文档里定义的「返回响应」**，去比这次实际拿到的响应。

问题出在**定义是哪来的**：

| 环节 | 发生了什么 |
|---|---|
| 我用脚本生成集合（Postman v2.1） | 只写了 `request`，**没写 `response`** |
| 导入 Apifox | 它"好心"给每个接口补了个默认定义：**200 + body 按 JSON 算** |
| 实际跑 | 返回 302 + HTML，跟那份默认定义**完全对不上** |

所以这两条红的真实含义是 ——
**"你的接口文档说它返回 200 的 JSON，可它实际返回了 302 和 HTML。"**
文档过时了，代码没错。

#### 修法（两条，按省事程度排）

**① 关掉「校验响应」** —— 本项目最省事，一次点击永久生效：

```
项目设置 → 校验响应设置 → 关闭
```

关掉后**手写的断言脚本照常跑**（这点很关键，别以为关了就没测试了）。
也可以在设置里只关「Body」那一项、留「状态码」，这样既有契约检查又不误报。

**② 把真实的返回响应写进集合** —— 让文档和实际一致：

我在生成器里加了 `buildResponses()`，从断言脚本里自动抠出期望状态码
（`pm.response.to.have.status(302)` → 302），按接口逐个生成返回响应定义。
重新生成后 52 个接口一共 102 条定义：

| 状态码 | 定义数 | 含义 |
|---|---|---|
| 302 Found | 50 | 跳转：登录成功 / 新增成功 / 未登录被拦… |
| 200 OK | 47 | 正常渲染页面 / 留在原页面显示错误 |
| 403 Forbidden | 3 | 权限不足 |
| 404 Not Found | 2 | 图片不存在 / 名字非法 |

导入这份新集合后，那两条红会自己消失 —— 因为文档终于说对了。

#### 进阶：一个接口本来就有好几种结果，怎么办

后台那批接口，**用不同参数跑同一个地址，结果是不一样的**：

| 场景 | 结果 |
|---|---|
| 带着身份访问商品列表 | 200，渲染出列表页 |
| 不带身份访问商品列表 | 302，被拦截去登录页 |
| `POST /login` 账号密码对 | 302，跳 `/mall` |
| `POST /login` 空表单 | 200，留在登录页显示「请输入用户名」 |

一开始我以为这是死结：**接口定义只能写一种状态码**，那另一种必然报红。
后来去翻官方文档，发现 Apifox 早就想到了 ——

> **校验 HTTP 状态码**：文档定义多个可能值（如 200、201），**按允许范围校验**。

**所以地址相同的多种结果，是"成对定义"进返回响应的**，不是一个接口一个定义。
生成器里对应 `fallbackOf()`：

```js
function fallbackOf(code) {
    if (code === 200) return 302; // 页面类：没带身份会被拦去登录页
    if (code === 302) return 200; // 跳转类：参数没过校验时，留在原页面继续报错
    if (code === 403) return 302; // 越权类：没登录时走不到权限判断，先被 302 拦走
    return 0;                     // 404（图片不存在 / 路径穿越被拒）结果是稳定的，不用兜底
}
```

于是每个接口变成「主路径 + 兜底」两条定义，点开 Apifox 里接口的「返回响应」就能看到：

```
登录 · 管理员      →  302 Found · 重定向        +  200 OK · 留在原页面显示错误
登录 · 用户名为空   →  200 OK · HTML 页面       +  302 Found · 登录成功跳转
```

> **通用教训**：报红先问一句"**这个地址是不是本来就有多种结果**"。
> 是，就把几种都写进文档（允许范围）；不是，才是接口或定义真有问题。
> 另：校验响应比的是**接口文档定义**，**改用例里的断言消除不了这条红** ——
> 真想让红彻底不出现，100% 管用的只有关掉它。

> **通用教训**：契约测试报红，**先分清是"接口错了"还是"文档错了"**。
> 分不清的时候，脱离工具、用 `curl -i` 直接看原始响应 ——
> 工具会带着它自己的假设，命令行不会。
> 这个项目和坑 18（Tomcat 静默不写日志）是一类的：
> **报错的地方，不一定是出错的地方。**

---

### 坑 23：`expected '' to include '/mall'` —— 同一句报错，两种完全不同的原因 ★★

在 Apifox 里跑 `POST /login`，红条长这样：

```
2. ❌ 跳向前台商城 /mall | AssertionError: expected '' to include '/mall'
```

字面意思是：**Location 响应头是空的**（我们断言它应当包含 `/mall`，拿到的是 `''`）。

但"Location 为空"有两种完全不同的原因，**只有一种该去动 Apifox 设置**：

| 响应体里是 | 真正原因 | 该动什么 |
|---|---|---|
| `class="login-body"`（**登录页**） | 请求**没带参数**（或账号密码不对）→ 服务端按"登录失败"返回 200，**压根没发生跳转** | 改请求的 Body 参数 |
| 商城页 / 列表页 | 「自动跟随重定向」开着，302 被工具走完、Location 被吞掉 | 改 Apifox 设置 |

本机实测对照（这就是判据的来源）：

| 请求 | 状态码 | Location | 响应体 |
|---|---|---|---|
| 空参数 | 200 | `""` | 含 `login-body`、含「请输入用户名」 |
| `admin/123456/redirect=/mall` | 302 | `/shop/mall` | 都不含 |

#### 我是怎么误诊的

原来的诊断逻辑是这么写的：

```js
if (pm.response.code === 200) {
    throw new Error('期望 302 却拿到 200 —— 「自动跟随重定向」把跳转跟掉了。');
}
```

**这个推断在"重定向被跟随"时是对的，在"压根没跳转"时是错的。**
我照着它去让用户关设置，关了两遍都没用 —— 因为他其实只是 Body 参数没填。

#### 修法：让断言自己去看响应体

生成器里抽出一段 `DIAG`，注入到 **状态码 / Location / 会话提取** 三处断言里：

```js
const __body = pm.response.text();
const __loc = pm.response.headers.get('Location') || '';
const __isLogin = __body.indexOf('login-body') >= 0;                      // 登录页特征
const __em = (__body.match(/class="login-error">([^<]*)/) || [])[1] || ''; // 页面上的错误提示
// 是登录页 → 报"没登录成功"；不是 → 才提"自动跟随重定向"
```

改完之后，同一句红变成这样：

```
期望 302，实际拿到 200。这次请求没登录成功（返回的是登录页）。
页面上写着：「请输入用户名」。
常见原因：① 请求 Body 的参数被清空了，填回接口定义里的值即可；
② 账号或密码不对 —— 那属于「登录 · 密码错误」「登录 · 用户名为空」两条接口的场景。
```

**把 `<div class="login-error">` 里的原文抠出来贴进报错**，这一招特别值：
看到「请输入用户名」四个字，两秒就知道是参数问题，不用再问人。

#### 顺带一个概念：一条接口 = 一个场景

「登录 · 管理员」的断言写死期望 302，**它就是拿来测"登录成功"的**。
把它的参数清空去测"用户名为空"是**用错了接口** —— 那种场景有专门的
「登录 · 用户名为空」（期望 200 + 页面出现「请输入用户名」）。

在 Apifox「运行」页签里手改了参数，地址栏旁边会出现「**不一致**」标记 ——
看到它就知道：跑的不是接口定义里那份请求。

> **通用教训**：
> ① **一条报错信息 ≠ 一个原因。** 同一个现象（Location 为空）背后可能是完全不同的两件事，
>    要靠**别的证据**（这里就是响应体）去分辨，不能选"最可能的那种"就下手。
>    这跟坑 20（`overflow:hidden` 静默裁内容）、坑 18（日志静默不写）是一个家族：
>    **症状相同，病因各异。**
> ② **好的报错要能自己指路。** 断言不只判"对不对"，还要说"错在哪、去改什么"。
> ③ 诊断逻辑写完**必须用假 `pm` 对象真跑一遍**（`test-diagnosis.mjs`）——
>    回放脚本走 Node `fetch`、**不执行 `pm.test`**，拼出来的 JS 有语法错它也发现不了。
>    这次就靠它抓到我把换行写进了字符串字面量里（生成的 JS 直接 SyntaxError）。

---

### 坑 24：工具**替你带了身份** —— 「未登录」用例总是拿到 200 ★★

#### 症状

用 Apifox 跑「未登录 · 访问后台被拦截」，期望 `302`（被 AuthFilter 踢走），实际拿到 `200`。
可命令行 `curl` 打**同一个地址**、不带 Cookie，明明就是 302。**看着像接口坏了。**

#### 根因：Apifox 的「自动 Cookie 管理」

Apifox 有一个 **Cookie 管理**，左下角带个「**启用全局 Cookie**」开关。
它会把记着的 Cookie **自动拼进每一个请求**。只要之前跑过一次登录，
jar 里就躺着一条有效的 `JSESSIONID`：

```
Cookie 管理 → localhost → JSESSIONID=243D47A978A2C81D88CBE81A1305E6AC
            domain=localhost  path=/shop  http-only  host-only
            生成时间 2026-09-29 11:31:05      ← 正是上次跑登录的时刻
```

于是「未登录」请求身上**挂了两个 JSESSIONID** —— 我们故意塞的无效值，
加上 jar 里自动带上的有效值。Tomcat 取到有效那个 → 认为你已登录 → 返回 200。
**请求本身没错，是工具替你带了身份证。**

这和坑 22（校验响应假红）是一类：**工具的行为 ≠ 接口的行为**。
判据永远是那句 —— **脱开工具用命令行打一次原始响应**：

```bash
curl -i http://localhost:8080/shop/dashboard
# 认真看：没有 Cookie 时到底是不是 302
```

#### 修法：让用例自己清场，别指望用户记得关开关

**错误做法**：在文档里写一句"跑之前请先清 Cookie"。
用户换个环境、重开 Apifox，照样中招 —— **把正确性寄托在人的记忆上，迟早翻车**。

生成器给所有 `rawCookie: NO_SESSION` 的用例**自动挂**一段前置脚本：

```js
// 未登录用例：先把 Apifox 自动管理的 Cookie 清掉，避免带着旧会话进来
if (pm.cookies && typeof pm.cookies.clear === 'function') {
    try { pm.cookies.clear(); } catch (e) { /* 某些版本没有这个 API，忽略 */ }
}
// 把请求头里已经拼好的 Cookie 删掉（Apifox 可能在 prerequest 之前就注入了）
pm.request.headers.remove('Cookie');
```

三步走：**清 jar → 删请求头里的 Cookie → 再塞明确的无效值**。
这样全局 Cookie 开着关着结果都一样。挂载是在 `mk()` 里做的，
**按标记自动判断**，以后新增"未登录"用例只要写 `rawCookie: NO_SESSION` 就自动生效：

```js
let preScript = o.pre;
if (o.rawCookie === NO_SESSION) {
    preScript = (preScript || []).concat([""], preClearCookie);
}
```

覆盖 7 条：2 条"未登录被拦" + 3 条商城游客接口 + 2 条图片接口。

> **通用教训**：
> ① **能自动化的前提，别写成操作说明。** 需要靠"用户记得做某件事"才正确的方案，不算修好。
> ② **工具自带的便利功能常常是测试的敌人。** 自动 Cookie、自动跟随重定向、自动补文档定义
>    （坑 22）—— 都是"为了让日常调接口省事"设计的，一到**验证边界场景**就帮倒忙。
>    所以做接口测试时，凡是"工具替你做的主"，都要能一键关掉或绕开。

---

## 七、怎么跑起来

### 方式 A：双击桌面图标（最省事，全程无黑窗口）

桌面上放了两个脚本：

| 文件 | 作用 |
|---|---|
| `启动商品管理系统.vbs` | 双击 → 后台静默启动 Tomcat → 自动打开浏览器 |
| `停止商品管理系统.vbs` | 双击 → 找到 Tomcat 进程并结束 |

关键在于 `WScript.Shell.Run` 的**第二个参数**：

```vbs
shell.Run cmd, 0, False
'             ↑  ↑
'             │  └─ False：不等待，立刻返回
'             └──── 0：窗口模式 = 隐藏
```

`0` 就是"把窗口藏起来"。`startup.bat` 本质上是开一个黑窗口去跑 `org.apache.catalina.startup.Bootstrap start`，这里直接把那条命令交给 shell 并指定窗口隐藏，黑窗口就不出现了。

脚本还会**轮询 `/shop/login` 直到返回 200 才打开浏览器**，所以不会出现"双击完浏览器就弹出来、结果页面 404"的尴尬：

```vbs
For i = 1 To 80
    WScript.Sleep 500              ' 最多等 40 秒
    If AppReady() Then Exit For
Next
shell.Run APP_URL, 1, False        ' 确认活着了，再开浏览器
```

> 小坑：VBS 里写引号要用 `""` 转义，很容易数错。改用 `Q = Chr(34)` 代替，拼接命令行时可读性高得多。

### 方式 B：命令行打包 + 手工部署（已经跑通）

```bash
cd D:\workpace\Calculator
mvn clean package                    # 生成 target/shop.war
copy target\shop.war C:\Users\22415\apache-tomcat-11.0.26\webapps\
cd C:\Users\22415\apache-tomcat-11.0.26\bin
startup.bat                          # 启动
# 浏览器打开 http://localhost:8080/shop/
shutdown.bat                         # 停止
```

Tomcat 会自动把 war 解压成 `webapps/shop/` 目录并部署。

#### `startup.bat` 到底做了什么？—— 值得知道，因为这里踩过坑

它核心就干一件事：**带着一整套 `-D` 参数**去调 `java`。这些参数一个都不能少，
其中最容易漏、**而且漏了不报错**的是这一条：

```text
-Djava.util.logging.config.file=<tomcat>\conf\logging.properties
```

少了它，Tomcat 就找不到 `conf\logging.properties`，于是退回 JDK 的默认日志配置 ——
默认配置**没有文件 handler**，结果就是：**应用照常跑，日志一个字都不落盘。**
不报错、不警告，你只会以为「我的日志语句没执行」。

完整经过写在**坑 18**里（那轮我为了图省事直接拼 `java` 命令，就这么中了招）。

> 所以结论很简单：**日常就用 `startup.bat` 或桌面图标，别自己拼 `java` 命令。**
> 真要自己拼，参数照桌面的 `启动商品管理系统.vbs` 里那份抄 ——
> 那份是完整的，连 `-Dfile.encoding=UTF-8` 都带了。

### 方式 C：在 IDEA 里配 Tomcat（推荐日常开发用）

1. `File` → `Project Structure` → `Artifacts` → `+` → `Web Application: Archive` → `From module 'Calculator'`
2. `Run` → `Edit Configurations` → `+` → `Tomcat Server` → `Local`
3. `Application server` 指到 `C:\Users\22415\apache-tomcat-11.0.26`
4. `Deployment` 标签 → `+` → `Artifact` → 选刚建的那个
5. `Application context` 填 `/shop`
6. 点绿色三角形运行，浏览器自动打开

以后改代码点一下"Redeploy"就生效，比手工打包快得多。

**注意**：IDEA 里 Tomcat 默认端口就是 8080。如果命令行那个 Tomcat 还开着，会端口冲突，记得先 `shutdown.bat`。

---

## 八、后台化改造：这一版多了什么

参照一个真实电商后台的样子，把原来的「一个商品列表页」扩成了「一个后台」。

### 1. 页面骨架：侧边栏 + 顶栏

每个页面都长一个样（左边菜单、上面面包屑 + 用户信息），
所以抽成 `common/layout-head.jsp` + `common/layout-foot.jsp`，页面只写中间那段。

主页面只需要提前准备两个变量：

```jsp
<c:set var="pageTitle" value="商品列表"/>   <%-- 显示在标题栏和面包屑 --%>
<c:set var="active" value="product"/>      <%-- 菜单高亮哪一项 --%>
```

菜单项的高亮就是拿 `active` 比出来的，不用每个页面写一遍 `class="active"`：

```jsp
<a class="nav-item${active eq 'product' ? ' active' : ''}" href="${ctx}/product/list">商品列表</a>
```

### 2. `<c:url>` 拼分页链接：筛选条件不能丢

翻到第 2 页时，如果链接里只有 `?page=2`，之前填的关键字、分类、价格区间**全丢了**。
所以每一页链接都要把当前筛选条件原样带上：

```jsp
<c:url var="prevUrl" value="/product/list">
    <c:param name="keyword"  value="${keyword}"/>
    <c:param name="category" value="${category}"/>
    <c:param name="sort"     value="${sort}"/>
    <c:param name="page"     value="${page.prevPage}"/>
</c:url>
<a href="${prevUrl}">上一页</a>
```

> ``<c:param>` 会自动做 URL 编码，中文关键字直接扔进去就行，不用自己 `URLEncoder`。

**为什么 Servlet 要把筛选条件再塞回 request？** 因为 GET 参数不会自动记住。
页面上的 `<input value="${keyword}">` 得靠这个回填，否则用户一翻页就发现搜索框空了，
以为搜索被重置 —— 这是体验问题，不是功能问题，但很容易忘。

### 3. 分页封装成 `Page<T>`

页面上要显示「共 37 件 / 第 2 页 / 显示第 9-16 条 / 上一页 下一页 1 2 3」——
这些要是写在 JSP 里，每个列表页都得重写一遍。封成一个对象，页面只管取值：

```java
Page.of(all, pageNo, size)   // 页码越界会自动夹回合法范围
```

**越界夹回**这个细节很重要：用户手输 `?page=999` 或 `?page=-3`，
不能给他一个空白页或者 500，而是落在最后一页 / 第一页。
`Math.min(Math.max(1, pageNo), totalPages)` 一行搞定。

### 4. PRG + Flash：刷新不会重复提交

表单提交成功后 **重定向**（Post-Redirect-Get），而不是直接转发页面。
好处是用户按 F5 刷新，浏览器重发的是 GET，不会把「新增」又执行一遍。

但重定向后，`request` 里的提示消息就没了。所以用 **session 当中转站**：

```java
Flash.ok(req, "已新增商品【xx】");   // 存进 session
resp.sendRedirect(ctx + "/product/list");
```

```java
Flash.take(req);   // 取出来放进 request，同时从 session 删掉
```

**「用完就删」是关键** —— 否则提示条会一直粘在页面上，
用户点几次都在，看起来像出了 bug。

### 5. 权限分两层：菜单级 + 按钮级

`Permission` 表里用 `type` 区分：

| type | 含义 | 谁在用 |
|---|---|---|
| 0 | 菜单 | 侧边栏据此决定这一项显不显示 |
| 1 | 按钮 | 列表页据此决定「新增/编辑/删除」显不显示 |

`pId` 指向所属的菜单，形成「菜单 → 按钮」两级。

真正拦权限的还是 `AuthFilter` 里那张**路径 → 权限 code 的总表**，
页面上藏按钮只是**不给他看见**，不是安全措施：

```java
case "/product/add": return DataStore.PERM_ADD;   // 想加功能就改这一行
```

> 页面上藏掉的按钮，用户手敲 URL 照样能请求 —— 所以服务端必须再拦一道。
> 这就是「前端隐藏」和「后端校验」的区别，两个都要有。

**EL 里怎么判断权限？** 不用 `Set.contains()`，而是额外转一个 `Map<code, Boolean>`：

```java
Map<String, Boolean> can = new HashMap<>();
for (String code : codes) can.put(code, Boolean.TRUE);
```

```jsp
<c:if test="${can['prod:add']}"> … </c:if>
```

不存在时取出来是 `null`，`c:if` 当 `false` 处理，比方法调用稳当得多。

### 6. 表格里怎么放表单：`form="id"` 属性

HTML 里 `<form>` **不能嵌套**，但表格里每行又都要有「保存」「删除」两个不同的提交目标。
办法是表单放在表格外，输入框用 `form` 属性「认领」到某个表单上：

```html
<td>
    <form id="cf-3" method="post" action="/shop/category/update">
        <input type="hidden" name="id" value="3">
    </form>
    <input form="cf-3" name="name" value="食品">      <!-- 归 cf-3 管 -->
    <button form="cf-3">保存</button>
</td>
```

这就是「行内编辑」的实现方式：输入框平时看着像纯文本，改完点保存直接提交，不用为编辑单独做页面。

### 7. 分类/品牌：删除有引用保护，改名要级联

商品里存的是分类**名字**（字符串），不是分类 id。所以：

- **删除**前先数一下有没有商品在用，有就拒绝，并在列表里显示「被占用」徽标 ——
  用户一眼能看出「为什么这个删不掉」，比弹个错误框友好
- **改名**时要同步把所有引用它的商品一起改掉（`renameCategoryInItems`），
  否则那些商品的分类就变成「查无此人」

> 这是「存名字」这个设计的代价。更规范的做法是商品存 `category_id`，
> 改名字就只改一张表 —— 那是一次外键改造，等真要接数据库时一起做更划算。

### 8. 批量删除：一个接口干两件事

列表每行一个复选框 `name="id"`，勾选后提交到同一个 `/product/delete`：

```java
String[] raw = req.getParameterValues("id");   // 单个 id 也返回长度 1 的数组
```

单个删除和批量删除**共用同一段代码**，只是分支不同 ——
不用为「批量」再写一个接口。

---

## 九、前台商城：再加一条面向顾客的链路

到这一版，同一个应用里住着两种人：后台的管理员，和前台来买东西的顾客。
把两条链路摊开对比，能看清不少东西。

### 1. 一个应用，两套「进门规矩」

| | 后台（`/dashboard`、`/product/**`、`/order`） | 前台（`/mall/**`） |
|---|---|---|
| 不登录能进吗 | 不能，直接弹去登录页 | 能，游客随便逛、随便加购物车 |
| 判断依据 | **权限码**（`can['prod:add']`） | **登录状态**（session 里有没有 user） |
| 判断写在哪 | `AuthFilter.requiredCode()` 一处集中 | Servlet 自己拦，只有下单/我的订单需要 |

为什么不把前台也塞进 `AuthFilter` 的权限表？
因为**它俩问的根本不是同一个问题**：

- 后台问的是「**你能干什么**」—— 同样是登录用户，管理员能删商品，普通用户不能
- 前台问的是「**你是谁**」—— 顾客不需要持有"下单"这个权限码，登录了就该能下单

两套判断混进同一个 `switch`，往后只会越来越难读。
所以这个项目定了一条规矩：**权限码管后台，登录状态管前台。**

`AuthFilter` 里对应的就是一行例外：

```java
// 放开的大门：前台商城 + 应用根路径（/ 只是 302 到 /mall 的跳板）
boolean openDoor = isMall(path) || path.equals("/");
if (user == null && !openDoor) {      // 前台不踢人
    resp.sendRedirect(ctx + "/login?redirect=" + URLEncoder.encode(back, UTF_8));
    return;
}
```

为什么根路径 `/` 也要放行？因为它只是个跳板，终点是商城。
拦下来的话，游客敲 `http://localhost:8080/shop/` 会先撞见登录页 ——
跟「前台不登录也能逛」自相矛盾，而且他连去商城的路都没有。

注意前台**不能**走 `WHITE_LIST` 那条捷径。两者含义不同：

- 白名单 = 连"你是谁"都不用知道（登录页、静态资源），放行就完事
- 前台商城 = 不登录也能逛，**但你要是登录了，页面得知道你是谁**（顶栏要显示用户名）

所以前台得继续往下走完属性注入那一段。

### 2. 购物车：为什么放 session，不放 DataStore

`DataStore` 是**全站共享**的（所有人看到同一批商品）；
购物车是**这个浏览器的临时清单**，别人不该看见 —— 所以它待在 session 里。

好处是顺带得到的：**游客也能加购**，不用先注册。

三个要注意的地方：

1. session 里的对象也是被多线程共享的（同一个浏览器可能并发发请求），
   所以 `Cart` 里的方法照样得 `synchronized`
2. 登录会换 session，得手动把 cart 迁移过去（见坑 13）
3. 购物车只存「编号 + 数量」，单价库存等显示时现查
   → **后台改了价，车里金额立刻跟着变**

### 3. 下单：为什么整个方法挂 `synchronized`

两个人同时买最后一件：

```
A 线程读到库存 1 → 判断够   ┐
B 线程也读到库存 1 → 也判断够 ┘ 两人各扣一次 → 库存 -1
```

这就是**超卖**。`placeOrder` 整个方法加锁，把「校验」和「扣减」圈在一起：

```java
public synchronized String placeOrder(User user, List<CartLine> lines, ...) {
    // ① 先整体校验一遍，全过了才动手
    for (CartLine l : lines) {
        if (l.getQty() > l.getItem().getStock()) {
            return "【" + l.getItem().getName() + "】库存只剩 ... 件";
        }
    }
    // ② 校验全过，再统一扣
    for (CartLine l : lines) {
        StoreItem it = l.getItem();
        it.setStock(it.getStock() - l.getQty());
    }
    // ③ 建订单（存快照）
}
```

两个关键细节：

- **先全检查、再全扣**。边查边扣的话，扣到第三件发现不够，
  前两件已经扣掉了还得再还回去 —— 麻烦，而且容易漏
- **校验和扣减必须在同一把锁里**。先不加锁地校验、再进锁里扣减，
  中间那段空隙照样能钻进来

单机内存版 `synchronized` 就够了。真上了多台服务器，
得靠数据库的行锁或乐观锁（版本号）—— 思路一样，只是把"锁"换成了别的东西。

### 4. 快照 vs 实时：`Order` 和 `Cart` 正好是一对反例

| | 存什么 | 后台改价之后 |
|---|---|---|
| `Cart` | 商品**编号 + 数量** | 车里的金额立刻跟着变 |
| `Order` | 名字、单价、数量的**副本** | 历史订单纹丝不动 |

订单必须存副本：昨天那单真收了 399 块，今天你把商品调到 299，
订单金额要是跟着变，账就彻底乱了。

回归测试里专门留了一条：**把商品删掉，订单页仍然显示它的名字** ——
这既验证了快照的价值，也说明订单表不该对商品加"删了就跟着删"的外键
（真上数据库的话，要么软删除，要么干脆不加外键）。

### 5. 开放重定向：`?redirect=` 不能直接信

前台点「去结算」→ 未登录 → 弹去登录 → 登录完回到结算页。
这个"回哪去"的参数写在地址栏里，**用户能随便改**：

```
/login?redirect=https://evil.com
```

用户老老实实登录完，却被送去钓鱼站。这叫**开放重定向**，是钓鱼常用的一招。

校验规则（`Params.safePath`）：

```java
static String safePath(String s, String def) {
    String v = trim(s);
    if (v.isEmpty() || !v.startsWith("/") || v.startsWith("//")) {
        return def;
    }
    return v;
}
```

- 必须**以单个 `/` 开头**（站内相对路径）
- **不能以 `//` 开头** —— 浏览器会把 `//evil.com` 当成"协议相对地址"，
  只是省略了 `https:` 而已，照样跳出站外。**这一条最容易漏。**

回归里三条断言盯着它：绝对 URL、`//` 开头、以及正常站内路径必须放行。

### 6. 水平越权：改个编号就想动别人的订单

`/mall/order/cancel?id=3` —— 如果只判断"登录了没"、不判断"这单是不是你的"，
把 id 从 3 改成 4 就能取消掉别人的订单。

```java
if (o == null || !o.getUserId().equals(user.getId())) {
    Flash.err(req, "订单不存在");     // 注意：不说"这不是你的订单"
}
```

两个细节：

- **`o.getUserId()` 写在前面**，防 `null` 触发 NPE
- 提示语一律说"订单不存在"，**不透露"这单存在但不是你的"** ——
  后者等于告诉攻击者"你猜对了编号"

同理，「我的订单」的过滤是在 **Servlet 里**做的（`store.ordersOf(userId)`），
不是把全部订单取出来再让页面筛 —— 页面筛意味着别人的数据已经进了内存，
哪天忘了筛就漏了。**该在哪一层过滤，是有讲究的。**

### 7. 状态机只写一份

订单状态就四个，流转单向：

```
待发货 ──发货──▶ 已发货 ──完成──▶ 已完成
   │
   └──取消──▶ 已取消
```

「能不能取消 / 能不能发货」这些判断写在 `Order` 里（`isCancelable()` 等），
Servlet 和 JSP 都只问结果：

```jsp
<c:if test="${o.cancelable}"> 取消按钮 </c:if>
```

好处：**改规则只改一处**。要是每个页面都写 `status eq '待发货'`，
哪天加个"已付款"状态，就得满项目去找。

后端也一样 —— `DataStore.updateOrderStatus()` 是唯一能改状态的地方，
合法性校验全在里面，外面想绕过都绕不过。

### 8. 取消订单要还货

取消不是简单改个状态：

```java
if (Order.STATUS_CANCELED.equals(status)) {
    restock(o);      // 把货还回库存
}
```

所以 `updateOrderStatus` 和 `placeOrder` 一样得加 `synchronized` ——
不然「取消」和「下单」可能同时改同一个商品的库存，件数就还错了。

容错上：商品可能已经被后台删掉了，`restock` 直接跳过、不报错 ——
为了一件已经不存在的商品让整个取消失败，不合理。

### 9. 入口在哪，以及「登录完该去哪」

| 入口 | 地址 | 谁能进 |
|---|---|---|
| 门面（根路径） | `http://localhost:8080/shop/` | 谁都能进，它 302 到商城 |
| 前台商城 | `http://localhost:8080/shop/mall` | 游客随便逛，下单才要登录 |
| 后台管理 | `http://localhost:8080/shop/dashboard` | 登录 + 有工作台权限 |
| 登录页 | `http://localhost:8080/shop/login` | —— |

两边互相有入口：后台顶栏右侧有个「前台商城」（新标签打开，不打断后台操作）；
商城顶栏有个「后台管理」，**只给有后台权限的人显示**，游客看不到。

#### 登录后默认落到哪

现在的答案是**前台商城**。改起来只是 `LoginServlet.safeRedirect()` 里的一个默认值：

```java
private String safeRedirect(HttpServletRequest req) {
    return Params.safePath(req.getParameter("redirect"), "/mall");   // ← 就改了这里
}
```

优先级：**带了 `redirect` 就用它，没带才用默认值。** 于是三种情况各归各位：

| 你怎么来的 | 登录完落到哪 |
|---|---|
| 自己主动打开登录页 | `/mall`（默认值生效） |
| 点「结算」被弹来的 | 回 `/mall/order/checkout` |
| 被 `/order` 这类后台页面弹来的 | 回 `/order`，接着被权限校验接管 |

改动本身只有一行，但**光改这一行等于没改** —— 其中缘由见坑 17。

---

## 十、商品图片：从上传到显示

### 10.1 就这么一件事，牵出两条完全不同的链路

| | 写入链路 | 读取链路 |
|---|---|---|
| 谁发起 | 管理员在后台提交表单 | 任何人，**包括没登录的游客** |
| 请求 | `POST /product/add`、`/product/edit`，`multipart/form-data` | `GET /img?name=3f9a1c2b7e4d5061.png` |
| 干什么 | 校验 → 落盘 → 把文件名写进 `StoreItem` | 按名字找到文件 → 按类型发回浏览器 |
| 难点 | 类型、大小、文件名**全都不可信** | 名字不能拿来穿越到别的目录 |

两条链路唯一的交汇点是**那个文件名**：
写的时候生成它、存进对象；读的时候拿它去找文件。
所以整个设计其实围绕着一个问题 —— **这个字符串能不能被信任？**

### 10.2 multipart 和普通表单的区别

| | `x-www-form-urlencoded`（默认） | `multipart/form-data` |
|---|---|---|
| 请求体长什么样 | `name=苹果&price=9.9`，用 `&` 连接 | 切成若干「段」，每段有自己的头和内容 |
| 能带文件吗 | **不能**，二进制会被毁掉 | 能，文件单独占一段 |
| 怎么设 | 什么都不用写 | 表单上 `enctype="multipart/form-data"` |
| 服务端怎么接 | 直接 `getParameter()` | 得先加 `@MultipartConfig`，再 `getPart()` |

**最容易忽略的一点**：`enctype` 忘了改的话，页面不报错、后端也不报错，
只是**文件静静地丢了** —— 因为浏览器把文件当成普通字段，只发了个文件名过去。
「改了半天不生效，但哪儿都没报错」的时候，先去查这一行。

### 10.3 `@MultipartConfig` 三个参数

```java
@MultipartConfig(
        fileSizeThreshold = 512 * 1024,    // 多大以内留在内存
        maxFileSize       = 3 * 1024 * 1024, // 单个文件上限
        maxRequestSize    = 6 * 1024 * 1024  // 整个请求上限
)
```

- **fileSizeThreshold** —— 超过它就先落临时文件，不一直占着内存。
  设太小 → 小图也走磁盘，慢；设太大 → 并发上传时内存飙升。
- **maxFileSize** —— 超了 Tomcat 抛 `IllegalStateException`（见**坑 14**，
  这个异常从哪儿冒出来很反直觉）。
- **maxRequestSize** —— 一般设成 `maxFileSize` 的两倍左右，
  给同请求里的文本字段留余量，免得几个字段就把合法的图误伤掉。

### 10.4 扩展名是用户说了算的，完全不可信

`accept="image/*"` 挡的是手滑，不是有心人。真实的攻击长这样：

```bash
# 把一个脚本改名成图片
mv evil.jsp shell.jpg
```

光看扩展名，这就是一张「图片」。所以真正的判断只能看**内容**——
每种图片格式的头几个字节是固定的，业内叫 **magic number（魔数）**：

| 格式 | 开头几个字节 |
|---|---|
| JPEG | `FF D8 FF` |
| PNG | `89 50 4E 47 0D 0A 1A 0A`（就是 `\x89PNG\r\n\x1a\n`） |
| GIF | `GIF8` |
| WEBP | `RIFF` …（跳过 4 字节长度）… `WEBP` |
| BMP | `BM` |

`Uploads.sniff()` 就干这一件事。还有个细节：**落盘时用的是嗅探出来的扩展名，
不是用户给的那个** —— 一个叫 `a.jpg` 的文件内容其实是 PNG，就存成 `.png`。
因为 `ImageServlet` 发什么 `content-type` 是按扩展名推的，
扩展名和真实内容对不上，等于给浏览器发了错的 MIME 类型。

### 10.5 为什么必须重新生成文件名

`Uploads.randomName()` 生成 16 位随机十六进制名。不用原始文件名的三个理由，
一个比一个实际：

1. **中文名、空格、各种符号**在 URL、磁盘、不同操作系统上的编码都容易出岔子
2. **不同商品传同名文件会互相覆盖** —— 两个人都传 `1.jpg`，后传的把先传的顶掉
3. **原始文件名可能带 `../` 或空字节** —— 这是路径穿越最经典的入口

16 位 = 2^64 种可能，撞名概率可以忽略，而且没法被人猜出来去枚举别人的图。

### 10.6 图片存哪里：绝不能放进 WAR 里

```xml
<context-param>
    <param-name>uploadDir</param-name>
    <param-value>D:/workpace/Calculator/shop-data/uploads</param-value>
</context-param>
```

看着最自然的做法是把图片传到 `webapps/shop/uploads/`——它就在应用目录里，
Tomcat 还能直接当静态资源发，连读图的 Servlet 都省了。

**但这个项目不能这么干。** 因为部署流程是：

```bash
rm -rf webapps/shop          # ← 整个目录删掉
mkdir webapps/shop && jar xf shop.war
```

图片放在里面，**每重新部署一次就全没了**。

> **一句话原则：代码和数据要分开。**
> WAR 是可替换的代码，用户上传的东西是数据。
> 数据放在 WAR 之外，重新部署多少次都还在。

配置读不到时的兜底是 `${catalina.base}/shop-uploads`——同样在 `webapps` 外面，
目的是「配置写漏了也别让上传功能直接崩」。

### 10.7 路径穿越：两道门

读图的地址是 `/img?name=xxx`。这个 `name` 是从 URL 来的，同样不可信：

```
/img?name=../../../../windows/win.ini
```

`Uploads.resolve()` 用两道门挡住它：

```java
// 第一道：白名单正则
// 只放行字母数字和 . _ - ，里面根本没有 "/" 和 "\"，
// 所以 "../" 这种写法连进都进不来
if (!name.matches("[A-Za-z0-9._-]{1,64}")) return null;
if (name.startsWith(".")) return null;   // 挡掉 "."、".."、".htaccess"

// 第二道：规范化之后必须还在 uploadDir 里面
String base = dir.getCanonicalPath();
String full = f.getCanonicalPath();
if (!full.startsWith(base + File.separator)) return null;
```

第二道看着多余（第一道已经把 `/` 和 `..` 都挡了），**但它不是多余的**：
`getCanonicalPath()` 会把 `a/../b` 解析成真实路径，也会追着符号链接走到底。
将来要是有人图省事放宽了那条正则，还有这道兜着。
**安全校验里，"多层重复"通常是故意的。**

### 10.8 改图片是「三态」，不是覆盖

这是表单里最容易写错的地方。`DataStore.update()` 收两个参数：

```java
public synchronized String update(..., String newImage, boolean removeImage) {
    // ...
    if (newImage != null) {
        it.setImage(newImage);        // ① 传了新图 → 换掉
    } else if (removeImage) {
        it.setImage(null);            // ② 没传新图但勾了「删除图片」→ 清空
    }
    // ③ 两个都没有 → 什么都不做（保持原样）
}
```

**如果图省事写成 `it.setImage(newImage)` 会怎样？**
用户每次改价格，图片都会被顺手抹掉 —— 因为表单里没选文件的时候
`newImage` 就是 `null`，直接 `set` 等于「没传新图 = 把图删了」。

> 表单里凡是「可以被留空」的字段，都要先想清楚**留空到底是什么意思**：
> 是「保持原样」，还是「清空它」？这两件事不能用同一个 `null` 表示。

### 10.9 孤儿文件：三种产生方式，两种清理

上传功能写不好，磁盘会慢慢堆满没人引用的文件。下面有两种是**代码要负责**的：

| 什么时候产生 | 怎么处理 |
|---|---|
| **换图**：新图存好了，旧图没人用了 | 更新成功后，比较「旧图名 ≠ 最终图名」就删旧图 |
| **存图成功但数据没存成**（比如商品重名）| 把刚落盘的新图立刻删掉 |
| **重启服务**：数据在内存里，重启就回到初始状态 | 代码**没有**对策 —— 见本节最后 |

第一种用「新旧对比」判断，好处是不用让 `update()` 额外返回"被换下来的旧图是谁"：

```java
StoreItem after = store.getById(id);
String finalImage = (after == null) ? newImage : after.getImage();
if (oldImage != null && !oldImage.equals(finalImage)) {
    Uploads.delete(getServletContext(), oldImage);
}
```

删商品也一样，但**顺序是关键**：

```java
// 先捞图片名，再删商品
StoreItem it = DataStore.get().getById(id);
String img = (it == null) ? null : it.getImage();
DataStore.get().delete(id);
Uploads.delete(getServletContext(), img);
```

反过来的话，商品已经从 `DataStore` 里没了，
挂在它身上的图片名就再也查不到 —— 那些图片会**永远留在磁盘上，没人知道它们属于谁**。

至于 `Uploads.delete()` 本身，它**故意吞掉所有异常**：
调用它的时机都是主流程已经成功之后，因为一个残留文件
把用户本来成功的操作报成失败，是本末倒置。

#### 第三种：重启带来的孤儿（内存版特有的）

`DataStore` 的数据**全在内存里**，重启 Tomcat 就回到 `initProducts()` 那 8 件原始商品，
`image` 字段自然都变回 `null`。可磁盘上的图片文件还躺在 `shop-data/uploads/` 里 ——
**文件在，只是再没有任何商品指向它们了。**

这不算 bug，是"数据存了两层、重启只重置了其中一层"的必然结果：

```text
商品数据（含图片名）  →  内存 DataStore   ← 重启清空
图片文件本身          →  磁盘 uploads/     ← 重启不动
```

两边的生命周期对不上，中间就断链。换成 JDBC 版（第十二节练习 1）这个问题自然消失 ——
商品和图片名一起落在数据库里，重启不会丢。

眼下要说的话只有一句：**心里有数就行。** 这些残留文件不影响任何功能，
但下次发现 uploads 目录越来越大、商品却都没图，别以为是上传功能漏了清理。

顺带一个验证技巧：想知道哪些文件成了孤儿，把商品逐个打开、抓页面里的
`/img?name=xxx`，再和目录列表求差集就出来了 —— 比盯着文件名猜可靠。

### 10.10 为什么订单项不存图片

`OrderItem` 是**快照**（存下单时的名字和价格），那图片要不要也快照一份？

**不要。** 因为图片文件和商品名/价格有一个本质区别：

- 名字、价格是**存在内存里的值**，快照一份就永远有效
- 图片是**磁盘上的文件**，而换图时我们会**把旧文件删掉**

存了图片名的订单，一换图就变成**悬空引用**（点开一片裂图）。
要不悬空，就得保留所有历史图片不许删 —— 那又是另一个复杂度了。

所以订单里继续用「首字色块」。**选择不存，是有意识的取舍，不是漏了。**

### 10.11 `/img` 为什么能进白名单

前台商城游客也要看得见商品图，所以 `/img` 加进了 `AuthFilter.WHITE_LIST`：

```java
private static final Set<String> WHITE_LIST = Set.of(
        "/login", "/logout", "/css", "/js", "/favicon.ico",
        "/img"      // ← 商品图片
);
```

这样放行安全吗？**安全**，因为：

1. 能取到的只有 `uploadDir` 里那几个随机命名的文件，猜不出来
2. 名字照样要过 `resolve()` 的两道校验，穿越不出去
3. 图片本身不是机密数据

> 判断一个地址能不能进白名单，别只问「要不要登录」，
> 要问「**不登录的人能从这里拿到什么**」。

### 10.12 附带的好处：可以放心长缓存

因为文件名是随机生成的，**换图 = 换名字**，所以「同一个 URL 永远对应同一张图」
这件事总是成立。于是可以放心让浏览器缓存七天：

```java
resp.setHeader("Cache-Control", "public, max-age=604800");
```

要是用商品的固定名（比如 `7.jpg`）当文件名，换了图 URL 不变，
浏览器就会一直拿老图 —— 那时候只能退回 `no-cache`，白白丢掉缓存的好处。
**「内容变了就换个 URL」，比「让缓存失效」干净得多。**

### 10.13 另一个刻意的设计：不要求必须 multipart

表单换成 multipart 之后，`ProductFormServlet` 依然能接收普通的
`x-www-form-urlencoded` 请求：

```java
String ct = req.getContentType();
if (ct != null && ct.regionMatches(true, 0, "multipart/", 0, 10)) {
    filePart = req.getPart("imageFile");
}
```

不判这一下的话，对非 multipart 请求调 `getPart()` 会直接抛 `ServletException`,
于是一个完全正常的「只改价格、不碰图片」的请求反而报错。
**服务端宽松一点，比强行要求所有调用方都改一遍要划算。**

（`regionMatches(true, ...)` 是忽略大小写比较前缀，
用它而不是 `toLowerCase()`，是为了躲开土耳其语 locale 把 `I` 转成 `ı` 的怪毛病。）

### 10.14 这次动了哪些文件

| 类型 | 文件 |
|---|---|
| 新增 | `Uploads.java`（存/取/删 + 三重校验）、`ImageServlet.java` |
| 改动 | `StoreItem`（加 `image`）、`DataStore`（`add` 重载 + `update` 八参三态）、`ProductFormServlet`（`@MultipartConfig` + 上传流程）、`ProductDeleteServlet`（清图）、`AuthFilter`（`/img` 白名单）、`web.xml`（`uploadDir`）、`CartLine`（`getImage()`）|
| 页面 | 后台 `product-edit`（图片字段）、`product-list`（缩略图列）、`style.css`；前台 `mall/card`、`mall/item`、`mall/cart`、`mall/checkout`、`mall.css` |

### 10.15 验证结果

新增 `图片回归测试.ps1`，**41 项断言全绿**，覆盖：

- 上传 PNG 新增 → 302、落盘 +1、落盘扩展名按内容嗅探
- 取图 200 且 `content-type` 正确；**游客未登录也能取图**
- 换图 → 新图在、旧图**404**
- **三态**：只改价格图还在 / 勾删除图真没了
- **伪装文件**（文本改名 `.jpg`）被拒且不留垃圾；**4MB 大图**被拒且是 302 不是 500
- 路径穿越 4 种写法全部 404
- 无图商品前台退回首字色块
- 删商品把图片一起带走；跑完数据回到起始状态

原有两条回归也重跑确认没被弄坏：**后台 97/97、前台 97/97**。
合计 **235 项断言**（后来又加了一批品牌的，见下一节）。

---

## 十一、品牌的「其他」：下拉里没有的怎么办

### 11.1 需求

「给品牌选择的时候加一个『其他』，可以自己输入。」

听着是个纯前端的小活儿，实际上一路牵到数据层。因为加完之后必须回答一个以前不用回答的问题：

**用户手输的那个名字，算不算一个品牌？**

### 11.2 先看清现状：品牌下拉的选项是从哪来的

```java
public List<String> allBrands() {
    List<String> names = new ArrayList<>();
    for (Brand b : allBrandList()) {   // ← 遍历的是 brandById，品牌表
        names.add(b.getName());
    }
    return names;
}
```

注意它遍历的是**品牌表**，不是遍历商品把品牌收集一遍。这个细节决定了后面所有事情。

商品和品牌之间其实是**按名字弱关联**的（`StoreItem.brand` 就是个 String），品牌表的作用是两件事：**提供可选项**、**提供统计**。

于是手输的品牌如果不进品牌表，立刻会冒出两处别扭：

1. 商品列表和前台商城的**品牌筛选下拉里没有它** → 那批商品根本筛不出来
2. 品牌管理页看不到它 → 写不了备注、算不出商品数、也没法给它改名

所以结论是：**手输了，它就得算一个品牌。**

### 11.3 两个控件怎么共存：拿 `disabled` 当隔离带

页面上其实是两个控件：

```html
<select name="brandPick"> … <option value="__other__">其他（自己输入）</option> </select>
<input type="text" name="brandCustom">
```

麻烦在于**它们不能同时提交** —— 不然服务端收到两个值，还得猜用户到底选了哪个。

这里用了个很省事的办法，**靠 `disabled` 当隔离带**：

```js
typed.disabled = !isOther;      // 选「其他」才解禁输入框
```

被禁用的表单控件，浏览器**压根不会往请求里放**。于是：

| 用户选了什么 | 谁提交 | 服务端收到 |
|---|---|---|
| 一个具体品牌 | 只有 select | `brandPick=小米` |
| 其他 + 手输 | 只有 input | `brandCustom=某品牌` |

永远只有一个值，不用猜。

**那为什么不干脆用 JS 在提交前把值拼好再提交一个字段？**
因为那就把「功能能不能用」押在了 JS 上：JS 一旦没跑（被拦、报错、用户禁用），请求里带的还是老结构，服务端又得靠猜。现在这套写法里，JS 只干「让输入框出现/消失」这种好看的活，**真正的规则全在服务端** —— 前端只是体验，不是约束。

### 11.4 下拉永远不能禁用

第一版我图省事，把两个控件做成严格互斥：选了「其他」就顺手把 select 也 `disabled`，选回具体品牌再把 input `disabled`。

结果发现是条**死路**：用户在「其他」状态下，那个下拉点不动了，**再也切不回具体品牌**。

规则改成「**只关输入框，永远不关下拉**」。下拉一直能点，用户随时能反悔。

> 心得：做「互斥/联动」的控件时，先问一句 —— **用户怎么退回来？**
> 只能进不能出的状态机，都是 bug。

### 11.5 服务端那条规则，用哨兵值写清楚

「其他」这个选项总得有个值。它不是任何真实品牌名，只是个信号，所以造一个哨兵：

```java
public static final String BRAND_OTHER = "__other__";
```

服务端就一句话：

```java
String brand;
if (DataStore.BRAND_OTHER.equals(brandPick)) {
    brand = brandTyped;                    // 下拉选的是「其他」→ 用手输的
    if (brand.isEmpty()) {                 // 手输框空着 → 拦下来
        backWithError(req, resp, editing, id, "选了「其他」，记得把品牌名填上");
        return;
    }
} else {
    brand = brandPick;                     // 否则 → 用下拉的
}
```

哨兵值单独拎成常量、并且在 `checkBrandName` 里**禁止真实品牌用这个名字**，是因为万一真有个品牌叫 `__other__`，「用户选了其他」和「用户选了那个品牌」就彻底分不清了。

### 11.6 编辑回填：这一步最容易漏

新增好办，编辑才是坑。

商品的品牌名**可能不在下拉里** —— 品牌管理里删过，或者就是历史上手输进来的。这种时候如果不管，编辑页会显示成「无品牌」，用户随手一保存，**原来的品牌就被冲掉了**。数据静默丢失，是最难查的那类问题。

所以模板里得先算一下「这个商品的品牌在下拉里吗」：

```jsp
<c:set var="brandInList" value="${false}"/>
<c:forEach var="bn" items="${brandOptions}">
    <c:if test="${bn eq item.brand}">
        <c:set var="brandInList" value="${true}"/>
    </c:if>
</c:forEach>
<c:set var="useOtherBrand" value="${not empty item.brand and not brandInList}"/>
```

`useOtherBrand` 为真时，下拉落到「其他」、输入框解禁、名字填进去。

> 顺带说一句现状：因为自定义品牌会自动入库，品牌表和商品实际上一直是一致的，
> 所以这条分支平时走不到 —— 它属于**防御性代码**，防的是数据被外部改坏。
> 这类分支该不该写？该写，但心里要清楚「它是保险，不是主路」，
> 注释里也最好写明白，免得后来人以为它天天在跑。

### 11.7 登记品牌要放在「商品保存成功之后」

```java
String err = editing ? store.update(...) : store.add(...);
if (err != null) { … return; }          // 商品没存成，就此打住

// 商品是真的落库了，这时候才轮到登记品牌
if (!brand.isEmpty() && store.ensureBrand(brand)) {
    brandTip = "，品牌【" + brand + "】也一并加进了品牌库";
}
```

顺序反过来的话：先登记品牌、再存商品，商品万一因为重名没存上，品牌库里就凭空多出一个没人引用的名字。

**这跟图片那次是同一类问题** —— 凡是「一次操作动两处地方」，都要先想清楚：哪一处失败了，另一处怎么收场。

`ensureBrand` 本身做成幂等的：已经有了就返回 false，不重复入库，也不报错。

### 11.8 校验抽成两边共用的一个方法

现在有**两个**地方能新增品牌了：品牌管理页的「新增品牌」、商品表单里的手输。两处规则必须一模一样 —— 不然会出现「商品表单能存进去的名字，到品牌管理页反而改不动」这种自相矛盾。

所以抽成 `public static`：

```java
public static String checkBrandName(String name) {
    // 非空 → 长度 ≤ 20 → 不许是保留字 → 不许含 < > " '
}
```

`addBrand` 和商品表单都调它，一条规矩。

为什么非要把 `< > " '` 挡在门外？因为品牌名会**铺在前后台好几个页面上**（下拉选项、表格单元格、前台卡片、商品详情……）。与其指望每个输出点都记得转义，不如从源头不让它进来。当然，该转义的地方照样转（这次顺手把商品列表的 `option` 和品牌列都换成了 `<c:out>`），源头拦截只是**多一层**保险。

### 11.9 参数改名不是局部手术：脚本这类「字符串调用方」编译器管不着

这次把参数从 `brand` 改成了 `brandPick` / `brandCustom`。改完编译通过、页面正常、自测也对 —— 但**回归脚本里还有 4 处在提交 `brand=`**：

- 后台回归 2 处（提交空品牌，没造成影响）
- 图片回归 2 处（提交 `brand="康师傅"`）

后者更隐蔽，它干了两件坏事：参数名对不上，品牌丢了；同时**「康师傅」这个新名字被动进了品牌库**（因为 `ensureBrand` 会无条件登记任何非空品牌名），跑完测试品牌表里凭空多一条。

> 教训：改一个对外接口的参数名，别只盯着 IDE 的编译报错。
> **字符串形式的调用方（脚本、模板、文档）编译器一滴都管不着**，
> 得手动把整个项目搜一遍。

### 11.10 这次动了哪些文件

| 文件 | 改了什么 |
|---|---|
| `DataStore.java` | 【新】`BRAND_NAME_MAX`、`BRAND_OTHER`、`checkBrandName()`、`ensureBrand()`；`addBrand` 改调 `checkBrandName` |
| `ProductFormServlet.java` | 【改】取 `brandPick`/`brandCustom` 两个参数 → 合成一个 brand → 校验 → 商品存成后登记品牌；把两个常量传给页面 |
| `product-edit.jsp` | 【改】品牌下拉 + 手输框 + 回填计算；引入 `/js/product-edit.js` |
| `js/product-edit.js` | 【新】选「其他」时解禁输入框，选别的重新禁用 |
| `css/style.css` | 【改】`.brand-custom` 的间距与禁用态（禁用就藏起来） |
| `product-list.jsp` | 【改】品牌的下拉项和单元格改用 `<c:out>` 输出 |

### 11.11 验证结果

新增 `品牌回归测试.ps1`，**48 项断言全绿**，覆盖：

- 走「其他」手输品牌 → 商品建成、品牌名正确落库
- **品牌自动进品牌库**（行数 +1、能反查到）
- 同一个名字再用一次 → **不重复入库**
- 品牌筛选下拉里出现它、**按它筛能筛出对应商品**
- 选了「其他」却不填 → 退回表单页，商品**没被建出来**
- **编辑页回填**：下拉选中手输的那个品牌、手输框此时是禁用的
- **下拉优先于手输**（模拟 JS 没跑起来，两个值一起提交 → 取下拉那个）
- 选「无品牌」清空 → 该筛选下只剩另一件
- 清空商品上的品牌 ≠ 删掉品牌（品牌库里那条记录还在）
- **multipart 下的中文品牌名**往返不乱码
- 非法品牌名（尖括号 / 超长 / 保留字）全部退回表单页，且**一个都没混进品牌库**
- 游客能在前台商品详情页看到这个自定义品牌
- 跑完品牌数与商品数**回到干净起点**

原有三条回归也重跑确认没被弄坏：**图片 41/41、后台 97/97、前台 97/97**。
四条合计 **283 项断言**。

（之后又把登录的默认落点改成了商城，前台那条补了 5 项断言升到 **102/102**，
总数 **288**。改动与验证见第九节 9.1 和坑 17。）

---

## 十二、监听器：抓住没有请求的那两个时刻

### 12.1 三大组件各站什么位置

Servlet、Filter、Listener 合称「Java Web 三大组件」，但它们跟请求的关系完全不同：

| | 干什么 | 在请求链路上吗 | 注册方式 | 本项目 |
|---|---|---|---|---|
| **Servlet** | 处理请求、生成响应 | ✅ 终点 | `@WebServlet` | 16 个 |
| **Filter** | 请求前后拦一道 | ✅ 中间 | `@WebFilter` | 1 个（`AuthFilter`） |
| **Listener** | 听容器的事件 | ❌ 不在 | `@WebListener` | 2 个（本轮加的） |

**最关键的一点：Servlet 和 Filter 都只能「被动等请求来」。**
而「应用启动的那一瞬间」「关闭的那一瞬间」，一个请求都没有 ——
这正是它们够不着的地方。**Listener 听的是容器自己的生命周期，不是用户发来的请求。**

按「听哪个域」分三组：

| 组 | 接口 | 什么时候被叫 |
|---|---|---|
| **context**（应用级） | `ServletContextListener` | 应用启动 / 关闭 |
| **session**（会话级） | `HttpSessionListener` | 会话创建 / 销毁 |
| **request**（请求级） | `ServletRequestListener` | 请求进入 / 离开 |

### 12.2 一个容易混的同名陷阱：JS 的 `addEventListener`

本项目里**确实有 `addEventListener`** —— 在 `js/product-edit.js` 和 `login.jsp` 里。
但它跟老师讲的 `Listener` 是**两码事**：

| | Java 的 Listener | JS 的 `addEventListener` |
|---|---|---|
| 听什么 | 服务器容器的事件 | 浏览器页面里的事件 |
| 跑在哪 | 服务器上 | 用户自己的电脑上 |
| 例子 | 应用启动、会话销毁 | 按钮被点击、下拉框切换 |

`product-edit.js` 里那句监听的是**品牌下拉框被切换**，纯前端，跟 Servlet 生命周期毫无关系。

### 12.3 AppListener：把「启动自检」放到启动时做

```java
@WebListener
public class AppListener implements ServletContextListener {
    public static final String ONLINE_COUNT = "onlineCount";

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        ServletContext sc = sce.getServletContext();
        try {
            File dir = Uploads.dirOf(sc);
            sc.log("[启动] 图片目录就绪：" + dir.getAbsolutePath());
        } catch (IOException ex) {
            sc.log("[启动] 图片目录不可用，上传功能会失败：" + ex.getMessage(), ex);
        }
        sc.setAttribute(ONLINE_COUNT, 0);
        sc.log("[启动] 商品管理系统就绪，上下文路径 = " + sc.getContextPath());
    }
}
```

三个设计决定，每个都有理由：

**① 为什么把「建图片目录」挪到启动时？**
在这之前，目录是 `Uploads.dirOf()` 每次调用时现查现建。改成启动时建一次，
好处是**故障暴露得早**：目录建不出来（盘满、路径写错、权限不够），
启动日志里立刻有一行「图片目录不可用」，而不是等用户上传到一半才撞上 500。

**② 为什么目录建不出来**不拦**启动？**
浏览商品、下单、管订单都不需要图片目录。为一个附属功能让整个系统起不来，是本末倒置。
**记录 + 继续**，让真正需要它的功能自己去报错。

**③ 为什么要先给 `onlineCount` 放一个 0？**
页面直接读这个值，不打底的话，第一个访客来之前那块会显示空白。

### 12.4 OnlineListener：数的是「会话」，不是「人」

```java
@WebListener
public class OnlineListener implements HttpSessionListener {
    @Override
    public void sessionCreated(HttpSessionEvent se)   { change(se,  1); }
    @Override
    public void sessionDestroyed(HttpSessionEvent se) { change(se, -1); }
}
```

两个必须提前知道的现实，不然你会以为它坏了：

**① 游客也会被算进去。**
JSP 默认 `session="true"`，**访问任何一页都会顺手创建一个 session** ——
哪怕这个人什么都没做、也没登录。这符合「有多少人在逛」的语义，
但爬虫、监控探针、无痕窗口同样各自占一个名额，**数字通常比真人多**。
真实项目里的「在线人数」从来都是估算值，没必要追求精确。

**② 会话销毁有延迟。**
Tomcat 不是一到 30 分钟就立刻销毁，而是后台线程**定期扫描**（默认约 60 秒一轮）。
所以人数往下掉会比你以为的慢一拍。这不是 bug，是「定期清理」这种设计的天性 ——
顺带也解释了它为什么省资源：**不值得给每个会话配一个定时器。**

### 12.5 为什么要加一把锁

`count + 1` 是「读出来 → 加一 → 写回去」三步，**不是原子操作**。
两个请求同时开新会话，可能都读到 3、都写回 4 —— 明明来了两个人，数字只涨了 1。

```java
private static final Object LOCK = new Object();

private void change(HttpSessionEvent se, int delta) {
    ServletContext sc = se.getSession().getServletContext();
    synchronized (LOCK) {
        int now = count(sc) + delta;
        if (now < 0) { now = 0; }
        sc.setAttribute(AppListener.ONLINE_COUNT, now);
    }
}
```

用**静态**锁而不是实例锁：容器对同一个监听器类通常只创建一个实例，实例锁本来就够用；
用 `static` 是为了不依赖「容器只创建一个」这个约定 —— 万一真有两个实例，计数也不会错。

性能完全不用担心：**只有会话生死时才进这段**，跟每个请求都要过的 Filter 不是一个量级。
真到高频计数的场景，才需要换成 `AtomicInteger`。

### 12.6 `if (now < 0) now = 0;` —— 这行不是多余的

防的是这种情况：Tomcat 正常关闭时会把 session **持久化**到磁盘
（`work` 目录下的 `SESSIONS.ser`），下次启动又**恢复**回来。
可 `ServletContext` 是全新的，计数从 0 开始 ——
那些「复活」的老会话后来陆续销毁，就会把计数扣成**负数**，页面上出现「-1 人在逛」。

根子是：**「应用级计数」和「会话级持久化」这两个生命周期不一样长**，凑一起就会对不上。
这一行兜底之后，最坏情况只是显示偏小，不会出现明显不对的值。

### 12.7 一条最有意思的断言：登录前后净变化为 0

```text
B12 登录换 session 后，在线数净变化为 0
```

为什么？因为 `LoginServlet` 为了防会话固定攻击，登录时会 `old.invalidate()` **再建一个新的**
（见坑 13）—— 落到监听器这边就是：`sessionDestroyed`（-1）紧跟着 `sessionCreated`（+1），
**净变化 0**。

这条断言的价值在于：**它同时验证了「减」和「加」都真的发生了。**
如果只测「退出登录会 -1」，那么漏掉 `sessionCreated` 也照样绿；
用「净变化为 0」就锁住了「这一对必须成对出现」。

### 12.8 什么时候**不需要**监听器

购物车存在 session 里，session 一销毁它自动就没了 —— **不需要**监听器去「清理」。

> **监听器监听的是「容器知道、但你的代码不知道」的事。**
> 购物车消亡这件事，你本来就知道（它就在 session 里）。硬加一个监听器，
> 只是把一个隐式的、自动的行为，换成一段显式的、可能出错的代码。

Listener 不是「用得越多越厉害」。

### 12.9 注册方式

两种，效果一样：

```java
@WebListener                                  // 注解，本项目用这种
public class AppListener implements ServletContextListener { ... }
```

```xml
<listener>                                    <!-- web.xml，另一种写法 -->
    <listener-class>com.cn.web.AppListener</listener-class>
</listener>
```

⚠️ 用注解的前提：`web.xml` **不能**带 `metadata-complete="true"` ——
写了它，Tomcat 会忽略项目里**所有**注解（`@WebServlet`、`@WebFilter`、`@WebListener` 一起失效）。

### 12.10 怎么验证它真的在工作

监听器没有页面、没有 URL，怎么证明它跑了？两条路：

**① 看它的副作用。** `OnlineListener` 一工作，页脚的人数就会动：

| 操作 | 期望 |
|---|---|
| 新开一个会话访问前台 | +1 |
| 同一会话再访问（换个页面也一样） | 不变 |
| 取 css / js 静态资源 | 不变（Tomcat 对静态资源不做会话跟踪） |
| 退出登录（`invalidate`） | -1 |
| 登录（换 session） | 净变化 0 |

**② 看它写的日志。** `AppListener` 在启动日志里留两行，
在 `logs\localhost.<日期>.log` 里搜 `[启动]` 就能确认应用换过一次。

上面这套写成了 `监听器回归测试.ps1`（25 条断言）。
注意它用的是**相对基线**比对，不写死绝对值 —— 会话要 30 分钟才超时，
之前测试留下的会话还占着名额，写死 `=1`、`=2` 这种数字，脚本第二次跑就会红。

### 12.11 监听器最适合干的三件事

| 场景 | 用哪个回调 |
|---|---|
| **启动自检**：建目录、校验配置、预热缓存 | `contextInitialized` |
| **关闭收尾**：内存数据存盘、关线程池、打告别日志 | `contextDestroyed` |
| **统计 / 审计**：在线人数、登录日志、不活跃会话清理 | `sessionCreated` / `sessionDestroyed` |

第二行正好对上本项目的一个真实痛点：**`DataStore` 是内存的，重启就回到初始 8 件商品。**
`contextDestroyed` 就是容器在关应用前给你的**最后一次机会**。
（内存版加它只是权宜之计 —— 正解是换成 JDBC 版，见下一节的练习。）

---

## 十三、手机上打开是什么样（移动端适配）

### 13.1 先说结论

这一节上一版只做了**诊断**（手机上会怎么坏），现在把它**改完了**。下面是改前改后的实测对照（Edge 无头浏览器，设备模拟 390×844，即 iPhone 14 的逻辑分辨率）：

| 指标（手机 390 宽） | 改前 | 改后 |
|---|---|---|
| 整页文档宽度 | **786px**，页面能横向拖 | **390px**，正好等于屏幕宽 |
| 顶栏容器 内容宽 | **786px**（溢出 396px） | 390px（不溢出） |
| 导航条右边界 | 786px —— 整条在屏幕外，一个都点不到 | **378px**，在屏内且可横滑 |
| 商品卡片 | **1 列**，卡片 354px 宽 | **2 列**，卡片 178px 宽 |
| 购物车表格 | 内容 405px / 盒子 364px，**「操作」列被裁掉** | 364 = 364，**不溢出** |
| 删除按钮位置 | 右边界 **418px**（在屏外，看不见也点不到） | 在屏内 |
| 表单控件字号 | 13.5px（iOS 聚焦会放大整页） | **16px** |
| 屏外元素数 | 每页都有若干 | **0**（6 个页面全部为 0） |

覆盖面：手机端测了 6 页 —— 首页（筛选收起）、首页（筛选展开）、购物车、商品详情、结算、我的订单，**全部无横向溢出、无屏外元素**。
同时拍了电脑端 1440px 对照图，**5 列卡片、顶栏一条线、筛选条一行，跟改之前完全一致** —— 新样式只该在窄屏生效，宽屏一点都不能动。

> 下面 13.2–13.6 是**改造前**的诊断，先看清"坏在哪"；**13.7 起才是改法**。

### 13.2 先纠正一个概念：「手机端」不是一个文件

Web 里没有"手机端页面"这种东西。服务器对所有请求一视同仁，返回的是**同一份 HTML + CSS**，区别只在浏览器怎么渲染。判断"是不是手机"只有两条线索：

| 线索 | 在哪判断 | 特点 |
|---|---|---|
| 窗口宽度 | CSS 媒体查询 `@media` | 一套页面通吃，拉窄窗口就变手机样 |
| User-Agent | 服务端 `request.getHeader("User-Agent")` 或 JS | 能真的"分开"，比如电脑访问自动跳走 |

所以**"电脑端也能打开"是天性，不是 bug**：地址只有一个 `/shop/mall`，谁打开都返回同一份页面。想让电脑端打不开，得额外加一道门（读 UA → 拦截/跳转）。

还有一个前提条件已经具备了：`layout-head.jsp` 里有 `<meta name="viewport" content="width=device-width, initial-scale=1.0">`。

**这一行的作用是"让 CSS 里的 1px 等于设备的 1 个逻辑像素"**。没有它，手机浏览器会假装自己有 980px 宽，然后把整页缩小塞进屏幕 —— 页面看起来"能用"，但字小得要用两根手指放大。很多老网站手机上打开像蚂蚁字，就是缺这一行。

### 13.3 首页：顶栏被推出屏幕

| 指标 | 实测值 | 说明 |
|---|---|---|
| `documentElement.scrollWidth` | **786px** | 整页内容宽是屏幕的 2 倍，能横向拖 |
| 顶栏 `.m-topbar-inner` | 盒子 390 / 内容 **786** | 溢出 396px |
| 导航条 `.m-nav` | 左边界 **402px** | 整条在屏幕外，一个链接都点不到 |
| 商品墙 `.m-grid` | **1 列**，卡片宽 354px | 一屏只放得下一件商品 |

**786 是怎么来的**：`.m-topbar-inner` 是 `display:flex`，**没有 `flex-wrap`**，三个孩子分别是品牌、搜索框（`flex:1`）、导航（`margin-left:auto`）。品牌和搜索框还能收缩，但**导航里有 6 个 `white-space:nowrap` 的链接，最小宽度就是 384px，收无可收** → 整个 flex 行撑到 786px → 溢出部分把 `body` 撑宽 → 整页出现横向滚动条。

最要命的是：**购物车入口和登录入口都在这个导航里**。手机用户进得来首页，进不去购物车。

**商品为什么变成一列**：`.m-grid` 是 `repeat(auto-fill, minmax(206px, 1fr))`。容器宽 354px，装不下两列（206×2 + 14 = 426 > 354），于是只剩一列，卡片被拉到 354px 宽 —— 一张卡占满一行，滚半天看不到几件。

### 13.4 购物车：表格被 `overflow:hidden` 裁掉

| 指标 | 实测值 |
|---|---|
| 表格 `.m-tbl` 实际宽度 | **418px** |
| 外层 `.m-panel` 宽度 | 354px |
| 外层 `overflow-x` | **hidden** |
| 表头列数 | 5（商品 / 单价 / 数量 / 小计 / 操作） |

两个原因叠在一起，结果比单纯"溢出"更糟：

1. **表格不会收缩**。`<table>` 的最小宽度由内容决定 —— 表头文字不换行、数量框固定 58px、小计的数字不能断行，算下来 418px 是它的底线，压不下去。
2. **外层是 `overflow:hidden`**。

`.m-panel` 当初加 `overflow:hidden` 是为了让 `border-radius` 能裁掉内部的直角背景（第十节里表格圆角就靠它）。但窄屏下，它把超出容器的 64px **直接裁掉，连滚动条都不给** —— 右侧「操作」列（删除按钮）整列消失，用户既看不到也点不到。

而表格左侧的商品列被挤到只剩几十像素，商品名只能一个字一行地竖排。

**这里有个通用教训：`overflow:hidden` 比溢出本身更难发现。** 溢出至少还会出现滚动条，用户能拖着看；`hidden` 是静默地让内容消失，页面上看不出任何异常。

### 13.5 为什么详情页和结算页反而没事

因为那两页当初写过断点：

```css
@media (max-width: 820px) { .m-detail  { grid-template-columns: 1fr; } }
@media (max-width: 860px) { .m-checkout { grid-template-columns: 1fr; } }
```

一行 `grid-template-columns: 1fr`，就把"左图右文"变成了"上图下文"。**这是移动端适配里性价比最高的一招**：多列网格在窄屏下改成单列，先解决"挤"，再谈别的。

### 13.6 顺带一个坑：13.5px 的输入框

iOS Safari 有条规矩：**表单控件的字号小于 16px 时，聚焦会自动把整个页面放大**。这个项目的输入框是 13.5px，所以手机上每点一次搜索框、数量框，页面都会"嗡"地放大一下，还得手动缩回去。

修法很简单：断点内把表单控件字号提到 16px，或者加 `maximum-scale=1`（后者会顺带禁掉用户的双指缩放，不太友好，不推荐）。

### 13.7 改法① 顶栏：让 flex 行允许换行

原来三个孩子一行排不下（导航里 6 个 `nowrap` 链接最小 384px，收无可收），改法是**换行**而不是硬压：

```css
@media (max-width: 640px) {
    .m-topbar-inner {
        height: auto;        /* 桌面版写死 62px，换行后必须放开 */
        flex-wrap: wrap;     /* ← 关键就这一句 */
        gap: 8px 10px;
    }
    .m-search { flex: 1 1 120px; max-width: none; }  /* 搜索框独占第一行剩下的宽度 */
    .m-nav {
        flex: 0 0 100%;      /* basis 100% 在 wrap 容器里 = 强制折行 */
        margin-left: 0;      /* 桌面版的 margin-left: auto 必须清掉 */
        overflow-x: auto;    /* 第二行横向可滑，不再折成第三行 */
        padding: 9px 2px 3px;
        scrollbar-width: none;
    }
    .m-nav::-webkit-scrollbar { display: none; }
    .m-nav a { flex: 0 0 auto; }   /* 别把链接压瘦，让它撑开去滑 */
}
```

四个值得记的点：

**① `flex: 0 0 100%` 是「这行我包了」。** 在 `flex-wrap: wrap` 的容器里，子项的 `flex-basis` 一旦超过剩余空间就会换行。写 `width: 100%` 也行，但 `flex-basis` 更贴合「我在参与 flex 布局」的语义。

**② 第二行用「横滑」而不是「再折一行」。** 顶栏是 `position: sticky` 的，每多一行就**永久**吃掉屏幕上约 30px 的正文空间。折成两行顶栏就 140px 高了 —— 在 844px 高的手机上那是 1/6 屏。

**③ `margin-left: auto` 必须清掉。** 它是桌面版用来「把导航推到最右边」的，换行后如果还留着，导航会贴着右边、左边空一大块。

**④ `padding-top: 9px` 不是随手加的。** 这里有个反直觉的规则：**`overflow-x` 一旦不是 `visible`，`overflow-y` 的计算值会被强制成 `auto`**（CSS 规范规定，因为不允许一个方向可滚、另一个方向随便溢出）。于是 `.m-nav` 变成了一个会裁切的滚动盒子，而购物车角标是用 `top: -9px` 浮在链接上方的 —— 不留出那 9px 就会被裁掉。所以给 `.m-nav` 加了 `padding-top`，角标才露得出来。

### 13.8 改法② 表格 → 卡片

购物车那张表在窄屏下**压不下去**（最小内容宽 418px），所以不跟它较劲，**直接改变它的形态**：

```css
@media (max-width: 640px) {
    .m-tbl-cart thead { display: none; }                 /* 表头不要了 */
    .m-tbl-cart, .m-tbl-cart tbody { display: block; }    /* 表格布局退化成块级 */
    .m-tbl-cart tr {                                      /* 一行 = 一张小卡片 */
        display: grid;
        grid-template-columns: 1fr auto;
        gap: 9px 10px;
        padding: 13px 14px;
    }
    .m-tbl-cart td { display: block; padding: 0; border: none; }

    /* 用 grid 摆位置，不再靠「第几列」 */
    .m-tbl-cart td:nth-child(1) { grid-column: 1 / -1; }               /* 商品，横跨 */
    .m-tbl-cart td:nth-child(2) { grid-column: 1; grid-row: 2; }       /* 单价 */
    .m-tbl-cart td:nth-child(3) { grid-column: 2; grid-row: 2; justify-self: end; }
    .m-tbl-cart td:nth-child(4) { grid-column: 1; grid-row: 3; }       /* 小计 */
    .m-tbl-cart td:nth-child(5) { grid-column: 2; grid-row: 3; justify-self: end; }

    /* 表头一藏，光一个 ¥59.00 看不出是单价还是小计，用 ::before 补一个字 */
    .m-tbl-cart td:nth-child(2)::before { content: "单价 "; }
    .m-tbl-cart td:nth-child(4)::before { content: "小计 "; }
}
```

**HTML 一个字没改** —— 还是那个 `<table>`，只是换了个摆法。每个商品在手机上变成：

```
[缩略图] 可乐
         可口可乐 · 食品
单价 ¥3.50                    [ 1 ]
小计 ¥3.50                [ 删除 ]
```

这是「内容结构」和「呈现方式」分开的好处：结构（谁是商品、谁是价格）留在 HTML 里，怎么摆交给 CSS。

结算页那张表少一列（没有操作按钮），所以另写了一套 `m-tbl-mini`。**两张表必须用不同的类名** —— 用 `nth-child` 数格子，列数不一样的表混在一起一定会错位。

⚠️ 这段改的时候撞上一个真坑，见 **13.12**。

### 13.9 改法③ 把筛选条收进折叠面板（不用一行 JS）

首页有 6 个筛选项，展开要占 357px 高（实测）——将近半屏。但筛选是**低频操作**，默认收起来更合理。

用「checkbox hack」：一个看不见的勾选框 + 一个 `<label>`，点 label 等于点勾选框，CSS 再用 `:checked` 决定展开。全程零 JavaScript。

**list.jsp 那边加的部分：**

```jsp
<!-- 注意：它必须是 .m-filters 的「兄弟元素」，CSS 靠 ~ 找它 -->
<input type="checkbox" id="mFilterToggle" class="m-filter-toggle" hidden
       ${(not empty keyword or not empty category or not empty brand
          or not empty minPrice or not empty maxPrice or not empty sort) ? 'checked' : ''}>
<label class="m-filter-bar" for="mFilterToggle">
    <span>筛选 / 排序</span>
    <span class="m-filter-arrow">▾</span>
</label>
```

**CSS 那边：**

```css
/* 桌面端一律不显示 —— 这样宽屏的行为和加这节之前一模一样 */
.m-filter-toggle, .m-filter-bar { display: none; }

@media (max-width: 640px) {
    .m-filter-bar { display: flex; height: 42px; /* … */ }
    .m-filter-toggle:not(:checked) ~ .m-filters { display: none; }
    .m-filter-toggle:checked  ~ .m-filter-bar .m-filter-arrow { transform: rotate(180deg); }
}
```

两个要点：

**① 那句 EL 三元决定「默认展开还是收起」。** 地址栏里带着筛选条件（`?category=数码`）时自动展开 —— 不然用户看到 2 件商品，会以为"就这些"，而不是"我自己筛过"。实测：不带条件时 `display:none`（收起），带 `?category=数码` 时 `display:flex`、高 357px（展开）。**同一个 CSS 规则，用数据决定初始状态。**

**② 兄弟选择器 `~` 有布局约束，而且失效是静默的。** 以后要在这附近包一层 `div`，必须把 `input` 和 `.m-filters` **一起**挪进去，否则折叠失效 —— 而且不报错，只是面板永远收起或永远展开。所以我在 JSP 里留了注释。

### 13.10 改法④ 手指相关的三件小事

```css
@media (max-width: 640px) {
    /* ① 表单控件字号一律 16px */
    .m-search input, .m-filters input, .m-filters select,
    .m-form-row input, .m-form-row textarea,
    .m-qty input, .m-qty-inline input { font-size: 16px; }

    /* ② 可点区域拔高 */
    .m-btn { height: 40px; }
    .m-btn-lg { height: 46px; }
}

/* ③ 触屏取消 hover 效果 */
@media (hover: none) {
    .m-card:hover { box-shadow: none; transform: none; border-color: #eceef1; }
}
```

**① 为什么非得是 16px**：这不是审美问题，是 iOS Safari 的一条硬规矩 —— 聚焦到字号小于 16px 的表单控件，它会**自动把整页放大**。13.5px 的输入框，手机上每点一次搜索框就"嗡"地放大一下，还得手动缩回去。

**② 为什么是 40px**：触摸目标的舒适下限一般建议 ≥44px（iOS 人机指南）或 ≥48px（Material）。这个项目按钮原高 34px，偏小；先提到 40px 是折中 —— 再高整页会显得松散，而且 640px 下还得考虑排版。

**③ 为什么用 `(hover: none)` 而不是按宽度猜**：「是不是触屏」和「屏幕多宽」是两件独立的事 —— 带触摸屏的笔记本两条都中，平板接鼠标时窄屏但不是触屏。`(hover: none)` 直接问的是「**主要输入方式有没有悬停能力**」，比猜宽度准。

**不这么改会怎样**：手机点完「加入购物车」，那张卡片会一直保持抬起的状态（`translateY(-2px)` + 阴影），因为触屏把最后一次点击记成了 hover，看起来像卡住了。

### 13.11 断点为什么取 640px，而且必须放在文件最后

原来的代码里已经有 820px（详情页）和 860px（结算）两个断点。新加的这层取 **640px**，理由是：

- 覆盖手机竖屏（360–430px）一直到小平板竖屏
- 640px 以上交给 `.m-grid` 的 `auto-fill` 自己决定列数（第 ④ 节），不用管；实测 641–820px 区间桌面布局本来就排得下
- 不跟已有的 820/860 打架

**⚠️ 但顺序很重要。** 媒体查询是**叠加**的：390px 下三个断点会**同时命中**。CSS 没有"特异性高于一切"这回事 —— 同权重下**后写的覆盖先写的**。所以移动端这一整节必须放在 `mall.css` 的**最末尾**。

如果哪天把它挪到文件中间，它就会被后面的桌面规则盖回去，而且**不报错**，只是手机上又变回原来的样子。

### 13.12 改的过程中踩进去的坑：选择器盖不住，静默失效

第一版改完一量，购物车的删除按钮**还是**跑到屏幕外（右边界 418px）。量出来的现场数据是：

```
td.col-act  内容 56px / 盒子 1px     ← 格子被压成 1px
其内 button  宽 56px，右边界 418px
外层 .m-panel  overflow-x: hidden     ← 又把它裁掉
```

**根因**：桌面版第 ⑥ 节里有一句 `.m-tbl .col-act { width: 1%; }`（让"操作"列尽量窄）。卡片化之后 `td` 变成了网格单元，这条规则**照样生效** —— 网格轨道在算自身宽度时，看到子项 `width: 1%` 没法解析，就按 0 处理，格子于是被压成 1px，里面的按钮溢出。

**修法**不是加 `!important`，是把选择器写具体到能赢：

| 规则 | 选择器 | 特异性 |
|---|---|---|
| 桌面版 | `.m-tbl .col-act` | (0, 2, 0) —— 两个类 |
| 我第一版写的（**输**） | `.m-tbl-cart td` | (0, 1, 1) —— 一个类 + 一个元素 |
| 改成这样（**赢**） | `.m-tbl-cart td.col-act` | (0, 2, 1) —— 两个类 + 一个元素 |

**通用教训**：写覆盖样式时，光"选择器写在后面"是不够的，还得**特异性不低于对方**。而且这类失败**完全静默** —— 页面不报错、控制台不警告，看起来"样式加了但没生效"，唯一可靠的办法就是**量**（见 13.13，把盒子的宽高打出来）。这和坑 20（`overflow:hidden` 静默丢内容）是同一个毛病家族：**CSS 不会因为你写错了就报错，它只会当没看见。**

### 13.13 怎么自己验证

#### 方法一：给浏览器下发真实的设备模拟（推荐，比"把窗口拖窄"准得多）

直接用 `--window-size=390` 启动无头浏览器是**不准的** —— Chromium 对窗口宽度有下限（约 500 CSS px），传 390 会被悄悄抬到 500，截出来的是 500 宽的布局。**必须用 CDP 的 `Emulation.setDeviceMetricsOverride`。**

工具在 `_shots/mobile-probe.mjs`，它会做三件事：下发 390×844 设备模拟 → 量页面 → 截图。

**① 量什么**（这才是关键，截图只是给人看的）

| 指标 | 判什么 |
|---|---|
| `documentElement.scrollWidth` vs 视口宽 | 整页有没有横向溢出（**权威指标**） |
| 每个元素的 `right` 边界 | 有没有元素跑到屏幕外 |
| `scrollWidth > clientWidth` 的元素 | 内容比盒子宽的有哪些（区分是"溢出"还是"故意横滑"） |
| `.m-topbar-inner` 的盒子宽 / 内容宽 | 顶栏挤不挤 |
| `.m-grid` 的 `gridTemplateColumns` 拆几段 | 商品几列 |
| 表格的盒子宽 / 内容宽 / 外层 `overflow-x` | 有没有被裁 |
| 所有表单控件的 `computedStyle.fontSize` | 有没有 <16px（iOS 会放大） |

**② 三个已经踩过的工具坑**（不记下来下次还得重踩）

**坑 A：不要在页面里用 `fetch` 去做登录。** 前台登录成功返回 **302**，页面内的 `fetch` 会跟着跳转，**CDP 那条命令就永远等不到结果，脚本直接卡死**。
正确做法：**在 Node 端登录拿到 `JSESSIONID`，再用 `Network.setCookie` 注进浏览器**。

**坑 B：同一个标签页连续导航 3 次以上，headless 的渲染进程会卡死**（症状：`Runtime.evaluate` 和 `Page.captureScreenshot` 全部超时，而且再也恢复不了）。
改法：**每测一个页面就开一个全新标签页**，测完不用关（关掉最后一个标签页浏览器会自己退出，反而把后面所有请求变成连接被拒）。

**坑 C：启动浏览器和跑脚本必须放在同一条命令里。** 后台异步启动的浏览器会被宿主环境很快回收掉 —— 表现是"脚本刚跑第一页就连接被拒"。把 `启动浏览器 & sleep 6 & 跑脚本` 写成一整条命令，浏览器就只在这条命令期间活着，够用了。

顺带：脚本支持按页分批跑，报告是**累加**的（同一页重跑覆盖旧的），所以一次跑不完可以分几批：

```bash
node mobile-probe.mjs                 # 全部 8 页
node mobile-probe.mjs cart,item       # 只跑这两页
```

#### 方法二：用真手机访问

1. 手机和电脑连**同一个 WiFi**
2. 电脑上 `ipconfig` 查到局域网地址，如 `192.168.1.7`
3. 手机浏览器打开 `http://192.168.1.7:8080/shop/mall`

两个前提：**手机上的 `localhost` 指的是手机自己**，一定得用电脑的 IP；另外 Windows 防火墙可能拦 8080，第一次连不上就往这个方向查。

Tomcat 这边不用改 —— `Connector` 没写 `address` 属性时默认监听所有网卡。

#### 方法三：改完之后别忘了回归

CSS 动的是"长相"，但 JSP 也动了几处（加折叠开关、给两张表加类名）。改完必须把回归测试跑一遍：

```
前台回归测试.ps1   → 102 / 102
回归测试.ps1       → 97 / 97
监听器回归测试.ps1 → 25 / 25
品牌回归测试.ps1   → 48 / 48
图片回归测试.ps1   → 41 / 41
```

> 中途有一项挂了（`final-state orders expose no action buttons`），排查下来是**我自己造的测试数据**造成的：体检脚本为了截"我的订单"页真下了两张单，都是「待发货」状态，于是管理后台的订单列表上多出 4 个操作按钮，把那条断言打破了。
> **重启一次 Tomcat（数据在内存里）再跑，102/102 全绿。**
> 教训：给内存版应用做验证时，**跑回归之前先重启一次**，别让探测脚本留下的数据污染断言。

## 十四、可以继续练的方向

1. **把 `DataStore` 换成 JDBC** —— `com.stud.JdbcDemo` 里有现成的连数据库代码，把内存三容器换成 MySQL 表，语义完全一样
2. **加过滤器记日志** —— 再写一个 `@WebFilter`，记录每个请求的 URL 和耗时，体会"横切"的好处
3. **加验证码** —— 在登录页生成一张图片验证码，存进 session 比对
4. **把 JSP 换成 Thymeleaf** —— 和你 shopweb 项目那套统一，对比一下两种模板引擎的差别
5. **分类也加「其他」** —— 品牌这条路已经走通了（第十一节），把同一套（下拉 + 手输框 + `disabled` 隔离 + 服务端合成 + 自动登记）搬到分类上。搬的时候想一个问题：**分类该不该像品牌那样自动入库？** 品牌是长尾的（谁都能造一个新牌子），分类往往是有限的几个 —— 也许更该拦住新值，让人去分类管理里加
6. **`web.xml` 版注册** —— 把 `@WebServlet` 注解全删了，改用 `web.xml` 里的 `<servlet>` 标签，体会一下"注解之前"的世界
7. **加「用户管理」页面** —— 把 `category-list.jsp` 的行内编辑套路照搬过来，做「给用户分配角色」；顺带体会权限表为什么要分菜单级和按钮级
8. **列表页加「导出 CSV」** —— 一个 `ExportServlet`，把当前筛选结果写出去，注意 BOM 和逗号转义
9. **工作台柱状图做成可点的** —— 点「数码」那根柱子跳到 `/product/list?category=数码`，把两个页面串起来
10. **把回归脚本的断言体检一遍** —— 翻一遍现有断言，把那些「页面里出现了某个字」型的，改成「认 id / 数行数 / 看 `selected`」（见**坑 16**）。把自己写的测试改成「能因为功能坏掉而变红」，是提升测试质量里最划算的一步
11. **把「登录后去哪」按角色分开** —— 现在是所有人一律落商城。改成 `admin` 落 `/dashboard`、`user` 落 `/mall`，也就一条 `if`。但先想清楚优先级：**带了 `redirect` 的时候，"角色的偏好"该不该给"用户的来路"让路？** 想清楚再动手，比写完再纠结省事
12. **用 `contextDestroyed` 给数据留个备份** —— 关应用时把 `DataStore` 存成文件、启动时读回来，重启就再也不丢数据了。别急着写，先想清楚三件事：**文件格式选什么**（手拼文本最省事，但字段一多就脆）、**写了一半崩了怎么办**（惯用做法是先写临时文件、写完再改名覆盖）、**存盘失败要不要阻止关闭**（大概率是不阻止，但要记日志）。这三问就是「能用的版本」和「可靠的版本」之间的分界线
13. **在线人数进阶版** —— 现在数的是**会话数**，把爬虫、探针、无痕窗口都算进去了。用 `HttpSessionAttributeListener` 监听 session 里 `user` 属性的增删，改成只数**登录过的人**，然后把两个数字摆在一起看 —— 你会直观看到「逛的人」和「买的人」差多少
14. **给手机端再加一条底部导航栏** —— 现在手机上的主入口是「顶栏第二行横滑」，能用但不算地道。真正的移动端应用一般用**吸底 tab 栏**（首页 / 购物车 / 我的），拇指够得着。
    要动手改的位置很集中：`layout-foot.jsp` 加一个 `<nav class="m-tabbar">`（只在 ≤640px 显示，`position: fixed; bottom: 0`），CSS 里再给 `body` 补 `padding-bottom` 免得挡住页脚。
    做之前先想清楚两件事：**① 顶栏那段横滑导航要不要精简掉重复项？**（首页/购物车会同时出现在两个地方）；**② `fixed` 定位 + iOS 的安全区**（刘海屏底部那条横杠）—— 要加 `padding-bottom: env(safe-area-inset-bottom)`，不然会被系统横杠压住
15. **在前台挂一个「PC 端才显示」的布局** —— 现在手机和电脑共用一套响应式布局（这是对的）。可以试着反过来体会一次「UA 分流」：在 `AuthFilter` 里读 `User-Agent`，把电脑访问 `/mall` 的请求跳到 `/mall/pc`。做完对比一下两种方案的维护成本，就能理解**为什么响应式才是主流**（同一份 HTML，不用维护两套）
