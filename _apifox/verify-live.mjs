/**
 * 把 Apifox 接口集合里的 50 条用例，用 Node 原样跑一遍。
 *
 * 目的不是替代 Apifox，而是在交出去之前先确认：
 * 接口地址、参数名、断言里引用的那些关键字，全都对得上。
 * 跑完再看 Apifox 那边就不会有「红一片」的意外。
 *
 * 跑之前 Tomcat 必须是启动状态。
 */

const BASE = "http://localhost:8080/shop";
const NO_SESSION = "THIS-SESSION-ID-IS-NOT-LOGGED-IN";

let pass = 0, fail = 0;
const out = [];

function ck(name, cond, extra) {
    if (cond) { pass++; out.push("  [OK]   " + name); }
    else { fail++; out.push("  [FAIL] " + name + (extra ? "   << " + extra : "")); }
}

async function req(method, path, opt) {
    opt = opt || {};
    let qs = "";
    if (opt.query) qs = "?" + new URLSearchParams(opt.query).toString();

    const headers = {};
    if (opt.cookie) headers["Cookie"] = "JSESSIONID=" + opt.cookie;

    let body;
    if (opt.multipart) {
        const fd = new FormData();
        Object.keys(opt.multipart).forEach((k) => fd.append(k, opt.multipart[k]));
        body = fd;
    } else if (opt.form) {
        headers["Content-Type"] = "application/x-www-form-urlencoded; charset=UTF-8";
        body = new URLSearchParams(opt.form).toString();
    }

    const res = await fetch(BASE + path + qs, { method, headers, body, redirect: "manual" });
    const text = await res.text();
    const sc = res.headers.getSetCookie ? res.headers.getSetCookie().join(";") : "";
    return {
        status: res.status,
        location: res.headers.get("location") || "",
        setCookie: sc,
        text: text,
    };
}

const sidOf = (r) => {
    const m = (r.setCookie || "").match(/JSESSIONID=([^;\s]+)/);
    return m ? m[1] : null;
};
const countIn = (text, sep) => text.split(sep).length - 1;

/* ==================== 开始 ==================== */

out.push("【00 登录与权限】");

const loginAdmin = await req("POST", "/login", { form: { username: "admin", password: "123456", redirect: "/mall" } });
ck("登录管理员 302", loginAdmin.status === 302, "实际 " + loginAdmin.status);
ck("登录管理员跳 /mall", loginAdmin.location.includes("/mall"), loginAdmin.location);
const adminSid = sidOf(loginAdmin);
ck("拿到 adminJsid", !!adminSid);

const loginUser = await req("POST", "/login", { form: { username: "user", password: "123456", redirect: "/mall" } });
ck("登录普通用户 302", loginUser.status === 302, "实际 " + loginUser.status);
const userSid = sidOf(loginUser);
ck("拿到 userJsid", !!userSid);

const badPwd = await req("POST", "/login", { form: { username: "admin", password: "wrong-password" } });
ck("密码错误 200", badPwd.status === 200, "实际 " + badPwd.status);
ck("密码错误有提示", badPwd.text.includes("用户名或密码错误"));

const noUser = await req("POST", "/login", { form: { username: "", password: "123456" } });
ck("用户名为空 200", noUser.status === 200, "实际 " + noUser.status);
ck("用户名为空有提示", noUser.text.includes("请输入用户名"));

const anonDash = await req("GET", "/dashboard", { cookie: NO_SESSION });
ck("未登录访问后台 302", anonDash.status === 302, "实际 " + anonDash.status);
ck("未登录跳 /login", anonDash.location.includes("/login"), anonDash.location);
ck("未登录带 redirect", anonDash.location.includes("redirect="));

const userDash = await req("GET", "/dashboard", { cookie: userSid });
ck("普通用户工作台 200", userDash.status === 200, "实际 " + userDash.status);
ck("工作台有内容", userDash.text.includes("工作台"));

const userAdd = await req("GET", "/product/add", { cookie: userSid });
ck("普通用户访问新增页 403", userAdd.status === 403, "实际 " + userAdd.status);
ck("403 页面文案", userAdd.text.includes("没有权限"));

const userDel = await req("POST", "/product/delete", { cookie: userSid, form: { id: "1" } });
ck("普通用户删除商品 403", userDel.status === 403, "实际 " + userDel.status);

const tempLogin = await req("POST", "/login", { form: { username: "admin", password: "123456" } });
ck("临时会话登录 302", tempLogin.status === 302, "实际 " + tempLogin.status);
const tempSid = sidOf(tempLogin);
ck("拿到 tempJsid", !!tempSid);

