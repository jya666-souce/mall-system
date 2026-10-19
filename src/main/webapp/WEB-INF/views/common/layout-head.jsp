<%--
  ⚠️ 这一行不能省！
  被静态包含（<%@ include %>）的片段文件，Tomcat 会**单独**按「有没有 BOM →
  pageEncoding → contentType → 默认 ISO-8859-1」的顺序猜它的源码编码，
  不会继承主页面第一行声明的那份。片段里没有 pageEncoding，
  里面的中文字面量就会被当成 ISO-8859-1 读进来，页面直接变成乱码。
  而 EL 取出来的中文（${pageTitle}）是运行时数据，不受影响 ——
  所以症状很怪：同一个 <title> 里，EL 出来的正常、写死的乱码。
--%>
<%@ page pageEncoding="UTF-8" %>
<%--
  后台骨架 · 上半部分（侧边栏 + 顶栏）
  用静态包含 <%@ include file="..." %> 引进来 —— 编译期就把内容并进来，
  所以这里能直接用主页面声明的 c: 标签，不用再声明一遍 taglib。

  页面需要提前准备的变量：
    pageTitle  当前页面标题（显示在标题栏和面包屑）
    active     当前高亮的菜单名：dashboard / product / category / brand
--%>
<c:set var="ctx" value="${pageContext.request.contextPath}"/>
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${pageTitle} · 商品管理系统</title>
    <link rel="stylesheet" href="${ctx}/css/style.css">
</head>
<body>
<div class="layout">

    <aside class="sidebar">
        <div class="brand">
            <div class="logo">商</div>
            <div class="name">商品管理系统</div>
        </div>

        <nav class="nav">
            <div class="nav-title">概览</div>
            <c:if test="${can['dash:view']}">
                <a class="nav-item${active eq 'dashboard' ? ' active' : ''}"
                   href="${ctx}/dashboard">工作台</a>
            </c:if>

            <div class="nav-title">商品管理</div>
            <c:if test="${can['prod:list']}">
                <a class="nav-item${active eq 'product' ? ' active' : ''}"
                   href="${ctx}/product/list">商品列表</a>
            </c:if>
            <c:if test="${can['cat:list']}">
                <a class="nav-item${active eq 'category' ? ' active' : ''}"
                   href="${ctx}/category">分类管理</a>
            </c:if>
            <c:if test="${can['brand:list']}">
                <a class="nav-item${active eq 'brand' ? ' active' : ''}"
                   href="${ctx}/brand">品牌管理</a>
            </c:if>
        </nav>

        <div class="nav-foot">Tomcat 11 · Servlet 6.1</div>
    </aside>

    <div class="main">
        <header class="topbar">
            <div class="crumb">
                <span>首页</span>
                <span class="sep">/</span>
                <span class="cur">${pageTitle}</span>
            </div>

            <div class="userbox">
                <div class="avatar">${userInitial}</div>
                <span>${currentUser.name}</span>
                <span class="role-tag">${roleName}</span>
                <a class="btn btn-ghost btn-sm" href="${ctx}/mall" target="_blank">前台商城</a>
                <a class="btn btn-ghost btn-sm" href="${ctx}/logout">退出</a>
            </div>
        </header>

        <div class="content">
