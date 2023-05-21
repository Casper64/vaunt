import os
import time
import net.http
import db.pg
import vaunt
import json

const (
	sport                  = 12381
	sport2                 = 12382
	localserver            = '127.0.0.1:${sport}'
	exit_after_time        = 12000 // milliseconds
	vexe                   = os.getenv('VEXE')
	serverexe              = os.join_path(os.cache_dir(), 'vaunt_generation_test_server.exe')
	db_user                = 'dev'
	db_password            = 'password'
	db_name                = 'vaunt-test'
	output_dir             = os.abs_path('tests/public')
	static_dir             = os.abs_path('tests/static')
	upload_dir             = os.abs_path('tests/uploads')

	jwt_token              = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwIiwibmFtZSI6ImFkbWluIiwiaWF0IjoxNjg0MDkwMTgwfQ.OJvgvMZ2uS6odHQ6vfp9zMnV765ssH4bjcppDKUxS9k'

	article_names          = ['normal', 'with space', 'differentCaps', 'without category']
	category_names         = ['web', 'category space', 'categoryCaps', '']
	correct_article_names  = ['normal', 'with-space', 'differentcaps', 'without-category']
	correct_category_names = ['web', 'category-space', 'categorycaps', '']
	no_show_article        = 'show'

	seo_url                = 'https://example.com'
)

// setup of vaunt webserver
fn testsuite_begin() {
	if os.exists(serverexe) {
		os.rm(serverexe) or {}
	}
	if os.exists('tests/uploads') {
		os.rmdir_all('tests/uploads')!
	}
	if os.exists('tests/public') {
		os.rmdir_all('tests/public')!
	}
}

fn test_setup_database() {
	mut db := get_connection() or { panic(err) }
	db.drop('categories') or {}
	db.drop('articles') or {}
	db.drop('images') or {}
}

fn test_vaunt_app_can_be_compiled() {
	did_server_compile := os.system('${os.quoted_path(vexe)} -o ${os.quoted_path(serverexe)} tests/vaunt_generation_test_app.v')
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

	insert_data()
}

fn test_generate_succeeds() {
	result := os.execute('${os.quoted_path(vexe)} run tests/vaunt_generation_test_app.v  ${sport2} ${exit_after_time} ${db_user} ${db_password} ${db_name} --generate --out ${output_dir}')
	assert result.exit_code == 0

	// test custom output dir
	assert result.output.contains('"${output_dir}"') == true
	assert os.exists(output_dir) == true

	// test empty page warning
	assert result.output.contains('warning: method "empty" produced no html! Did you forget to set `app.s_html`?') == true

	// test dynamic route warning
	assert result.output.contains('error while generating "custom_dynamic": generating custom dynamic routes is not supported yet!') == true
}

fn test_file_and_folder_names() {
	// TODO: ignore static and uploads folder
	os.walk(output_dir, fn (path string) {
		file := os.base(path)

		assert file.is_lower() == true
		assert file.contains_u8(` `) == false
	})
}

fn walk_dir(dir string) ! {
	mut files := []string{}

	os.walk_with_context(dir, files, fn [dir] (mut files []string, path string) {
		files << path.replace(dir, '')
	})

	for file in files {
		path := os.join_path(output_dir, file)
		assert os.exists(path) == true

		// test if file contents is copied correctly
		if os.is_file(path) {
			static_path := os.join_path(dir, file)
			static_file := os.read_file(static_path)!

			copied_file := os.read_file(path)!

			assert static_file == copied_file
		}
	}
}

fn test_static_folder_is_copied() {
	walk_dir(static_dir)!
}

fn test_upload_folder_is_copied() {
	walk_dir(upload_dir)!
}

fn test_index_page() {
	file := os.join_path(output_dir, 'index.html')

	assert os.exists(file) == true
	contents := os.read_file(file)!
	assert contents == 'index'
}

