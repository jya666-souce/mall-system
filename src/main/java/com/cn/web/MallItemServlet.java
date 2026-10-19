package com.cn.web;

import com.cn.StoreItem;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;

/**
 * 商品详情页
 *
 * 顾客从列表点进来，看到的是一件商品的完整信息 + 加购按钮。
 *
 * 两个细节值得注意：
 *   ① 商品编号是地址栏传来的，可能根本不存在（手输、或者刚被后台删了）
 *      → 不能 500，要明确地回一个 404
 *   ② 下标越界、编号不存在这类问题，永远要用「查不到」来兜，
 *      而不是先假设它一定在，再去用
 *
 * @author 靳迎奥
 */
@WebServlet("/mall/item")
public class MallItemServlet extends HttpServlet {

    /** 相关推荐最多放几件 */
    private static final int RELATED_MAX = 4;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        Long id = Params.toLong(req.getParameter("id"));
        DataStore store = DataStore.get();
        StoreItem item = store.getById(id);

        if (item == null) {
            // 商品不存在（或已被后台删除）→ 给一个明确的 404，
            // 而不是让后面的 ${item.name} 抛空指针变成 500
            resp.sendError(HttpServletResponse.SC_NOT_FOUND, "商品不存在或已下架");
            return;
        }
        req.setAttribute("item", item);

        // 同类推荐：先查出同分类的全部，再去掉自己
        List<StoreItem> related = new ArrayList<>();
        for (StoreItem it : store.query(null, item.getCategory(), null, null, null, null)) {
            if (!it.getId().equals(item.getId())) {
                related.add(it);
            }
            if (related.size() >= RELATED_MAX) {
                break;
            }
        }
        req.setAttribute("related", related);

        Flash.take(req);
        req.getRequestDispatcher("/WEB-INF/views/mall/item.jsp").forward(req, resp);
    }
}
