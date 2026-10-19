/**
 * 验证集合里那些「人话诊断」本身写对没有。
 *
 * 为什么必须单独测：回放脚本 verify-live.mjs 走的是 Node fetch，
 * **不会执行** Apifox 里那段 pm.test 脚本 —— 也就是说生成器拼出来的 JS
 * 有没有语法错、诊断分支对不对，回放是验不出来的。
 * 所以这里搭一个假的 pm 对象，把它真跑一遍。
 *
 * 用法：node test-diagnosis.mjs <登录页.html> <商品列表页.html>
 */
import { readFileSync } from 'node:fs';

const COLLECTION = 'D:/workpace/商品管理系统-Apifox接口集合.json';
const j = JSON.parse(readFileSync(COLLECTION, 'utf8'));

const scriptOf = (groupIdx, itemIdx) => {
    const r = j.item[groupIdx].item[itemIdx];
    return { name: r.name, code: r.event.find(e => e.listen === 'test').script.exec.join('\n') };
};

const loginPage = readFileSync(process.argv[2], 'utf8');
const listPage = readFileSync(process.argv[3], 'utf8');

/** 造一个最小的 pm，够跑我们的断言就行；断言结果 / 写入的变量 / console 输出都收集起来 */
function runScript(title, script, resp, expect) {
    const vars = {};
    const logs = [];
    const results = [];
    const find = (k) => Object.keys(resp.headers || {}).find(x => x.toLowerCase() === String(k).toLowerCase());
    const pm = {
        response: {
            code: resp.code,
            text: () => resp.body,
            headers: {
                get: (k) => { const h = find(k); return h ? resp.headers[h] : null; },
                all: () => Object.keys(resp.headers || {}).map(k => ({ key: k, value: resp.headers[k] })),
            },
            to: {
                have: {
                    status: (n) => { if (resp.code !== n) throw new Error('expected status ' + n + ' but got ' + resp.code); },
                },
            },
        },
        cookies: { get: (n) => ((resp.cookies || {})[n] !== undefined ? resp.cookies[n] : null) },
        expect: (v) => ({
            to: {
                include: (kw) => { if (!String(v).includes(kw)) throw new Error("expected ... to include '" + kw + "'"); },
                eql: () => { },
                above: () => { },
                not: { be: { null: () => { if (v === null) throw new Error('value is null'); } } },
            },
        }),
        test: (name, fn) => {
            try { fn(); results.push(['PASS', name, '']); }
            catch (e) { results.push(['FAIL', name, e.message]); }
        },
        environment: { set: (k, v) => { vars[k] = v; }, get: (k) => vars[k] },
    };

    new Function('pm', 'console', script)(pm, { log: (...a) => logs.push(a.join(' ')) });

    console.log('\n===== ' + title + ' =====');
    for (const [mark, name, err] of results) {
        console.log('  [' + mark + '] ' + name);
        if (err) console.log('         -> ' + err);
    }
    if (Object.keys(vars).length) console.log('  变量: ' + JSON.stringify(vars));
    return { results, vars, logs, expect };
}

let ok = true;
const fail = (msg) => { ok = false; console.log('  ✗ ' + msg); };

/* ---------- 场景 1/2：需要登录的页面 ---------- */
const listReq = scriptOf(1, 0);
{
    const r = runScript('场景 1 · 商品列表，但拿到的是登录页（会话没带上）', listReq.code,
        { code: 200, body: loginPage, headers: {} });
    if (!(r.results[0][0] === 'PASS' && r.results[1][0] === 'FAIL' && r.results[1][2].includes('拿到的是登录页')))
        fail('场景 1：应「状态码过 / 页面断言失败并提示拿到登录页」');
}
{
    const r = runScript('场景 2 · 商品列表，正常拿到页面', listReq.code,
        { code: 200, body: listPage, headers: {} });
    if (!r.results.every(x => x[0] === 'PASS')) fail('场景 2：应该两条全过');
}

/* ---------- 场景 3/4：登录接口 ---------- */
const loginReq = scriptOf(0, 0);
{
    // 关掉「自动跟随重定向」后：302 + Location + Set-Cookie，一切正常
    const r = runScript('场景 3 · 登录，自动跟随重定向【已关】→ 302', loginReq.code,
        {
            code: 302, body: '',
            headers: {
                Location: 'http://localhost:8080/shop/mall',
                'Set-Cookie': 'JSESSIONID=ABC123DEF456; Path=/shop; HttpOnly',
            },
        });
    if (!r.results.every(x => x[0] === 'PASS')) fail('场景 3：应该三条全过');
    if (r.vars.adminJsid !== 'ABC123DEF456') fail('场景 3：adminJsid 没存对，实际 = ' + r.vars.adminJsid);
}
{
    // 这就是小靳实际遇到的情形：200 + 商城页，Location / Set-Cookie 全被吞掉
    const r = runScript('场景 4 · 登录，自动跟随重定向【开着】→ 200（小靳实际遇到的）', loginReq.code,
        { code: 200, body: listPage, headers: {}, cookies: {} });
    if (!r.results[0][2].includes('自动跟随重定向'))
        fail('场景 4：状态码断言应明确指出「自动跟随重定向」并给出关闭路径');
    if (!r.results[2][2].includes('自动跟随重定向'))
        fail('场景 4：会话提取失败时也应指向这个设置');
}
{
    // 跟随重定向但 Cookie jar 里有会话 → 兜底路径要能救回来
    const r = runScript('场景 5 · 登录，跟随重定向但 Cookie jar 里有会话 → 兜底成功', loginReq.code,
        { code: 200, body: listPage, headers: {}, cookies: { JSESSIONID: 'ZZZ999' } });
    if (r.vars.adminJsid !== 'ZZZ999') fail('场景 5：兜底没生效，adminJsid = ' + r.vars.adminJsid);
}

/* ---------- 场景 6：请求没带参数（小靳真实踩的）---------- */
{
    // 用空表单跑「登录 · 管理员」：服务端返回 200 + 登录页，压根没跳转。
    // 以前这里会甩一句 "expected '' to include '/mall'"，误导成"重定向设置问题"。
    const r = runScript('场景 6 · 登录，Body 参数是空的 → 200 + 登录页（小靳实际踩的）', loginReq.code,
        { code: 200, body: loginPage, headers: {}, cookies: {} });
    const statusMsg = r.results[0][2] || '';
    const locMsg = r.results[1][2] || '';
    if (!statusMsg.includes('没登录成功')) fail('场景 6：状态码断言应指出「这次请求没登录成功」');
    if (!statusMsg.includes('请输入用户名')) fail('场景 6：应把页面上的错误提示原样抠出来（当前：' + statusMsg + '）');
    if (!locMsg.includes('没有发生跳转')) fail('场景 6：Location 断言应说「没有发生跳转」而不是怪重定向设置');
    if (locMsg.includes('自动跟随重定向')) fail('场景 6：Location 报错不该在"没登录成功"时说重定向的事');
    const saveMsg = r.results[2][2] || '';
    if (saveMsg.includes('自动跟随重定向')) fail('场景 6：会话提取失败也不该在"没登录成功"时怪重定向设置');
    if (!saveMsg.includes('没登录成功')) fail('场景 6：会话提取失败应指出「这次没登录成功」');
}

console.log('\n' + (ok ? '✓ 全部诊断逻辑验证通过' : '✗ 有诊断逻辑不符合预期'));
process.exit(ok ? 0 : 1);
