<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<c:set var="pageTitle" value="商品列表"/>
<c:set var="active" value="product"/>
<%@ include file="/WEB-INF/views/common/layout-head.jsp" %>

<div class="page-head">
    <div>
        <h1>商品列表</h1>
        <p class="desc">共 ${page.total} 件商品，当前第 ${page.page} / ${page.totalPages} 页</p>
    </div>
    <c:if test="${can['prod:add']}">
        <a class="btn btn-primary" href="${ctx}/product/add">+ 新增商品</a>
    </c:if>
</div>

<%@ include file="/WEB-INF/views/common/flash.jsp" %>

<div class="card">
    <div class="card-head">
        <h2>筛选条件</h2>
        <a class="btn btn-ghost btn-sm" href="${ctx}/product/list">重置</a>
    </div>
    <div class="card-body">
        <form class="filters" method="get" action="${ctx}/product/list">
            <div class="f wide">
                <label>关键字</label>
                <input type="text" name="keyword" value="${keyword}"
                       placeholder="名称 / 分类 / 品牌">
            </div>

            <div class="f">
                <label>分类</label>
                <select name="category">
                    <option value="">全部</option>
                    <c:forEach var="cn" items="${catOptions}">
                        <option value="${cn}"${cn eq category ? ' selected' : ''}>${cn}</option>
                    </c:forEach>
                </select>
            </div>

            <div class="f">
                <label>品牌</label>
                <select name="brand">
                    <option value="">全部</option>
                    <c:forEach var="bn" items="${brandOptions}">
                        <option value="<c:out value='${bn}'/>"${bn eq brand ? ' selected' : ''}><c:out value="${bn}"/></option>
                    </c:forEach>
                </select>
            </div>

            <div class="f">
                <label>价格下限</label>
                <input type="text" name="minPrice" value="${minPrice}" placeholder="0">
            </div>

            <div class="f">
                <label>价格上限</label>
                <input type="text" name="maxPrice" value="${maxPrice}" placeholder="不限">
            </div>

            <div class="f">
                <label>排序</label>
                <select name="sort">
                    <option value=""${empty sort ? ' selected' : ''}>默认（按编号）</option>
                    <option value="priceDesc"${sort eq 'priceDesc' ? ' selected' : ''}>价格从高到低</option>
                    <option value="priceAsc"${sort eq 'priceAsc' ? ' selected' : ''}>价格从低到高</option>
                    <option value="stockDesc"${sort eq 'stockDesc' ? ' selected' : ''}>库存从多到少</option>
                </select>
            </div>

            <button type="submit" class="btn btn-primary">查询</button>
        </form>
    </div>
</div>

<%-- 批量删除用的空表单：下面的复选框靠 form="bulkForm" 属性挂到它上面，
     这样表格本身不用被 form 包起来（HTML 里 form 不能套 form，
     而行内的单个删除也需要自己的 form）。
     表单本身也要跟着权限走 —— 没有删除权限的人，页面上连这个 form 都不该出现，
     否则查看源码就看到一个自己用不了的接口地址。 --%>
<c:if test="${can['prod:del']}">
    <form id="bulkForm" method="post" action="${ctx}/product/delete"></form>
</c:if>

