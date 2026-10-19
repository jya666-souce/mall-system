package com.cn.web;

import java.util.ArrayList;
import java.util.List;

/**
 * 分页结果封装
 *
 * 为什么不让 Servlet 直接把 List 和页码丢给 JSP？
 *   因为页面上要显示「共几页」「上一页/下一页」「本页第几条到第几条」，
 *   这些计算写在 JSP 里会把页面模板弄脏，而且每个列表页都要重写一遍。
 *   封成一个对象，JSP 只管 ${page.rows} 和 ${page.totalPages}，各司其职。
 *
 * @param <T> 列表里装的是什么类型的行
 * @author 靳迎奥
 */
public class Page<T> {

    private final List<T> rows;   // 当前页的数据
    private final int page;       // 当前第几页，从 1 开始
    private final int size;       // 每页几条
    private final int total;      // 总记录数

    public Page(List<T> rows, int page, int size, int total) {
        this.rows = rows;
        this.page = page;
        this.size = size;
        this.total = total;
    }

    /**
     * 从完整列表里切出一页
     *
     * 页码越界会自动夹回合法范围 ——
     * 用户手输 ?page=999 也不会看到一个空页面，而是落在最后一页。
     * 这种「不信任输入」的兜底，在分页上特别重要。
     */
    public static <T> Page<T> of(List<T> all, int pageNo, int size) {
        int total = all == null ? 0 : all.size();
        if (size <= 0) {
            size = 10;
        }
        int totalPages = Math.max(1, (total + size - 1) / size);
        int p = Math.min(Math.max(1, pageNo), totalPages);

        int from = Math.min((p - 1) * size, total);
        int to = Math.min(from + size, total);

        List<T> slice = new ArrayList<>(all.subList(from, to));
        return new Page<>(slice, p, size, total);
    }

    public List<T> getRows() {
        return rows;
    }

    public int getPage() {
        return page;
    }

    public int getSize() {
        return size;
    }

    public int getTotal() {
        return total;
    }

    /** 总页数，至少 1 页 */
    public int getTotalPages() {
        return Math.max(1, (total + size - 1) / size);
    }

    /* 下面这几个是给 JSP 用的开关，名字以 is 开头，EL 里写 ${page.hasPrev} 即可 */

    public boolean isHasPrev() {
        return page > 1;
    }

    public boolean isHasNext() {
        return page < getTotalPages();
    }

    public int getPrevPage() {
        return Math.max(1, page - 1);
    }

    public int getNextPage() {
        return Math.min(getTotalPages(), page + 1);
    }

    public boolean isEmpty() {
        return total == 0;
    }

    /** 本页第一条是全局第几条（从 1 开始），没有数据时返回 0 */
    public int getFrom() {
        return total == 0 ? 0 : (page - 1) * size + 1;
    }

    /** 本页最后一条是全局第几条 */
    public int getTo() {
        return Math.min(page * size, total);
    }

    /**
     * 页码按钮列表：当前页前后各留 2 页，最多显示 5 个
     * 页数很多时不会把一排按钮撑爆
     */
    public List<Integer> getPageNumbers() {
        int tp = getTotalPages();
        int start = Math.max(1, page - 2);
        int end = Math.min(tp, start + 4);
        start = Math.max(1, end - 4);

        List<Integer> nums = new ArrayList<>();
        for (int i = start; i <= end; i++) {
            nums.add(i);
        }
        return nums;
    }
}
