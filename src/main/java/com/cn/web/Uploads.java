package com.cn.web;

import jakarta.servlet.ServletContext;
import jakarta.servlet.http.Part;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.StandardCopyOption;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/**
 * 商品图片的「仓库管理员」—— 存、取、删三件事都在这儿
 *
 * 为什么单独抽一个类，而不是直接写在 ProductFormServlet 里？
 *   有三处要用它：
 *     ProductFormServlet   —— 存新图、换图时删旧图
 *     ProductDeleteServlet —— 删商品时顺手删图
 *     ImageServlet         —— 读图返回给浏览器
 *   更要紧的是：类型校验、大小校验、路径校验必须只有一份。
 *   抄三份的话，改漏一处的后果就是「某个入口没有防护」——
 *   这种漏洞特别隐蔽，因为正常功能全都好好的。
 *
 * 图片存在哪？
 *   由 web.xml 里的 &lt;context-param&gt; uploadDir 指定。
 *   为什么不放在 WAR 里面（比如 webapps/shop/uploads）？
 *     因为我们的部署方式是「先删掉整个 webapps/shop，再解开新 war」。
 *     图片要是放在里面，每重新部署一次就被一起删掉。
 *     放到项目目录下、WAR 之外，部署多少次都还在。
 *
 * @author 靳迎奥
 */
public final class Uploads {

    /** 图片目录的配置项名字，对应 web.xml 里的 &lt;param-name&gt; */
    public static final String CTX_PARAM = "uploadDir";

    /** 单张图上限，和 ProductFormServlet 的 @MultipartConfig 保持一致 */
    public static final long MAX_BYTES = 3L * 1024 * 1024;

    /** 扩展名（小写）→ 浏览器该用什么类型打开 */
    private static final Map<String, String> MIME = new HashMap<>();

    static {
        MIME.put("jpg", "image/jpeg");
        MIME.put("jpeg", "image/jpeg");
        MIME.put("png", "image/png");
        MIME.put("gif", "image/gif");
        MIME.put("webp", "image/webp");
        MIME.put("bmp", "image/bmp");
    }

    /** 工具类，不让 new */
    private Uploads() {
    }

    /* ==================== 目录 ==================== */

    /**
     * 拿到图片目录，不存在就建
     *
     * 找不到配置时的兜底：放到 Tomcat 根目录下的 shop-uploads。
     * 兜底值同样在 webapps 之外，所以重新部署不会丢 ——
     * 目的是「配置写漏了也别让上传功能直接崩」。
     */
    public static File dirOf(ServletContext sc) throws IOException {
        String configured = (sc == null) ? null : sc.getInitParameter(CTX_PARAM);

        File dir;
        if (configured != null && !configured.trim().isEmpty()) {
            dir = new File(configured.trim());
        } else {
            String base = System.getProperty("catalina.base");
            dir = new File(base == null ? "." : base, "shop-uploads");
        }

        if (!dir.isDirectory() && !dir.mkdirs()) {
            throw new IOException("图片目录建不出来：" + dir.getAbsolutePath());
        }
        return dir;
    }

    /* ==================== 存 ==================== */

