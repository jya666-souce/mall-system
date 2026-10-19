<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>登录 · 商品管理系统</title>
    <link rel="stylesheet" href="${ctx}/css/style.css">
</head>
<body class="login-body">

<div class="login-card">
    <h1>商品管理系统</h1>
    <p class="sub">Servlet + JSP + Tomcat 版 · 后台管理 + 前台商城</p>

    <%-- 登录失败时 LoginServlet 会 forward 回来并带上 error --%>
    <c:if test="${not empty error}">
        <div class="login-error">${error}</div>
    </c:if>

    <form method="post" action="${ctx}/login">
        <%-- 「登录后回哪去」的目的地。
             从前台被弹过来时（比如点结算），地址栏带着 ?redirect=/mall/order/checkout，
             LoginServlet 会把它放进 request，这里用隐藏域再交回去。
             服务端会校验它是不是站内路径 —— 这个值来自地址栏，不能直接信。 --%>
        <input type="hidden" name="redirect" value="<c:out value='${redirect}'/>">

        <label for="username">用户名</label>
        <input type="text" id="username" name="username"
               value="${username}" placeholder="admin 或 user" autofocus autocomplete="off">

        <label for="password">密码</label>
        <%-- 别把真实密码当 placeholder：占位文字是浅灰色的，
             看着像"已经填好了"，用户直接点登录 → 提交空密码 → 报"用户名或密码错误"，
             然后开始怀疑账号是不是有问题。提示语就该写成"请输入密码"。 --%>
        <input type="password" id="password" name="password"
               placeholder="请输入密码" autocomplete="off">

        <button type="submit" class="btn btn-primary btn-block">登 录</button>
    </form>

    <div class="tip">
        <b>测试账号（点一下自动填入）</b>
        <span class="fill" data-user="admin" data-pass="123456">
            <code>admin</code> / <code>123456</code> —— 管理员（后台全部功能 + 前台购物）
        </span>
        <span class="fill" data-user="user" data-pass="123456">
            <code>user</code> / <code>123456</code> —— 普通用户（后台只读 + 前台购物）
        </span>
        <span style="margin-top:6px">
            登录成功后进入 <b>前台商城</b>；要管理后台，点商城顶栏的「后台管理」。
        </span>
        <span>
            <a href="${ctx}/mall">← 不登录也能直接逛前台商城</a>
        </span>
    </div>
</div>

<script>
    // 点一下测试账号 → 自动填进表单，省得手打。
    // 纯粹是浏览器里跑的小交互，不发给服务器。
    document.querySelectorAll('.fill').forEach(function (el) {
        el.addEventListener('click', function () {
            document.getElementById('username').value = el.dataset.user;
            document.getElementById('password').value = el.dataset.pass;
        });
    });
</script>

</body>
</html>
