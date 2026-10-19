package com.cn.web;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

import java.io.IOException;

/**
 * 退出登录
 *
 * 核心就一句：session.invalidate()
 * 把服务端那份 session 数据（里面存着 user）整个作废。
 * 下次请求带着旧 Cookie 过来，服务端找不到对应 session，
 * 就当成没登录的人处理。
 *
 * 顺带一件事：购物车也存在 session 里，所以退出 = 购物车一起清空。
 * 这是合理的 —— 购物车跟着账号走，不跟着浏览器走。
 * （真实电商会因为「未登录也能加购」而做一次合并，这里先不做。）
 *
 * @author 靳迎奥
 */
@WebServlet("/logout")
public class LogoutServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        // getSession(false)：没有就返回 null，不要新建一个
        HttpSession session = req.getSession(false);
        if (session != null) {
            session.invalidate();
        }

        // 从哪来回哪去：后台退出回登录页，前台退出回商城首页。
        // 同样要过一遍站内路径校验（防开放重定向），规则见 Params.safePath
        resp.sendRedirect(req.getContextPath()
                + Params.safePath(req.getParameter("redirect"), "/login"));
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws IOException {
        doGet(req, resp);
    }
}
