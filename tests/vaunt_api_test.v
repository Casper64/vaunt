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
	db.drop('articles') or {}
	db.drop('images') or {}
}

fn test_vaunt_app_can_be_compiled() {
	did_server_compile := os.system('${os.quoted_path(vexe)} -o ${os.quoted_path(serverexe)} tests/vaunt_test_app.v')
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

// 		Articles
// ==================

fn test_no_articles() {
	json_empty_articles := json.encode([]vaunt.Article{})
	x := http.get('http://${localserver}/api/articles') or { panic(err) }

	assert x.header.get(.content_type)! == 'application/json'
	assert x.body == json_empty_articles

	articles := json.decode([]vaunt.Article, x.body) or { panic(err) }
	assert articles.len == 0
}

fn test_create_article() {
	mut form := map[string]string{}

	// test errors
	mut x := http.post_form('http://${localserver}/api/articles', form) or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: field "name" and "description" are required'

	form['description'] = 'test description'
	x = http.post_form('http://${localserver}/api/articles', form) or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: field "name" and "description" are required'

	form['name'] = 'test'
	x = http.post_form('http://${localserver}/api/articles', form) or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: must provide default "block_data" when creating an article'

	form['block_data'] = '{}'
	x = http.post_form('http://${localserver}/api/articles', form) or { panic(err) }
	assert x.status() == .ok
	assert x.header.get(.content_type)! == 'application/json'

	// test response
	article := json.decode(vaunt.Article, x.body) or { panic(err) }
	assert x.status() == .ok
	assert article.name == form['name']
	assert article.description == form['description']
	assert article.block_data == form['block_data']

	// test inserted into database
	x = http.get('http://${localserver}/api/articles/${article.id}') or { panic(err) }
	assert x.status() == .ok
	fetched_article := json.decode(vaunt.Article, x.body) or { panic(err) }
	assert fetched_article == article
}

fn test_delete_article() {
	new_article := create_article('to_delete', 'should be deleted', '{}') or { panic(err) }

	mut x := http.get('http://${localserver}/api/articles') or { panic(err) }
	mut all_articles := json.decode([]vaunt.Article, x.body) or { panic(err) }
	prev_len := all_articles.len

	x = http.delete('http://${localserver}/api/articles/${new_article.id}') or { panic(err) }
	assert x.status() == .ok
	assert x.body == 'deleted article with id ${new_article.id}'

	x = http.get('http://${localserver}/api/articles') or { panic(err) }
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

	mut x := http.post_multipart_form('http://${localserver}/api/articles', form_config)!
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
	x = http.get('http://${localserver}/${article.image_src}') or { panic(err) }
	assert x.header.get(.content_type)! == files[0].content_type
	assert x.body == files[0].data
}

fn test_delete_article_with_image() {
	mut x := http.delete('http://${localserver}/api/articles/s') or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: "id" is not a number'

	x = http.get('http://${localserver}/api/articles/3') or { panic(err) }
	article := json.decode(vaunt.Article, x.body) or { panic(err) }
	assert article.image_src != ''

	// last article id is 3
	x = http.delete('http://${localserver}/api/articles/3') or { panic(err) }
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

	mut x := http.post_multipart_form('http://${localserver}/api/articles', form_config)!
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
	x = http.post_multipart_form('http://${localserver}/api/articles', form_config2)!
	assert x.status() == .ok

	// when the article1 gets deleted `duplicate.txt` should not get deleted
	// since it's still used by article2
	x = http.delete('http://${localserver}/api/articles/${article1.id}') or { panic(err) }
	assert x.status() == .ok

	mut db := get_connection() or { panic(err) }
	// img id should be 4
	image := vaunt.get_image(mut db, article1.thumbnail) or {
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
	) or { panic(err) }
	assert x.status() == .ok

	x = http.get('http://${localserver}/api/articles/${article.id}') or { panic(err) }
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
	) or { panic(err) }
	assert x.status() == .ok

	x = http.get('http://${localserver}/api/articles/${article.id}') or { panic(err) }
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

	mut x := http.get('http://${localserver}/api/blocks?article=${article.id}') or { panic(err) }
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

	mut x := http.get('http://${localserver}/api/articles') or { panic(err) }
	all_articles := json.decode([]vaunt.Article, x.body) or { panic(err) }
	assert all_articles.len > 0
	last_article := all_articles.last()

	data := json.encode(blocks)
	x = http.post('http://${localserver}/api/blocks?article=${last_article.id}', data) or {
		panic(err)
	}
	assert x.status() == .ok
	assert x.body == 'updated block'

	x = http.get('http://${localserver}/api/blocks?article=${last_article.id}') or { panic(err) }
	new_blocks := json.decode([]vaunt.Block, x.body)!
	assert new_blocks.len == blocks.len
	assert blocks[0] == new_blocks[0]
}

// 		Image Uploads
// ========================

fn test_upload_image() {
	mut x := http.post('http://${localserver}/api/upload-image', '') or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: field "article" is required'

	x = http.post_form('http://${localserver}/api/upload-image', {
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
		header: http.Header{}
	}
	x = http.post_multipart_form('http://${localserver}/api/upload-image', form_config) or {
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
		header: http.Header{}
	}

	x = http.post_multipart_form('http://${localserver}/api/upload-image', form_config2) or {
		panic(err)
	}
	assert x.status() == .ok
	assert x.header.get(.content_type)! == 'application/json'

	image_block := json.decode(vaunt.ImageBlockResponse, x.body) or { panic(err) }
	assert image_block.success == 1
	assert image_block.file['url'] == 'uploads/img/${files2[0].filename}'

	mut db := get_connection() or { panic(err) }
	// img id should be 4
	image := vaunt.get_image(mut db, 4) or {
		assert err.msg() == ''
		vaunt.Image{}
	}
	assert image.src == image_block.file['url']
}

fn test_delete_image() {
	mut x := http.post('http://${localserver}/api/delete-image', '') or { panic(err) }
	assert x.status() == .bad_request
	assert x.body == 'error: fields "image" and "article" are required'

	x = http.post_form('http://${localserver}/api/delete-image', {
		'image':   'data.txt'
		'article': '1'
	}) or { panic(err) }
	assert x.status() == .ok

	assert os.exists('tests/uploads/img/data.txt') == false

	mut db := get_connection() or { panic(err) }
	// deleted img id should be 4
	if _ := vaunt.get_image(mut db, 4) {
		assert true == false
	}
}

// TODO: Categories
// 		Categories
// ======================

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
	mut x := http.post_form('http://${localserver}/api/articles', form_data)!
	return json.decode(vaunt.Article, x.body)!
}

fn get_connection() !pg.DB {
	mut db := pg.connect(user: db_user, password: db_password, dbname: db_name)!
	return db
}
