<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%--
  我的订单
  只显示当前登录用户自己的单 —— 过滤在 OrderServlet 里做（store.ordersOf(userId)），
  不是在这边筛。数据该在哪一层过滤是有讲究的：
  放到页面上筛，等于把所有订单都取回来了，一旦哪天忘了筛，别人的单就露出来了。
--%>
<c:set var="pageTitle" value="我的订单"/>
<%@ include file="layout-head.jsp" %>

<div class="m-crumb">
    <a href="${ctx}/mall">首页</a>
    <span class="sep">/</span>
    <span>我的订单</span>
</div>

<%@ include file="flash.jsp" %>

<c:choose>

    <c:when test="${empty orders}">
        <div class="m-empty">
            <span class="big">📦</span>
            还没有订单
            <br>
            <a class="m-btn m-btn-primary" href="${ctx}/mall">去逛逛</a>
        </div>
    </c:when>

    <c:otherwise>
        <c:forEach var="o" items="${orders}">
            <div class="m-order">

                <div class="m-order-head">
                    <div>
                        订单号 <span class="m-order-no">${o.orderNo}</span>
                        <span class="m-muted" style="margin-left:12px">${o.createTime}</span>
                    </div>
                    <span class="m-status ${o.statusClass}">${o.status}</span>
                </div>

                <div class="m-order-lines">
                    <c:forEach var="oi" items="${o.items}">
                        <div class="m-order-line">
                            <span>${oi.name}</span>
                            <%-- 这里显示的是下单那一刻的价格快照，不是商品现在的价钱。
                                 后台改过价，老订单金额也不会跟着变。 --%>
                            <span class="r">¥${oi.priceText} × ${oi.qty} = ¥${oi.subtotalText}</span>
                        </div>
                    </c:forEach>
                </div>

                <div class="m-order-foot">
                    <div class="t">
                        收货人 ${o.receiver} · ${o.phone}
                        <br>
                        <span class="m-muted">${o.address}</span>
                    </div>

                    <div style="display:flex;align-items:center;gap:13px">
                        <span class="t">共 ${o.itemCount} 件 · 合计 <b>¥${o.totalText}</b></span>

                        <%-- 只有「待发货」才给取消按钮（isCancelable 判断逻辑在 Order 里） --%>
                        <c:if test="${o.cancelable}">
                            <form method="post" action="${ctx}/mall/order/cancel"
                                  onsubmit="return confirm('确定取消这张订单吗？库存会退回。')">
                                <input type="hidden" name="id" value="${o.id}">
                                <button type="submit" class="m-btn m-btn-ghost m-btn-sm">取消订单</button>
                            </form>
                        </c:if>
                    </div>
                </div>

            </div>
        </c:forEach>
    </c:otherwise>
</c:choose>

<%@ include file="layout-foot.jsp" %>