<div class="card">
    <div class="card-head">
        <h2>商品数据</h2>
        <div style="display:flex;align-items:center;gap:10px">
            <span style="font-size:12.5px;color:#94a3b8">
                显示第 ${page.from}-${page.to} 条，共 ${page.total} 条
            </span>
            <c:if test="${can['prod:del']}">
                <button form="bulkForm" class="btn btn-danger btn-sm"
                        onclick="return confirm('确定删除勾选的所有商品吗？')">批量删除</button>
            </c:if>
        </div>
    </div>

    <c:choose>
        <c:when test="${empty page.rows}">
            <div class="empty">没有符合条件的商品，换个筛选条件试试</div>
        </c:when>
        <c:otherwise>
            <table class="tbl">
                <thead>
                <tr>
                    <c:if test="${can['prod:del']}">
                        <th class="col-check">
                            <input type="checkbox" title="全选" onclick="toggleAll(this)">
                        </th>
                    </c:if>
                    <th class="col-img">图片</th>
                    <th>编号</th>
                    <th>名称</th>
                    <th>分类</th>
                    <th>品牌</th>
                    <th class="num">单价</th>
                    <th class="num">库存</th>
                    <th>状态</th>
                    <th class="col-act">操作</th>
                </tr>
                </thead>
                <tbody>
                <c:forEach var="it" items="${page.rows}">
                    <tr>
                        <c:if test="${can['prod:del']}">
                            <td><input form="bulkForm" type="checkbox" name="id" value="${it.id}"></td>
                        </c:if>
                        <td>
                            <%-- 缩略图。没传图的商品显示一个带首字的灰底小块 ——
                                 表格里最忌讳出现空洞，一行少一块看着像页面坏了。 --%>
                            <c:choose>
                                <c:when test="${not empty it.image}">
                                    <img class="thumb" src="${ctx}/img?name=${it.image}"
                                         alt="${it.name}">
                                </c:when>
                                <c:otherwise>
                                    <span class="thumb thumb-none">${it.initial}</span>
                                </c:otherwise>
                            </c:choose>
                        </td>
                        <td class="muted">${it.id}</td>
                        <td>${it.name}</td>
                        <td><c:out value="${it.category}"/></td>
                        <td><c:out value="${it.brand}"/></td>
                        <td class="num price">¥${it.priceText}</td>
                        <td class="num">${it.stock}</td>
                        <td>
                            <c:choose>
                                <c:when test="${it.stock lt 10}">
                                    <span class="badge badge-danger">严重不足</span>
                                </c:when>
                                <c:when test="${it.stock lt lowStockLine}">
                                    <span class="badge badge-warn">需要补货</span>
                                </c:when>
                                <c:otherwise>
                                    <span class="badge badge-ok">充足</span>
                                </c:otherwise>
                            </c:choose>
                        </td>
                        <td class="col-act">
                            <div class="row-actions">
                                <c:if test="${can['prod:upd']}">
                                    <a class="btn btn-ghost btn-sm"
                                       href="${ctx}/product/edit?id=${it.id}">编辑</a>
                                </c:if>
                                <c:if test="${can['prod:del']}">
                                    <form method="post" action="${ctx}/product/delete"
                                          style="display:inline">
                                        <input type="hidden" name="id" value="${it.id}">
                                        <button class="btn btn-danger btn-sm"
                                                onclick="return confirm('确定删除这条商品吗？')">删除</button>
                                    </form>
                                </c:if>
                                <c:if test="${not can['prod:upd'] and not can['prod:del']}">
                                    <span style="font-size:12.5px;color:#cbd5e1">只读</span>
                                </c:if>
                            </div>
                        </td>
                    </tr>
                </c:forEach>
                </tbody>
            </table>
        </c:otherwise>
    </c:choose>
</div>

<c:if test="${page.total > 0}">
    <div class="pager">
        <c:choose>
            <c:when test="${page.hasPrev}">
                <c:url var="prevUrl" value="/product/list">
                    <c:param name="keyword" value="${keyword}"/>
                    <c:param name="category" value="${category}"/>
                    <c:param name="brand" value="${brand}"/>
                    <c:param name="minPrice" value="${minPrice}"/>
                    <c:param name="maxPrice" value="${maxPrice}"/>
                    <c:param name="sort" value="${sort}"/>
                    <c:param name="page" value="${page.prevPage}"/>
                </c:url>
                <a href="${prevUrl}">上一页</a>
            </c:when>
            <c:otherwise>
                <span class="off">上一页</span>
            </c:otherwise>
        </c:choose>

        <c:forEach var="n" items="${page.pageNumbers}">
            <c:choose>
                <c:when test="${n eq page.page}">
                    <span class="cur">${n}</span>
                </c:when>
                <c:otherwise>
                    <c:url var="nUrl" value="/product/list">
                        <c:param name="keyword" value="${keyword}"/>
                        <c:param name="category" value="${category}"/>
                        <c:param name="brand" value="${brand}"/>
                        <c:param name="minPrice" value="${minPrice}"/>
                        <c:param name="maxPrice" value="${maxPrice}"/>
                        <c:param name="sort" value="${sort}"/>
                        <c:param name="page" value="${n}"/>
                    </c:url>
                    <a href="${nUrl}">${n}</a>
                </c:otherwise>
            </c:choose>
        </c:forEach>

        <c:choose>
            <c:when test="${page.hasNext}">
                <c:url var="nextUrl" value="/product/list">
                    <c:param name="keyword" value="${keyword}"/>
                    <c:param name="category" value="${category}"/>
                    <c:param name="brand" value="${brand}"/>
                    <c:param name="minPrice" value="${minPrice}"/>
                    <c:param name="maxPrice" value="${maxPrice}"/>
                    <c:param name="sort" value="${sort}"/>
                    <c:param name="page" value="${page.nextPage}"/>
                </c:url>
                <a href="${nextUrl}">下一页</a>
            </c:when>
            <c:otherwise>
                <span class="off">下一页</span>
            </c:otherwise>
        </c:choose>

        <span class="info">第 ${page.page} / ${page.totalPages} 页</span>
    </div>
</c:if>

<script>
    function toggleAll(box) {
        var list = document.querySelectorAll('input[name="id"][form="bulkForm"]');
        for (var i = 0; i < list.length; i++) {
            list[i].checked = box.checked;
        }
    }
</script>

<%@ include file="/WEB-INF/views/common/layout-foot.jsp" %>
