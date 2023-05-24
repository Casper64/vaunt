module vaunt

import db.pg
import vweb

type SkipGenerationResult = vweb.Result

pub struct Util {
pub:
	skip_generation SkipGenerationResult = SkipGenerationResult{}
pub mut:
	theme_css    string
	is_superuser bool
}

// get the correct url in your templates
// // usage: `@{app.article_url(app.db, article)}`
pub fn (u &Util) article_url(db pg.DB, article Article) string {
	if article.category_id != 0 {
		category := get_category_by_id(db, article.category_id) or { return '' }
		url := '/articles/${category.name}/${article.name}'
		return sanitize_path(url)
	}

	url := '/articles/${article.name}'
	return sanitize_path(url)
}

// 		Helper functions
// =============================

// get all categories
pub fn get_all_categories(db pg.DB) []Category {
	mut categories := sql db {
		select from Category order by name
	} or { []Category{} }

	return categories
}

pub fn get_category_by_id(db pg.DB, category_id int) !Category {
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
pub fn get_all_articles(db pg.DB) []Article {
	mut articles := sql db {
		select from Article order by created_at desc
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
pub fn get_all_articles_by_category(db pg.DB, category int) []Article {
	mut articles := sql db {
		select from Article where category_id == category order by created_at desc
	} or { []Article{} }

	for mut article in articles {
		if article.thumbnail != 0 {
			img := get_image(db, article.thumbnail) or { Image{} }
			article.image_src = img.src
		}
	}
	return articles
}

// get an article by id
pub fn get_article(db pg.DB, article_id int) !Article {
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
pub fn get_article_by_name(db pg.DB, _article_name string) !Article {
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
pub fn get_image(db pg.DB, image_id int) !Image {
	images := sql db {
		select from Image where id == image_id
	}!
	if images.len == 0 {
		return error('image was not found')
	}
	return images[0]
}

// get all types of tags
pub fn get_all_tags(db pg.DB) []Tag {
	tags := sql db {
		select from Tag where article_id == 0
	} or { []Tag{} }
	return tags
}

// get all tags that belong to an article
pub fn get_tags_from_article(db pg.DB, _article_id int) []Tag {
	tags := sql db {
		select from Tag where article_id == _article_id
	} or { []Tag{} }
	return tags
}

// get a tag by id
pub fn get_tag_by_id(db pg.DB, tag int) !Tag {
	tags := sql db {
		select from Tag where id == tag
	}!
	if tags.len == 0 {
		return error('tag with id "${tag}" does not exist')
	}
	return tags[0]
}