const logout = await req("GET", "/logout", { cookie: tempSid });
ck("退出登录 302", logout.status === 302, "实际 " + logout.status);
ck("退出后回 /login", logout.location.includes("/login"), logout.location);

const afterLogout = await req("GET", "/dashboard", { cookie: tempSid });
ck("退出后同会话访问后台 302", afterLogout.status === 302, "实际 " + afterLogout.status);
ck("会话确实失效", afterLogout.location.includes("/login"), afterLogout.location);

const adminStill = await req("GET", "/dashboard", { cookie: adminSid });
ck("adminJsid 未被退出影响", adminStill.status === 200, "实际 " + adminStill.status);

/* ---------- 01 商品 ---------- */
out.push("【01 后台 · 商品接口】");

const plist = await req("GET", "/product/list", { cookie: adminSid });
ck("商品列表 200", plist.status === 200, "实际 " + plist.status);
ck("列表含「商品列表」", plist.text.includes("商品列表"));

const pfilter = await req("GET", "/product/list", {
    cookie: adminSid,
    query: { category: "数码", minPrice: "100", maxPrice: "1000", sort: "priceDesc", page: "1" },
});
ck("组合筛选 200", pfilter.status === 200, "实际 " + pfilter.status);
ck("筛选条件回显", pfilter.text.includes("数码"));

const pEmpty = await req("GET", "/product/list", { cookie: adminSid, query: { keyword: "这个关键字肯定搜不到XYZ" } });
ck("空结果 200", pEmpty.status === 200, "实际 " + pEmpty.status);

const testName = "接口测试商品" + Date.now();
const add = await req("POST", "/product/add", {
    cookie: adminSid,
    multipart: { name: testName, category: "数码", brandPick: "小米", price: "19.90", stock: "5" },
});
ck("新增商品 302", add.status === 302, "实际 " + add.status);
ck("新增跳 /product/list", add.location.includes("/product/list"), add.location);

const addNeg = await req("POST", "/product/add", {
    cookie: adminSid,
    multipart: { name: "负价格商品", category: "数码", brandPick: "小米", price: "-5", stock: "1" },
});
ck("负价格被拦 302", addNeg.status === 302, "实际 " + addNeg.status);
ck("负价格退回 /product/add", addNeg.location.includes("/product/add"), addNeg.location);

const addNoBrand = await req("POST", "/product/add", {
    cookie: adminSid,
    multipart: { name: "缺品牌商品", category: "数码", brandPick: "__other__", brandCustom: "", price: "9.90", stock: "1" },
});
ck("选其他不填名 302", addNoBrand.status === 302, "实际 " + addNoBrand.status);
ck("退回 /product/add", addNoBrand.location.includes("/product/add"), addNoBrand.location);

const pfind = await req("GET", "/product/list", { cookie: adminSid, query: { keyword: testName } });
ck("按名字搜到 200", pfind.status === 200, "实际 " + pfind.status);
const editIds = pfind.text.split("/product/edit?id=").slice(1)
    .map((s) => parseInt(s, 10)).filter((n) => !isNaN(n));
ck("抽到商品 id", editIds.length > 0, "找到 " + editIds.length + " 条");
const delPid = Math.max.apply(null, editIds);

const editForm = await req("GET", "/product/edit", { cookie: adminSid, query: { id: String(delPid) } });
ck("编辑表单 200", editForm.status === 200, "实际 " + editForm.status);
ck("表单含「编辑商品」", editForm.text.includes("编辑商品"));

const editPost = await req("POST", "/product/edit", {
    cookie: adminSid,
    multipart: { id: String(delPid), name: testName, category: "数码", brandPick: "小米", price: "29.90", stock: "8" },
});
ck("修改商品 302", editPost.status === 302, "实际 " + editPost.status);
ck("修改跳 /product/list", editPost.location.includes("/product/list"), editPost.location);

const del = await req("POST", "/product/delete", { cookie: adminSid, form: { id: String(delPid) } });
ck("删除商品 302", del.status === 302, "实际 " + del.status);
ck("删除跳 /product/list", del.location.includes("/product/list"), del.location);

const pAfter = await req("GET", "/product/list", { cookie: adminSid, query: { keyword: testName } });
ck("删除后已无编辑链接", countIn(pAfter.text, "/product/edit?id=") === 0,
    "还剩 " + countIn(pAfter.text, "/product/edit?id=") + " 条");

/* ---------- 02 分类 ---------- */
out.push("【02 后台 · 分类接口】");

