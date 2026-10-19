/**
 * 把「商品管理系统」的 Servlet 接口生成一份 Postman Collection v2.1 JSON。
 *
 * 为什么不手写 JSON：40 多个请求，手写括号容易错；
 * 用脚本生成，以后加接口只要往下面数组里加一条，重跑就行。
 *
 * 生成的文件可以直接拖进 Apifox（项目 → 导入数据 → Postman）。
 *
 * 运行：node build-collection.mjs
 */

import { writeFileSync } from "node:fs";

const BASE = "http://localhost:8080/shop";
const OUT = "D:/workpace/商品管理系统-Apifox接口集合.json";

/* ==================== 小工具 ==================== */

function urlOf(path, query) {
    query = query || [];
    const qs = query.map(([k, v]) => k + "=" + v).join("&");
    return {
        raw: BASE + path + (qs ? "?" + qs : ""),
        protocol: "http",
        host: ["localhost"],
        port: "8080",
        path: ["shop"].concat(path.split("/").filter(Boolean)),
        query: query.map(([k, v]) => ({ key: k, value: v })),
    };
}

/** 组一个请求，参数少一点好看 */
function mk(o) {
    const headers = [];
    if (o.cookie) {
        headers.push({ key: "Cookie", value: "JSESSIONID={{" + o.cookie + "}}" });
    } else if (o.rawCookie) {
        headers.push({ key: "Cookie", value: "JSESSIONID=" + o.rawCookie });
    }

    const request = {
        method: o.method,
        header: headers,
        url: urlOf(o.path, o.query),
        description: o.desc || "",
    };

    if (o.multipart) {
        request.body = {
            mode: "formdata",
            formdata: Object.keys(o.multipart).map((k) => ({ key: k, value: o.multipart[k], type: "text" })),
        };
    } else if (o.form) {
        request.body = {
            mode: "urlencoded",
            urlencoded: Object.keys(o.form).map((k) => ({ key: k, value: o.form[k], type: "text" })),
        };
    }

    const item = { name: o.name, request: request };

    /* 接口的「返回响应」定义 —— 见下方 buildResponses 的说明，不定义就等着被契约测试报错 */
    item.response = buildResponses(o);

    const events = [];
    /* 「未登录」用例统一挂上前置清 Cookie 脚本，谁写的都自动生效 */
    let preScript = o.pre;
    if (o.rawCookie === NO_SESSION) {
        preScript = (preScript || []).concat([""], preClearCookie);
    }
    if (preScript) events.push({ listen: "prerequest", script: { type: "text/javascript", exec: preScript } });
    if (o.test) events.push({ listen: "test", script: { type: "text/javascript", exec: o.test } });
    if (events.length) item.event = events;

    return item;
}

/* ---- 返回响应定义 ---- */

/**
 * 为什么非要写这一段（这是被 Apifox 的「校验响应」逼出来的）：
 *
 * Apifox 导入 Postman 集合时，item 里如果没有 response 数组，
 * 它会好心给你**补一个默认的「成功(200)」返回响应，body 按 JSON 算**。
 * 然后「校验响应」（契约测试）开着的时候，它就拿这个默认定义去比实际响应：
 *   · 本项目登录成功返回 302 → 报「实际 302，定义 200」
 *   · 本项目返回的是 HTML 不是 JSON → 报「返回的数据格式不是 JSON」
 * 两条红杠，但接口本身一点问题没有 —— 纯粹是文档定义跟不上实际。
 *
 * 解法就是这里：把每个接口真实的返回响应写进集合，
 * 状态码直接从断言脚本里抠（不用再维护第二份），导入之后契约测试自然就对上了。
 */
const STATUS_TEXT = {
    200: "OK",
    302: "Found",
    403: "Forbidden",
    404: "Not Found",
    500: "Internal Server Error",
};

/** 这个接口期望哪个状态码 —— 从 pm.response.to.have.status(NNN) 里抠第一个 */
function detectStatus(o) {
    const m = (o.test || []).join("\n").match(/pm\.response\.to\.have\.status\((\d{3})\)/);
    return m ? Number(m[1]) : 200;
}

/** 期望跳去哪儿 —— 从 tLocation 生成的断言里抠出那个片段 */
function detectLocation(o) {
    const m = (o.test || []).join("\n").match(/get\('Location'\) \|\| ''\)\.to\.include\("([^"]+)"\)/);
    return m ? m[1] : "";
}

/** 非跳转的接口返回的是渲染好的页面，这里给一段示意 body 当示例响应 */
function htmlSample(title) {
    return [
        "<!DOCTYPE html>",
        '<html lang="zh-CN">',
        "<head>",
        '    <meta charset="UTF-8">',
        "    <title>" + title + "</title>",
        "</head>",
        "<body>",
        "    ...（服务端用 JSP 渲染好的页面）...",
        "</body>",
        "</html>",
    ].join("\n");
}

/**
 * 同一个地址的第二种可能结果。
 *
 * Apifox 的契约测试在「文档里定义了多个状态码」时，是按**允许范围**校验的
 * （官方原话：文档定义多个可能值，如 200、201，按允许范围校验）。
 * 所以把两种结果都写进定义，用不同参数去跑就都不会报红了。
 *
 * 这是本项目绕不开的：一个地址本来就对应好几种结果 ——
 *   · 带身份 → 200 渲染页面；不带身份 → 302 拦去登录页
 *   · 参数合法 → 302 跳走；参数不合法 → 200 留在原地显示错误
 */
function fallbackOf(code) {
    if (code === 200) return 302; // 页面类：没带身份会被拦去登录页
    if (code === 302) return 200; // 跳转类：参数没过校验时，留在原页面继续报错
    if (code === 403) return 302; // 越权类：没登录时走不到权限判断，先被 302 拦走
    return 0; // 404（图片不存在 / 路径穿越被拒）结果是稳定的，不用兜底
}

