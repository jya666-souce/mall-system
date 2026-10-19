<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%-- 商品详情。item 由 MallItemServlet 塞进来；查不到的话那边已经回 404 了，这里不用再判空 --%>
<c:set var="pageTitle" value="${item.name}"/>
<%@ include file="layout-head.jsp" %>

<div class="m-crumb">
    <a href="${ctx}/mall">首页</a>
    <span class="sep">/</span>
    <a href="${ctx}/mall?category=${item.category}">${item.category}</a>
    <span class="sep">/</span>
    <span>${item.name}</span>
</div>

<%@ include file="flash.jsp" %>

<div class="m-detail">

    <%-- 详情页大图。跟卡片一样：有图用图，没图退回首字色块。
         .m-detail .m-thumb 那条样式已经把高度定成 330px，
         这里只要多挂一个 m-thumb-img 把渐变背景换成图片就行。 --%>
    <c:choose>
        <c:when test="${not empty item.image}">
            <div class="m-thumb m-thumb-img">
                <img src="${ctx}/img?name=${item.image}" alt="${item.name}">
            </div>
        </c:when>
        <c:otherwise>
            <div class="m-thumb">${item.initial}</div>
        </c:otherwise>
    </c:choose>

    <div>
        <div class="m-detail-brand">${item.brand}</div>
        <h1>${item.name}</h1>

        <div class="m-detail-price">
            <div class="p"><i>¥</i>${item.priceText}</div>
            <div class="s">
                <c:choose>
                    <c:when test="${item.stock <= 0}">暂时缺货，正在补货中</c:when>
                    <c:when test="${item.stock < lowStockLine}">库存紧张，仅剩 ${item.stock} 件</c:when>
                    <c:otherwise>现货 ${item.stock} 件，下单后尽快发出</c:otherwise>
                </c:choose>
            </div>
        </div>

        <div class="m-attrs">
            <span class="k">分类</span><span>${item.category}</span>
            <span class="k">品牌</span><span>${item.brand}</span>
            <span class="k">商品编号</span><span>#${item.id}</span>
        </div>

        <form method="post" action="${ctx}/mall/cart/add">
            <input type="hidden" name="id" value="${item.id}">
            <%-- 加完留在本页。backUrl 是 layout-head 按「当前地址 + 查询串」算出来的，
                 在详情页正好等于 /mall/item?id=N --%>
            <input type="hidden" name="back" value="<c:out value='${backUrl}'/>">

            <div class="m-buy-row">
                <div class="m-qty">
                    <%-- max 给到库存：浏览器会顺手帮我们挡掉明显超量的输入。
                         但服务端照样要校验一次 —— 前端限制只是体验，不是安全。 --%>
                    <input type="number" name="qty" value="1" min="1"
                           max="${item.stock}" title="购买数量">
                </div>

                <button type="submit" class="m-btn m-btn-primary m-btn-lg"
                        ${item.stock <= 0 ? 'disabled' : ''}>加入购物车</button>

                <a class="m-btn m-btn-ghost m-btn-lg" href="${ctx}/mall/cart">去购物车结算</a>
            </div>
        </form>
    </div>
</div>

<c:if test="${not empty related}">
    <div class="m-section-title">同类商品</div>
    <div class="m-grid">
        <c:forEach var="it" items="${related}">
            <%@ include file="card.jsp" %>
        </c:forEach>
    </div>
</c:if>

<%@ include file="layout-foot.jsp" %>
