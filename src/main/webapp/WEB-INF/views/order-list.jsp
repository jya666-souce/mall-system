<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%--
  后台 · 订单管理
  顾客在前台下的单会实时出现在这里 —— 内存版的好处是不用等，存进去就查得到。

  状态按钮的出现与否由 Order 里的 isShippable/isCompletable/isCancelable 决定，
  这里不重复写「status 等于待发货」这种判断 ——
  状态机只有一份定义，改规则时不会漏掉某个页面。
--%>
<c:set var="pageTitle" value="订单管理"/>
<c:set var="active" value="order"/>
<%@ include file="common/layout-head.jsp" %>

<div class="page-head">
    <div>
        <h1>订单管理</h1>
        <p class="desc">前台顾客下单后会实时出现在这里，一共 ${countAll} 张订单</p>
    </div>
</div>

<%@ include file="common/flash.jsp" %>

<%-- 状态筛选：数字直接标在标签上，一眼看出哪堆单最多 --%>
<div class="card">
    <div class="card-body tight" style="display:flex;flex-wrap:wrap;gap:8px;align-items:center">
        <a class="btn btn-sm ${empty status ? 'btn-primary' : 'btn-ghost'}" href="${ctx}/order">
            全部 ${countAll}
        </a>
        <c:forEach var="s" items="${statusOptions}">
            <c:url var="sUrl" value="/order">
                <c:param name="status" value="${s}"/>
            </c:url>
            <a class="btn btn-sm ${status eq s ? 'btn-primary' : 'btn-ghost'}" href="${sUrl}">
                ${s} ${byStatus[s]}
            </a>
        </c:forEach>
    </div>
</div>

<c:choose>

    <c:when test="${empty orders}">
        <div class="card">
            <div class="empty">这里还没有订单</div>
        </div>
    </c:when>

    <c:otherwise>
        <c:forEach var="o" items="${orders}">
            <div class="card">

                <div class="card-head">
                    <h2>
                        订单 ${o.orderNo}
                        <span class="badge badge-${o.statusClass}" style="margin-left:8px">${o.status}</span>
                    </h2>
                    <span style="font-size:12.5px;color:#94a3b8">${o.createTime}</span>
                </div>

                <table class="tbl">
                    <thead>
                    <tr>
                        <th>商品</th>
                        <th class="num">单价</th>
                        <th class="num">数量</th>
                        <th class="num">小计</th>
                    </tr>
                    </thead>
                    <tbody>
                    <c:forEach var="oi" items="${o.items}">
                        <tr>
                            <td>${oi.name}</td>
                            <%-- 显示的是下单时的价格快照，不是商品现在的价钱 --%>
                            <td class="num muted">¥${oi.priceText}</td>
                            <td class="num">${oi.qty}</td>
                            <td class="num">¥${oi.subtotalText}</td>
                        </tr>
                    </c:forEach>
                    </tbody>
                </table>

                <div class="card-body"
                     style="display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap;border-top:1px solid #eef2f7">
                    <div style="font-size:12.5px;color:#64748b;line-height:1.8">
                        下单人 <b>${o.username}</b> ｜ 收货 ${o.receiver} · ${o.phone}
                        <br>
                        ${o.address}
                    </div>

                    <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap">
                        <span style="font-size:13px">
                            共 ${o.itemCount} 件 · 合计
                            <b style="color:#dc2626;font-size:16px">¥${o.totalText}</b>
                        </span>

                        <%-- 只读角色（普通用户）看得到这一页，但看不到处理按钮 --%>
                        <c:if test="${can['order:upd']}">

                            <c:if test="${o.shippable}">
                                <form method="post" action="${ctx}/order/status">
                                    <input type="hidden" name="id" value="${o.id}">
                                    <input type="hidden" name="status" value="已发货">
                                    <button type="submit" class="btn btn-primary btn-sm">发货</button>
                                </form>
                            </c:if>

                            <c:if test="${o.completable}">
                                <form method="post" action="${ctx}/order/status">
                                    <input type="hidden" name="id" value="${o.id}">
                                    <input type="hidden" name="status" value="已完成">
                                    <button type="submit" class="btn btn-ghost btn-sm">标记完成</button>
                                </form>
                            </c:if>

                            <c:if test="${o.cancelable}">
                                <form method="post" action="${ctx}/order/status"
                                      onsubmit="return confirm('取消后这单的库存会退回，确定吗？')">
                                    <input type="hidden" name="id" value="${o.id}">
                                    <input type="hidden" name="status" value="已取消">
                                    <button type="submit" class="btn btn-danger btn-sm">取消</button>
                                </form>
                            </c:if>

                        </c:if>
                    </div>
                </div>

            </div>
        </c:forEach>
    </c:otherwise>
</c:choose>

<%@ include file="common/layout-foot.jsp" %>
