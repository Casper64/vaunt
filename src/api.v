module vaunt

import vweb
import db.pg
import net.http
import net.urllib
import net.html
import os
import time
import json

pub struct Api {
	vweb.Context
pub:
	middlewares map[string][]vweb.Middleware = {
		'/': [cors]
	}
	template_dir string [required; vweb_global]
	upload_dir   string [required; vweb_global]
	articles_url string [required; vweb_global]
pub mut:
	db pg.DB [required; vweb_global]
}

// simple cors handler for admin panel dev server, that's also why you see method "options" on some routes
fn cors(mut ctx vweb.Context) bool {
	ctx.add_header('Access-Control-Allow-Origin', 'http://127.0.0.1:5173')
	ctx.add_header('Access-Control-Allow-Credentials', 'true')
	ctx.add_header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, access-control-allow-credentials,access-control-allow-origin')
	ctx.add_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
	return true
}

// 			Categories
// ==========================
['/categories'; get; options]
pub fn (mut app Api) get_categories() vweb.Result {
	categories := get_all_categories(mut app.db)
	return app.json(categories)
}

['/categories'; post]
pub fn (mut app Api) create_category() vweb.Result {
	if is_empty('name', app.form) {
		app.set_status(400, '')
		return app.text('error: field "name" is required')
	}

	mut new_category := Category{
		name: app.form['name']
	}

	sql app.db {
		insert new_category into Category
	} or {
		app.set_status(500, '')
		return app.text('error: could not make new category, please try again later.')
	}

	new_category.id = app.db.last_id()
	return app.json(new_category)
}

['/categories/:category_id'; get; options]
pub fn (mut app Api) get_category(category_id int) vweb.Result {
	rows := sql app.db {
		select from Category where id == category_id
	} or {
		app.set_status(500, '')
		return app.text('error: could not get category')
	}

	if rows.len == 0 {
		return app.not_found()
	} else {
		return app.json(rows[0])
	}
}

['/categories/:category_id'; delete]
pub fn (mut app Api) delete_category(category_id int) vweb.Result {
	sql app.db {
		delete from Category where id == category_id
	} or {
		app.set_status(500, '')
		return app.text('error: could not delete category')
	}

	return app.ok('ok')
}

['/categories/:category_id'; put]
pub fn (mut app Api) update_category(category_id int) vweb.Result {
	if is_empty('name', app.form) {
		app.set_status(400, '')
		return app.text('error: field "name" is required')
	}

	new_name := app.form['name']
	sql app.db {
		update Category set name = new_name where id == category_id
	} or {
		app.set_status(500, '')
		return app.text('error: could not update category')
	}

	return app.ok('ok')
}

// 			Articles
// ==========================

['/articles'; get; options]
pub fn (mut app Api) get_articles() vweb.Result {
	if is_empty('category', app.query) {
		articles := get_all_articles(mut app.db)
		return app.json(articles)
	} else {
		category_id := app.query['category'].int()
		articles := get_all_articles_by_category(mut app.db, category_id)
		return app.json(articles)
	}
}

