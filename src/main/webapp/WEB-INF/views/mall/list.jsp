<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%@ taglib prefix="c" uri="jakarta.tags.core" %>
<%--
  前台首页 = 商品墙
  搜索、筛选、排序、分页全部靠 GET 参数，Servlet 那边一一对应。
  和后台 /product/list 是同一套 DataStore.query，只是换了张脸。
--%>
<c:set var="pageTitle" value="全部商品"/>
<%@ include file="layout-head.jsp" %>

<div class="m-crumb">
    <a href="${ctx}/mall">首页</a>
    <span class="sep">/</span>
    <span>全部商品</span>
</div>

<%@ include file="flash.jsp" %>

<%-- 手机端的筛选折叠开关。
     这用的是「checkbox hack」：一个看不见的勾选框 + 一个 label，
     点 label 等于点勾选框，CSS 再用 :checked 决定筛选条显不显示 ——
     全程不需要一行 JavaScript。

     ⚠️ 这个 input 和下面的 .m-filters 必须是**彼此相邻的兄弟元素**
     （中间可以隔东西，但不能跨层），因为 CSS 那边靠 `~` 兄弟选择器找它。
     以后要在这附近包一层 div，记得把这两个一起挪进去。

     默认展开还是收起：如果地址栏里已经带了筛选条件，就默认展开，
     让用户一眼看见「我筛过什么」，不然他会以为商品就这么少。
     用一个 EL 三元表达式判断，真值时输出 checked 这个属性名。 --%>
<input type="checkbox" id="mFilterToggle" class="m-filter-toggle" hidden
       ${(not empty keyword or not empty category or not empty brand
          or not empty minPrice or not empty maxPrice or not empty sort) ? 'checked' : ''}>
<label class="m-filter-bar" for="mFilterToggle">
    <span>筛选 / 排序</span>
    <span class="m-filter-arrow">▾</span>
</label>

<%-- 筛选条。
     注意这些控件全在一个 <form> 里，一起 GET 提交 ——
     这样浏览器地址栏会带上全部条件，用户可以直接收藏或分享这一屏结果。 --%>
<form class="m-filters" method="get" action="${ctx}/mall">
    <div class="f wide">
        <label>关键字</label>
        <input type="text" name="keyword" value="${keyword}" placeholder="商品名 / 分类 / 品牌">
    </div>

    <div class="f">
        <label>分类</label>
        <select name="category">
            <option value="">全部</option>
            <c:forEach var="c" items="${catOptions}">
                <option value="${c}" ${c eq category ? 'selected' : ''}>${c}</option>
            </c:forEach>
        </select>
    </div>

    <div class="f">
        <label>品牌</label>
        <select name="brand">
            <option value="">全部</option>
            <c:forEach var="b" items="${brandOptions}">
                <option value="${b}" ${b eq brand ? 'selected' : ''}>${b}</option>
            </c:forEach>
        </select>
    </div>

    <div class="f mid">
        <label>价格下限</label>
        <input type="number" name="minPrice" value="${minPrice}" min="0" placeholder="不限">
    </div>
    <div class="f mid">
        <label>价格上限</label>
        <input type="number" name="maxPrice" value="${maxPrice}" min="0" placeholder="不限">
    </div>

    <div class="f">
        <label>排序</label>
        <select name="sort">
            <option value="" ${empty sort ? 'selected' : ''}>默认</option>
            <option value="priceAsc" ${sort eq 'priceAsc' ? 'selected' : ''}>价格从低到高</option>
            <option value="priceDesc" ${sort eq 'priceDesc' ? 'selected' : ''}>价格从高到低</option>
            <option value="stockDesc" ${sort eq 'stockDesc' ? 'selected' : ''}>库存多的在前</option>
        </select>
    </div>

    <button type="submit" class="m-btn m-btn-primary">筛选</button>
    <a class="m-btn m-btn-ghost" href="${ctx}/mall">重置</a>
</form>

<c:choose>
    <c:when test="${page.total > 0}">

        <div class="m-grid">
            <c:forEach var="it" items="${page.rows}">
                <%@ include file="card.jsp" %>
            </c:forEach>
        </div>

        <%-- 分页。
             先把「除页码以外的全部筛选条件」拼成一个带 ? 的基地址，
             后面每个页码链接只要 &page=N 就行 —— 不用把 6 个 c:param 抄三遍。
             用 c:url 而不是手拼字符串，是因为它会把中文关键字自动做 URL 编码。 --%>
        <c:if test="${page.totalPages > 1}">
            <c:url var="baseUrl" value="/mall">
                <c:param name="keyword" value="${keyword}"/>
                <c:param name="category" value="${category}"/>
                <c:param name="brand" value="${brand}"/>
                <c:param name="minPrice" value="${minPrice}"/>
                <c:param name="maxPrice" value="${maxPrice}"/>
                <c:param name="sort" value="${sort}"/>
            </c:url>

            <div class="m-pager">
                <c:choose>
                    <c:when test="${page.hasPrev}">
                        <a href="${baseUrl}&page=${page.prevPage}">上一页</a>
                    </c:when>
                    <c:otherwise>
                        <span class="off">上一页</span>
                    </c:otherwise>
                </c:choose>

                <c:forEach var="p" items="${page.pageNumbers}">
                    <c:choose>
                        <c:when test="${p eq page.page}">
                            <span class="cur">${p}</span>
                        </c:when>
                        <c:otherwise>
                            <a href="${baseUrl}&page=${p}">${p}</a>
                        </c:otherwise>
                    </c:choose>
                </c:forEach>

                <c:choose>
                    <c:when test="${page.hasNext}">
                        <a href="${baseUrl}&page=${page.nextPage}">下一页</a>
                    </c:when>
                    <c:otherwise>
                        <span class="off">下一页</span>
                    </c:otherwise>
                </c:choose>

                <span class="info">共 ${page.total} 件 · 第 ${page.page}/${page.totalPages} 页</span>
            </div>
        </c:if>

    </c:when>
    <c:otherwise>
        <div class="m-empty">
            <span class="big">🔍</span>
            没有找到符合条件的商品
            <br>
            <a class="m-btn m-btn-ghost" href="${ctx}/mall">看看全部商品</a>
        </div>
    </c:otherwise>
</c:choose>

<%@ include file="layout-foot.jsp" %>
