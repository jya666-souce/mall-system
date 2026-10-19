<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<c:set var="pageTitle" value="工作台"/>
<c:set var="active" value="dashboard"/>
<%@ include file="/WEB-INF/views/common/layout-head.jsp" %>

<div class="page-head">
    <div>
        <h1>工作台</h1>
        <p class="desc">商品数据的整体概览，数字实时来自 DataStore</p>
    </div>
</div>

<div class="stat-grid">
    <div class="stat accent">
        <div class="label">商品总数</div>
        <div class="value">${itemCount}</div>
        <div class="sub">在售 SKU</div>
    </div>
    <div class="stat">
        <div class="label">分类数</div>
        <div class="value">${categoryCount}</div>
        <div class="sub">个分类</div>
    </div>
    <div class="stat">
        <div class="label">品牌数</div>
        <div class="value">${brandCount}</div>
        <div class="sub">个品牌</div>
    </div>
    <div class="stat">
        <div class="label">库存总量</div>
        <div class="value">${totalStock}</div>
        <div class="sub">件</div>
    </div>
    <div class="stat warn">
        <div class="label">库存总价值</div>
        <div class="value">¥${totalValueText}</div>
        <div class="sub">单价 × 库存 累加</div>
    </div>
</div>

<div class="two-col">

    <div class="card">
        <div class="card-head">
            <h2>分类分布</h2>
            <span class="badge badge-gray">${categoryCount} 个分类</span>
        </div>
        <div class="card-body">
            <c:forEach var="s" items="${catStats}">
                <div class="bar-row">
                    <div class="bar-name">${s.name}</div>
                    <div class="bar-track">
                        <div class="bar-fill" style="width:${s.percent}%"></div>
                    </div>
                    <div class="bar-num">${s.count}</div>
                </div>
            </c:forEach>
        </div>
    </div>

    <div class="card">
        <div class="card-head">
            <h2>品牌分布</h2>
            <span class="badge badge-gray">${brandCount} 个品牌</span>
        </div>
        <div class="card-body">
            <c:forEach var="s" items="${brandStats}">
                <div class="bar-row">
                    <div class="bar-name">${s.name}</div>
                    <div class="bar-track">
                        <div class="bar-fill" style="width:${s.percent}%"></div>
                    </div>
                    <div class="bar-num">${s.count}</div>
                </div>
            </c:forEach>
        </div>
    </div>

</div>

<div class="card">
    <div class="card-head">
        <h2>库存预警</h2>
        <span class="badge badge-warn">库存低于 ${lowStockLine} 件</span>
    </div>

    <c:choose>
        <c:when test="${empty lowStock}">
            <div class="empty">没有库存告急的商品</div>
        </c:when>
        <c:otherwise>
            <table class="tbl">
                <thead>
                <tr>
                    <th>编号</th>
                    <th>名称</th>
                    <th>分类</th>
                    <th>品牌</th>
                    <th class="num">单价</th>
                    <th class="num">库存</th>
                    <th>状态</th>
                </tr>
                </thead>
                <tbody>
                <c:forEach var="it" items="${lowStock}">
                    <tr>
                        <td class="muted">${it.id}</td>
                        <td>${it.name}</td>
                        <td>${it.category}</td>
                        <td>${it.brand}</td>
                        <td class="num price">¥${it.priceText}</td>
                        <td class="num">${it.stock}</td>
                        <td>
                            <c:choose>
                                <c:when test="${it.stock lt 10}">
                                    <span class="badge badge-danger">严重不足</span>
                                </c:when>
                                <c:otherwise>
                                    <span class="badge badge-warn">需要补货</span>
                                </c:otherwise>
                            </c:choose>
                        </td>
                    </tr>
                </c:forEach>
                </tbody>
            </table>
        </c:otherwise>
    </c:choose>
</div>

<%@ include file="/WEB-INF/views/common/layout-foot.jsp" %>
