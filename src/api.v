module vaunt

import vweb
import net.http
import net.urllib
import net.html
import orm
import os
import time
import json
import stbi

pub const (
	resizable_image_mimes = ['.png', '.jpg', '.jpeg', '.tga', '.bmp']
	small_image_size      = 640
	medium_image_size     = 1280
)

pub struct Api {
	vweb.Context
	secret string [vweb_global]
pub:
	middlewares map[string][]vweb.Middleware = {
		'/': [cors]
	}
	template_dir string [required; vweb_global]
	upload_dir   string [required; vweb_global]
	articles_url string [required; vweb_global]
pub mut:
	db orm.Connection [required]
}

// simple cors handler for admin panel dev server, that's also why you see method "options" on some routes
fn cors(mut ctx vweb.Context) bool {
	ctx.add_header('Access-Control-Allow-Origin', 'http://127.0.0.1:5173')
	ctx.add_header('Access-Control-Allow-Credentials', 'true')
	ctx.add_header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, access-control-allow-credentials,access-control-allow-origin')
	ctx.add_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
	return true
}

pub fn (mut app Api) before_request() {
	// fix for cors ...
	if app.req.method != .options {
		login_required_401(mut app.Context, app.secret)
	} else {
		cors(mut app.Context)
		app.ok('')
	}
}

// 			Categories
// ==========================
['/categories'; get; options]
pub fn (mut app Api) get_categories() vweb.Result {
	categories := get_all_categories(app.db)
	return app.json(categories)
}

