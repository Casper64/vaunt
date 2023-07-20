module vaunt

import vweb
import orm
import os
import json

type SkipGenerationResult = vweb.Result

pub struct Util {
mut:
	dev bool = true
pub:
	skip_generation SkipGenerationResult
pub mut:
	db           orm.Connection
	theme_css    vweb.RawHtml
	is_superuser bool
	s_html       string // used by Vaunt to generate html
}

// get the correct url in your templates
// usage: `href="@{app.article_url(article)} "`
pub fn (u &Util) article_url(article Article) vweb.RawHtml {
	if article.category_id != 0 {
		category := get_category_by_id(u.db, article.category_id) or { return '' }
		url := '/articles/${category.name}/${article.name}'
		return sanitize_path(u.url(url))
	}

	url := '/articles/${article.name}'
	return sanitize_path(u.url(url))
}

// article_html returns the html for that article
pub fn (u &Util) article_html(article_name string, template_dir string) !vweb.RawHtml {
	// If you press the `publish` button in the admin panel the html will be generated
	// and outputted to  `"[template_dir]/articles/[article_name].html"`.
	mut article_file := os.join_path(template_dir, 'articles', '${article_name}.html')

	// read the generated article html file
	return os.read_file(article_file)!
}

// category_article_html returns the html for that article with category
pub fn (u &Util) category_article_html(category_name string, article_name string, template_dir string) !vweb.RawHtml {
	// If you press the `publish` button in the admin panel the html will be generated
	// and outputted to  `"[template_dir]/articles/[category_name]/[article_name].html"`.
	mut article_file := os.join_path(template_dir, 'articles', category_name, '${article_name}.html')

	// read the generated article html file
	return os.read_file(article_file)!
}

// html_picture_from_article_thumbnail returns a `<picture>` tag containing the different
// sizes of the articles thumbnail, if they exist
pub fn (u &Util) html_picture_from_article_thumbnail(article Article) vweb.RawHtml {
	if article.thumbnail == 0 {
		return ''
	}

	return u.html_picture_from_image(article.thumbnail)
}

// html_picture_from_image returns a `<picture>` tag containing the different
//  sizes of the image, if they exist
pub fn (u &Util) html_picture_from_image(img_id int) vweb.RawHtml {
	img := sql u.db {
		select from Image where id == img_id
	} or { return '' }
	if img.len == 0 {
		return ''
	}

	return get_html_picture_from_src(img[0].src, '[${img[0].name}]')
}

// url adds '.html' after the url if the site is being generated
// usage: `href="@{app.url('/my-page')} "`
pub fn (u &Util) url(url string) vweb.RawHtml {
	if u.dev {
		return '${url}'
	} else {
		if url.ends_with('/') {
			return '${url}index.html'
		}
		return '${url}.html'
	}
}

// 		Table of Contents
// ============================

pub struct TOCBlock {
pub:
	// the header level: h1, h2, h3 etc.
	level int
	text  string
	// the id of the article element
	link string
}

[params]
pub struct TOCParams {
	// by default show h1-h3
	min_level int = 1
	max_level int = 3
}

// get_toc returns a table of contents markup for the headers of `article`
pub fn (u &Util) get_toc(article Article, params TOCParams) vweb.RawHtml {
	blocks := u.get_toc_blocks(article, params)
	return $tmpl('./templates/components/toc.html')
}

// get_toc_blocks returns a list of the header blocks that can be used to generate a
// table of contents
pub fn (u &Util) get_toc_blocks(article Article, params TOCParams) []TOCBlock {
	mut blocks := json.decode([]Block, article.block_data) or { []Block{} }

	mut toc_blocks := []TOCBlock{}

	for idx, block in blocks {
		if block.block_type != 'heading' {
			continue
		}

		data := json.decode(HeadingData, block.data) or { HeadingData{} }
		if !(data.level >= params.min_level && data.level <= params.max_level) {
			continue
		}

		toc_blocks << TOCBlock{
			level: data.level
			text: data.text
			link: '#' + sanitize_path(data.text) + '-' + idx.str()
		}
	}

	return toc_blocks
}

// 		Database Helpers
// =============================

pub fn (u &Util) get_all_articles() []Article {
	return get_all_articles(u.db)
}

pub fn (u &Util) get_articles_by_category(category int) []Article {
	return get_all_articles_by_category(u.db, category)
}

pub fn (u &Util) get_articles_by_tag(name string) []Article {
	return get_articles_by_tag(u.db, name)
}

pub fn (u &Util) get_article_by_name(name string) !Article {
	return get_article_by_name(u.db, name)
}

pub fn (u &Util) get_article_by_id(id int) !Article {
	return get_article(u.db, id)
}

pub fn (u &Util) get_all_categories() []Category {
	return get_all_categories(u.db)
}

