package com.cn.web;

import jakarta.servlet.ServletContext;
import jakarta.servlet.annotation.WebListener;
import jakarta.servlet.http.HttpSessionEvent;
import jakarta.servlet.http.HttpSessionListener;

/**
 * 在线人数 —— 数的是「现在有多少个活跃会话」
 *
 * 容器在会话「诞生」和「销毁」这两个时刻叫它，正好一加一减：
 *   sessionCreated   有人第一次来（或上一个会话过期后又来）
 *   sessionDestroyed 会话超时 / 主动退出登录（invalidate）
 *
 * 计数存在 ServletContext 里，而不是某个 static 变量。差别在于：
 * 放 ServletContext 的生命周期归容器管，应用一关它跟着没，
 * 不会出现「上一个应用的数据漂到下一个应用」这种事。
 *
 * ⚠️ 两个必须提前知道的现实，不然你会以为它坏了：
 *
 * ① 它数的是「会话」不是「人」。
 *    JSP 默认 session="true"，**访问任何一页都会顺手创建一个 session**，
 *    所以没登录的游客也算一个 —— 这符合「有多少人在逛」的语义。
 *    但爬虫、监控探针、无痕窗口也会各自占一个名额，
 *    数字通常比真人多。真实项目里的「在线人数」从来都是估算值，
 *    没必要追求精确 —— 想精确就得靠登录态去重，那是另一套做法。
 *
 * ② 会话销毁有延迟。
 *    Tomcat 不是一到 30 分钟就立刻销毁，而是后台线程定期扫描
 *    （默认约 60 秒一轮，backgroundProcessorDelay）。
 *    所以人数往下掉会比你以为的慢一拍。这不是 bug，
 *    是「定期清理」这种设计的天性 —— 顺带也说明它为什么省资源：
 *    每个会话不值得配一个定时器。
 *
 * @author 靳迎奥
 */
@WebListener
public class OnlineListener implements HttpSessionListener {

    /**
     * 一把锁
     *
     * `count + 1` 是「读出来 → 加一 → 写回去」三步，不是原子操作。
     * 两个请求同时开新会话，可能都读到 3、都写回 4 ——
     * 明明来了两个人，数字只涨了 1。加锁把整段圈起来才安全。
     *
     * 为什么用静态锁而不是实例锁：
     *   容器对一个监听器类通常只创建一个实例，实例锁本来就够用；
     *   用 static 是为了不依赖「容器只创建一个」这个约定 ——
     *   万一哪天真的有两个实例，计数也不会错。
     *
     * 性能上完全不用担心：只有会话生死时才进这段代码，
     * 跟每次请求都要过的 Filter 完全不是一个量级。
     * 真到了高频计数的场景，才需要换成 AtomicInteger。
     */
    private static final Object LOCK = new Object();

    @Override
    public void sessionCreated(HttpSessionEvent se) {
        change(se, 1);
    }

    @Override
    public void sessionDestroyed(HttpSessionEvent se) {
        change(se, -1);
    }

    private void change(HttpSessionEvent se, int delta) {
        ServletContext sc = se.getSession().getServletContext();

        synchronized (LOCK) {
            int now = count(sc) + delta;

            /* 下限保护，防的是这种情况：
               Tomcat 正常关闭时会把 session 持久化到磁盘（work 目录下的
               SESSIONS.ser），下次启动又给恢复回来。可 ServletContext 是全新的，
               计数从 0 开始 —— 那些「复活」的老会话后来陆续销毁，
               就会把计数扣成负数，页面上出现「-1 人在逛」。
               加这一道，最多也就是显示偏小，不会出现负数这种明显不对的值。 */
            if (now < 0) {
                now = 0;
            }

            sc.setAttribute(AppListener.ONLINE_COUNT, now);
        }
    }

    /** 读当前计数。AppListener 没打过底就按 0 算，避免 null 拆箱炸掉 */
    private int count(ServletContext sc) {
        Object v = sc.getAttribute(AppListener.ONLINE_COUNT);
        return (v instanceof Integer) ? (Integer) v : 0;
    }
}
