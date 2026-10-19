<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%--
  确认订单
  左边填收货信息 + 看商品清单，右边是金额汇总和提交按钮。

  这个页面的 error 提示走 request 属性（${err}）而不是 flash ——
  因为下单失败时用的是 forward 而不是 redirect：
  redirect 会把表单里刚填的收货信息丢掉，用户得重打一遍。
  「失败要 forward、成功才 redirect」是个好用的判断口诀。
--%>
<c:set var="pageTitle" value="确认订单"/>
<%@ include file="layout-head.jsp" %>

<div class="m-crumb">
    <a href="${ctx}/mall">首页</a>
    <span class="sep">/</span>
    <a href="${ctx}/mall/cart">购物车</a>
    <span class="sep">/</span>
    <span>确认订单</span>
</div>

<c:if test="${not empty err}">
    <div class="m-flash m-flash-err">${err}</div>
</c:if>

<form method="post" action="${ctx}/mall/order/checkout">
    <div class="m-checkout">

        <div>
            <%-- 收货信息：三个必填，服务端还会再校验一遍（见 DataStore.placeOrder） --%>
            <div class="m-panel">
                <div class="m-panel-head">收货信息</div>
                <div class="m-panel-body">
                    <div class="m-form-row">
                        <label>收货人 <span class="req">*</span></label>
                        <input type="text" name="receiver" value="${receiver}"
                               placeholder="请填写收货人姓名" autocomplete="off">
                    </div>

                    <div class="m-form-row">
                        <label>联系电话 <span class="req">*</span></label>
                        <input type="text" name="phone" value="${phone}"
                               placeholder="请填写手机号" autocomplete="off">
                    </div>

                    <div class="m-form-row">
                        <label>收货地址 <span class="req">*</span></label>
                        <textarea name="address" rows="3"
                                  placeholder="例如：安徽省芜湖市湾沚区新芜校区 3 号宿舍楼">${address}</textarea>
                    </div>

                    <div class="m-form-row" style="margin-bottom:0">
                        <label>下单人</label>
                        <%-- disabled 的输入框不会被提交，这里本来就只是给人看的 --%>
                        <input type="text" value="${currentUser.name}（${currentUser.username}）" disabled>
                    </div>
                </div>
            </div>

            <div class="m-panel">
                <div class="m-panel-head">商品清单</div>
                <%-- 跟购物车那张表同样的道理，只是少一列、不带走操作按钮，
                     所以手机端用的是另一套摆位（m-tbl-mini）。 --%>
                <table class="m-tbl m-tbl-mini">
                    <thead>
                    <tr>
                        <th>商品</th>
                        <th>单价</th>
                        <th class="num">数量</th>
                        <th class="num">小计</th>
                    </tr>
                    </thead>
                    <tbody>
                    <c:forEach var="l" items="${lines}">
                        <tr>
                            <td>
                                <div class="m-goods">
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
                                        ${l.name}
                                        <div class="m-meta" style="margin:2px 0 0">${l.brand}</div>
                                    </div>
                                </div>
                            </td>
                            <td class="m-muted">¥${l.priceText}</td>
                            <td class="num">× ${l.qty}</td>
                            <td class="subtotal">¥${l.subtotalText}</td>
                        </tr>
                    </c:forEach>
                    </tbody>
                </table>
            </div>
        </div>

        <div class="m-panel">
            <div class="m-panel-head">订单汇总</div>
            <div class="m-panel-body">
                <c:forEach var="l" items="${lines}">
                    <div class="m-summary-line">
                        <span>${l.name} × ${l.qty}</span>
                        <span class="v">¥${l.subtotalText}</span>
                    </div>
                </c:forEach>

                <div class="m-summary-total">
                    <span>应付合计</span>
                    <b>¥${cartTotal}</b>
                </div>

                <div style="margin-top:16px">
                    <button type="submit" class="m-btn m-btn-primary m-btn-lg m-btn-block"
                            ${cartProblem ? 'disabled' : ''}>提交订单</button>

                    <a class="m-btn m-btn-ghost m-btn-block" style="margin-top:9px"
                       href="${ctx}/mall/cart">返回购物车</a>
                </div>

                <div class="m-meta" style="margin-top:11px;text-align:center;line-height:1.6">
                    提交后库存立即扣减<br>订单状态可以在「我的订单」里查看
                </div>
            </div>
        </div>

    </div>
</form>

<%@ include file="layout-foot.jsp" %>
