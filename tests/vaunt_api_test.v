import os
import time
import json
import net.http
import db.pg
import vaunt

const (
	sport           = 12380
	localserver     = '127.0.0.1:${sport}'
	exit_after_time = 12000 // milliseconds
	vexe            = os.getenv('VEXE')
	serverexe       = os.join_path(os.cache_dir(), 'vaunt_test_server.exe')
	db_user         = 'dev'
	db_password     = 'password'
	db_name         = 'vaunt-test'

	vaunt_username  = 'admin'
	jwt_token       = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwIiwibmFtZSI6ImFkbWluIiwiaWF0IjoxNjg0MDkwMTgwfQ.OJvgvMZ2uS6odHQ6vfp9zMnV765ssH4bjcppDKUxS9k'
)

// setup of vaunt webserver
fn testsuite_begin() {
	if os.exists(serverexe) {
		os.rm(serverexe) or {}
	}
	if os.exists('tests/uploads/img') {
		os.rmdir_all('tests/uploads/img')!
	}
}

fn test_setup_database() {
	mut db := get_connection() or { panic(err) }
	db.drop('categories') or {}
	db.drop('articles') or {}
	db.drop('images') or {}
	db.drop('users') or {}
	db.drop('tags') or {}
}

fn test_vaunt_app_can_be_compiled() {
	did_server_compile := os.system('${os.quoted_path(vexe)} -o ${os.quoted_path(serverexe)} tests/vaunt_api_test_app.v')
	assert did_server_compile == 0
	assert os.exists(serverexe)
}

fn test_vaunt_runs_in_background() {
	mut suffix := ''
	$if !windows {
		suffix = ' > /dev/null &'
	}
	server_exec_cmd := '${os.quoted_path(serverexe)} ${sport} ${exit_after_time} ${db_user} ${db_password} ${db_name} ${suffix}'
	$if windows {
		spawn os.system(server_exec_cmd)
	} $else {
		res := os.system(server_exec_cmd)
		assert res == 0
	}
	$if macos {
		time.sleep(1000 * time.millisecond)
	} $else {
		time.sleep(100 * time.millisecond)
	}
}

fn test_route_authorized() {
	mut x := http.get('http://${localserver}/') or { panic(err) }
	assert x.status() == .ok

	x = http.get('http://${localserver}/auth/login') or { panic(err) }
	assert x.status() == .ok

	x = http.get('http://${localserver}/admin') or { panic(err) }
	assert x.status() == .ok
	assert x.body.contains('<title>Vaunt Login</title>') == true

	x = http.get('http://${localserver}/uploads') or { panic(err) }
	assert x.status() != .unauthorized
}

fn test_routes_unauthorized() {
	// Api App
	mut x := http.get('http://${localserver}/api/articles') or { panic(err) }
	assert x.status() == .unauthorized
	// ThemeHandler App
	x = http.get('http://${localserver}/api/theme') or { panic(err) }
	assert x.status() == .unauthorized
}

fn test_create_user() {
	mut db := get_connection() or { panic(err) }

	user := vaunt.User{
		username: vaunt_username
		// precalculated
		password: r'$2a$10$NgvETQhHdkWMc4sq3EzTbAbUmzs+ACZ0htSbOz4AJnSG1Js7PgAmc'
	}
	sql db {
		insert user into vaunt.User
	} or { panic(err) }
}

// 		Articles
// ==================

fn test_no_articles() {
	json_empty_articles := json.encode([]vaunt.Article{})
	x := do_get('http://${localserver}/api/articles') or { panic(err) }

	assert x.header.get(.content_type)! == 'application/json'
	assert x.body == json_empty_articles

	articles := json.decode([]vaunt.Article, x.body) or { panic(err) }
	assert articles.len == 0
}