fn test_about_page() {
	file := os.join_path(output_dir, 'about.html')

	assert os.exists(file) == true
	contents := os.read_file(file)!
	assert contents == 'About'
}

fn test_empty_page() {
	file := os.join_path(output_dir, 'empty.html')

	assert os.exists(file) == false
}

fn test_nested_index() {
	file := os.join_path(output_dir, 'nested', 'index.html')

	assert os.exists(file) == true
	contents := os.read_file(file)!
	assert contents == 'nested index'
}

fn test_no_custom_dynamic() {
	files := os.ls(os.join_path(output_dir, 'nested'))!

	assert files.len == 1
}

fn test_article_show_false() {
	file := os.join_path(output_dir, 'articles', no_show_article + '.html')

	assert os.exists(file) == false
}

fn test_category_article_outputs() {
	zip(correct_article_names, correct_category_names, fn (article string, category string) {
		if category != '' {
			dir := os.join_path(output_dir, 'articles', category)
			assert os.exists(dir) == true
			assert os.is_dir(dir) == true

			file := os.join_path(dir, article + '.html')
			assert os.exists(file) == true

			contents := os.read_file(file) or {
				eprintln('file ${file} does not exist!')
				''
			}
			assert contents == '${category} ${article}'
		} else {
			file := os.join_path(output_dir, 'articles', article + '.html')
			assert os.exists(file) == true

			contents := os.read_file(file) or {
				eprintln('file ${file} does not exist!')
				''
			}
			assert contents == article
		}
	})
}

fn test_sitemap() {
	sitemap_file := os.join_path(output_dir, 'sitemap.xml')
	assert os.exists(sitemap_file) == true

	data := os.read_file(sitemap_file)!

	// no https://example.com/index.html in the sitemap but only the url
	assert data.contains(to_url('index')) == false
	assert data.contains('<loc>${seo_url}</loc>') == true

	assert data.contains(to_url('about')) == true
	assert data.contains(to_url('empty')) == true

	zip(correct_article_names, correct_category_names, fn [data] (article string, category string) {
		if category != '' {
			dir := os.join_path('articles', category)
			file := os.join_path(dir, article)

			assert data.contains(to_url(file)) == true
		} else {
			file := os.join_path('articles', article)
			assert data.contains(to_url(file)) == true
		}
	})
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

// Utility
fn get_connection() !pg.DB {
	mut db := pg.connect(user: db_user, password: db_password, dbname: db_name)!
	return db
}

fn insert_data() {
	mut db := get_connection() or { panic(err) }

	zip(article_names, category_names, fn [db] (article string, category string) {
		if category != '' {
			c := create_category(category) or { vaunt.Category{} }

			a := create_article(article, 'test', '{}', c.id, true) or { vaunt.Article{} }
			assert a.category_id == c.id
		} else {
			create_article(article, 'test', '{}', 0, true) or {}
		}
	})

	// create article where show is false
	create_article(no_show_article, 'test', '{}', 0, false) or {}
}

fn zip[T, U](a []T, b []U, iterator fn (T, U)) {
	mut idx := 0
	for idx < a.len && idx < b.len {
		iterator(a[idx], b[idx])
		idx++
	}
}

fn create_category(name string) !vaunt.Category {
	form_data := {
		'name': name
	}
	mut x := do_post_form('http://${localserver}/api/categories', form_data)!
	return json.decode(vaunt.Category, x.body)!
}

fn create_article(name string, description string, block_data string, category int, show bool) !vaunt.Article {
	form_data := {
		'name':        name
		'description': description
		'block_data':  block_data
		'category':    category.str()
		'show':        if show { 'true' } else { '' }
	}
	mut x := do_post_form('http://${localserver}/api/articles', form_data)!
	return json.decode(vaunt.Article, x.body)!
}

fn to_url(url string) string {
	file := os.join_path(seo_url, url) + '.html'
	return '<loc>${file}</loc>'
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
