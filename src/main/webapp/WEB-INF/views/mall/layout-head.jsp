<%--
  ⚠️ 这一行不能省！
  被静态包含（<%@ include %>）进来的片段文件，Tomcat 会**单独**判断它的源码编码，
  不会继承主页面第一行那份声明。片段里没有 pageEncoding，
  中文字面量就会被当成 ISO-8859-1 读进来，页面直接乱码。
  详情写在后台的 layout-head.jsp 里，这里只提醒一句。
--%>
<%@ page pageEncoding="UTF-8" %>
<%--
  前台骨架 · 上半部分（顶栏）
  用静态包含引进来，所以能用主页面声明的 c: 标签。

  页面需要提前准备的变量：
    pageTitle        当前页面标题
    keyword（可选）    搜索框回填用
    搜索引擎依赖 AuthFilter 注入的 here（当前路径，不含上下文）

  注意 isMall 那条路径在 AuthFilter 里是**放行**的，
  所以这里的 ${currentUser} 对游客来说是空的 ——
  页面必须能用「没登录」的状态正常渲染，登录/未登录两套导航都得有。
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>

<%-- 购物车角标：session 里没有 cart 就显示 0，
     这里用 c:set 打底是为了避免 EL 对 null 取属性 --%>
<c:set var="cartCount" value="0"/>
<c:if test="${not empty sessionScope.cart}">
    <c:set var="cartCount" value="${sessionScope.cart.count}"/>
</c:if>

<%-- 「登录后回到当前页」的目标地址。
     用 <c:url>/<c:param> 拼，参数里的中文和 & 会被自动编码，
     手拼字符串很容易在带查询参数时出岔子。 --%>
<c:set var="backUrl" value="${here}"/>
<c:if test="${not empty pageContext.request.queryString}">
    <c:set var="backUrl" value="${here}?${pageContext.request.queryString}"/>
</c:if>
<c:url var="loginUrl" value="/login">
    <c:param name="redirect" value="${backUrl}"/>
</c:url>
<c:url var="logoutUrl" value="/logout">
    <c:param name="redirect" value="/mall"/>
</c:url>

<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${pageTitle} · 优选商城</title>
    <link rel="stylesheet" href="${ctx}/css/mall.css">
</head>
<body>

<header class="m-topbar">
    <div class="m-wrap m-topbar-inner">

        <a class="m-brand" href="${ctx}/mall">
            <span class="m-logo">优</span>
            <span>优选商城</span>
        </a>

        <form class="m-search" method="get" action="${ctx}/mall">
            <input type="text" name="keyword" value="${keyword}"
                   placeholder="搜索商品 / 分类 / 品牌" autocomplete="off">
            <button type="submit">搜索</button>
        </form>

        <nav class="m-nav">
            <a href="${ctx}/mall">首页</a>
            <a class="m-cart-link" href="${ctx}/mall/cart">购物车<c:if test="${cartCount > 0}"><span
                    class="m-badge">${cartCount}</span></c:if></a>

            <%-- 后台入口。判据用「有没有工作台权限」——admin 和 user 都有，
                 游客没有，所以没登录时这一条不会出现。
                 这条链接是必须的：登录后默认落在商城，没有它，
                 管理员就只能自己敲 /dashboard 才能回后台。
                 can 这个 Map 由 AuthFilter 注入，前台路径也是走完整段注入的
                 （见 AuthFilter.isMall 的注释）。 --%>
            <c:if test="${can['dash:view']}">
                <a class="m-admin-link" href="${ctx}/dashboard">后台管理</a>
            </c:if>

            <c:choose>
                <c:when test="${not empty currentUser}">
                    <a href="${ctx}/mall/order/list">我的订单</a>
                    <span class="m-user">你好，${currentUser.name}</span>
                    <a href="${logoutUrl}">退出</a>
                </c:when>
                <c:otherwise>
                    <a href="${loginUrl}">登录</a>
                </c:otherwise>
            </c:choose>
        </nav>

    </div>
</header>

<main class="m-wrap m-main">