function makeResp(code, o, isFallback) {
    const isRedirect = code === 302;
    const headers = [];

    if (isRedirect) {
        // 兜底的 302 = 被拦去登录页；主路径的 302 = 成功跳去目标页
        let loc;
        if (isFallback && o.path !== "/login") {
            loc = "/shop/login";
        } else if (o.path === "/login") {
            loc = "/shop/mall"; // 登录条目的 302，不管哪条路径都是跳商城
        } else {
            const got = detectLocation(o);
            // 断言里写的是 '/mall' 这种片段，补全成完整路径，看着像真的
            loc = got ? (got.startsWith("/shop") ? got : "/shop" + got) : "/shop/";
        }
        headers.push({ key: "Location", value: loc });
        headers.push({ key: "Content-Length", value: "0" });
    } else {
        headers.push({ key: "Content-Type", value: "text/html;charset=UTF-8" });
    }

    // 登录那几条会在响应头里带回新会话，这里也如实写出来
    if (!isFallback && (o.test || []).join("\n").indexOf("响应里带回 JSESSIONID") >= 0) {
        headers.push({ key: "Set-Cookie", value: "JSESSIONID=0A1B2C3D4E5F60718293A4B5C6D7E8F9; Path=/shop; HttpOnly" });
    }

    let name = code + " " + (STATUS_TEXT[code] || "") + (isRedirect ? " · 重定向" : " · HTML 页面");
    if (isFallback) {
        if (code === 302) {
            name = o.path === "/login" ? "302 Found · 登录成功跳转" : "302 Found · 未登录被拦截";
        } else {
            name = "200 OK · 留在原页面显示错误";
        }
    }

    return {
        name: name,
        originalRequest: { method: o.method, header: [], url: urlOf(o.path, o.query) },
        status: STATUS_TEXT[code] || "OK",
        code: code,
        _postman_previewlanguage: "html",
        header: headers,
        cookie: [],
        body: isRedirect ? "" : htmlSample(o.name),
    };
}

function buildResponses(o) {
    const code = detectStatus(o);
    const list = [makeResp(code, o, false)];
    const fb = fallbackOf(code);
    if (fb) list.push(makeResp(fb, o, true));
    return list;
}

/* ---- 断言片段 ---- */

/**
 * 响应诊断片段 —— 注入到断言脚本里，让红条**自己说人话**。
 *
 * 为什么需要：以前期望 302 却拿到 200 时，一律报「自动跟随重定向没关」。
 * 但「拿到 200」其实有两种完全不同的原因：
 *   ① 302 被工具跟掉了          → 响应体是**跳转后的页面**（商城/列表页）
 *   ② 请求没登录成功，压根没跳转 → 响应体是**登录页**（body class="login-body"）
 * 一口咬定是①，会把人带偏（小靳就被带偏过：他其实只是没填 Body 参数）。
 *
 * 这里靠响应体里的 `login-body` 特征把两种分开，并把页面上的错误提示
 * （`<div class="login-error">`）原样抠出来贴进报错里 —— 看到「请输入用户名」
 * 就知道是参数问题，不用回来问人。
 */
const DIAG = [
    "    const __body = pm.response.text();",
    "    const __loc = pm.response.headers.get('Location') || '';",
    "    const __isLogin = __body.indexOf('login-body') >= 0;",
    "    const __em = (__body.match(/class=\"login-error\">([^<]*)/) || [])[1] || '';",
    "    const __loginWhy = '这次请求没登录成功（返回的是登录页）。' + (__em ? '页面上写着：「' + __em + '」。' : '') + '常见原因：① 请求 Body 的参数被清空了，填回接口定义里的值即可；② 账号或密码不对 —— 那属于「登录 · 密码错误」「登录 · 用户名为空」两条接口的场景，不要去改这条接口的参数。';",
    "    const __otherWhy = '返回的不是登录页 —— 两种可能：①「自动跟随重定向」还开着，302 被跟成 200、Location 被吞掉（关闭位置：设置 → 通用 → Headers → 取消勾选「自动跟随重定向」）；② 这次请求本来就不该被拦，例如你已经带着登录态。';",
].join("\n");

/**
 * 状态码断言。
 *
 * 期望 302 时额外加一层诊断：Apifox / Postman **默认「自动跟随重定向」**，
 * 它会替你把 302 走完 —— 于是你看到的状态码是 200、页面是跳转后的那个页面，
 * 而且 Location 和 Set-Cookie 两个响应头**全都不见了**。
 * 后果很严重：会话变量存不进去，后面所有带身份的接口连锁失败。
 * 这里直接把处理方法写进报错里。
 */
const tStatus = (code, label) => {
    const lines = ["pm.test(" + JSON.stringify(label) + ", function () {"];
    if (code === 302) {
        lines.push("    if (pm.response.code !== 302) {");
        lines.push(DIAG);
        lines.push("        throw new Error('期望 302，实际拿到 ' + pm.response.code + '。'");
        lines.push("            + (__isLogin ? __loginWhy : __otherWhy));");
        lines.push("    }");
    }
    lines.push("    pm.response.to.have.status(" + code + ");");
    lines.push("});");
    return lines;
};

const tContains = (kw, label) => [
    "pm.test(" + JSON.stringify(label) + ", function () {",
    "    pm.expect(pm.response.text()).to.include(" + JSON.stringify(kw) + ");",
    "});",
];

/**
 * 登录页的识别特征。一旦响应里出现它，就说明这次请求被 AuthFilter
 * 踢回登录页了 —— 也就是说「会话没带上」。
 */
const LOGIN_PAGE_MARK = 'name="username"';

/**
 * 「必须登录才能看的页面」专用断言 —— 比 tContains 多做一步诊断。
 *
 * 为什么需要它（这是实测踩出来的）：
 *   没带登录态访问 /product/list，AuthFilter 会 302 到 /login，
 *   而 Apifox / Postman 默认**跟随重定向** —— 最终拿到的是 200 + 登录页。
 *   于是「状态码 200」这条照样绿，只有页面关键字断言炸掉，
 *   报错信息甩给你一坨 '\n\n\n<!DOCTYPE html>\n<html lang="zh...' ，
 *   根本看不出真正原因（其实是 {{xxxJsid}} 是空的）。
 * 所以这里先认出登录页，直接把话说明白。
 */