const catList = await req("GET", "/category", { cookie: adminSid });
ck("分类列表 200", catList.status === 200, "实际 " + catList.status);
ck("含「分类管理」", catList.text.includes("分类管理"));

const catName = "接口测试分类" + Date.now();
const catAdd = await req("POST", "/category/add", { cookie: adminSid, form: { name: catName, remark: "自动化测试新增" } });
ck("新增分类 302", catAdd.status === 302, "实际 " + catAdd.status);
ck("跳 /category", catAdd.location.includes("/category"), catAdd.location);

const catList2 = await req("GET", "/category", { cookie: adminSid });
const catIds = catList2.text.split('name="id" value="').slice(1)
    .map((s) => parseInt(s, 10)).filter((n) => !isNaN(n));
ck("抽到分类 id", catIds.length > 0, "找到 " + catIds.length + " 个");
const catId = Math.max.apply(null, catIds);
ck("新分类在页面上", catList2.text.includes(catName));

const catUpd = await req("POST", "/category/update", { cookie: adminSid, form: { id: String(catId), name: catName, remark: "注释改过了" } });
ck("修改分类 302", catUpd.status === 302, "实际 " + catUpd.status);

const catDel = await req("POST", "/category/delete", { cookie: adminSid, form: { id: String(catId) } });
ck("删除分类 302", catDel.status === 302, "实际 " + catDel.status);

/* ---------- 03 品牌 ---------- */
out.push("【03 后台 · 品牌接口】");

const brdList = await req("GET", "/brand", { cookie: adminSid });
ck("品牌列表 200", brdList.status === 200, "实际 " + brdList.status);
ck("含「品牌管理」", brdList.text.includes("品牌管理"));

const brdName = "接口测试品牌" + Date.now();
const brdAdd = await req("POST", "/brand/add", { cookie: adminSid, form: { name: brdName, remark: "自动化测试新增" } });
ck("新增品牌 302", brdAdd.status === 302, "实际 " + brdAdd.status);
ck("跳 /brand", brdAdd.location.includes("/brand"), brdAdd.location);

const brdList2 = await req("GET", "/brand", { cookie: adminSid });
const brdIds = brdList2.text.split('name="id" value="').slice(1)
    .map((s) => parseInt(s, 10)).filter((n) => !isNaN(n));
ck("抽到品牌 id", brdIds.length > 0, "找到 " + brdIds.length + " 个");
const brandId = Math.max.apply(null, brdIds);
ck("新品牌在页面上", brdList2.text.includes(brdName));

const brdUpd = await req("POST", "/brand/update", { cookie: adminSid, form: { id: String(brandId), name: brdName, remark: "注释改过了" } });
ck("修改品牌 302", brdUpd.status === 302, "实际 " + brdUpd.status);

const brdDel = await req("POST", "/brand/delete", { cookie: adminSid, form: { id: String(brandId) } });
ck("删除品牌 302", brdDel.status === 302, "实际 " + brdDel.status);

/* ---------- 04 订单后台 ---------- */
out.push("【04 后台 · 订单接口】");

const ordList = await req("GET", "/order", { cookie: adminSid });
ck("订单列表 200", ordList.status === 200, "实际 " + ordList.status);
ck("含「订单管理」", ordList.text.includes("订单管理"));

const ordFilter = await req("GET", "/order", { cookie: adminSid, query: { status: "待发货" } });
ck("按状态筛选 200", ordFilter.status === 200, "实际 " + ordFilter.status);

const ordUser = await req("GET", "/order", { cookie: userSid });
ck("普通用户也能看订单 200", ordUser.status === 200, "实际 " + ordUser.status);

const ordUpd = await req("POST", "/order/status", { cookie: userSid, form: { id: "1", status: "已发货" } });
ck("普通用户改订单状态 403", ordUpd.status === 403, "实际 " + ordUpd.status);

/* ---------- 05 商城 ---------- */
out.push("【05 前台 · 商城与购物车】");

const mall = await req("GET", "/mall", { cookie: NO_SESSION });
ck("商城首页游客 200", mall.status === 200, "实际 " + mall.status);
ck("含「全部商品」", mall.text.includes("全部商品"));
const pids = mall.text.split("/mall/item?id=").slice(1)
    .map((s) => parseInt(s, 10)).filter((n) => !isNaN(n));
ck("抽到商品 id", pids.length > 0, "找到 " + pids.length + " 个");
const pid = pids[0];

