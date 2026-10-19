<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%--
  购物车
  三个状态要分清：
    ① 空车            → 直接给个「去逛逛」
    ② 有失效行        → 明确点出是哪几件，并且不给结算
    ③ 一切正常        → 才能点「去结算」
  第 ② 种是很多人会漏的：商品被后台删了、或者顾客加购之后库存被别人买走了，
  这时候如果不提示，顾客会一路点到提交订单才被打回来，体验很差。
--%>
<c:set var="pageTitle" value="购物车"/>
<%@ include file="layout-head.jsp" %>

<div class="m-crumb">
    <a href="${ctx}/mall">首页</a>
    <span class="sep">/</span>
    <span>购物车</span>
</div>

<%@ include file="flash.jsp" %>

<c:choose>

    <%-- ① 空车 --%>
    <c:when test="${empty lines}">
        <div class="m-empty">
            <span class="big">🛒</span>
            购物车还是空的
            <br>
            <a class="m-btn m-btn-primary" href="${ctx}/mall">去逛逛</a>
        </div>
    </c:when>

    <%-- ②③ 有东西 --%>
    <c:otherwise>

        <c:if test="${cartProblem}">
            <div class="m-warn-box">
                有 ${badCount} 件商品已经下架、或者数量超过了当前库存，请先处理掉它们再结算。
            </div>
        </c:if>

        <div class="m-panel">
            <div class="m-panel-head">
                <span>我的购物车（共 ${cartCount} 件）</span>
                <form method="post" action="${ctx}/mall/cart/clear">
                    <button type="submit" class="m-btn m-btn-ghost m-btn-sm">清空购物车</button>
                </form>
            </div>

            <%-- 那个 m-tbl-cart 是给手机端准备的：
                 窄屏下 mall.css 会把这张表的每一行摊成一张小卡片
                 （隐藏表头、td 变块级、grid 摆位），
                 不然表格的最小内容宽度 418px 会被 .m-panel 的
                 overflow: hidden 静默裁掉最右边的「操作」列。 --%>
            <table class="m-tbl m-tbl-cart">
                <thead>
                <tr>
                    <th>商品</th>
                    <th>单价</th>
                    <th>数量</th>
                    <th class="num">小计</th>
                    <th class="col-act">操作</th>
                </tr>
                </thead>
                <tbody>
                <c:forEach var="l" items="${lines}">
                    <tr>
                        <td>
                            <div class="m-goods">
                                <%-- l.image 是 CartLine 上的便利属性，不是 l.item.image ——
                                     商品被后台删掉时 item 是 null，
                                     CartLine 那一侧把判空收掉了，页面才能写这么一句。 --%>
                                <c:choose>
                                    <c:when test="${not empty l.image}">
                                        <div class="m-mini m-mini-img">
                                            <img src="${ctx}/img?name=${l.image}" alt="${l.name}">
                                        </div>
                                    </c:when>
                                    <c:otherwise>
                                        <div class="m-mini">${l.initial}</div>
                                    </c:otherwise>
                                </c:choose>
                                <div>
                                    <c:choose>
                                        <c:when test="${l.missing}">
                                            <span class="m-muted">${l.name}</span>
                                        </c:when>
                                        <c:otherwise>
                                            <a href="${ctx}/mall/item?id=${l.itemId}">${l.name}</a>
                                        </c:otherwise>
                                    </c:choose>
                                    <div class="m-meta" style="margin:2px 0 0">${l.brand} · ${l.category}</div>
                                </div>
                            </div>
                        </td>

                        <td class="m-muted">
                            <c:if test="${not l.missing}">¥${l.priceText}</c:if>
                        </td>

                        <td>
                            <%-- 数量改动直接提交。改完 PRG 回到本页，
                                 不留在浏览器历史里堆一堆「改数量」的记录。 --%>
                            <form method="post" action="${ctx}/mall/cart/set" class="m-qty-inline">
                                <input type="hidden" name="id" value="${l.itemId}">
                                <input type="number" name="qty" value="${l.qty}" min="0"
                                       title="改成 0 就是删掉这一行"
                                       onchange="this.form.submit()">
                            </form>
                            <c:if test="${l.overStock}">
                                <div class="m-bad">库存只剩 ${l.item.stock} 件</div>
                            </c:if>
                        </td>

                        <td class="subtotal">¥${l.subtotalText}</td>

                        <td class="col-act">
                            <form method="post" action="${ctx}/mall/cart/remove">
                                <input type="hidden" name="id" value="${l.itemId}">
                                <button type="submit" class="m-btn m-btn-ghost m-btn-sm">删除</button>
                            </form>
                        </td>
                    </tr>
                </c:forEach>
                </tbody>
            </table>

            <div class="m-total-bar">
                <div class="t">合计（不含运费）：<b>¥${cartTotal}</b></div>
                <div style="display:flex;gap:9px">
                    <a class="m-btn m-btn-ghost" href="${ctx}/mall">继续挑选</a>
                    <c:choose>
                        <c:when test="${cartProblem}">
                            <%-- 有失效行就不让走：与其让他结算时被打回来，不如现在拦住 --%>
                            <button class="m-btn m-btn-primary" disabled>去结算</button>
                        </c:when>
                        <c:otherwise>
                            <a class="m-btn m-btn-primary" href="${ctx}/mall/order/checkout">去结算</a>
                        </c:otherwise>
                    </c:choose>
                </div>
            </div>
        </div>

    </c:otherwise>
</c:choose>

<%@ include file="layout-foot.jsp" %>