const tLoggedContains = (kw, label) => [
    "pm.test(" + JSON.stringify(label) + ", function () {",
    "    const body = pm.response.text();",
    "    if (body.indexOf(" + JSON.stringify(LOGIN_PAGE_MARK) + ") >= 0) {",
    "        throw new Error(",
    "            '拿到的是登录页 —— 这次请求没带上有效会话。'",
    "            + ' 先跑「00 登录与权限 → 登录 · 管理员」，'",
    "            + '并确认右上角环境下拉框从头到尾没换过：'",
    "            + '会话变量存在当前环境里，切环境等于换了个空抽屉。'",
    "        );",
    "    }",
    "    pm.expect(body).to.include(" + JSON.stringify(kw) + ");",
    "});",
];

const tLocation = (part, label) => [
    "pm.test(" + JSON.stringify(label) + ", function () {",
    DIAG,
    "    if (!__loc) {",
    "        throw new Error('没有发生跳转（Location 响应头是空的）。'",
    "            + (__isLogin ? __loginWhy : __otherWhy));",
    "    }",
    "    pm.expect(__loc).to.include(" + JSON.stringify(part) + ");",
    "});",
];

/**
 * 登录成功后把 JSESSIONID 存进变量，后面的请求靠它冒充这个身份。
 *
 * 两条路取，因为「自动跟随重定向」开着时第一条路是断的：
 *   ① 302 响应头里的 Set-Cookie  —— 没跟随重定向时才有
 *   ② Cookie jar（pm.cookies）   —— 跟随重定向后会话已经进了 jar，
 *      虽然响应头看不到，但 jar 里有，捞出来一样能用
 * 两条都拿不到才报错，并提示去关「自动跟随重定向」。
 */
const tSaveSession = (varName) => [
    "pm.test(" + JSON.stringify("响应里带回 JSESSIONID，存进变量 " + varName) + ", function () {",
    "    let sid = '';",
    "    let c = pm.response.headers.get('Set-Cookie') || '';",
    "    if (!c && pm.response.headers.all) {",
    "        const all = pm.response.headers.all();",
    "        const hit = all.find(function (h) { return String(h.key).toLowerCase() === 'set-cookie'; });",
    "        if (hit) { c = hit.value || ''; }",
    "    }",
    "    const m = c.match(/JSESSIONID=([^;\\s]+)/);",
    "    if (m) { sid = m[1]; }",
    "    if (!sid && pm.cookies && typeof pm.cookies.get === 'function') {",
    "        sid = pm.cookies.get('JSESSIONID') || '';",
    "        if (sid) { console.log('从 Cookie jar 里取到 JSESSIONID（响应头里没有，说明「自动跟随重定向」开着）'); }",
    "    }",
    "    if (!sid) {",
    "        const __b = pm.response.text();",
    "        const __e = (__b.match(/class=\"login-error\">([^<]*)/) || [])[1] || '';",
    "        if (__b.indexOf('login-body') >= 0) {",
    "            throw new Error('这次没登录成功，所以没有新会话。' + (__e ? '页面上写着：「' + __e + '」。' : '')",
    "                + '检查这条接口的 Body 参数是不是被清空了、账号密码对不对 —— 接口本身没问题。');",
    "        }",
    "        throw new Error('响应里没找到 JSESSIONID。如果 Apifox 开着「自动跟随重定向」，'",
    "            + '302 会被跟掉、Set-Cookie 就看不到了 —— 请到「设置 → 通用 → Headers」里关掉它。');",
    "    }",
    "    pm.environment.set(" + JSON.stringify(varName) + ", sid);",
    "    console.log(" + JSON.stringify(varName + " = ") + " + sid);",
    "});",
];

/**
 * 从页面 HTML 里把 id 抽出来存进变量 —— 这是接口测试里最常用的一招：
 * 上一步的返回值当成下一步的输入，用例之间才有依赖关系。
 * sep 用 split 而不是正则，省得写一堆反斜杠。
 */
const tPickId = (varName, sep, label, mode) => [
    "pm.test(" + JSON.stringify(label) + ", function () {",
    "    const parts = pm.response.text().split(" + JSON.stringify(sep) + ");",
    "    const ids = parts.slice(1)",
    "        .map(function (s) { return parseInt(s, 10); })",
    "        .filter(function (n) { return !isNaN(n); });",
    "    pm.expect(ids.length).to.be.above(0);",
    "    const picked = " + (mode === "max" ? "Math.max.apply(null, ids)" : "ids[0]") + ";",
    "    pm.environment.set(" + JSON.stringify(varName) + ", String(picked));",
    "    console.log(" + JSON.stringify(varName + " = ") + " + picked);",
    "});",
];

/** 断言页面里已经找不到「编辑」链接 —— 用来证明删除真的生效了 */
const tNoEditLink = (label) => [
    "pm.test(" + JSON.stringify(label) + ", function () {",
    "    const hits = pm.response.text().split('/product/edit?id=').length - 1;",
    "    pm.expect(hits).to.eql(0);",
    "});",
];

/* ---- 前置脚本：每次跑都换一个不重名的名字，反复跑不会互相干扰 ---- */

const preUnique = (varName, prefix) => [
    "let n = " + JSON.stringify(prefix) + " + Date.now();",
    "pm.environment.set(" + JSON.stringify(varName) + ", n);",
    "console.log(" + JSON.stringify(varName + " = ") + " + n);",
];

/**
 * 前置脚本：把 Apifox 自己管着的 Cookie 清干净。
 *
 * 为什么需要它：「未登录」这类用例必须真的不带有效会话，
 * 但 Apifox 有「自动 Cookie 管理 / 全局 Cookie」—— 只要之前跑过登录，
 * jar 里就存着一个有效的 JSESSIONID，它会被自动拼进请求头。
 * 结果是请求上挂了两个 JSESSIONID，Tomcat 取到有效那个 → 判定已登录 → 返回 200，
 * 而这条用例期望的是 302。看着像接口坏了，其实是工具替你「带了身份证」。
 *
 * 这里三步走：清 jar → 清请求头里已有的 Cookie → 再塞一个明确的无效值。
 * 这样不管用户有没有关全局 Cookie，结果都稳定。
 */
const preClearCookie = [
    "// 未登录用例：先把 Apifox 自动管理的 Cookie 清掉，避免带着旧会话进来",
    "if (pm.cookies && typeof pm.cookies.clear === 'function') {",
    "    try { pm.cookies.clear(); } catch (e) { /* 某些版本没有这个 API，忽略 */ }",
    "}",
    "// 把请求头里已经拼好的 Cookie 删掉（Apifox 可能在 prerequest 之前就注入了）",
    "pm.request.headers.remove('Cookie');",
    "console.log('已清空 Cookie，本请求将以「未登录」身份发出');",
];

