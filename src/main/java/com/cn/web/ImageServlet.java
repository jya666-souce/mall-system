package com.cn.web;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.File;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;

/**
 * 读商品图片：/img?name=3f9a1c2b7e4d5061.png
 *
 * 为什么不让 Tomcat 直接把图片目录当静态资源发出去，非要自己写个 Servlet？
 *   ① 图片目录在 webapps 之外，Tomcat 本来就不认它，得有个入口
 *   ② 能自己控制发什么 content-type（错的话浏览器会当文件下载）
 *   ③ 文件被人删了、或者名字是乱编的 → 干净地回 404，而不是抛个 500 出去
 *   ④ 所有请求都得经过 resolve() 那道路径校验，防住 "../" 这类穿越
 *
 * 权限：这个地址在 AuthFilter 的 WHITE_LIST 里，不登录也能取图 ——
 *   前台商城游客也要看图，图片本身又不是什么机密。
 *
 * @author 靳迎奥
 */
@WebServlet("/img")
public class ImageServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        String name = Params.trim(req.getParameter("name"));
        File f = Uploads.resolve(getServletContext(), name);

        // resolve 返回 null 表示名字不合法（比如带 "../"），
        // 文件不存在也走这里 —— 对外都是「找不到图」，不透露具体原因
        if (f == null || !f.isFile()) {
            resp.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }

        resp.setContentType(Uploads.mimeOf(f.getName()));
        resp.setContentLengthLong(f.length());

        /* 可以放心让浏览器长期缓存 7 天。
           因为文件名是上传时随机生成的，换图会换成一个新名字 ——
           「同一个 URL 对应同一张图」这件事永远成立。
           要是用商品的原始文件名（比如 7.jpg），换了图 URL 不变，
           浏览器就会一直拿老图，那时候就只能靠 no-cache 了。 */
        resp.setHeader("Cache-Control", "public, max-age=604800");

        try (OutputStream out = resp.getOutputStream()) {
            Files.copy(f.toPath(), out);
        }
    }
}
