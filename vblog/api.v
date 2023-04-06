module vblog

import vweb
import db.pg
import net.http
import net.html
import os
import time

pub struct Api {
	vweb.Context
	middlewares map[string][]vweb.Middleware = {
		'/': [cors]
	}
	pages_dir    string [required; vweb_global]
	upload_dir   string [required; vweb_global]
	articles_url string [required; vweb_global]
pub mut:
	db pg.DB [required; vweb_global]
}

// simple cors
fn cors(mut ctx vweb.Context) bool {
	ctx.add_header('Access-Control-Allow-Origin', 'http://127.0.0.1:5173')
	ctx.add_header('Access-Control-Allow-Credentials', 'true')
	ctx.add_header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, access-control-allow-credentials,access-control-allow-origin')
	ctx.add_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
	return true
}

// 			Articles
// ==========================

// options request is only sent once??? Or per route
['/articles'; get; options]
pub fn (mut app Api) get_articles() vweb.Result {
	articles := get_all_articles(mut app.db)
	return app.json(articles)
}

['/articles'; post]
pub fn (mut app Api) create_article() vweb.Result {
	if is_empty('name', app.form) || is_empty('description', app.form) {
		app.set_status(400, '')
		return app.text('error: field "name" and "description" are required')
	}
	if is_empty('block_data', app.form) {
		app.set_status(400, '')
		return app.text('error: must provide default "block_data" when creating an article')
	}

	new_article := Article{
		name: app.form['name']
		description: app.form['description']
		block_data: app.form['block_data']
	}

	sql app.db {
		insert new_article into Article
	} or {}

	rows := sql app.db {
		select from Article where id == app.db.last_id()
	} or {
		app.set_status(500, '')
		return app.text('error: inserting article into database has failed')
	}

	mut article := rows[0] as Article

	if 'thumbnail' in app.files && is_empty('thumbnail-name', app.form) == false {
		img_id, img_src := app.upload_image('thumbnail', app.form['thumbnail-name']) or {
			app.set_status(500, '')
			return app.text('error: failed to upload image')
		}

		sql app.db {
			update Article set thumbnail = img_id where id == article.id
		} or {
			app.set_status(500, '')
			return app.text('error: failed to upload article image')
		}

		article.image_src = img_src
	}

	return app.json(article)
}

['/articles/:article_id'; get; options]
pub fn (mut app Api) get_article(article_id int) vweb.Result {
	article := get_article(mut app.db, article_id) or { return app.not_found() }
	return app.json(article)
}

['/articles/:article_id'; delete]
pub fn (mut app Api) delete_article(article_id int) vweb.Result {
	if article_id == 0 {
		app.set_status(400, '')
		return app.text('error: "id" is not a number')
	}

	sql app.db {
		delete from Article where id == article_id
	} or {
		app.set_status(500, '')
		return app.text('error: could not delete article')
	}

	return app.ok('deleted article with id ${article_id}')
}

['/articles/:article_id'; put]
pub fn (mut app Api) update_article(article_id int) vweb.Result {
	if article_id == 0 {
		app.set_status(400, '')
		return app.text('error: "id" is not a number')
	}

	if is_empty('name', app.form) || is_empty('description', app.form) {
		app.set_status(400, '')
		return app.text('error: field "name" and "description" are required')
	}

	if 'thumbnail' in app.files && is_empty('thumbnail-name', app.form) == false {
		img_id, _ := app.upload_image('thumbnail', app.form['thumbnail-name']) or {
			app.set_status(500, '')
			return app.text('error: failed to upload image')
		}

		sql app.db {
			update Article set thumbnail = img_id where id == article_id
		} or {
			app.set_status(500, '')
			return app.text('error: failed to update article')
		}
	}

	article_name := app.form['name']
	article_descr := app.form['description']
	sql app.db {
		update Article set name = article_name, description = article_descr where id == article_id
	} or {
		app.set_status(500, '')
		return app.text('error: failed to update article')
	}
	return app.ok('')
}

// upload_image returns the Image id and the path of the uploaded file
fn (mut app Api) upload_image(file_key string, img_name string) !(int, string) {
	img_dir := os.join_path(app.upload_dir, 'img')

	fdata := app.files[file_key][0].data.bytes()

	os.mkdir_all(img_dir)!

	file_path := os.join_path(img_dir, img_name)

	mut f := os.create(file_path)!

	f.write(fdata)!

	f.close()

	upload_path := 'uploads/img/${img_name}'

	img := Image{
		name: img_name
		src: upload_path
	}

	sql app.db {
		insert img into Image
	}!

	return app.db.last_id(), upload_path
}