/* ==================== 接口清单 ==================== */

const NO_SESSION = "THIS-SESSION-ID-IS-NOT-LOGGED-IN";

const groups = [

    /* ---------- 00 登录与权限 ---------- */
    {
        name: "00 登录与权限",
        item: [
            mk({
                name: "登录 · 管理员",
                method: "POST",
                path: "/login",
                form: { username: "admin", password: "123456", redirect: "/mall" },
                desc: "账号 admin / 123456，拥有全部权限。\n成功后把会话 ID 存进变量 adminJsid，后面所有后台接口的 Cookie 都用它。\n\n先跑这一条，再跑其他后台接口。",
                test: [
                    ...tStatus(302, "状态码 302（登录成功是重定向）"),
                    ...tLocation("/mall", "跳向前台商城 /mall"),
                    ...tSaveSession("adminJsid"),
                ],
            }),
            mk({
                name: "登录 · 普通用户",
                method: "POST",
                path: "/login",
                form: { username: "user", password: "123456", redirect: "/mall" },
                desc: "账号 user / 123456，只有「看」的权限：工作台、商品列表（含查询和排序）、分类/品牌/订单都只能看，不能改。\n会话 ID 存进 userJsid。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/mall", "跳向前台商城 /mall"),
                    ...tSaveSession("userJsid"),
                ],
            }),
            mk({
                name: "登录 · 密码错误",
                method: "POST",
                path: "/login",
                form: { username: "admin", password: "wrong-password" },
                desc: "边界用例：密码错的时候不能跳转，必须留在登录页把提示显示出来。\n所以这里断言的是 200（forward 回登录页），不是 302。",
                test: [
                    ...tStatus(200, "状态码 200（forward 回登录页，不跳转）"),
                    ...tContains("用户名或密码错误", "页面上出现「用户名或密码错误」"),
                ],
            }),
            mk({
                name: "登录 · 用户名为空",
                method: "POST",
                path: "/login",
                form: { username: "", password: "123456" },
                desc: "边界用例：用户名空着就点登录。\n代码里对「没填」和「填错了」给了不同提示，这里验的是「没填」那一条。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tContains("请输入用户名", "页面上出现「请输入用户名」"),
                ],
            }),
            mk({
                name: "未登录 · 访问后台被拦截",
                method: "GET",
                path: "/dashboard",
                rawCookie: NO_SESSION,
                desc: "不带登录态直接敲后台地址。\nAuthFilter 应该把人踢回登录页，并且把「原本想去哪」记在 redirect 参数里。\n\n这条接口带了一个前置脚本，会先把 Apifox 自动管理的 Cookie 清干净 —— 不然之前登录过留下的 JSESSIONID 会被自动带上，服务端以为你已登录，就得不到 302 了。所以不用你手动清 Cookie。",
                test: [
                    ...tStatus(302, "状态码 302（被过滤器踢走）"),
                    ...tLocation("/login", "Location 指向 /login"),
                    ...tLocation("redirect=", "顺便带上了 redirect 参数，登录后能回到原页面"),
                ],
            }),
            mk({
                name: "权限 · 普通用户访问工作台（有权限，正常）",
                method: "GET",
                path: "/dashboard",
                cookie: "userJsid",
                desc: "对照用例：普通用户有「工作台」这个菜单权限，应该正常打开。\n有了这一条，下面那条 403 才能说明「是权限不够，不是没登录」。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("工作台", "页面渲染出「工作台」"),
                ],
            }),
            mk({
                name: "权限 · 普通用户访问新增商品页（无权限）",
                method: "GET",
                path: "/product/add",
                cookie: "userJsid",
                desc: "普通用户没有「新增商品」这个权限码，应该被 AuthFilter 拦下来渲染 403 页面。",
                test: [
                    ...tStatus(403, "状态码 403（权限不足）"),
                    ...tLoggedContains("没有权限", "渲染出 403 页面"),
                ],
            }),
            mk({
                name: "权限 · 普通用户删除商品（无权限）",
                method: "POST",
                path: "/product/delete",
                cookie: "userJsid",
                form: { id: "1" },
                desc: "写操作更要拦。这里故意用普通用户的身份去调删除接口。\n好在过滤器在 Servlet 之前执行，请求根本进不去业务代码，所以库里的 1 号商品不会被删掉。",
                test: [
                    ...tStatus(403, "状态码 403（权限不足）"),
                    ...tLoggedContains("没有权限", "渲染出 403 页面"),
                ],
            }),
            mk({
                name: "登录 · 临时会话（专供退出登录用）",
                method: "POST",
                path: "/login",
                form: { username: "admin", password: "123456" },
                desc: "为什么要多登录一次？\n因为退出登录会把会话作废 —— 要是直接拿 adminJsid 去退，后面所有后台接口都会变成「未登录」，一红一大片。\n所以这里单独开一个临时会话 tempJsid，专门拿来测退出。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tSaveSession("tempJsid"),
                ],
            }),
            mk({
                name: "退出登录",
                method: "GET",
                path: "/logout",
                cookie: "tempJsid",
                desc: "退出后 session 作废，重定向回登录页。\n用的是上一步那个临时会话，adminJsid 和 userJsid 都不受影响。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/login", "跳回 /login"),
                ],
            }),
            mk({
                name: "退出后 · 再用这个会话访问后台",
                method: "GET",
                path: "/dashboard",
                cookie: "tempJsid",
                desc: "验证退出是真的退出去了：拿刚作废的那个会话再敲一次后台，应该被踢回登录页。\n只看退出接口返回 302 是不够的 —— 会话有没有真的失效，得再试一次才知道。",
                test: [
                    ...tStatus(302, "状态码 302（会话确实失效了）"),
                    ...tLocation("/login", "Location 指向 /login"),
                ],
            }),
        ],
    },

    /* ---------- 01 后台 · 商品接口 ---------- */
    {
        name: "01 后台 · 商品接口",
        item: [
            mk({
                name: "商品列表",
                method: "GET",
                path: "/product/list",
                cookie: "adminJsid",
                desc: "基础列表接口，返回渲染好的表格页面。\n本项目的接口返回的是 HTML 而不是 JSON —— 因为当初是按「服务端渲染」写的。所以断言只能查状态码和页面里的关键字，用不了 json.id 那一套。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("商品列表", "页面渲染出「商品列表」"),
                ],
            }),
            mk({
                name: "商品列表 · 分类 + 价格区间 + 排序",
                method: "GET",
                path: "/product/list",
                cookie: "adminJsid",
                query: [
                    ["category", "数码"],
                    ["minPrice", "100"],
                    ["maxPrice", "1000"],
                    ["sort", "priceDesc"],
                    ["page", "1"],
                ],
                desc: "组合查询。sort 的可选值是 priceAsc / priceDesc / stockDesc（是驼峰，不是下划线）。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("数码", "页面里带上了筛选条件「数码」"),
                ],
            }),
            mk({
                name: "商品列表 · 关键字搜不到结果",
                method: "GET",
                path: "/product/list",
                cookie: "adminJsid",
                query: [["keyword", "这个关键字肯定搜不到XYZ"]],
                desc: "边界用例：搜不到东西的时候页面不能报错，得有「暂无数据」之类的空状态。",
                test: [
                    ...tStatus(200, "状态码 200（空结果不算错）"),
                ],
            }),
            mk({
                name: "新增商品",
                method: "POST",
                path: "/product/add",
                cookie: "adminJsid",
                pre: preUnique("testProductName", "接口测试商品"),
                multipart: {
                    name: "{{testProductName}}",
                    category: "数码",
                    brandPick: "小米",
                    price: "19.90",
                    stock: "5",
                },
                desc: "商品名带时间戳，保证每次跑都是新的一条，反复跑不会互相干扰。\n\n表单是 multipart/form-data（因为要传图片），图片字段名叫 imageFile。这里没带图片 —— 图片是可选的。要测上传，在 Apifox 的 Body 里加一个 file 类型的 imageFile 字段就行。\n\n成功的话重定向到 /product/list。",
                test: [
                    ...tStatus(302, "状态码 302（新增成功）"),
                    ...tLocation("/product/list", "跳回商品列表"),
                ],
            }),
            mk({
                name: "新增商品 · 价格为负（边界）",
                method: "POST",
                path: "/product/add",
                cookie: "adminJsid",
                multipart: {
                    name: "负价格商品",
                    category: "数码",
                    brandPick: "小米",
                    price: "-5",
                    stock: "1",
                },
                desc: "边界用例：把价格改成负数提交。\n服务端应该拦下来并退回表单页 —— 所以 Location 是 /product/add 而不是 /product/list，这个差别正好能证明校验生效了。",
                test: [
                    ...tStatus(302, "状态码 302（退回表单，而不是往下走）"),
                    ...tLocation("/product/add", "Location 退回 /product/add，说明被校验拦住了"),
                ],
            }),
            mk({
                name: "新增商品 · 选了「其他」却没填品牌名（边界）",
                method: "POST",
                path: "/product/add",
                cookie: "adminJsid",
                multipart: {
                    name: "缺品牌商品",
                    category: "数码",
                    brandPick: "__other__",
                    brandCustom: "",
                    price: "9.90",
                    stock: "1",
                },
                desc: "品牌下拉的最后一项是「其他」，它的 option value 是哨兵值 __other__（不是中文「其他」两个字）。\n选它就必须自己手输品牌名，这里故意留空 —— 服务端要能把这一条拦下来。\n前端 JS 只负责把输入框亮出来，真正的规则必须在服务端，不然把 value 改一改就能塞任意品牌。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/product/add", "Location 退回 /product/add，说明被校验拦住了"),
                ],
            }),
            mk({
                name: "商品列表 · 定位刚新增的那条（取 id）",
                method: "GET",
                path: "/product/list",
                cookie: "adminJsid",
                query: [["keyword", "{{testProductName}}"]],
                desc: "用关键字把刚新增的那条筛出来，从页面里的「编辑」链接把 id 抠出来存进 delPid。\n这就是接口测试里最常见的「上一步的结果当下一步的输入」。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tPickId("delPid", "/product/edit?id=", "抽到商品 id 并存入 delPid", "max"),
                ],
            }),
            mk({
                name: "编辑商品 · 打开表单",
                method: "GET",
                path: "/product/edit",
                cookie: "adminJsid",
                query: [["id", "{{delPid}}"]],
                desc: "回显要改的那条数据。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("编辑商品", "页面渲染出「编辑商品」"),
                ],
            }),
            mk({
                name: "编辑商品 · 提交修改",
                method: "POST",
                path: "/product/edit",
                cookie: "adminJsid",
                multipart: {
                    id: "{{delPid}}",
                    name: "{{testProductName}}",
                    category: "数码",
                    brandPick: "小米",
                    price: "29.90",
                    stock: "8",
                },
                desc: "改价格和库存。成功重定向回列表页。",
                test: [
                    ...tStatus(302, "状态码 302（修改成功）"),
                    ...tLocation("/product/list", "跳回商品列表"),
                ],
            }),
            mk({
                name: "删除商品",
                method: "POST",
                path: "/product/delete",
                cookie: "adminJsid",
                form: { id: "{{delPid}}" },
                desc: "删除上一步建的那条测试数据，顺便把环境收拾干净。\n删除接口支持一次传多个 id（id=1&id=2），这里只传一个。",
                test: [
                    ...tStatus(302, "状态码 302（删除成功）"),
                    ...tLocation("/product/list", "跳回商品列表"),
                ],
            }),
            mk({
                name: "商品列表 · 确认已经删掉了",
                method: "GET",
                path: "/product/list",
                cookie: "adminJsid",
                query: [["keyword", "{{testProductName}}"]],
                desc: "再查一次：如果删干净了，页面上就不该再有「编辑」链接。\n只断言状态码是不够的 —— 删除接口返回 302 不代表数据真的没了。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tNoEditLink("页面上已经没有「编辑」链接，确认删除生效"),
                ],
            }),
        ],
    },

    /* ---------- 02 后台 · 分类接口 ---------- */
    {
        name: "02 后台 · 分类接口",
        item: [
            mk({
                name: "分类列表",
                method: "GET",
                path: "/category",
                cookie: "adminJsid",
                desc: "新增 / 修改 / 删除都挂在同一个 Servlet 上，靠请求路径区分动作。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("分类管理", "页面渲染出「分类管理」"),
                ],
            }),
            mk({
                name: "新增分类",
                method: "POST",
                path: "/category/add",
                cookie: "adminJsid",
                pre: preUnique("testCatName", "接口测试分类"),
                form: { name: "{{testCatName}}", remark: "自动化测试新增" },
                desc: "分类名带时间戳，反复跑不会重名。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/category", "跳回分类列表"),
                ],
            }),
            mk({
                name: "分类列表 · 取 id",
                method: "GET",
                path: "/category",
                cookie: "adminJsid",
                desc: "从页面里的隐藏域把分类 id 抠出来。新加的那条 id 最大，所以取最大值就是它。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tPickId("catId", 'name="id" value="', "抽到分类 id 并存入 catId", "max"),
                ],
            }),
            mk({
                name: "修改分类",
                method: "POST",
                path: "/category/update",
                cookie: "adminJsid",
                form: { id: "{{catId}}", name: "{{testCatName}}", remark: "注释改过了" },
                desc: "备注栏同理，用来确认修改真的落库了。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/category", "跳回分类列表"),
                ],
            }),
            mk({
                name: "删除分类",
                method: "POST",
                path: "/category/delete",
                cookie: "adminJsid",
                form: { id: "{{catId}}" },
                desc: "把测试分类删掉。\n如果这个分类下面还挂着商品，页面上的删除按钮会被「被占用」替掉 —— 服务端也应该挡住。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/category", "跳回分类列表"),
                ],
            }),
        ],
    },

    /* ---------- 03 后台 · 品牌接口 ---------- */
    {
        name: "03 后台 · 品牌接口",
        item: [
            mk({
                name: "品牌列表",
                method: "GET",
                path: "/brand",
                cookie: "adminJsid",
                desc: "品牌列表还会统计每个品牌被多少商品用着，被占用的不给删。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("品牌管理", "页面渲染出「品牌管理」"),
                ],
            }),
            mk({
                name: "新增品牌",
                method: "POST",
                path: "/brand/add",
                cookie: "adminJsid",
                pre: preUnique("testBrandName", "接口测试品牌"),
                form: { name: "{{testBrandName}}", remark: "自动化测试新增" },
                desc: "这里也顺手验证了「手输品牌自动进品牌库」那条规则。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/brand", "跳回品牌列表"),
                ],
            }),
            mk({
                name: "品牌列表 · 取 id",
                method: "GET",
                path: "/brand",
                cookie: "adminJsid",
                desc: "同上，取页面里隐藏域的最大 id。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tPickId("brandId", 'name="id" value="', "抽到品牌 id 并存入 brandId", "max"),
                ],
            }),
            mk({
                name: "修改品牌",
                method: "POST",
                path: "/brand/update",
                cookie: "adminJsid",
                form: { id: "{{brandId}}", name: "{{testBrandName}}", remark: "注释改过了" },
                desc: "改名会让挂在这个品牌下的商品跟着显示新名字。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/brand", "跳回品牌列表"),
                ],
            }),
            mk({
                name: "删除品牌",
                method: "POST",
                path: "/brand/delete",
                cookie: "adminJsid",
                form: { id: "{{brandId}}" },
                desc: "刚建的这个品牌下面没有商品，可以正常删掉。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/brand", "跳回品牌列表"),
                ],
            }),
        ],
    },

    /* ---------- 04 后台 · 订单接口 ---------- */
    {
        name: "04 后台 · 订单接口",
        item: [
            mk({
                name: "订单列表（管理员）",
                method: "GET",
                path: "/order",
                cookie: "adminJsid",
                desc: "管理员看全部订单。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("订单管理", "页面渲染出「订单管理」"),
                ],
            }),
            mk({
                name: "订单列表 · 按状态筛选",
                method: "GET",
                path: "/order",
                cookie: "adminJsid",
                query: [["status", "待发货"]],
                desc: "订单状态一共四种：待发货 / 已发货 / 已完成 / 已取消。",
                test: [
                    ...tStatus(200, "状态码 200"),
                ],
            }),
            mk({
                name: "订单列表 · 普通用户也能看（只读）",
                method: "GET",
                path: "/order",
                cookie: "userJsid",
                desc: "对照用例：普通用户有「订单管理」菜单权限但没有「处理订单」按钮权限，所以列表能进、状态改不了。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("订单管理", "页面渲染出「订单管理」"),
                ],
            }),
            mk({
                name: "权限 · 普通用户改订单状态（无权限）",
                method: "POST",
                path: "/order/status",
                cookie: "userJsid",
                form: { id: "1", status: "已发货" },
                desc: "同一条接口，管理员能改、普通用户应该被 403 挡住。\n这组「能看不能改」正好演示了权限码粒度到按钮级别。",
                test: [
                    ...tStatus(403, "状态码 403（权限不足）"),
                    ...tLoggedContains("没有权限", "渲染出 403 页面"),
                ],
            }),
        ],
    },

    /* ---------- 05 前台 · 商城与购物车 ---------- */
    {
        name: "05 前台 · 商城与购物车",
        item: [
            mk({
                name: "商城首页（游客，不登录）",
                method: "GET",
                path: "/mall",
                rawCookie: NO_SESSION,
                desc: "前台商城不登录也能逛 —— 这是和后台最大的区别。\n顺便从页面里抽出商品 id，给后面的详情和加购用。",
                test: [
                    ...tStatus(200, "状态码 200（游客也能打开）"),
                    ...tLoggedContains("全部商品", "页面渲染出「全部商品」"),
                    ...tPickId("pid", "/mall/item?id=", "抽到商品 id 并存入 pid", "first"),
                ],
            }),
            mk({
                name: "商城列表 · 分类 + 价格区间 + 排序",
                method: "GET",
                path: "/mall",
                rawCookie: NO_SESSION,
                query: [
                    ["category", "数码"],
                    ["minPrice", "100"],
                    ["maxPrice", "2000"],
                    ["sort", "priceAsc"],
                    ["page", "1"],
                ],
                desc: "前台自己的筛选。和后台不一样：游客就能用，不需要登录。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("全部商品", "页面仍是商城列表"),
                ],
            }),
            mk({
                name: "商品详情",
                method: "GET",
                path: "/mall/item",
                rawCookie: NO_SESSION,
                query: [["id", "{{pid}}"]],
                desc: "商品详情页。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("优选商城", "页面是商城的壳"),
                ],
            }),
            mk({
                name: "加入购物车",
                method: "POST",
                path: "/mall/cart/add",
                cookie: "userJsid",
                form: { id: "{{pid}}", qty: "2" },
                desc: "游客也能加购物车（购物车挂在 session 上）。这里用已登录的普通用户，方便后面下单。\n加购数量超过库存会被拦下来，也是 302。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/mall/cart", "跳回购物车"),
                ],
            }),
            mk({
                name: "购物车",
                method: "GET",
                path: "/mall/cart",
                cookie: "userJsid",
                desc: "看购物车页面。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("购物车", "页面渲染出「购物车」"),
                ],
            }),
            mk({
                name: "修改购物车数量",
                method: "POST",
                path: "/mall/cart/set",
                cookie: "userJsid",
                form: { id: "{{pid}}", qty: "3" },
                desc: "直接改成 3 件。\n顺带一个规则：数量改成 0 等于删掉这一行。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/mall/cart", "跳回购物车"),
                ],
            }),
            mk({
                name: "移除购物车里的商品",
                method: "POST",
                path: "/mall/cart/remove",
                cookie: "userJsid",
                form: { id: "{{pid}}" },
                desc: "删掉一行。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/mall/cart", "跳回购物车"),
                ],
            }),
            mk({
                name: "清空购物车",
                method: "POST",
                path: "/mall/cart/clear",
                cookie: "userJsid",
                desc: "一键清空。跑完这一条，购物车就干净了。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/mall/cart", "跳回购物车"),
                ],
            }),
        ],
    },

    /* ---------- 06 前台 · 订单接口 ---------- */
    {
        name: "06 前台 · 订单接口",
        item: [
            mk({
                name: "加入购物车（为下单做准备）",
                method: "POST",
                path: "/mall/cart/add",
                cookie: "userJsid",
                form: { id: "{{pid}}", qty: "1" },
                desc: "购物车空着是走不到结算页的，所以先加一件。",
                test: [
                    ...tStatus(302, "状态码 302"),
                ],
            }),
            mk({
                name: "结算确认页",
                method: "GET",
                path: "/mall/order/checkout",
                cookie: "userJsid",
                desc: "GET 是「看一眼确认页」，POST 才是真正下单。\n收货人默认填的是登录名，省得每次手打。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("确认订单", "页面渲染出「确认订单」"),
                ],
            }),
            mk({
                name: "提交订单",
                method: "POST",
                path: "/mall/order/checkout",
                cookie: "userJsid",
                form: {
                    receiver: "测试收货人",
                    phone: "13800000000",
                    address: "安徽省芜湖市湾沚区 安徽信息工程学院",
                },
                desc: "真正的下单：扣库存 + 建订单在 DataStore 里加了锁，不会超卖。\n下完之后购物车会自动清空。",
                test: [
                    ...tStatus(302, "状态码 302（下单成功）"),
                    ...tLocation("/mall/order/list", "跳到我的订单"),
                ],
            }),
            mk({
                name: "我的订单（取订单 id）",
                method: "GET",
                path: "/mall/order/list",
                cookie: "userJsid",
                desc: "只能看自己的订单。顺便把订单 id 抽出来，下一步取消它。",
                test: [
                    ...tStatus(200, "状态码 200"),
                    ...tLoggedContains("我的订单", "页面渲染出「我的订单」"),
                    ...tPickId("orderId", 'name="id" value="', "抽到订单 id 并存入 orderId", "max"),
                ],
            }),
            mk({
                name: "取消订单",
                method: "POST",
                path: "/mall/order/cancel",
                cookie: "userJsid",
                form: { id: "{{orderId}}" },
                desc: "只有「待发货」的订单能取消，取消之后库存会退回去。\n代码里还校验了「只能取消自己的订单」—— 不校验的话，把 id 一改就能取消别人的单。",
                test: [
                    ...tStatus(302, "状态码 302"),
                    ...tLocation("/mall/order/list", "跳回我的订单"),
                ],
            }),
            mk({
                name: "未登录 · 查我的订单被拦",
                method: "GET",
                path: "/mall/order/list",
                rawCookie: NO_SESSION,
                desc: "商城能随便逛，但「我的订单」必须登录。\n注意这个拦截是 Servlet 自己做的（它要的是「你是谁」，不是某个权限码），跟后台那套权限码不是一回事。",
                test: [
                    ...tStatus(302, "状态码 302（被踢去登录）"),
                    ...tLocation("/login", "Location 指向 /login"),
                ],
            }),
        ],
    },

    /* ---------- 07 图片接口 ---------- */
    {
        name: "07 图片接口",
        item: [
            mk({
                name: "图片 · 路径穿越防御",
                method: "GET",
                path: "/img",
                rawCookie: NO_SESSION,
                query: [["name", "../../WEB-INF/web.xml"]],
                desc: "安全用例：故意传一个带 ../ 的文件名，想读服务器上的其他文件。\nUploads.resolve() 应该把它判成非法名字，返回 404 —— 绝不能真的把 web.xml 吐出来。\n这条接口在过滤器白名单里（游客要能看得见图），所以安全性全靠自己这道校验。",
                test: [
                    ...tStatus(404, "状态码 404（非法名字被拒）"),
                ],
            }),
            mk({
                name: "图片 · 文件不存在",
                method: "GET",
                path: "/img",
                rawCookie: NO_SESSION,
                query: [["name", "not-exist-123456.jpg"]],
                desc: "名字合法但文件没有，也是 404。\n「名字非法」和「文件不存在」对外统一报 404，不透露具体原因。",
                test: [
                    ...tStatus(404, "状态码 404"),
                ],
            }),
        ],
    },
];