    /**
     * 把上传的文件存进图片目录
     *
     * @return 存好之后的文件名（不含目录），比如 "3f9a1c2b7e4d5061.png"
     * @throws UploadException 校验没过，getMessage() 是能直接给用户看的提示
     * @throws IOException     磁盘层面出了问题
     */
    public static String save(ServletContext sc, Part part) throws IOException, UploadException {

        /* ---- ① 大小 ----
           @MultipartConfig 的 maxFileSize 其实已经拦过一道，
           这里再查一次是给「Servlet 之外的调用方」留的保险。 */
        long size = part.getSize();
        if (size <= 0) {
            throw new UploadException("选中的文件是空的");
        }
        if (size > MAX_BYTES) {
            throw new UploadException("图片不能超过 " + (MAX_BYTES / 1024 / 1024) + "MB");
        }

        /* ---- ② 扩展名：快速失败 ----
           看一眼就能拒掉的东西，别拖到写了一半磁盘再说。
           注意真正算数的是第 ④ 步的嗅探，这一步只是省事。 */
        String submitted = stripPath(part.getSubmittedFileName());
        if (!MIME.containsKey(extOf(submitted))) {
            throw new UploadException("只支持 jpg / png / gif / webp / bmp 格式的图片");
        }

        File dir = dirOf(sc);

        /* ---- ③ 先落到临时文件 ----
           为什么不直接写成最终文件名？
           因为最终扩展名要等第 ④ 步嗅探出真实内容才能定下来。 */
        File tmp = new File(dir, "up_" + randomName() + ".tmp");
        try (InputStream in = part.getInputStream()) {
            Files.copy(in, tmp.toPath(), StandardCopyOption.REPLACE_EXISTING);
        }

        /* ---- ④ 嗅探真实类型：这一步才是真正的防线 ----
           扩展名是「用户说了算」的信息，完全不可信。
           把 a.txt 改名成 a.jpg 传上来，第 ② 步会痛快放行，
           但文件头那几个字节骗不了人。 */
        String real = sniff(tmp);
        if (real == null) {
            // 不是图片 —— 别把垃圾留在磁盘上
            tmp.delete();
            throw new UploadException("这个文件看着不像图片（内容格式和扩展名对不上）");
        }

        /* ---- ⑤ 用嗅探出的扩展名定名 ----
           用的是 real 而不是用户给的扩展名：
           传进来叫 a.jpg、内容其实是 PNG，那就存成 .png。
           因为 ImageServlet 发什么 content-type 是按扩展名推的，
           扩展名和真实内容对不上，等于给浏览器发了错的 MIME 类型。 */
        File dest = new File(dir, randomName() + "." + real);
        if (!tmp.renameTo(dest)) {
            // 极少数情况 rename 会失败（例如临时目录和目标是不同卷），退化成复制
            Files.copy(tmp.toPath(), dest.toPath(), StandardCopyOption.REPLACE_EXISTING);
            tmp.delete();
        }
        return dest.getName();
    }

    /* ==================== 取 ==================== */

    /**
     * 文件名 → 磁盘文件
     *
     * 名字不合法就返回 null（调用方按「找不到」处理）。
     * 两道防线，任何一道不过都拒掉：
     *
     *   第一道 · 白名单正则
     *     只放行字母、数字、点、下划线、短横。
     *     里面没有 "/" 也没有 "\"，所以 "../../windows/win.ini"
     *     这类路径穿越的写法根本进不到下一步。
     *
     *   第二道 · canonical path 复核
     *     把路径规范化（"a/../b" 会被解析成真实的绝对路径，
     *     符号链接也会被追到底）之后，必须仍然落在 uploadDir 里面。
     *     第一道已经挡住了，这道是双保险 ——
     *     万一以后有人手抖把正则放宽了，还有它兜着。
     */
    public static File resolve(ServletContext sc, String name) {
        if (name == null) {
            return null;
        }
        if (!name.matches("[A-Za-z0-9._-]{1,64}")) {
            return null;
        }
        // 点开头的统统不要："."、".."，以及 .htaccess 这种隐藏文件
        if (name.startsWith(".")) {
            return null;
        }

        File dir;
        try {
            dir = dirOf(sc);
        } catch (IOException e) {
            return null;
        }

        File f = new File(dir, name);
        try {
            String base = dir.getCanonicalPath();
            String full = f.getCanonicalPath();
            if (!full.startsWith(base + File.separator)) {
                return null;
            }
        } catch (IOException e) {
            return null;
        }
        return f;
    }

    /** 按扩展名给 content-type；认不出来就给二进制流 */
    public static String mimeOf(String name) {
        return MIME.getOrDefault(extOf(name), "application/octet-stream");
    }

    /* ==================== 删 ==================== */

    /**
     * 删掉一张图
     *
     * 刻意「不报错」：调用它的时机都是主流程已经成功之后
     * （商品改完了、商品删掉了）。
     * 因为一个残留文件把用户本来成功的操作报成失败，是本末倒置。
     * 最坏的结果只是磁盘上多一个没人引用的文件。
     */
    public static void delete(ServletContext sc, String name) {
        if (name == null || name.isEmpty()) {
            return;
        }
        try {
            File f = resolve(sc, name);
            if (f != null && f.isFile()) {
                f.delete();
            }
        } catch (Exception ignored) {
            // 见方法注释：这里故意吞掉
        }
    }

