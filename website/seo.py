"""SEO output shared by every page. Uses only the configured production origin."""
from pathlib import Path
from urllib.parse import urlsplit
from html import escape, unescape
import json
import os
import re
import xml.etree.ElementTree as ET

ROOT = Path(__file__).parent
IMAGE_SIZES = {'portrait_6.webp': (1024, 1024), 'portrait_5.webp': (1024, 1024), 'portrait_4.webp': (1024, 1024), 'portrait_3.webp': (1024, 1024), 'portrait_2.webp': (1024, 1024), 'portrait_1.webp': (1024, 1024), 'venue_rooftop.webp': (1264, 848), 'venue_interior.webp': (1264, 848), 'venue_bar.webp': (1264, 848), 'dish_tacos.webp': (1024, 1024), 'dish_sushi.webp': (1024, 1024), 'dish_steak.webp': (1024, 1024), 'dish_pasta.webp': (1024, 1024), 'dish_dessert.webp': (1024, 1024), 'dish_brunch.webp': (1024, 1024), 'hero_tasting.webp': (1536, 1024)}
CONFIG = json.loads((ROOT / 'seo-config.json').read_text())
SITE_URL = os.environ.get('DINECIRCLE_SITE_URL', CONFIG.get('site_url', '')).rstrip('/')
if SITE_URL:
    origin = urlsplit(SITE_URL)
    if origin.scheme != 'https' or not origin.hostname or origin.username or origin.password or origin.query or origin.fragment or origin.path:
        raise ValueError('site_url must be a production HTTPS origin, such as https://your-domain.com')


def absolute(path):
    return SITE_URL + '/' + ('' if path == 'index.html' else path)


def enhance_page(path, content):
    def size_image(match):
        tag = match.group(0)
        source = re.search(r'src="([^"]+)"', tag)
        size = IMAGE_SIZES.get(source.group(1).split('/')[-1]) if source else None
        if size and not re.search(r'\bwidth=', tag) and not re.search(r'\bheight=', tag):
            tag = tag[:-1] + f' width="{size[0]}" height="{size[1]}">'
        return tag
    content = re.sub(r'<img\b[^>]*>', size_image, content)
    title = unescape(re.search(r'<title>(.*?)</title>', content).group(1))
    description = unescape(re.search(r'<meta name="description" content="([^"]*)"', content).group(1))
    image_match = re.search(r'<meta property="og:image" content="([^"]*)"', content)
    image = image_match.group(1).removeprefix('../')
    image_alt = 'DineCircle: restaurants, cafés and shared dining in Karachi'
    for tag in re.findall(r'<img\b[^>]*>', content):
        if f'src="{image_match.group(1)}"' in tag:
            match = re.search(r'alt="([^"]*)"', tag)
            if match:
                image_alt = unescape(match.group(1))
                break
    extras = [
        '<meta name="robots" content="index, follow, max-image-preview:large">',
        '<meta property="og:locale" content="en_PK">',
        f'<meta property="og:image:alt" content="{escape(image_alt, quote=True)}">',
        '<meta name="twitter:card" content="summary_large_image">',
        f'<meta name="twitter:title" content="{escape(title, quote=True)}">',
        f'<meta name="twitter:description" content="{escape(description, quote=True)}">',
        f'<meta name="twitter:image:alt" content="{escape(image_alt, quote=True)}">',
    ]
    if SITE_URL:
        url = absolute(path)
        image_url = absolute(image)
        content = content.replace(image_match.group(0), f'<meta property="og:image" content="{escape(image_url, quote=True)}"')
        extras += [f'<link rel="canonical" href="{escape(url, quote=True)}">',
                   f'<meta property="og:url" content="{escape(url, quote=True)}">',
                   f'<meta name="twitter:image" content="{escape(image_url, quote=True)}">']
        website_id = SITE_URL + '/#website'
        page_node = {'@type': 'WebPage', '@id': url + '#webpage', 'url': url,
                     'name': title, 'description': description, 'inLanguage': 'en-PK',
                     'isPartOf': {'@id': website_id}, 'primaryImageOfPage': {'@type': 'ImageObject', 'url': image_url}}
        nodes = [page_node]
        if path == 'index.html':
            nodes += [{'@type': 'WebSite', '@id': website_id, 'url': absolute('index.html'),
                       'name': 'DineCircle', 'description': 'Your local guide to discovering where to eat and what’s worth going out for.',
                       'inLanguage': 'en-PK'}]
        else:
            labels = {'restaurants': 'Restaurants', 'experiences': 'Experiences', 'hosts': 'Hosts'}
            crumbs = [('Home', absolute('index.html'))]
            if '/' in path:
                parent = path.split('/')[0]
                crumbs.append((labels[parent], absolute(parent + '.html')))
            heading = re.search(r'<h1[^>]*>(.*?)</h1>', content, re.S)
            name = unescape(re.sub('<[^>]+>', '', heading.group(1))) if heading else title
            crumbs.append((name, url))
            breadcrumb_id = url + '#breadcrumb'
            page_node['breadcrumb'] = {'@id': breadcrumb_id}
            nodes.append({'@type': 'BreadcrumbList', '@id': breadcrumb_id, 'itemListElement': [
                {'@type': 'ListItem', 'position': i, 'name': label, 'item': link}
                for i, (label, link) in enumerate(crumbs, 1)]})
        data = json.dumps({'@context': 'https://schema.org', '@graph': nodes}, ensure_ascii=False).replace('<', '\\u003c')
        extras.append('<script type="application/ld+json">' + data + '</script>')
    return content.replace('</head>', '  ' + '\n  '.join(extras) + '\n</head>')


def write_crawl_files(paths):
    robots = 'User-agent: *\nAllow: /\n'
    if SITE_URL:
        namespace = 'http://www.sitemaps.org/schemas/sitemap/0.9'
        ET.register_namespace('', namespace)
        root = ET.Element('{' + namespace + '}urlset')
        for path in sorted(paths):
            entry = ET.SubElement(root, '{' + namespace + '}url')
            ET.SubElement(entry, '{' + namespace + '}loc').text = absolute(path)
        ET.ElementTree(root).write(ROOT / 'sitemap.xml', encoding='utf-8', xml_declaration=True)
        robots += '\nSitemap: ' + SITE_URL + '/sitemap.xml\n'
    else:
        (ROOT / 'sitemap.xml').unlink(missing_ok=True)
        print('SEO: production URL is not configured; canonical URLs, JSON-LD and sitemap await seo-config.json.')
    (ROOT / 'robots.txt').write_text(robots)
