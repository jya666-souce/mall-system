<%@ page pageEncoding="UTF-8" %>
<%--
  前台骨架 · 下半部分
  只管把 main 收掉，再加上页脚。
--%>
</main>

<%-- 在线人数由 OnlineListener 维护在 ServletContext 里（启动时 AppListener 先放一个 0）。
     这里用 c:set 转一道，是防 EL 读到不存在的属性 —— 那会输出空字符串，
     页面就变成「当前  人在逛」，中间缺一块。
     本片段是被静态包含进来的，主页面声明的 c: 标签在这里能直接用。 --%>
<c:set var="onlineCount" value="${empty applicationScope.onlineCount ? 0 : applicationScope.onlineCount}"/>

<footer class="m-foot">
    <div class="m-wrap">
        优选商城 · 一个用 Servlet + JSP 手写的练习项目 · 前后台共用同一份数据
        <span class="m-online">当前 <b>${onlineCount}</b> 人在逛</span>
    </div>
</footer>

</body>
</html>