/* ==================== 组装并落盘 ==================== */

const collection = {
    info: {
        name: "商品管理系统 · 后端接口与测试用例",
        description: [
            "课程作业：编写商品系统后端接口和测试用例。",
            "",
            "【这套接口长什么样】",
            "后端是 Servlet 6.1 + JSP，部署在 Tomcat 上，上下文路径 /shop。",
            "接口返回的是渲染好的 HTML 页面和 302 跳转 —— 不是 JSON。",
            "所以断言不能写 pm.response.json().data.id 那一套，",
            "只能查状态码、Location 响应头、以及页面里的关键字。",
            "",
            "【怎么用】",
            "1. 先把 Tomcat 跑起来：双击桌面的「启动商品管理系统.vbs」，",
            "   浏览器能打开 http://localhost:8080/shop/ 就算就绪。",
            "2. 先按顺序跑完「00 登录与权限」这一组。它里面的登录请求会把会话 ID",
            "   存进变量 adminJsid / userJsid / tempJsid，后面的请求才有身份。",
            "   顺序不能乱：退出登录会把会话作废，所以它单独用了一个临时会话，",
            "   不然 adminJsid 一废，后面整片都会红。",
            "3. 再按顺序跑其他分组。带写操作的分组（01/02/03）会真的改数据 ——",
            "   测试数据都带时间戳，不会和之前的打架；想完全恢复初始数据，重启一次 Tomcat 就行",
            "   （数据是存在内存里的）。",
            "",
            "【变量】",
            "adminJsid / userJsid —— 两个账号的会话 ID，登录接口自动写入。",
            "pid / delPid / catId / brandId / orderId —— 从页面里抠出来的各种 id，自动写入。",
            "testProductName / testCatName / testBrandName —— 每次跑都带时间戳，自动生成。",
            "换端口或换机器，把每个请求 URL 里的 localhost:8080 全局替换掉即可。",
            "",
            "【三个提醒，都会让用例莫名其妙变红 —— 跑之前先花一分钟设好】",
            "",
            "提醒 1（最重要）· 关掉「自动跟随重定向」。",
            "   位置：设置 → 通用 → Headers → 取消勾选「自动跟随重定向」。",
            "   为什么：本项目的接口大量用 302 表达结果（登录成功、新增成功、未登录被拦…）。",
            "   Apifox 默认会把 302 自动走完，于是你看到的是「200 + 跳转后的页面」，",
            "   Location 和 Set-Cookie 两个响应头全都被吞掉。后果是：",
            "   · 期望 302 的断言全红，但报的是页面内容对不上，完全看不出原因；",
            "   · 会话变量 adminJsid 存不进去，后面所有带身份的接口连锁变成登录页。",
            "   ※ 关掉之后，登录请求应该返回 302、Location 是 /mall，这才是对的。",
            "",
            "提醒 2 · 「校验响应」（契约测试）—— 本集合已经替你摆平了，但仍建议关掉。",
            "   它是拿接口文档里定义的「返回响应」去比实际响应。默认定义是 200 + JSON，",
            "   而本项目的接口返回 302 跳转和 HTML 页面，于是会挂两条红：",
            "   ① 实际状态码 302 与定义的 200 不一致；② 返回的数据格式不是 JSON。",
            "   ★ 本集合已为每个接口写好了真实的返回响应（302 / 200 / 403 / 404），",
            "     重新导入后这两条红应该自动消失。",
            "   ★ 如果还有残留（旧集合没删干净），最省事的做法是直接关掉它：",
            "     项目设置 → 功能设置 → 响应校验设置，把【校验内容】里的两项关掉：",
            "       · 校验响应 HTTP 状态码   ← 报「实际 200 / 定义 302」的就是它",
            "       · 校验响应 Body 的数据结构 ← 报「数据格式不是 JSON」的是它",
            "     该页面没有总开关，也不用管上面那 3 个「模块功能开关」（它们只管显不显示）。",
            "     或者在单条请求界面上关掉「校验响应」开关（只对当前接口生效）。",
            "   注意：它报红不代表接口坏了，只是文档定义和实际不一致。",
            "   关掉它也≠放弃测试：状态码的真正检查在每个请求「测试」页签的脚本里，照常跑。",
            "   ★ 同一个接口本来就可能有好几种结果，本集合已经按「允许范围」处理过了：",
            "     比如 POST /login —— 登录成功是 302 跳 /mall，账号密码没填是 200 留在登录页。",
            "     本集合给它写了【两条】返回响应（302 成功 + 200 报错），",
            "     Apifox 在文档定义了多个状态码时是按「允许范围」校验的，所以两种都不报红。",
            "     凡是「带身份 200 / 不带身份 302」「参数合法 302 / 参数不合法 200」的接口，",
            "     都这样成对定义了，点开接口的「返回响应」就能看到。",
            "     注意：改用例里的断言消除不了校验响应的红 —— 它比的是接口文档定义，",
            "     不是用例的断言。真要让红彻底不出现，唯一 100% 的办法是关掉这个开关。",
            "",
            "提醒 3 · Cookie：本集合已经自己处理好了，你不用管。",
            "   本集合靠自己往请求头里塞 JSESSIONID 来切换身份（登录接口把会话存进",
            "   变量 adminJsid / userJsid，其他接口再用它拼 Cookie 头）。",
            "   而 Apifox 还有一个「自动 Cookie 管理」（Cookie 管理弹窗左下角的",
            "   「启用全局 Cookie」）：只要之前登录过一次，它就把那个 JSESSIONID 记在",
            "   jar 里、后续请求自动带上 —— 对「未登录」用例是致命的：请求身上挂了两个",
            "   JSESSIONID，Tomcat 取到有效那个，就判你已登录，返回 200 而不是 302。",
            "   ✔ 本集合的「未登录」用例都带了一段前置脚本，会先清空 Apifox 的 Cookie",
            "     再发请求，所以开不开那个开关都不影响。你不需要手动清 Cookie。",
            "   如果你在界面上还想更保险：Cookie 管理弹窗点「清空」即可。",
        ].join("\n"),
        schema: "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
    },
    item: groups,
};

writeFileSync(OUT, JSON.stringify(collection, null, 2), "utf8");

const count = groups.reduce((n, g) => n + g.item.length, 0);
console.log("已生成：" + OUT);
console.log("分组 " + groups.length + " 个，接口 " + count + " 个");
groups.forEach((g) => console.log("  " + g.name + " → " + g.item.length + " 个"));