fn test_create_article() {
	mut form := map[string]string{}

	// test errors
	mut x := do_post_form('http://${localserver}/api/articles', form) or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: field "name" and "description" are required'

	form['description'] = 'test description'
	x = do_post_form('http://${localserver}/api/articles', form) or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: field "name" and "description" are required'

	form['name'] = 'test'
	x = do_post_form('http://${localserver}/api/articles', form) or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: must provide default "block_data" when creating an article'

	form['block_data'] = '{}'
	x = do_post_form('http://${localserver}/api/articles', form) or { panic(err) }
	assert x.status() == .ok
	assert x.header.get(.content_type)! == 'application/json'

	// test response
	article := json.decode(vaunt.Article, x.body) or { panic(err) }
	assert x.status() == .ok
	assert article.name == form['name']
	assert article.description == form['description']
	assert article.block_data == form['block_data']

	// test inserted into database
	x = do_get('http://${localserver}/api/articles/${article.id}') or { panic(err) }
	assert x.status() == .ok
	fetched_article := json.decode(vaunt.Article, x.body) or { panic(err) }
	assert fetched_article == article
}

fn test_delete_article() {
	new_article := create_article('to_delete', 'should be deleted', '{}') or { panic(err) }

	mut x := do_get('http://${localserver}/api/articles') or { panic(err) }
	mut all_articles := json.decode([]vaunt.Article, x.body) or { panic(err) }
	prev_len := all_articles.len

	x = do_delete('http://${localserver}/api/articles/${new_article.id}') or { panic(err) }
	assert x.status() == .ok
	assert x.body == 'deleted article with id ${new_article.id}'

	x = do_get('http://${localserver}/api/articles') or { panic(err) }
	all_articles = json.decode([]vaunt.Article, x.body) or { panic(err) }
	assert prev_len == all_articles.len + 1
}

fn test_create_article_with_image() {
	// use text file instead of image but the concept works the same
	mut files := []http.FileData{}
	files << http.FileData{
		filename: 'image.txt'
		content_type: 'text/plain'
		data: '"Vaunt test"'
	}
	form_config := http.PostMultipartFormConfig{
		form: {
			'name':           'image'
			'description':    'image test'
			'block_data':     '{}'
			'thumbnail-name': 'image.txt'
		}
		files: {
			'thumbnail': files
		}
	}
	mut x := do_post_multipart_form('http://${localserver}/api/articles', form_config)!
	assert x.status() == .ok
	article := json.decode(vaunt.Article, x.body) or { panic(err) }
	assert article.thumbnail != 0
	assert article.image_src != ''

	// test if file exists in the uploads folder
	image_path := os.join_path('tests', article.image_src)
	assert os.exists(image_path) == true
	txt_data := os.read_file(image_path) or { panic(err) }
	assert txt_data == files[0].data

	// test if file is accessible via the Vaunt server
	x = do_get('http://${localserver}/${article.image_src}') or { panic(err) }
	assert x.header.get(.content_type)! == files[0].content_type
	assert x.body == files[0].data
}

fn test_delete_article_with_image() {
	mut x := do_delete('http://${localserver}/api/articles/s') or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: "id" is not a number'

	x = do_get('http://${localserver}/api/articles/3') or { panic(err) }
	article := json.decode(vaunt.Article, x.body) or { panic(err) }
	assert article.image_src != ''

	// last article id is 3
	x = do_delete('http://${localserver}/api/articles/3') or { panic(err) }
	assert x.status() == .ok
	assert x.body == 'deleted article with id 3'

	image_path := os.join_path('tests', article.image_src)
	assert os.exists(image_path) == false
}

