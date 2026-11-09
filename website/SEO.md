# SEO configuration

Set `site_url` in `seo-config.json` to the actual production HTTPS origin, without a trailing slash or path. Then run `python3 build.py`. You can instead set `DINECIRCLE_SITE_URL` for deployment builds. Do not use preview URLs for production canonicals.

Every build generates page metadata, social cards, robots.txt, and, once the production origin is configured, canonical URLs, absolute sharing images, WebSite/WebPage/BreadcrumbList JSON-LD, and sitemap.xml. All 29 generated pages are included. Metadata uses existing visible content; no reviews, ratings, host identities, or dated events are invented.

Deploy the generated HTML, assets, robots.txt and sitemap.xml together. The hosting service must serve `/` from index.html. Redirect alternative domains and HTTP to the chosen HTTPS origin at the hosting layer. Register the production property in Google Search Console and submit `/sitemap.xml` after publishing. Confirm live indexing and structured data with Google's URL Inspection and Rich Results Test.

The site has illustrative host profiles and time-sensitive dining offers. Verify venue information, prices, offers and host details before production publication. No live deployment or Search Console submission is performed by the local build.
