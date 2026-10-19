<%@ page pageEncoding="UTF-8" %>
<%--
  前台的一次性提示条
  和后台那份逻辑一样，只是换了套配色 —— 前台是红色系。
  两个 flash 值由 Flash.take(req) 从 session 搬到 request，取完就没，
  所以刷新页面不会重复弹出。
--%>
<c:if test="${not empty flashOk}">
    <div class="m-flash m-flash-ok">${flashOk}</div>
</c:if>
<c:if test="${not empty flashErr}">
    <div class="m-flash m-flash-err">${flashErr}</div>
</c:if>