// 			Blocks
// ==========================

['/blocks'; get; options]
pub fn (mut app Api) get_blocks() vweb.Result {
	if is_empty('article', app.query) {
		app.set_status(400, '')
		return app.text('error: query parameter "article" is not specified')
	}

	article_id := app.query['article'].int()

	rows := sql app.db {
		select from Article where id == article_id
	} or { return app.not_found() }

	if rows.len == 0 {
		return app.not_found()
	} else {
		app.send_response_to_client('application/json', rows[0].block_data)
		return app.ok('')
	}
}

['/blocks'; post]
pub fn (mut app Api) save_blocks() vweb.Result {
	if is_empty('article', app.query) {
		app.set_status(400, '')
		return app.text('error: query parameter "article" is not specified')
	}

	article_id := app.query['article'].int()
	sql app.db {
		update Article set block_data = app.req.data where id == article_id
		update Article set updated_at = time.now() where id == article_id
	} or {
		app.set_status(500, '')
		return app.text('error: could not update article')
	}

	return app.ok('updated block')
}

struct LinkData {
pub mut:
	link    string
	success int
	meta    struct {
	pub mut:
		title       string
		description string
		image       struct {
		pub mut:
			url string
		}
	}
}

// implement editor.js link backend --> https://github.com/editor-js/link
['/fetch-link'; get; options]
pub fn (mut app Api) fetch_link() vweb.Result {
	if is_empty('url', app.query) {
		return app.text('error: query parameter "url" is not specified')
	}

	link := app.query['url']

	mut link_data := LinkData{}

	response := http.get(link) or { return app.json(link_data) }
	// only parse the first 100.000 characters, not very error proof...
	mut res_str := response.bytestr()
	if res_str.len > 50000 {
		res_str = res_str[..50000]
	}
	mut document := html.parse(res_str)
	link_data.success = 1

	title_tag := document.get_tag_by_attribute_value('property', 'og:title')
	if title_tag.len > 0 {
		link_data.meta.title = title_tag[0].attributes['content']
	}
	description_tag := document.get_tag_by_attribute_value('property', 'og:description')
	if description_tag.len > 0 {
		link_data.meta.description = description_tag[0].attributes['content']
	}
	image_tag := document.get_tag_by_attribute_value('property', 'og:image')
	if image_tag.len > 0 {
		link_data.meta.image.url = image_tag[0].attributes['content']
	}

	return app.json(link_data)
}

['/publish'; get; options]
pub fn (mut app Api) publish_article() vweb.Result {
	if is_empty('article', app.query) {
		app.set_status(400, '')
		return app.text('error: query parameter "article" is required')
	}

	article_id := app.query['article'].int()

	rows := sql app.db {
		select from Article where id == article_id
	} or { []Article{} }

	if rows.len == 0 {
		return app.not_found()
	}
	blocks := rows[0].block_data
	file := generate(blocks)

	file_path := os.join_path_single(app.pages_dir, '${article_id}.html')
	mut f := os.create(file_path) or {
		app.set_status(500, 'file "${file_path}" is not writeable')
		return app.text('error writing file...')
	}

	f.write_string(file) or {
		app.set_status(500, 'could not write file "${article_id}.html"')
		return app.text('error writing file...')
	}

	f.close()

	return app.text('${app.articles_url}/${article_id}')
}

// 			Files
// ==========================

// ['/upload-image'; options; post]
// pub fn (mut app Api) upload_image() vweb.Result {
// 	return app.ok('uploaded image')
// }

// ['/upload-image-url'; options; post]
// pub fn (mut app Api) upload_image_url() vweb.Result {
// 	return app.ok('uploaded image url')
// }

// 			Utility
// ==========================

fn must_exist[T](rows []T) ?T {
	if rows.len == 0 {
		return none
	} else {
		return rows[0]
	}
}

fn is_empty(key string, form map[string]string) bool {
	return form[key] == '' || form[key] == 'undefined'
}

// get all articles
pub fn get_all_articles(mut db pg.DB) []Article {
	mut articles := sql db {
		select from Article order by updated_at desc
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
