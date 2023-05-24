module vaunt

import time

// SEO module

// TwitterCardType implement the meta twitter:card types
// see https://developer.twitter.com/en/docs/twitter-for-websites/cards/guides/getting-started
pub enum TwitterCardType {
	summary
	summary_large_image
	app
}

// Twitter SEO implementation
// see https://developer.twitter.com/en/docs/twitter-for-websites/cards/guides/getting-started
pub struct Twitter {
pub mut:
	card_type TwitterCardType [name: 'card'] = .summary
	// @username for the website used in the card footer.
	site string
	// @username for the content creator / author.
	creator string
	// all other properties of twitter. The map key is the property attribute
	// and the map value is the content attribute.
	// All properties are prefixed with 'twitter:'
	other_properties map[string]string
}

// OpenGraph article attributes; are filled in automatically for each article
// time fields must follow ISO_8601
pub struct OpenGraphArticle {
pub mut:
	published_time  string
	modified_time   string
	expiration_time string
	author          []string
	section         string
	tag             []string
}

// OpenGraph meta tags
// see https://ogp.me/
pub struct OpenGraph {
pub:
	// add this as `prefix="@app.seo.og.prefix"` attribute to the `html` tag in your page
	prefix string [skip] = 'og: https://ogp.me/ns#'
pub mut:
	title            string
	og_type          string           [name: 'type']
	image_url        string           [name: 'image']
	url              string
	description      string
	audio            string
	determiner       string
	locale           string
	locale_alternate []string         [name: 'locale:alternate']
	site_name        string
	video            string
	article          OpenGraphArticle
	// all other properties of opengraph. The map key is the property attribute
	// and the map value is the content attribute.
	// All properties are prefixed with 'og:'
	other_properties map[string]string
}

pub struct SEO {
pub mut:
	// twitter card configuration
	twitter Twitter
	// Open Graph configuration
	og OpenGraph
	// your websites url
	website_url string
	// your pages description. Is automatically set by `set_article`
	description string
	// If you need any other meta tags. The map key is the property attribute
	// and the map value is the content attribute.
	other_properties map[string]string
}

interface SEOInterface {
	seo voidptr
}

// set_article updates the seo meta tags with the data from `article` at url `url`
pub fn (mut seo SEO) set_article(article &Article, url string) {
	seo.og.title = article.name
	seo.og.og_type = 'article'
	seo.set_description(article.description)

	if article.thumbnail != 0 {
		seo.og.image_url = seo.website_url + article.image_src
	}

	published_time := time.parse(article.created_at) or { time.now() }
	seo.og.article.published_time = published_time.format_rfc3339()
	modified_time := time.parse(article.updated_at) or { time.now() }
	seo.og.article.modified_time = modified_time.format_rfc3339()

	seo.set_url(url)
}

// set_url sets the OG url with `website_url` as prefix
pub fn (mut seo SEO) set_url(url string) {
	if seo.website_url.ends_with('/') {
		// url starts with a '/'
		seo.og.url = seo.website_url + url[1..]
	} else {
		// don't let urls end with a '/'
		seo.og.url = seo.website_url + url
	}
}

pub fn (mut seo SEO) set_description(description string) {
	seo.description = description
	seo.og.description = description
}

// html returns the meta tags for the SEO configuration
pub fn (mut seo SEO) html() string {
	mut meta_tags := []string{}

	meta_tags << '<meta name="description" content="${seo.description}">'

	meta_tags << seo.get_meta_from(seo.og, create_og_meta)
	meta_tags << seo.get_meta_from(seo.og.article, create_og_article_meta)
	meta_tags << seo.get_meta_from(seo.twitter, create_twitter_meta)

	for key, val in seo.other_properties {
		meta_tags << create_meta(key, val)
	}

	return meta_tags.join_lines()
}

// get_meta_from generates loop over all fields of prop and returns an array of
// all meta tags outputted by the `to_meta` function
fn (seo &SEO) get_meta_from[T](prop T, to_meta fn (string, string) string) []string {
	mut meta_tags := []string{}

	$for field in T.fields {
		if 'skip' !in field.attrs {
			mut name := field.name

			// check for `name` attribute
			name_attr := field.attrs.filter(it.starts_with('name:'))
			if name_attr.len != 0 {
				// field has attribute `[name: '']`
				name = name_attr[0].all_after('name: ')
			}

			$if field.typ is string {
				if prop.$(field.name) != '' {
					meta_tags << to_meta(name, prop.$(field.name))
				}
			} $else $if field.typ is []string {
				for val in prop.$(field.name) {
					if val != '' {
						meta_tags << to_meta(name, val)
					}
				}
			} $else $if field.typ is $enum {
				meta_tags << to_meta(name, prop.$(field.name).str())
			} $else $if field.typ is map[string]string {
				for key, val in prop.$(field.name) {
					meta_tags << to_meta(key, val)
				}
			}
		}
	}
	return meta_tags
}

// meta tag generators

[inline]
fn create_og_meta(property string, content string) string {
	return '<meta property="og:${property}" content="${content}" />'
}

[inline]
fn create_og_article_meta(property string, content string) string {
	return '<meta property="article:${property}" content="${content}" />'
}

[inline]
fn create_twitter_meta(property string, content string) string {
	return '<meta property="twitter:${property}" content="${content}" />'
}

[inline]
fn create_meta(property string, content string) string {
	return '<meta property="${property}" content="${content}" />'
}

// generate_sitemap generates a `sitemap.xml` file for the `app`
fn generate_sitemap(urls []string) string {
	mut xml := $tmpl('./templates/sitemap.xml')
	// beautify
	return xml.replace('\n\n', '\n')
}
