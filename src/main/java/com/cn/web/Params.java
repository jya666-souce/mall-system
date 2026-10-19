package com.cn.web;

/**
 * 参数解析小工具
 *
 * 浏览器传过来的东西全都是字符串，而且是"不可信"的：
 *   - 用户没填 → null 或 ""
 *   - 手输地址栏乱传 → "abc"、"99999999999999999999"
 * 直接 Integer.parseInt() 会抛 NumberFormatException，
 * 一个异常就能把整个请求打成 500 错误页。
 * 所以统一在这里兜住，转不了就返回默认值。
 *
 * @author 靳迎奥
 */
final class Params {

    private Params() {
    }

    /** 转 Long，转不了返回 null（用于"编号"这类必填字段） */
    static Long toLong(String s) {
        if (s == null || s.trim().isEmpty()) {
            return null;
        }
        try {
            return Long.valueOf(s.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** 转 Double，转不了返回 null（用于价格区间筛选，不填就是不限） */
    static Double toDouble(String s) {
        if (s == null || s.trim().isEmpty()) {
            return null;
        }
        try {
            return Double.valueOf(s.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    static double toDouble(String s, double def) {
        Double v = toDouble(s);
        return v == null ? def : v;
    }

    static int toInt(String s, int def) {
        if (s == null || s.trim().isEmpty()) {
            return def;
        }
        try {
            return Integer.parseInt(s.trim());
        } catch (NumberFormatException e) {
            return def;
        }
    }

    /** 去掉首尾空格，null 安全 */
    static String trim(String s) {
        return s == null ? "" : s.trim();
    }

    /**
     * 站内路径校验 —— 给 ?redirect= / ?back= 这类「待会儿跳回哪」的参数用
     *
     * 为什么非要校验？因为这种值来自地址栏，用户可以随便改，
     * 直接拿来跳很危险：
     *     /login?redirect=https://evil.com
     * 用户老老实实登录完，却被送到钓鱼站 —— 这叫「开放重定向」，
     * 是 phishing 里很常见的一招：域名看着是你家的，点进去不是。
     *
     * 只放行同时满足两条的路径：
     *   ① 以单个 / 开头 —— 站内相对路径
     *   ② 不是以 // 开头 —— 浏览器会把 //evil.com 当成「协议相对地址」，
     *      省略了 https: 而已，照样能跳出站外。这一条最容易被漏掉。
     *
     * @param def 校验不过时兜底去哪（后台用 /dashboard，前台用 /mall）
     */
    static String safePath(String s, String def) {
        String v = trim(s);
        if (v.isEmpty() || !v.startsWith("/") || v.startsWith("//")) {
            return def;
        }
        return v;
    }
}
