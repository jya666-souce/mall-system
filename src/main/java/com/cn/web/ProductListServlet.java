package com.cn.web;

import com.cn.StoreItem;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;

/**
 * 商品列表：搜索 + 筛选 + 排序 + 分页
 *
 * Servlet 这边只做三件事：
 *   ① 把浏览器传来的字符串参数转成 Java 类型
 *   ② 交给 DataStore 去查
 *   ③ 把结果和「筛选条件」一起塞进 request，转发给 JSP
 *
 * 为什么要回填筛选条件？
 *   用户翻到第 2 页、或者改完一条商品回到列表，搜索框要是空的，
 *   他会以为搜索被重置了。这些值不会自动记住，
 *   得靠页面把它们重新写回 input 的 value 里。
 *
 * @author 靳迎奥
 */
@WebServlet("/product/list")
public class ProductListServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        String keyword  = Params.trim(req.getParameter("keyword"));
        String category = Params.trim(req.getParameter("category"));
        String brand    = Params.trim(req.getParameter("brand"));
        Double min      = Params.toDouble(req.getParameter("minPrice"));
        Double max      = Params.toDouble(req.getParameter("maxPrice"));
        String sort     = Params.trim(req.getParameter("sort"));
        int pageNo      = Params.toInt(req.getParameter("page"), 1);

        DataStore store = DataStore.get();

        Page<StoreItem> page = store.page(keyword, category, brand, min, max, sort,
                pageNo, DataStore.PAGE_SIZE);
        req.setAttribute("page", page);

        // 回填用：价格区间保留原始字符串，不填就显示空
        req.setAttribute("keyword", keyword);
        req.setAttribute("category", category);
        req.setAttribute("brand", brand);
        req.setAttribute("minPrice", req.getParameter("minPrice"));
        req.setAttribute("maxPrice", req.getParameter("maxPrice"));
        req.setAttribute("sort", sort);

        // 筛选下拉的选项
        req.setAttribute("catOptions", store.allCategories());
        req.setAttribute("brandOptions", store.allBrands());
        req.setAttribute("lowStockLine", DataStore.LOW_STOCK);

        Flash.take(req);
        req.getRequestDispatcher("/WEB-INF/views/product-list.jsp").forward(req, resp);
    }
}