const mallFilter = await req("GET", "/mall", {
    cookie: NO_SESSION,
    query: { category: "数码", minPrice: "100", maxPrice: "2000", sort: "priceAsc", page: "1" },
});
ck("商城筛选 200", mallFilter.status === 200, "实际 " + mallFilter.status);

const itemPage = await req("GET", "/mall/item", { cookie: NO_SESSION, query: { id: String(pid) } });
ck("商品详情 200", itemPage.status === 200, "实际 " + itemPage.status);
ck("详情页是商城壳", itemPage.text.includes("优选商城"));

const cartAdd = await req("POST", "/mall/cart/add", { cookie: userSid, form: { id: String(pid), qty: "2" } });
ck("加购 302", cartAdd.status === 302, "实际 " + cartAdd.status);
ck("加购跳 /mall/cart", cartAdd.location.includes("/mall/cart"), cartAdd.location);

const cartPage = await req("GET", "/mall/cart", { cookie: userSid });
ck("购物车页 200", cartPage.status === 200, "实际 " + cartPage.status);
ck("含「购物车」", cartPage.text.includes("购物车"));

const cartSet = await req("POST", "/mall/cart/set", { cookie: userSid, form: { id: String(pid), qty: "3" } });
ck("改数量 302", cartSet.status === 302, "实际 " + cartSet.status);

const cartRm = await req("POST", "/mall/cart/remove", { cookie: userSid, form: { id: String(pid) } });
ck("移除一项 302", cartRm.status === 302, "实际 " + cartRm.status);

const cartClr = await req("POST", "/mall/cart/clear", { cookie: userSid });
ck("清空购物车 302", cartClr.status === 302, "实际 " + cartClr.status);

/* ---------- 06 前台订单 ---------- */
out.push("【06 前台 · 订单接口】");

const addAgain = await req("POST", "/mall/cart/add", { cookie: userSid, form: { id: String(pid), qty: "1" } });
ck("再次加购 302", addAgain.status === 302, "实际 " + addAgain.status);

const checkout = await req("GET", "/mall/order/checkout", { cookie: userSid });
ck("结算页 200", checkout.status === 200, "实际 " + checkout.status);
ck("含「确认订单」", checkout.text.includes("确认订单"));

const place = await req("POST", "/mall/order/checkout", {
    cookie: userSid,
    form: { receiver: "测试收货人", phone: "13800000000", address: "安徽省芜湖市湾沚区 安徽信息工程学院" },
});
ck("提交订单 302", place.status === 302, "实际 " + place.status);
ck("跳到我的订单", place.location.includes("/mall/order/list"), place.location);

const myOrders = await req("GET", "/mall/order/list", { cookie: userSid });
ck("我的订单 200", myOrders.status === 200, "实际 " + myOrders.status);
ck("含「我的订单」", myOrders.text.includes("我的订单"));
const orderIds = myOrders.text.split('name="id" value="').slice(1)
    .map((s) => parseInt(s, 10)).filter((n) => !isNaN(n));
ck("抽到订单 id", orderIds.length > 0, "找到 " + orderIds.length + " 个");
const orderId = Math.max.apply(null, orderIds);

const cancel = await req("POST", "/mall/order/cancel", { cookie: userSid, form: { id: String(orderId) } });
ck("取消订单 302", cancel.status === 302, "实际 " + cancel.status);

const anonOrders = await req("GET", "/mall/order/list", { cookie: NO_SESSION });
ck("未登录查订单 302", anonOrders.status === 302, "实际 " + anonOrders.status);
ck("未登录跳 /login", anonOrders.location.includes("/login"), anonOrders.location);

/* ---------- 07 图片 ---------- */
out.push("【07 图片接口】");

const traversal = await req("GET", "/img", { cookie: NO_SESSION, query: { name: "../../WEB-INF/web.xml" } });
ck("路径穿越 404", traversal.status === 404, "实际 " + traversal.status);
ck("没吐出 web.xml", !traversal.text.includes("web-app"));

const noFile = await req("GET", "/img", { cookie: NO_SESSION, query: { name: "not-exist-123456.jpg" } });
ck("文件不存在 404", noFile.status === 404, "实际 " + noFile.status);

/* ==================== 汇总 ==================== */

out.push("");
out.push("================================");
out.push("通过 " + pass + " 项，失败 " + fail + " 项");
out.push("================================");

const report = out.join("\n");
console.log(report);
process.stdout.write("");
await import("node:fs").then((fs) => fs.writeFileSync("D:/workpace/Calculator/_apifox/verify-live-result.txt", report, "utf8"));
