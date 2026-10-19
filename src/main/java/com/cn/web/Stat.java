package com.cn.web;

/**
 * 统计项：一个名字 + 一个数值 + 相对占比
 *
 * 工作台那个「分类分布」条形图就是拿它渲染的 ——
 * percent 是相对最大值的百分比（最大的那项 = 100），
 * JSP 里直接写成 style="width:${s.percent}%"，不用在页面里做除法。
 *
 * @author 靳迎奥
 */
public class Stat {

    private final String name;
    private final int count;
    private final int percent;

    public Stat(String name, int count, int percent) {
        this.name = name;
        this.count = count;
        this.percent = percent;
    }

    public String getName() {
        return name;
    }

    public int getCount() {
        return count;
    }

    /** 条形图宽度百分比，最大值的那一项是 100 */
    public int getPercent() {
        return percent;
    }
}
