/* hexo plugin: injects the Artalk comment widget ONLY on individual post
   pages (layout === 'post').

   Uses the after_render:html filter instead of after_post_render: appending
   the widget to post content pollutes every place that content is reused —
   the homepage post loop (duplicate id="artalk-comments" divs, comments all
   binding to the first one) and the Atom feed. Checking the rendered page
   layout guarantees exactly one widget per post page and none on
   index/archive/feed. */
'use strict';

const CDN = 'https://cdn.jsdelivr.net/npm/artalk@2/dist';

function widgetHtml(pageKey, pageTitle) {
  const key = JSON.stringify(pageKey || '');
  const title = JSON.stringify(pageTitle || '');
  // ARTALK_SITE_URL is injected by Railway template vars (default: comments
  // service's public domain). Falls back to same-origin /comment for local dev.
  const server = process.env.ARTALK_SITE_URL || '';
  // ARTALK_SITE_NAME must match the comments service's site_default (Artalk
  // backend rejects empty site_name with 400 "Site name cannot be empty").
  const site = process.env.ARTALK_SITE_NAME || 'My Hexo Blog';
  return [
    '<div id="artalk-comments" style="margin-top:56px"></div>',
    '<link rel="stylesheet" href="' + CDN + '/Artalk.css">',
    '<script src="' + CDN + '/Artalk.js"><\/script>',
    '<script>',
    '(function(){',
    '  var el = document.getElementById("artalk-comments");',
    '  if (!el) return;',
    '  Artalk.init({',
    '    el: el,',
    '    pageKey: ' + key + ' || location.pathname,',
    '    pageTitle: ' + title + ' || document.title,',
    '    server: ' + JSON.stringify(server) + ' || location.origin + "/comment",',
    '    site: ' + JSON.stringify(site) + ',',
    '    darkMode: false',
    '  });',
    '})();',
    '</script>'
  ].join('\n');
}

hexo.extend.filter.register('after_render:html', function (str, data) {
  if (!data || !data.page) return str;
  // Only single post pages get the widget. Index, archives, tags, pages
  // (about, etc.) and the feed are left untouched.
  if (data.page.layout !== 'post') return str;
  // Guard against double injection (e.g. multiple render passes).
  if (str.indexOf('id="artalk-comments"') !== -1) return str;

  const html = widgetHtml(data.page.path, data.page.title);
  // Insert before the closing article tag when present, else append.
  if (str.indexOf('</article>') !== -1) {
    return str.replace('</article>', html + '\n</article>');
  }
  return str + '\n' + html;
});
