module vaunt

import vweb.assets
import db.pg

pub struct Util {
pub mut:
	styles        []string
	asset_manager &assets.AssetManager = assets.new_manager()
}

// get the correct url in your templates with a category
// usage: `@{app.category_article_url(category.name, article.name)}`
pub fn (u &Util) category_article_url(category_name string, article_name string) string {
	mut url := '/articles/${category_name}/${article_name}'
	return sanitize_path(url)
}

// get the correct url in your templates
// // usage: `@{app.article_url(article.name)}`
pub fn (u &Util) article_url(article_name string) string {
	mut url := '/articles/${article_name}'
	return sanitize_path(url)
}

// get all categories
pub fn get_all_categories(mut db pg.DB) []Category {
	mut categories := sql db {
		select from Category order by name
	} or { []Category{} }

	return categories
}

pub fn get_category_by_id(mut db pg.DB, category_id int) !Category {
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
pub fn get_all_articles(mut db pg.DB) []Article {
	mut articles := sql db {
		select from Article order by created_at desc
	} or { []Article{} }

	for mut article in articles {
		if article.thumbnail != 0 {
			img := get_image(mut db, article.thumbnail) or { Image{} }
			article.image_src = img.src
		}
	}
	return articles
}

// get all articles by category id
pub fn get_all_articles_by_category(mut db pg.DB, category int) []Article {
	mut articles := sql db {
		select from Article where category_id == category order by created_at desc
	} or { []Article{} }

	for mut article in articles {
		if article.thumbnail != 0 {
			img := get_image(mut db, article.thumbnail) or { Image{} }
			article.image_src = img.src
		}
	}
	return articles
}

// get an article by id
pub fn get_article(mut db pg.DB, article_id int) !Article {
	mut articles := sql db {
		select from Article where id == article_id
	}!
	if articles.len == 0 {
		return error('article was not found')
	}

	if articles[0].thumbnail != 0 {
		img := get_image(mut db, articles[0].thumbnail) or { Image{} }
		articles[0].image_src = img.src
	}
	return articles[0]
}

// get an article by name
pub fn get_article_by_name(mut db pg.DB, _article_name string) !Article {
	// de-sanitize path
	article_name := _article_name.replace('-', ' ')
	mut articles := get_all_articles(mut db)

	for article in articles {
		if article.name.to_upper() == article_name.to_upper() {
			if articles[0].thumbnail != 0 {
				img := get_image(mut db, articles[0].thumbnail) or { Image{} }
				articles[0].image_src = img.src
			}

			return article
		}
	}

	return error('article was not found')
}

// get image by id
pub fn get_image(mut db pg.DB, image_id int) !Image {
	images := sql db {
		select from Image where id == image_id
	}!
	if images.len == 0 {
		return error('image was not found')
	}
	return images[0]
}