pub fn (u &Util) get_category_by_id(id int) !Category {
	return get_category_by_id(u.db, id)
}

pub fn (u &Util) get_image_by_id(id int) !Image {
	return get_image(u.db, id)
}

pub fn (u &Util) get_all_tags() []Tag {
	return get_all_tags(u.db)
}

pub fn (u &Util) get_tags_from_article(article_id int) []Tag {
	return get_tags_from_article(u.db, article_id)
}

pub fn (u &Util) get_tag(name string) !Tag {
	return get_tag(u.db, name)
}

pub fn (u &Util) get_tag_by_id(id int) !Tag {
	return get_tag_by_id(u.db, id)
}

// 		Helper functions
// =============================

// get all categories
pub fn get_all_categories(db orm.Connection) []Category {
	mut categories := sql db {
		select from Category order by name
	} or { []Category{} }

	return categories
}

pub fn get_category_by_id(db orm.Connection, category_id int) !Category {
	mut rows := sql db {
		select from Category where id == category_id
	} or { []Category{} }

	if rows.len == 0 {
		return error('Category does not exist')
	} else {
		return rows[0]
	}
}

// get all articles
pub fn get_all_articles(db orm.Connection) []Article {
	mut articles := sql db {
		select from Article order by updated_at desc
	} or { []Article{} }

	for mut article in articles {
		if article.thumbnail != 0 {
			img := get_image(db, article.thumbnail) or { Image{} }
			article.image_src = img.src
		}
	}
	return articles
}

// get all articles by category id
pub fn get_all_articles_by_category(db orm.Connection, category int) []Article {
	mut articles := sql db {
		select from Article where category_id == category order by updated_at desc
	} or { []Article{} }

	for mut article in articles {
		if article.thumbnail != 0 {
			img := get_image(db, article.thumbnail) or { Image{} }
			article.image_src = img.src
		}
	}
	return articles
}

// get all articles that have the tag `tag_name`
pub fn get_articles_by_tag(db orm.Connection, _tag_name string) []Article {
	tag_name := sanitize_path(_tag_name)

	mut articles := get_all_articles(db)
	articles = articles.filter(fn [db, tag_name] (article Article) bool {
		tags := get_tags_from_article(db, article.id)
		return tags.filter(it.name == tag_name).len != 0
	})

	return articles
}

// get an article by id
pub fn get_article(db orm.Connection, article_id int) !Article {
	mut articles := sql db {
		select from Article where id == article_id
	}!
	if articles.len == 0 {
		return error('article was not found')
	}

	if articles[0].thumbnail != 0 {
		img := get_image(db, articles[0].thumbnail) or { Image{} }
		articles[0].image_src = img.src
	}
	return articles[0]
}

// get an article by name
pub fn get_article_by_name(db orm.Connection, _article_name string) !Article {
	// de-sanitize path
	article_name := _article_name.replace('-', ' ')
	mut articles := get_all_articles(db)

	for article in articles {
		if article.name.to_upper() == article_name.to_upper() {
			if articles[0].thumbnail != 0 {
				img := get_image(db, articles[0].thumbnail) or { Image{} }
				articles[0].image_src = img.src
			}

			return article
		}
	}

	return error('article was not found')
}

// get image by id
pub fn get_image(db orm.Connection, image_id int) !Image {
	images := sql db {
		select from Image where id == image_id
	}!
	if images.len == 0 {
		return error('image was not found')
	}
	return images[0]
}

// get all types of tags
pub fn get_all_tags(db orm.Connection) []Tag {
	tags := sql db {
		select from Tag where article_id == 0
	} or { []Tag{} }
	return tags
}

// get all tags that belong to an article
pub fn get_tags_from_article(db orm.Connection, _article_id int) []Tag {
	tags := sql db {
		select from Tag where article_id == _article_id
	} or { []Tag{} }
	return tags
}

// get a tag by name
pub fn get_tag(db orm.Connection, name string) !Tag {
	converted_name := sanitize_path(name)
	tags := sql db {
		select from Tag where name == converted_name && article_id == 0
	}!
	if tags.len == 0 {
		return error('tag with name "${name}" does not exist')
	}
	return tags[0]
}

// get a tag by id
pub fn get_tag_by_id(db orm.Connection, tag int) !Tag {
	tags := sql db {
		select from Tag where id == tag
	}!
	if tags.len == 0 {
		return error('tag with id "${tag}" does not exist')
	}
	return tags[0]
}

// Types

pub fn (a []Article) no_category() []Article {
	return a.filter(it.category_id == 0)
}

pub fn (a []Article) category(id int) []Article {
	return a.filter(it.category_id == id)
}

pub fn (a []Article) visible() []Article {
	return a.filter(it.show == true)
}

pub fn (a []Article) hidden() []Article {
	return a.filter(it.show == false)
}
