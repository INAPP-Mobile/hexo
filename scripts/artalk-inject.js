/* hexo plugin: injects the Artalk comment widget into every generated post.
   Uses the after_post_render filter (full post object), so no theme edits are
   required — the widget is appended to the post body before layout rendering. */
'use strict';

const CDN = 'https://cdn.jsdelivr.net/npm/artalk@2/dist';

function widgetHtml(pageKey, pageTitle) {
  const key = JSON.stringify(pageKey || '');
  const title = JSON.stringify(pageTitle || '');
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
    '    server: location.origin + "/comment",',
    '    darkMode: false',
    '  });',
    '})();',
    '</script>'
  ].join('\n');
}

hexo.extend.filter.register('after_post_render', function (data) {
  if (!data || !data.content) return data;
  if (data.content.indexOf('artalk-comments') !== -1) return data;
  data.content += '\n' + widgetHtml(data.path, data.title);
  return data;
});