['/categories'; post]
pub fn (mut app Api) create_category() vweb.Result {
	if is_empty('name', app.form) {
		app.set_status(400, '')
		return app.text('error: field "name" is required')
	}

	mut new_category := Category{
		name: capitalize_text_field(app.form['name'])
	}

	check_category_article_name_collision(app.db, new_category.name) or {
		app.set_status(400, '')
		return app.text(err.msg())
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

['/categories/:cat_id'; delete]
pub fn (mut app Api) delete_category(cat_id int) vweb.Result {
	sql app.db {
		delete from Category where id == cat_id
	} or {
		app.set_status(500, '')
		return app.text('error: could not delete category')
	}

	// update articles category_id
	sql app.db {
		update Article set category_id = 0 where category_id == cat_id
	} or {
		app.set_status(500, '')
		return app.text('error: could not update articles')
	}

	return app.ok('ok')
}

['/categories/:category_id'; put]
pub fn (mut app Api) update_category(category_id int) vweb.Result {
	if is_empty('name', app.form) {
		app.set_status(400, '')
		return app.text('error: field "name" is required')
	}

	new_name := capitalize_text_field(app.form['name'])

	current_category := get_category_by_id(app.db, category_id) or {
		app.set_status(400, '')
		return app.text('error: category does not exist')
	}

	if current_category.name != new_name {
		check_category_article_name_collision(app.db, new_name) or {
			app.set_status(400, '')
			return app.text(err.msg())
		}
	}

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
		articles := get_all_articles(app.db)
		return app.json(articles)
	} else {
		category_id := app.query['category'].int()
		articles := get_all_articles_by_category(app.db, category_id)
		return app.json(articles)
	}
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

	mut new_article := Article{
		name: sanitize_text_field(app.form['name'])
		category_id: app.form['category'].int()
		description: sanitize_text_field(app.form['description'])
		block_data: app.form['block_data']
	}

	if is_empty('show', app.form) == false {
		new_article.show = app.form['show'] == 'true'
	}

	check_category_article_name_collision(app.db, new_article.name) or {
		app.set_status(400, '')
		return app.text(err.msg())
	}

	sql app.db {
		insert new_article into Article
	} or {
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
		img_name := sanitize_text_field(app.form['thumbnail-name'])
		img_id, img_src := app.upload_image(article.id, 'thumbnail', img_name) or {
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

['/articles/md'; post]
pub fn (mut app Api) create_article_from_markdown() vweb.Result {
	mut fdata := app.files['markdown']
	if fdata.len != 1 {
		app.set_status(400, '')
		return app.text('error: must provide one file: "markdown"')
	}
	md := fdata[0].data

	blocks := get_blocks_from_markdown(md)
	app.form['block_data'] = json.encode(blocks)

	return app.create_article()
}

['/articles/:article_id'; get; options]
pub fn (mut app Api) get_article(article_id int) vweb.Result {
	article := get_article(app.db, article_id) or { return app.not_found() }
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
	article := get_article(app.db, article_id) or { return app.not_found() }
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
		showing := app.form['show'] == 'true'
		sql app.db {
			update Article set show = showing where id == article_id
		} or {
			app.set_status(500, '')
			return app.text('error: cannot change visibility')
		}
		return app.ok('')
	}

	// change category
	if is_empty('category_id', app.form) == false {
		new_category := app.form['category_id'].int()
		sql app.db {
			update Article set category_id = new_category where id == article_id
		} or {
			app.set_status(500, '')
			return app.text('error: cannot change visibility')
		}
	}

	// check if article exists
	current_article := get_article(app.db, article_id) or {
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
		img_name := sanitize_text_field(app.form['thumbnail-name'])
		img_id, img_src := app.upload_image(article_id, 'thumbnail', img_name) or {
			app.set_status(500, '')
			return app.text('error: failed to upload image')
		}

		sql app.db {
			update Article set thumbnail = img_id, image_src = img_src where id == article_id
		} or {
			app.set_status(500, '')
			return app.text('error: failed to update article')
		}
	}

	article_name := sanitize_text_field(app.form['name'])

	if current_article.name != article_name {
		check_category_article_name_collision(app.db, article_name) or {
			app.set_status(400, '')
			return app.text(err.msg())
		}
	}

	article_descr := sanitize_text_field(app.form['description'])
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

	replaced_name := img_name.replace('\r', '')

	upload_resized_images_from(fdata, replaced_name, img_dir)!

	upload_path := '/uploads/img/${replaced_name}'
	img := Image{
		name: replaced_name
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
	} or {
		app.set_status(500, '')
		return app.text('error: could not update article')
	}

	return app.ok('updated block')
}

// 			Tags
// ========================

['/tags'; get; options]
pub fn (mut app Api) get_tags() vweb.Result {
	tags := get_all_tags(app.db)
	return app.json(tags)
}

['/tags'; post]
pub fn (mut app Api) create_tag(name string, color string) vweb.Result {
	if name == '' || color == '' {
		app.set_status(400, '')
		return app.text('error: fields "name" and "color" are required')
	}

	check_tag_name_collision(app.db, name) or {
		app.set_status(400, '')
		return app.text(err.msg())
	}

	mut tag := Tag{
		name: sanitize_path(name)
		color: sanitize_text_field(color)
	}

	sql app.db {
		insert tag into Tag
	} or {
		app.set_status(500, '')
		return app.text('error: could not create tag')
	}

	tag.id = app.db.last_id()
	return app.json(tag)
}

['/tags'; put]
pub fn (mut app Api) update_tag() vweb.Result {
	tag_id := app.form['tag_id'].int()
	if tag_id == 0 || is_empty('name', app.form) || is_empty('color', app.form) {
		app.set_status(400, '')
		return app.text('error: fields "tag_id", "name" and "color" are required')
	}
	new_name := sanitize_path(app.form['name'])
	new_color := sanitize_text_field(app.form['color'])

	check_tag_name_collision_exclusive(app.db, new_name, tag_id) or {
		app.set_status(400, '')
		return app.text(err.msg())
	}

	mut base_tag := get_tag_by_id(app.db, tag_id) or {
		app.set_status(400, '')
		return app.text('error: no base tag with id "${tag_id}" exists')
	}

	if base_tag.article_id != 0 {
		app.set_status(400, '')
		return app.text('error: no base tag with id "${tag_id}" exists')
	}

	sql app.db {
		update Tag set name = new_name, color = new_color where name == base_tag.name
	} or {
		app.set_status(500, '')
		return app.text('error: could not update tag')
	}

	base_tag.name = new_name
	base_tag.color = new_color
	return app.json(base_tag)
}

['/tags/:article'; get; options]
pub fn (mut app Api) get_tags_from_article(article int) vweb.Result {
	tags := get_tags_from_article(app.db, article)
	return app.json(tags)
}

['/tags/:article'; post]
pub fn (mut app Api) add_tag_to_article(article int) vweb.Result {
	if is_empty('tag_id', app.form) {
		app.set_status(400, '')
		return app.text('error: field "tag_id" is required')
	}
	tag_id := app.form['tag_id'].int()

	mut tag := get_tag_by_id(app.db, tag_id) or {
		app.set_status(400, '')
		return app.text('error: tag with id "${tag_id}" does not exist')
	}
	tag.id = 0
	tag.article_id = article

	sql app.db {
		insert tag into Tag
	} or {
		eprintln(err.msg())
		app.set_status(500, '')
		return app.text('error: could not add tag to article')
	}

	tag.id = app.db.last_id()
	return app.json(tag)
}

['/tags/:tag_id'; delete]
pub fn (mut app Api) delete_tag(tag_id int) vweb.Result {
	if tag_id == 0 {
		app.set_status(400, '')
		return app.text('error: field "tag_id" is invalid')
	}

	base_tag := get_tag_by_id(app.db, tag_id) or {
		app.set_status(400, '')
		return app.text('error: no base tag with id "${tag_id}" exists')
	}

	if base_tag.article_id == 0 {
		// base tag so remove all tags
		sql app.db {
			delete from Tag where name == base_tag.name
		} or {
			app.set_status(500, '')
			return app.text('error: could not delete tag')
		}
	} else {
		// tag that belongs to an article
		sql app.db {
			delete from Tag where id == base_tag.id
		} or {
			app.set_status(500, '')
			return app.text('error: could not delete tag')
		}
	}

	return app.ok('')
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

	title_tag := document.get_tags_by_attribute_value('property', 'og:title')
	if title_tag.len > 0 {
		link_data.meta.title = title_tag[0].attributes['content']
	}
	description_tag := document.get_tags_by_attribute_value('property', 'og:description')
	if description_tag.len > 0 {
		link_data.meta.description = description_tag[0].attributes['content']
	}
	image_tag := document.get_tags_by_attribute_value('property', 'og:image')
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
		update Article set updated_at = time.now() where id == article_id
	} or {
		app.set_status(500, '')
		return app.text('error: could not update article, please try again later')
	}

	article := rows[0]
	blocks := article.block_data
	file := generate(blocks)

	// set file path accordingly when article has a category or not
	file_path, article_path := get_publish_paths(app.db, app.template_dir, article) or {
		app.set_status(400, '')
		return app.text('error: category of article "${article.name}" does not exist')
	}

	// create all directories for the category
	os.mkdir_all(os.dir(file_path)) or {
		app.set_status(500, 'file "${file_path}" is not writeable')
		return app.text('error writing file...')
	}

	mut f := os.create(file_path) or {
		app.set_status(500, 'file "${file_path}" is not writeable')
		return app.text('error writing file...')
	}

	f.write_string(file) or {
		app.set_status(500, 'could not write file "${article_id}.html"')
		return app.text('error writing file...')
	}

	f.close()

	return app.text('${app.articles_url}/${article_path}')
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

	mut fdata := app.files['image'][0]
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
	img_name := sanitize_text_field(app.form['image'])
	file_path := os.join_path(app.upload_dir, 'img', img_name)

	app.delete_image_file(article_id, file_path) or {
		app.set_status(500, '')
		return app.text(err.msg())
	}
	return app.ok('')
}

fn (mut app Api) delete_image_file(article_id int, file_path string) ! {
	mut img_url := os.join_path(os.base(app.upload_dir), 'img', os.base(file_path))
	// img url has '/' before it, because it needs to be available at all routes
	img_url = '/' + img_url
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

		// Also remove the image from the `small` and `medium` directory
		// ignore any errors since we don't know if the images will exist
		name := os.file_name(file_path)
		path_small := os.dir(file_path) + '/small/' + name
		path_medium := os.dir(file_path) + '/medium/' + name
		os.rm(path_small) or {}
		os.rm(path_medium) or {}
	} else {
		return error('image "${file_path}" does not exist')
	}
}

// 			Utility
// ==========================

// must_exist is a wrapper that returns an option if the element does not exist
fn must_exist[T](rows []T) ?T {
	if rows.len == 0 {
		return none
	} else {
		return rows[0]
	}
}

// is_empty can be used to check if a key in a map is undefined (interop with js)
fn is_empty(key string, form map[string]string) bool {
	return form[key] == '' || form[key] == 'undefined'
}

// sanitize_text_field removes unwanted characters from a text field
fn sanitize_text_field(value string) string {
	return value.replace('\r', '')
}

// capitalize_text_field converts `value` to lowercase and capitalizes it
fn capitalize_text_field(value string) string {
	mut new_value := value.to_lower()
	new_value = new_value.capitalize()
	return sanitize_text_field(new_value)
}

// sanitize_path converts `path` to lowercase and replaces spaces with '-'
fn sanitize_path(path string) string {
	mut new_path := path.to_lower()
	new_path = new_path.replace(' ', '-')
	return sanitize_text_field(new_path)
}

// check_category_article_name_collision returns an error if `name` collides
// with an article or category name
fn check_category_article_name_collision(db orm.Connection, name string) ! {
	converted_name := sanitize_path(name)

	all_categories := get_all_categories(db)
	for category in all_categories {
		category_name := sanitize_path(category.name)
		if category_name == converted_name {
			return error('A category with the name "${name}" already exists!')
		}
	}
	all_articles := get_all_articles(db)
	for article in all_articles {
		article_name := sanitize_path(article.name)
		if article_name == converted_name {
			return error('An article with the name "${name}" already exists!')
		}
	}
}

fn check_tag_name_collision(db orm.Connection, name string) ! {
	converted_name := sanitize_path(name)

	all_tags := get_all_tags(db)
	for tag in all_tags {
		if tag.name == converted_name {
			return error('A tag with the name "${name}" already exist!')
		}
	}
}

fn check_tag_name_collision_exclusive(db orm.Connection, new_name string, old_id int) ! {
	converted_new_name := sanitize_path(new_name)

	all_tags := get_all_tags(db)
	for tag in all_tags {
		if tag.id == old_id {
			continue
		} else if tag.name == converted_new_name {
			return error('A tag with the name "${new_name}" already exist!')
		}
	}
}

// get_publish_paths returns the file path for the html file and the according
// url WITHOUT '/articles/'
fn get_publish_paths(db orm.Connection, template_dir string, article &Article) !(string, string) {
	mut file_path := ''
	mut article_path := ''
	if article.category_id == 0 {
		file_path = os.join_path(template_dir, 'articles', '${article.name}.html')
		article_path = article.name
	} else {
		category := get_category_by_id(db, article.category_id) or {
			return error('error: category does not exist!')
		}
		file_path = os.join_path(template_dir, 'articles', category.name, '${article.name}.html')
		article_path = '${category.name}/${article.name}'
	}
	// always convert paths to lowercase and replace spaces by '-'
	file_path = sanitize_path(file_path)
	article_path = sanitize_path(article_path)
	return file_path, article_path
}

// upload_resized_images_from writes 3 images to `img_dir`: one small sized
// one medium sized and one full-sized if the image is large enough to allow 3 sizes.
fn upload_resized_images_from(fdata []u8, name string, img_dir string) ! {
	os.mkdir_all(img_dir)!

	ext := os.file_ext(name)

	// full sized image
	file_path := os.join_path(img_dir, name)
	mut f := os.create(file_path)!
	f.write(fdata)!
	f.close()

	// check if the file extension is supported for write
	if ext !in vaunt.resizable_image_mimes {
		return
	}

	img := stbi.load(file_path, desired_channels: 0)!

	// get minimum width/height to determine orientation
	landscape := img.width >= img.height

	mut new_width, mut new_height := 0, 0

	// small image
	if (landscape && img.width <= vaunt.small_image_size)
		|| (!landscape && img.height <= vaunt.small_image_size) {
		// image is already at full size
		return
	}
	small_file_path := os.join_path(img_dir, 'small', name)
	os.mkdir_all(os.join_path(img_dir, 'small'))!

	if landscape {
		new_width = vaunt.small_image_size
		new_height = int(f32(new_width) / f32(img.width) * f32(img.height))
	} else {
		new_height = vaunt.small_image_size
		new_width = int(f32(new_height) / f32(img.height) * f32(img.width))
	}

	sm_img := stbi.resize_uint8(img, new_width, new_height)!
	stbi_write_ext(sm_img, small_file_path)!

	// medium image
	if (landscape && img.width <= vaunt.medium_image_size)
		|| (!landscape && img.height <= vaunt.medium_image_size) {
		// image is already at full size
		return
	}
	medium_file_path := os.join_path(img_dir, 'medium', name)
	os.mkdir_all(os.join_path(img_dir, 'medium'))!

	if landscape {
		new_width = vaunt.medium_image_size
		new_height = int(f32(new_width) / f32(img.width) * f32(img.height))
	} else {
		new_height = vaunt.medium_image_size
		new_width = int(f32(new_height) / f32(img.height) * f32(img.width))
	}

	md_img := stbi.resize_uint8(img, new_width, new_height)!
	stbi_write_ext(md_img, medium_file_path)!
}

// stbi_write_ext calls the right `stbi_write_*` function for each file extension and
// returns an error if the file extension is unsupported.
fn stbi_write_ext(img &stbi.Image, path string) ! {
	match img.ext {
		'png' {
			stbi.stbi_write_png(path, img.width, img.height, img.nr_channels, img.data,
				img.width * 4)!
		}
		'jpeg', 'jpg' {
			println('write jpeg')
			stbi.stbi_write_jpg(path, img.width, img.height, img.nr_channels, img.data,
				100)!
		}
		'tga' {
			stbi.stbi_write_tga(path, img.width, img.height, img.nr_channels, img.data)!
		}
		'bmp' {
			stbi.stbi_write_bmp(path, img.width, img.height, img.nr_channels, img.data)!
		}
		else {
			return error('image extension is not recognized!')
		}
	}
}
