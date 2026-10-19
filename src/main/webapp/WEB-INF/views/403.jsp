<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <title>没有权限 · 商品管理系统</title>
    <link rel="stylesheet" href="${ctx}/css/style.css">
</head>
<body class="login-body">

<div class="login-card error-card">
    <div class="badge-num">403</div>
    <h1>没有权限</h1>

    <p class="sub">
        你当前的角色是
        <span class="role-tag">${roleName}</span>，
        没有操作 <code>${neededPerm}</code> 的权力。
    </p>

    <p class="hint">
        这不是「点了按钮被拦下来」，而是这个权限压根不在你的权限列表里 ——
        所以列表页上对应的按钮根本不会渲染出来。
        你现在看到这个页面，是因为浏览器直接请求了一个需要权限的地址。
    </p>

    <a class="btn btn-primary btn-block" href="${ctx}/dashboard">返回工作台</a>
</div>

</body>
</html>
