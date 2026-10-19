package com.cn.web;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;

/**
 * 「一次性提示消息」小工具（业内的叫法：flash message）
 *
 * 为什么需要它？
 *   增删改处理完要 redirect 回列表页（PRG 模式，见笔记第四节），
 *   而 redirect 会让 request 里的数据全部丢掉 ——
 *   提示信息没法跟着走。
 *   所以先塞进 session，到列表页时再取出来「顺便删掉」，
 *   这样 F5 刷新不会反复看到同一句提示。
 *
 * @author 靳迎奥
 */
final class Flash {

    private Flash() {
    }

    /** 记一条成功提示 */
    static void ok(HttpServletRequest req, String msg) {
        req.getSession().setAttribute("flashOk", msg);
    }

    /** 记一条失败提示 */
    static void err(HttpServletRequest req, String msg) {
        req.getSession().setAttribute("flashErr", msg);
    }

    /**
     * 按操作结果自动挑提示种类
     *
     * DataStore 里所有写操作都是「返回 null 表示成功，否则返回错误文案」，
     * 所以调用处只要把返回值 + 成功时想说的话递进来就行，
     * 省掉每个分支写一遍 if/else。
     */
    static void report(HttpServletRequest req, String err, String okMsg) {
        if (err == null) {
            ok(req, okMsg);
        } else {
            err(req, err);
        }
    }

    /**
     * 把 session 里的提示搬到 request 上，并从 session 里删掉。
     * 列表页转发前调一次，JSP 里就能用 ${flashOk} / ${flashErr} 了。
     */
    static void take(HttpServletRequest req) {
        HttpSession session = req.getSession(false);
        if (session == null) {
            return;
        }
        Object ok = session.getAttribute("flashOk");
        if (ok != null) {
            req.setAttribute("flashOk", ok);
            session.removeAttribute("flashOk");
        }
        Object error = session.getAttribute("flashErr");
        if (error != null) {
            req.setAttribute("flashErr", error);
            session.removeAttribute("flashErr");
        }
    }
}
