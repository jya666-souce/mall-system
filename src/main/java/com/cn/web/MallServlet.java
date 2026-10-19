package com.cn.web;

import com.cn.StoreItem;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.io.IOException;

/**
 * 前台商城首页 = 商品墙
 *
 * 和后台的 /product/list 长得几乎一样，但有三处刻意的不同：
 *   ① 不需要登录 —— AuthFilter 对 /mall/* 放行，游客直接能逛
 *   ② 每页 12 件（卡片比表格占地方），后台是 8 条
 *   ③ 只给「顾客该看的信息」：不显示库存预警、不显示后台那些操作按钮
 *
 * 这也顺便说明了一件事：同一份数据，面向不同的人要有不同的视图。
 * 后端复用同一个 DataStore.query，前端换一套模板就够 ——
 * 这就是「前后台分离」最朴素的样子。
 *
 * @author 靳迎奥
 */
@WebServlet({"/mall", "/mall/list"})
public class MallServlet extends HttpServlet {

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
                pageNo, DataStore.MALL_PAGE_SIZE);
        req.setAttribute("page", page);

        // 回填筛选条件：翻页或从详情页返回时，搜索框不能变空
        req.setAttribute("keyword", keyword);
        req.setAttribute("category", category);
        req.setAttribute("brand", brand);
        req.setAttribute("minPrice", req.getParameter("minPrice"));
        req.setAttribute("maxPrice", req.getParameter("maxPrice"));
        req.setAttribute("sort", sort);

        req.setAttribute("catOptions", store.allCategories());
        req.setAttribute("brandOptions", store.allBrands());

        // 页面上不显示「低于 50 件预警」这种经营信息，
        // 但可以用它给顾客一个「仅剩 N 件」的紧迫感提示
        req.setAttribute("lowStockLine", DataStore.LOW_STOCK);

        Flash.take(req);
        req.getRequestDispatcher("/WEB-INF/views/mall/list.jsp").forward(req, resp);
    }
}
