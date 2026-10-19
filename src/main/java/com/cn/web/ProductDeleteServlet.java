package com.cn.web;

import com.cn.StoreItem;

import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * 删除商品
 *
 * 一个地址干两件事：
 *   表单里传一个 id          → 删这一条（列表每行的「删除」按钮）
 *   表单里传多个 id（复选框）→ 批量删除
 *
 * 两种情况都用 request.getParameterValues("id") 取：
 *   只有一个值时它返回长度为 1 的数组，
 *   所以不用写两套代码，统一按数组处理就行。
 *
 * 顺带负责清理商品图片。
 *
 * 名称说明：处理逻辑叫 handleDelete 而不是 doDelete ——
 *   HttpServlet 里已经有 protected doDelete()（对应 HTTP 的 DELETE 方法），
 *   自己再定义一个同名的会把父类方法盖住还降了访问权限，编译直接报错。
 *
 * @author 靳迎奥
 */
@WebServlet("/product/delete")
public class ProductDeleteServlet extends HttpServlet {

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws IOException {
        handleDelete(req, resp);
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws IOException {
        // 也允许 GET，方便在地址栏里直接试
        handleDelete(req, resp);
    }

    private void handleDelete(HttpServletRequest req, HttpServletResponse resp)
            throws IOException {

        String[] raw = req.getParameterValues("id");
        List<Long> ids = new ArrayList<>();
        if (raw != null) {
            for (String s : raw) {
                Long id = Params.toLong(s);
                if (id != null) {
                    ids.add(id);
                }
            }
        }

        if (ids.isEmpty()) {
            Flash.err(req, "没有选中任何商品");

        } else if (ids.size() == 1) {
            Long id = ids.get(0);

            /* 关键顺序：先把图片名捞出来，再删商品。
               反过来的话，商品已经从 DataStore 里没了，
               挂在它身上的图片名就再也查不到 ——
               那些图片会永远留在磁盘上，没人知道它们属于谁。 */
            StoreItem it = DataStore.get().getById(id);
            String img = (it == null) ? null : it.getImage();

            String err = DataStore.get().delete(id);
            if (err == null) {
                // 数据都删干净了，图片文件才跟着删
                Uploads.delete(getServletContext(), img);
                Flash.ok(req, "已删除 1 条商品");
            } else {
                Flash.err(req, err);
            }

        } else {
            // 批量：先把要删的图片名统统收集起来
            List<String> imgs = new ArrayList<>();
            for (Long id : ids) {
                StoreItem it = DataStore.get().getById(id);
                if (it != null && it.getImage() != null) {
                    imgs.add(it.getImage());
                }
            }

            Flash.ok(req, DataStore.get().deleteAll(ids));

            // 数据删完了，再挨个清图片文件
            for (String img : imgs) {
                Uploads.delete(getServletContext(), img);
            }
        }

        resp.sendRedirect(req.getContextPath() + "/product/list");
    }
}
