<%@ page contentType="text/html;charset=UTF-8" pageEncoding="UTF-8" %>
<%--
  应用根路径：什么都不显示，直接把顾客送进前台商城。
  访问 http://localhost:8080/shop/ 会走到这里。

  以前这里转的是 /dashboard（后台工作台）—— 那会儿这个应用只有后台一张脸。
  现在商城是对外的门面，根路径当然该把人送到商城；后台还在 /dashboard，
  商城顶栏也有「后台管理」的入口。

  这不是「页面跳转」，是服务端发一个 302 让浏览器再请求一次。
  登录校验和权限判断都在 AuthFilter 里 —— 不过 / 和 /mall 都是放行的，
  这里不用管。

  顺带一提：这个文件放在 webapp 根目录，所以浏览器能直接访问到它；
  而放在 WEB-INF/views/ 下的页面浏览器是够不着的，只能由 Servlet 转发过去。
--%>
<% response.sendRedirect(request.getContextPath() + "/mall"); %>
