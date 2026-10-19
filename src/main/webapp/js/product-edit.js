/*
 * 商品表单里「品牌」那一小块联动。
 *
 * 只干一件事：
 *   下拉选中「其他（自己输入）」时，把旁边的输入框解禁；
 *   选回具体品牌时，重新把它禁掉。
 *
 * 为什么用 disabled 当开关，而不是在提交前用 JS 把两个值拼成一个？
 *   因为「被禁用的控件不会被浏览器放进请求体」是浏览器给的保证。
 *   拿它当隔离带，服务端收到的品牌值永远只有一个、没有歧义，
 *   也就不需要靠什么魔法值去猜用户走了哪条路。
 *
 *   反过来，如果让 JS 在提交前拼值：JS 一旦没跑起来（被拦、报错、
 *   用户禁用），请求里带的还是老结构，服务端就得去猜。
 *   「尽量不依赖 JS」比「少写两行服务端代码」重要得多。
 *
 * @author 靳迎奥
 */
(function () {
    'use strict';

    var pick = document.getElementById('brandPick');     // 品牌下拉
    var typed = document.getElementById('brandCustom');   // 「其他」的手输框

    // 不是商品表单那张页面（或者页面结构改了），直接不干活，别抛错
    if (!pick || !typed) return;

    // 哨兵值由服务端渲染进 data-other，不在这里硬写字符串 ——
    // 两边各写一份的话，改了 Java 忘了改 JS，功能会静默失效
    var OTHER = pick.getAttribute('data-other');

    function sync(focusIfOther) {
        var isOther = pick.value === OTHER;

        // 只动输入框，绝不动下拉。
        // 下拉要是一起禁掉，用户落在「其他」状态后就再也切不回具体品牌了。
        typed.disabled = !isOther;

        if (isOther && focusIfOther) typed.focus();
    }

    // 页面刚打开时对齐一次。
    // 编辑一件「品牌不在下拉里」的老商品时，服务端已经把手输框渲染成可用的了，
    // 这时候不该再抢焦点去打扰人，所以传 false。
    sync(false);

    pick.addEventListener('change', function () {
        sync(true);
    });
})();