fn test_delete_article_with_conflicting_images() {
	// create 2 articles
	mut files := []http.FileData{}
	files << http.FileData{
		filename: 'duplicate.txt'
		content_type: 'text/plain'
		data: '"Vaunt test"'
	}
	form_config := http.PostMultipartFormConfig{
		form: {
			'name':           'image'
			'description':    'image test'
			'block_data':     '{}'
			'thumbnail-name': 'duplicate.txt'
		}
		files: {
			'thumbnail': files
		}
	}

	mut x := do_post_multipart_form('http://${localserver}/api/articles', form_config)!
	assert x.status() == .ok
	article1 := json.decode(vaunt.Article, x.body)!

	form_config2 := http.PostMultipartFormConfig{
		form: {
			'name':           'image dup'
			'description':    'image duplicate'
			'block_data':     '{}'
			'thumbnail-name': 'duplicate.txt'
		}
		files: {
			'thumbnail': files
		}
	}
	x = do_post_multipart_form('http://${localserver}/api/articles', form_config2)!
	assert x.status() == .ok

	// when the article1 gets deleted `duplicate.txt` should not get deleted
	// since it's still used by article2
	x = do_delete('http://${localserver}/api/articles/${article1.id}') or { panic(err) }
	assert x.status() == .ok

	mut db := get_connection() or { panic(err) }
	// img id should be 4
	image := vaunt.get_image(db, article1.thumbnail) or {
		assert err.msg() == 'image was not found'
		vaunt.Image{}
	}
	assert image.id == 0

	image_path := os.join_path('tests', article1.image_src)
	assert os.exists(image_path) == true
}

fn test_update_not_existing_article() {
	form_data := {
		'name':        'update1'
		'description': 'update test2'
	}

	mut x := http.fetch(
		method: .put
		url: 'http://${localserver}/api/articles/88'
		header: http.new_header(key: .content_type, value: 'application/x-www-form-urlencoded')
		data: http.url_encode_form_data(form_data)
		cookies: {
			'vaunt_token': jwt_token
		}
	) or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: article with id "88" does not exist'
}

fn test_update_article() {
	article := create_article('update', 'update test', '{}') or { panic(err) }

	// update name & description
	form_data := {
		'name':        'update1'
		'description': 'update test2'
	}
	mut x := http.fetch(
		method: .put
		url: 'http://${localserver}/api/articles/${article.id}'
		header: http.new_header(key: .content_type, value: 'application/x-www-form-urlencoded')
		data: http.url_encode_form_data(form_data)
		cookies: {
			'vaunt_token': jwt_token
		}
	) or { panic(err) }
	assert x.status() == .ok

	x = do_get('http://${localserver}/api/articles/${article.id}') or { panic(err) }
	mut new_article := json.decode(vaunt.Article, x.body) or { panic(err) }
	assert new_article.name == form_data['name']
	assert new_article.description == form_data['description']

	// update show
	x = http.fetch(
		method: .put
		url: 'http://${localserver}/api/articles/${article.id}'
		header: http.new_header(key: .content_type, value: 'application/x-www-form-urlencoded')
		data: http.url_encode_form_data({
			'show': 'true'
		})
		cookies: {
			'vaunt_token': jwt_token
		}
	) or { panic(err) }
	assert x.status() == .ok

	x = do_get('http://${localserver}/api/articles/${article.id}') or { panic(err) }
	new_article = json.decode(vaunt.Article, x.body) or { panic(err) }
	assert new_article.show == true
}

// TODO: implement
fn test_update_thumbnail() {
}

// TODO: implement
fn test_replace_thumbnail() {
}

// 		Blocks
// ==================

fn test_get_blocks() {
	block_data := vaunt.ParagraphData{
		text: 'block text'
	}
	mut blocks := []vaunt.Block{}
	blocks << vaunt.Block{
		block_type: 'paragraph'
		data: json.encode(block_data)
	}
	article := create_article('blocks', 'blocks test', json.encode(blocks)) or { panic(err) }

	mut x := do_get('http://${localserver}/api/blocks?article=${article.id}') or { panic(err) }
	assert x.status() == .ok
	assert x.header.get(.content_type)! == 'application/json'
	fetched_blocks := json.decode([]vaunt.Block, x.body) or { panic(err) }
	assert fetched_blocks.len == 1

	block := fetched_blocks[0]
	assert block.block_type == blocks[0].block_type

	fetched_block_data := json.decode(vaunt.ParagraphData, block.data) or { panic(err) }
	assert fetched_block_data == block_data
}