    /* ==================== 内部小工具 ==================== */

    /** 取扩展名，统一小写；没有就返回空串 */
    public static String extOf(String name) {
        if (name == null) {
            return "";
        }
        int dot = name.lastIndexOf('.');
        if (dot < 0 || dot == name.length() - 1) {
            return "";
        }
        return name.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    /**
     * 生成随机文件名（16 位十六进制）
     *
     * 为什么不用原始文件名？三个理由，一个比一个实际：
     *   ① 中文名、空格、特殊字符在 URL 和磁盘上的编码很麻烦
     *   ② 不同商品传同名文件会互相覆盖
     *   ③ 原始文件名可能带 "../" 或空字节，是路径穿越最常见的入口
     *
     * 16 位 = 2^64 种可能，撞名概率可以忽略；
     * 而且是随机的，没法被人猜出来去枚举别人的图。
     *
     * 附带的好处：名字带随机串 ⇒ 「同一个名字的内容永远不会变」
     * （换图 = 换名字），所以浏览器可以放心长期缓存，见 ImageServlet。
     */
    private static String randomName() {
        return UUID.randomUUID().toString().replace("-", "").substring(0, 16);
    }

    /**
     * 从文件头判断真实图片类型，认不出来返回 null
     *
     * 这就是所谓的 magic number（魔数）——
     * 每种图片格式的头几个字节是固定的，跟文件名一点关系都没有。
     */
    private static String sniff(File f) throws IOException {
        byte[] h = new byte[12];
        int n;
        try (InputStream in = Files.newInputStream(f.toPath())) {
            n = in.readNBytes(h, 0, h.length);
        }
        if (n < 2) {
            return null;
        }

        // JPEG：FF D8 FF 开头
        if (n >= 3 && u(h[0]) == 0xFF && u(h[1]) == 0xD8 && u(h[2]) == 0xFF) {
            return "jpg";
        }
        // PNG：89 50 4E 47 0D 0A 1A 0A（即 "\x89PNG\r\n\x1a\n"）
        if (n >= 8 && u(h[0]) == 0x89
                && h[1] == 'P' && h[2] == 'N' && h[3] == 'G'
                && u(h[4]) == 0x0D && u(h[5]) == 0x0A && u(h[6]) == 0x1A && u(h[7]) == 0x0A) {
            return "png";
        }
        // GIF：GIF8 开头（后面还有 7a 或 9a，不影响判断）
        if (n >= 4 && h[0] == 'G' && h[1] == 'I' && h[2] == 'F' && h[3] == '8') {
            return "gif";
        }
        // WEBP：RIFF .... WEBP（中间 4 字节是文件长度，跳过去看第 9-12 字节）
        if (n >= 12 && h[0] == 'R' && h[1] == 'I' && h[2] == 'F' && h[3] == 'F'
                && h[8] == 'W' && h[9] == 'E' && h[10] == 'B' && h[11] == 'P') {
            return "webp";
        }
        // BMP：BM 开头
        if (n >= 2 && h[0] == 'B' && h[1] == 'M') {
            return "bmp";
        }
        return null;
    }

    /** byte 转成 0~255 的整数。Java 的 byte 是有符号的，直接比大小会出错 */
    private static int u(byte b) {
        return b & 0xFF;
    }

    /**
     * 剥掉文件名里的路径
     *
     * 有些老浏览器（尤其旧版 IE）会把完整路径一起发上来，
     * 比如 "C:\Users\me\图片\手机.jpg"。
     * 反斜杠和正斜杠都当分隔符切一刀，只留最后一段。
     */
    private static String stripPath(String submitted) {
        if (submitted == null) {
            return "";
        }
        String s = submitted.replace('\\', '/');
        int slash = s.lastIndexOf('/');
        return (slash >= 0) ? s.substring(slash + 1) : s;
    }

    /**
     * 上传校验不通过时抛这个
     *
     * 用异常的 message 直接当用户提示 —— 因为校验和提示语是在
     * 同一个地方写出来的，不用担心两边对不上。
     */
    public static class UploadException extends Exception {
        public UploadException(String message) {
            super(message);
        }
    }
}
