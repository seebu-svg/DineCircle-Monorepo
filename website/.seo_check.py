"""Validate SEO output against the configured domain, without network access."""
from html.parser import HTMLParser
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET
from seo import SITE_URL, absolute

root=Path(__file__).parent
class Head(HTMLParser):
    def __init__(self): super().__init__(); self.meta={};self.canon=[];self.ids=[];self.h1=0;self.images=[]
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag=='meta': self.meta[a.get('name',a.get('property'))]=a.get('content')
        if tag=='link' and a.get('rel')=='canonical': self.canon.append(a['href'])
        if 'id' in a:self.ids.append(a['id'])
        if tag=='h1':self.h1+=1
        if tag=='img':self.images.append(a)

titles=set(); descriptions=set(); pages=list(root.rglob('*.html'))
for p in pages:
    s=p.read_text(); parsed=Head();parsed.feed(s)
    title=re.search('<title>(.*?)</title>',s).group(1)
    assert title not in titles, (p,'duplicate title'); titles.add(title)
    desc=parsed.meta['description']; assert desc and desc not in descriptions,(p,'duplicate description');descriptions.add(desc)
    assert parsed.h1==1,(p,'h1 count')
    assert len(parsed.ids)==len(set(parsed.ids)),(p,'duplicate IDs')
    for key in ['robots','og:title','og:description','og:image','og:image:alt','twitter:card','twitter:title','twitter:description']:assert parsed.meta.get(key),(p,key)
    for image in parsed.images:assert 'alt' in image and image.get('width') and image.get('height'),(p,'image attributes')
    if SITE_URL:
        expected=absolute(p.relative_to(root).as_posix())
        assert parsed.canon==[expected],(p,'canonical')
        assert parsed.meta['og:url']==expected
        assert parsed.meta['og:image'].startswith(SITE_URL+'/assets/images/')
        assert parsed.meta['twitter:image']==parsed.meta['og:image']
        data=json.loads(re.search(r'<script type="application/ld\+json">(.*?)</script>',s,re.S).group(1))
        graph=data['@graph'];assert graph[0]['url']==expected
        if p.name!='index.html':assert any(n['@type']=='BreadcrumbList' for n in graph)
    else:assert not parsed.canon
if SITE_URL:
    ns={'s':'http://www.sitemaps.org/schemas/sitemap/0.9'}
    locations=ET.parse(root/'sitemap.xml').findall('s:url/s:loc',ns)
    assert {n.text for n in locations}=={absolute(p.relative_to(root).as_posix()) for p in pages}
    assert f'Sitemap: {SITE_URL}/sitemap.xml' in (root/'robots.txt').read_text()
print(f'SEO checks passed for {len(pages)} pages; production URL configured: {bool(SITE_URL)}')