fn test_update_block() {
	block_data := vaunt.ParagraphData{
		text: 'updated block text'
	}
	mut blocks := []vaunt.Block{}
	blocks << vaunt.Block{
		block_type: 'paragraph'
		data: json.encode(block_data)
	}

	mut x := do_get('http://${localserver}/api/articles') or { panic(err) }
	all_articles := json.decode([]vaunt.Article, x.body) or { panic(err) }
	assert all_articles.len > 0
	last_article := all_articles.last()

	data := json.encode(blocks)
	x = do_post('http://${localserver}/api/blocks?article=${last_article.id}', data) or {
		panic(err)
	}
	assert x.status() == .ok
	assert x.body == 'updated block'

	x = do_get('http://${localserver}/api/blocks?article=${last_article.id}') or { panic(err) }
	new_blocks := json.decode([]vaunt.Block, x.body)!
	assert new_blocks.len == blocks.len
	assert blocks[0] == new_blocks[0]
}

// 		Image Uploads
// ========================

fn test_upload_image() {
	mut x := do_post('http://${localserver}/api/upload-image', '') or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: field "article" is required'

	x = do_post_form('http://${localserver}/api/upload-image', {
		'article': '1'
	}) or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: field "image" is required in files'

	mut files := []http.FileData{}
	files << http.FileData{
		filename: ''
		content_type: 'text/plain'
		data: '"This is a test upload"'
	}
	mut form_config := http.PostMultipartFormConfig{
		form: {
			'article': '1'
		}
		files: {
			'image': files
		}
	}
	x = do_post_multipart_form('http://${localserver}/api/upload-image', form_config) or {
		panic(err)
	}
	assert x.status() == .bad_request
	assert x.body == 'error: must provide an image name'

	mut files2 := []http.FileData{}
	files2 << http.FileData{
		filename: 'data.txt'
		content_type: 'text/plain'
		data: '"This is a test upload"'
	}
	mut form_config2 := http.PostMultipartFormConfig{
		form: {
			'article': '1'
		}
		files: {
			'image': files2
		}
	}

	x = do_post_multipart_form('http://${localserver}/api/upload-image', form_config2) or {
		panic(err)
	}
	assert x.status() == .ok
	assert x.header.get(.content_type)! == 'application/json'

	image_block := json.decode(vaunt.ImageBlockResponse, x.body) or { panic(err) }
	assert image_block.success == 1
	assert image_block.file['url'] == '/uploads/img/${files2[0].filename}'

	mut db := get_connection() or { panic(err) }
	// img id should be 4
	image := vaunt.get_image(db, 4) or {
		assert err.msg() == ''
		vaunt.Image{}
	}
	assert image.src == image_block.file['url']
}

fn test_delete_image() {
	mut x := do_post('http://${localserver}/api/delete-image', '') or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: fields "image" and "article" are required'

	x = do_post_form('http://${localserver}/api/delete-image', {
		'image':   'data.txt'
		'article': '1'
	}) or { panic(err) }
	assert x.status() == .ok

	assert os.exists('tests/uploads/img/data.txt') == false

	mut db := get_connection() or { panic(err) }
	// deleted img id should be 4
	if _ := vaunt.get_image(db, 4) {
		assert true == false
	}
}

// 		Categories
// ======================

fn test_create_category() {
	category_name := 'loWer'
	correct_category_name := 'Lower'

	mut form := map[string]string{}

	mut x := do_post_form('http://${localserver}/api/categories', form)!
	assert x.status() == .bad_request

	form['name'] = category_name
	x = do_post_form('http://${localserver}/api/categories', form)!
	assert x.status() == .ok

	mut c := json.decode(vaunt.Category, x.body)!
	assert c.name == correct_category_name
}

fn test_duplicate_category_name() {
	mut x := do_post_form('http://${localserver}/api/categories', {
		'name': 'lower'
	})!

	assert x.status() == .bad_request
}

fn test_get_categories() {
	mut x := do_get('http://${localserver}/api/categories')!
	assert x.status() == .ok

	categories := json.decode([]vaunt.Category, x.body)!
	assert categories.len == 1
}

