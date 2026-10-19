package com.cn.web;

import jakarta.servlet.ServletContext;
import jakarta.servlet.ServletContextEvent;
import jakarta.servlet.ServletContextListener;
import jakarta.servlet.annotation.WebListener;

import java.io.File;
import java.io.IOException;

/**
 * 应用监听器 —— 只在「应用启动」和「应用关闭」这两个时刻被叫醒一次
 *
 * 为什么不写成 Filter 或 Servlet？
 *   那两个都只能「等请求来」。可应用启动的那一瞬间、关闭的那一瞬间，
 *   **一个请求都没有** —— 这正是它们够不着的地方。
 *   Listener 补的就是这个缺口：它听的是容器自己的生命周期事件，
 *   而不是用户发过来的请求。
 *
 * 这里做三件事：
 *
 *   ① 启动时把「图片目录」建出来。
 *      与其等用户上传到一半才发现目录不可用，不如启动时就查一遍 ——
 *      故障暴露得越早越值钱，日志里一眼就能看到，不用去猜。
 *      注意：目录建不出来**不拦启动**。浏览、下单这些功能
 *      不该被「上传」这一个功能连累，只记日志、让上传自己去报错。
 *
 *   ② 给「在线人数」打底（onlineCount = 0）。
 *      页面直接读这个值，不先放一个的话，第一个访客来之前那块是空白。
 *
 *   ③ 起止各打一行日志。
 *      看着没用，但排查问题时最怕的就是「我到底重启成功没有」——
 *      日志里搜一下「[启动]」就知道，比看进程 pid 靠谱。
 *
 * 注册方式：@WebListener 注解，效果等同在 web.xml 里写
 *   &lt;listener&gt;&lt;listener-class&gt;com.cn.web.AppListener&lt;/listener-class&gt;&lt;/listener&gt;
 * 前提是 web.xml 不能带 metadata-complete="true" —— 写了就会忽略所有注解。
 *
 * @author 靳迎奥
 */
@WebListener
public class AppListener implements ServletContextListener {

    /**
     * 「当前在线会话数」存在 ServletContext 里用的 key
     *
     * 定义成常量，是为了让 OnlineListener 和页面读到的是同一个名字。
     * 字符串字面量写两遍，改一处漏一处，就会得到「页面永远显示 0」
     * 这种不报错、只是不对的 bug —— 最难查的那种。
     */
    public static final String ONLINE_COUNT = "onlineCount";

    @Override
    public void contextInitialized(ServletContextEvent sce) {
        ServletContext sc = sce.getServletContext();

        /* ① 图片目录：在这里查一次，别拖到用户上传时才发现问题 */
        try {
            File dir = Uploads.dirOf(sc);
            sc.log("[启动] 图片目录就绪：" + dir.getAbsolutePath());
        } catch (IOException ex) {
            // 只记日志，不抛出去 —— 抛出去整个应用就起不来了
            sc.log("[启动] 图片目录不可用，上传功能会失败：" + ex.getMessage(), ex);
        }

        /* ② 在线人数打底 */
        sc.setAttribute(ONLINE_COUNT, 0);

        /* ③ 启动日志 */
        sc.log("[启动] 商品管理系统就绪，上下文路径 = " + sc.getContextPath());
    }

    @Override
    public void contextDestroyed(ServletContextEvent sce) {
        ServletContext sc = sce.getServletContext();
        // 关闭前把在线数带出来，方便对照「关闭后页面为什么还显示 N」
        sc.log("[关闭] 商品管理系统正在关闭，关闭前在线会话数 = " + sc.getAttribute(ONLINE_COUNT));
    }
}