['/articles'; post]
pub fn (mut app Api) create_article() vweb.Result {
	if is_empty('name', app.form) || is_empty('description', app.form)
		|| is_empty('category', app.form) {
		app.set_status(400, '')
		return app.text('error: field "name", "description" and "category" are required')
	}
	if is_empty('block_data', app.form) {
		app.set_status(400, '')
		return app.text('error: must provide default "block_data" when creating an article')
	}

	new_article := Article{
		name: app.form['name']
		category_id: app.form['category'].int()
		description: app.form['description']
		block_data: app.form['block_data']
	}

	sql app.db {
		insert new_article into Article
	} or {
		if err.msg().contains('unique') {
			app.set_status(400, '')
			return app.text('error: article with name "${new_article.name}" already exists!')
		}
		app.set_status(500, '')
		return app.text('error: inserting article into database has failed')
	}

	rows := sql app.db {
		select from Article where id == app.db.last_id()
	} or {
		app.set_status(500, '')
		return app.text('error: inserting article into database has failed')
	}

	mut article := rows[0] as Article

	if 'thumbnail' in app.files && is_empty('thumbnail-name', app.form) == false {
		img_id, img_src := app.upload_image(article.id, 'thumbnail', app.form['thumbnail-name']) or {
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
		article.thumbnail = img_id
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

	// remove all images used in that article
	img_blocks := app.get_all_image_blocks(article_id) or { []Block{} }
	mut img_urls := img_blocks.map(fn (block Block) string {
		img_data := json.decode(ImageData, block.data) or { ImageData{} }
		url := urllib.parse(img_data.file['url']) or { urllib.URL{} }
		return url.path[1..]
	})

	// get img of article
	article := get_article(mut app.db, article_id) or { return app.not_found() }
	img_rows := sql app.db {
		select from Image where id == article.thumbnail
	} or { []Image{} }
	if img_rows.len != 0 {
		img_urls << img_rows[0].src
	}

	// delete all images
	for url in img_urls {
		file_path := os.join_path(app.upload_dir, 'img', os.base(url))
		app.delete_image_file(article_id, file_path) or {}
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

	// change visibility
	if is_empty('show', app.form) == false {
		showing := app.form['show']
		sql app.db {
			update Article set show = showing where id == article_id
		} or {
			app.set_status(500, '')
			return app.text('error: cannot change visibility')
		}
		return app.ok('')
	}

	// change category
	if is_empty('category', app.form) == false {
		new_category := app.form['category'].int()
		sql app.db {
			update Article set category_id = new_category where id == article_id
		} or {
			app.set_status(500, '')
			return app.text('error: cannot change visibility')
		}
		return app.ok('')
	}

	// check if article exists
	get_article(mut app.db, article_id) or {
		app.set_status(400, '')
		return app.text('error: article with id "${article_id}" does not exist')
	}

	// TODO: split?
	if is_empty('name', app.form) || is_empty('description', app.form) {
		app.set_status(400, '')
		return app.text('error: field "name" and "description" are required')
	}
	if 'thumbnail' in app.files && is_empty('thumbnail-name', app.form) == false {
		// TODO: remove old thumbnail img + plus check if its used elsewhere

		img_id, _ := app.upload_image(article_id, 'thumbnail', app.form['thumbnail-name']) or {
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

// 			Images
// ==========================

// upload_image returns the Image id and the path of the uploaded file
fn (mut app Api) upload_image(article_id int, file_key string, img_name string) !(int, string) {
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
		article_id: article_id
	}

	sql app.db {
		insert img into Image
	}!
	return app.db.last_id(), upload_path
}

// get_all_image_blocks returns all blocks with type="image" of an article with id=`aritcle_id`
fn (mut app Api) get_all_image_blocks(article_id int) ![]Block {
	article := sql app.db {
		select from Article where id == article_id
	}![0]

	blocks := json.decode([]Block, article.block_data)!
	return blocks.filter(it.block_type == 'image')
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

// used in editorjs Image block
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

	// change visibility
	sql app.db {
		update Article set show = true where id == article_id
	} or {
		app.set_status(500, '')
		return app.text('error: could not update article, please try again later')
	}

	article := rows[0]
	blocks := article.block_data
	file := generate(blocks)

	file_path := os.join_path(app.template_dir, 'articles', '${article_id}.html')
	mut f := os.create(file_path) or {
		app.set_status(500, 'file "${file_path}" is not writeable')
		return app.text('error writing file...')
	}

	f.write_string(file) or {
		app.set_status(500, 'could not write file "${article_id}.html"')
		return app.text('error writing file...')
	}

	f.close()

	return app.text('${app.articles_url}/${article.id}')
}

// 			Files
// ==========================

pub struct ImageBlockResponse {
pub mut:
	success int
	file    map[string]string
}

['/upload-image'; options; post]
pub fn (mut app Api) upload_image_endpoint() vweb.Result {
	// cors
	if app.req.method == .options {
		return app.ok('')
	}

	if is_empty('article', app.form) {
		app.set_status(400, '')
		return app.text('error: field "article" is required')
	}
	article_id := app.form['article'].int()

	if 'image' !in app.files {
		app.set_status(400, '')
		return app.text('error: field "image" is required in files')
	}

	fdata := app.files['image'][0]
	if fdata.filename == '' {
		app.set_status(400, '')
		return app.text('error: must provide an image name')
	}

	mut response := ImageBlockResponse{}

	_, img_src := app.upload_image(article_id, 'image', fdata.filename) or {
		response.success = 0

		app.set_status(500, '')
		return app.json(response)
	}

	response.success = 1
	response.file['url'] = img_src

	return app.json(response)
}

['/delete-image'; options; post]
pub fn (mut app Api) delete_image_endpoint() vweb.Result {
	// cors
	if app.req.method == .options {
		return app.ok('')
	}

	if is_empty('image', app.form) || is_empty('article', app.form) {
		app.set_status(400, '')
		return app.text('error: fields "image" and "article" are required')
	}

	article_id := app.form['article'].int()
	file_path := os.join_path(app.upload_dir, 'img', app.form['image'])

	app.delete_image_file(article_id, file_path) or {
		app.set_status(500, '')
		return app.text(err.msg())
	}
	return app.ok('')
}

fn (mut app Api) delete_image_file(article_id int, file_path string) ! {
	img_url := os.join_path(os.base(app.upload_dir), 'img', os.base(file_path))
	// ignore for now, won't affect anything if this stays in the database
	sql app.db {
		delete from Image where src == img_url && article_id == article_id
	} or {}

	// check if the image has any references outside of the article
	// TODO: fix the case where an article has two times the same image
	references := sql app.db {
		select count from Image where src == img_url && article_id != article_id
	} or { 0 }

	if references > 0 {
		return
	}
	// no other references to the image so we can safely delete it

	// prevent directory traversal
	if file_path.starts_with(app.upload_dir) == false {
		return error('invalid filename')
	}
	if os.exists(file_path) {
		os.rm(file_path)!
	} else {
		return error('image "${file_path}" does not exist')
	}
}

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

// get all categories
pub fn get_all_categories(mut db pg.DB) []Category {
	mut categories := sql db {
		select from Category order by name
	} or { []Category{} }

	return categories
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