fn test_update_category() {
	mut form := map[string]string{}

	mut x := do_put_form('http://${localserver}/api/categories/1', form)!
	assert x.status() == .bad_request

	form['name'] = 'Other'

	x = do_put_form('http://${localserver}/api/categories/10', form)!
	assert x.status() == .bad_request

	x = do_put_form('http://${localserver}/api/categories/1', form)!
	assert x.status() == .ok

	x = do_get('http://${localserver}/api/categories')!
	categories := json.decode([]vaunt.Category, x.body)!
	assert categories.len == 1
	assert categories[0].name == form['name']
}

fn test_update_duplicate_category_name() {
	mut x := do_post_form('http://${localserver}/api/categories', {
		'name': 'Other'
	})!
	assert x.status() == .bad_request
}

fn test_delete_category() {
	mut x := do_delete('http://${localserver}/api/categories/1')!
	assert x.status() == .ok

	x = do_get('http://${localserver}/api/categories')!
	categories := json.decode([]vaunt.Category, x.body)!
	assert categories.len == 0
}

// 		Tags
// ===============

fn test_create_tag() {
	mut form := map[string]string{}

	mut x := do_post_form('http://${localserver}/api/tags', form)!
	assert x.status() == .bad_request

	form['name'] = 'WiTh SpAcE'
	x = do_post_form('http://${localserver}/api/tags', form)!
	assert x.status() == .bad_request

	form['color'] = '#000000'
	x = do_post_form('http://${localserver}/api/tags', form)!
	assert x.status() == .ok
	tag := json.decode(vaunt.Tag, x.body)!

	assert tag.name == 'with-space'
}

fn test_create_duplicate_name_tag() {
	mut x := do_post_form('http://${localserver}/api/tags', {
		'name':  'with Space'
		'color': '#000000'
	})!
	assert x.status() == .bad_request
}

fn test_get_tags() {
	mut x := do_get('http://${localserver}/api/tags')!
	assert x.status() == .ok
	tags := json.decode([]vaunt.Tag, x.body)!
	assert tags.len == 1
}

fn test_add_tag_to_article() {
	article := create_article('with tag', 'tagz', '{}')!
	eprintln("note to self: check article id's again!")
	assert article.id == 8

	mut form := map[string]string{}

	mut x := do_post_form('http://${localserver}/api/tags/8', form)!
	assert x.status() == .bad_request

	// tag does not exist
	form['tag_id'] = '2'
	x = do_post_form('http://${localserver}/api/tags/8', form)!
	assert x.status() == .bad_request

	form['tag_id'] = '1'
	x = do_post_form('http://${localserver}/api/tags/8', form)!
	assert x.status() == .ok

	tag := json.decode(vaunt.Tag, x.body)!
	assert tag.id == 2
}

fn test_get_tags_from_article() {
	mut x := do_get('http://${localserver}/api/tags/3')!
	assert x.status() == .ok
	mut tags := json.decode([]vaunt.Tag, x.body)!
	assert tags.len == 0

	x = do_get('http://${localserver}/api/tags/8')!
	assert x.status() == .ok

	tags = json.decode([]vaunt.Tag, x.body)!
	assert tags.len == 1
	assert tags[0].id == 2
}

fn test_update_tag() {
	mut x := do_put_form('http://${localserver}/api/tags', {
		'tag_id': '1'
		'name':   'other'
		'color':  '#000000'
	})!
	assert x.status() == .ok
	tag := json.decode(vaunt.Tag, x.body)!
	assert tag.name == 'other'

	// tag should be changed for all articles as well
	x = do_get('http://${localserver}/api/tags/8')!
	assert x.status() == .ok
	tags := json.decode([]vaunt.Tag, x.body)!
	assert tags.len == 1
	assert tags[0].name == 'other'
}

