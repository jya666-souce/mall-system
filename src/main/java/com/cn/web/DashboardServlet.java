package com.cn.web;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;

/**
 * 工作台：把统计数字算好，交给 dashboard.jsp 渲染
 *
 * 注意这里一行 HTML 都没拼 —— Servlet 只负责「取数据、选页面」，
 * 拼页面是 JSP 的活。
 * 统计口径全在 DataStore 里（数错了去那里改，不用翻页面）。
 *
 * @author 靳迎奥
 */
@WebServlet("/dashboard")
public class DashboardServlet extends HttpServlet {

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws ServletException, IOException {

        DataStore store = DataStore.get();

        // 顶部五张统计卡
        req.setAttribute("itemCount", store.count());
        req.setAttribute("categoryCount", store.countCategories());
        req.setAttribute("brandCount", store.countBrands());
        req.setAttribute("totalStock", store.totalStock());
        req.setAttribute("totalValueText", String.format("%.2f", store.totalValue()));

        // 两个分布条形图 + 库存预警列表
        req.setAttribute("catStats", store.categoryStats());
        req.setAttribute("brandStats", store.brandStats());
        req.setAttribute("lowStock", store.lowStockItems());
        req.setAttribute("lowStockLine", DataStore.LOW_STOCK);

        Flash.take(req);
        req.getRequestDispatcher("/WEB-INF/views/dashboard.jsp").forward(req, resp);
    }
}