fn test_update_duplicate_tag_name() {
	mut x := do_post_form('http://${localserver}/api/tags', {
		'name':  'test'
		'color': '#000000'
	})!
	assert x.status() == .ok

	x = do_put_form('http://${localserver}/api/tags', {
		'tag_id': '3'
		'name':   'Other'
		'color':  '#000000'
	})!
	assert x.status() == .bad_request

	x = do_put_form('http://${localserver}/api/tags', {
		'tag_id': '3'
		'name':   'test'
		'color':  '#000001'
	})!
	assert x.status() == .ok
}

fn test_remove_tag_from_article() {
	mut x := do_delete('http://${localserver}/api/tags/2')!
	assert x.status() == .ok

	x = do_get('http://${localserver}/api/tags/8')!
	assert x.status() == .ok
	mut tags := json.decode([]vaunt.Tag, x.body)!
	assert tags.len == 0
}

fn test_delete_tag() {
	// add tag back to article
	mut x := do_post_form('http://${localserver}/api/tags/8', {
		'tag_id': '3'
	})!
	assert x.status() == .ok

	x = do_get('http://${localserver}/api/tags/8')!
	assert x.status() == .ok

	mut tags := json.decode([]vaunt.Tag, x.body)!
	assert tags.len == 1
	assert tags[0].id == 4

	// tag is added to article so we can delete both
	x = do_delete('http://${localserver}/api/tags/3')!
	assert x.status() == .ok
	// tag is deleted from article
	x = do_get('http://${localserver}/api/tags/8')!
	assert x.status() == .ok
	tags = json.decode([]vaunt.Tag, x.body)!
	assert tags.len == 0

	x = do_get('http://${localserver}/api/tags')!
	assert x.status() == .ok
	del_tags := json.decode([]vaunt.Tag, x.body)!
	// only the duplicate tag 'other' should be present
	assert del_tags.len == 1
}

fn testsuite_end() {
	// This test is guaranteed to be called last.
	// It sends a request to the server to shutdown.
	x := http.fetch(
		url: 'http://${localserver}/shutdown'
		method: .get
	) or {
		assert err.msg() == ''
		return
	}
	assert x.status() == .ok
	assert x.body == 'good bye'
}

// utility

fn create_article(name string, description string, block_data string) !vaunt.Article {
	form_data := {
		'name':        name
		'description': description
		'block_data':  block_data
	}
	mut x := do_post_form('http://${localserver}/api/articles', form_data)!
	return json.decode(vaunt.Article, x.body)!
}

fn get_connection() !pg.DB {
	mut db := pg.connect(user: db_user, password: db_password, dbname: db_name)!
	return db
}

fn do_get(url string) !http.Response {
	req := http.Request{
		method: .get
		url: url
		cookies: {
			'vaunt_token': jwt_token
		}
	}
	return req.do()!
}

fn do_post(url string, data string) !http.Response {
	req := http.Request{
		method: .post
		data: data
		url: url
		cookies: {
			'vaunt_token': jwt_token
		}
	}
	return req.do()!
}

fn do_delete(url string) !http.Response {
	req := http.Request{
		method: .delete
		url: url
		cookies: {
			'vaunt_token': jwt_token
		}
	}
	return req.do()!
}

fn do_put_form(url string, form map[string]string) !http.Response {
	req := http.Request{
		method: .put
		data: http.url_encode_form_data(form)
		url: url
		cookies: {
			'vaunt_token': jwt_token
		}
	}
	return req.do()!
}

fn do_post_form(url string, form map[string]string) !http.Response {
	req := http.Request{
		method: .post
		data: http.url_encode_form_data(form)
		url: url
		cookies: {
			'vaunt_token': jwt_token
		}
	}
	return req.do()!
}

fn do_post_multipart_form(url string, conf http.PostMultipartFormConfig) !http.Response {
	body, boundary := http.multipart_form_body(conf.form, conf.files)
	mut header := conf.header
	header.set(.content_type, 'multipart/form-data; boundary="${boundary}"')
	return http.fetch(
		method: .post
		url: url
		header: header
		cookies: {
			'vaunt_token': jwt_token
		}
		data: body
	)!
}
