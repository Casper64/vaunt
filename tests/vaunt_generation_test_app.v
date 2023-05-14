module main

import vaunt
import vweb
import os
import db.pg
import time

const (
	template_dir = os.abs_path('tests/templates') // where you want to store templates
	upload_dir   = os.abs_path('tests/uploads') // where you want to store uploads
)

struct Theme {}

// Base app for Vaunt which you can extend
struct App {
	vweb.Context
pub:
	controllers  []&vweb.ControllerPath
	template_dir string                 [vweb_global]
	upload_dir   string                 [vweb_global]
pub mut:
	dev    bool      [vweb_global] // used by Vaunt internally
	seo    vaunt.SEO [vweb_global]
	theme  Theme
	db     pg.DB
	s_html string // used by Vaunt to generate html
}

fn exit_after_timeout(timeout_in_ms int) {
	time.sleep(timeout_in_ms * time.millisecond)
	println('>> webserver: pid: ${os.getpid()}, exiting ...')
	exit(0)
}

fn main() {
	if os.args.len < 6 {
		panic('Usage: `vaunt_test_app.exe PORT TIMEOUT_IN_MILLISECONDS DB_USER DB_PASSWORD DB_NAME`')
	}

	http_port := os.args[1].int()
	assert http_port > 0
	timeout := os.args[2].int()

	if '--generate' !in os.args {
		assert timeout > 0
		spawn exit_after_timeout(timeout)
	}

	theme := Theme{}

	// insert your own credentials
	db := pg.connect(user: os.args[3], password: os.args[4], dbname: os.args[5])!

	// setup database and controllers
	controllers := vaunt.init(db, template_dir, upload_dir, theme, 'secret')!

	// create the app
	mut app := &App{
		template_dir: template_dir
		upload_dir: upload_dir
		db: db
		controllers: controllers
		seo: vaunt.SEO{
			website_url: 'https://example.com'
		}
	}

	// serve all css files from 'static'
	app.handle_static('tests/static', true)

	// start the Vaunt server
	vaunt.start(mut app, http_port)!
}

pub fn (mut app App) before_request() {}

['/articles/:category_name/:article_name']
pub fn (mut app App) category_article_page(category_name string, article_name string) vweb.Result {
	html := '${category_name} ${article_name}'
	app.s_html = html
	return app.html(html)
}

['/articles/:article_name']
pub fn (mut app App) article_page(article_name string) vweb.Result {
	app.s_html = article_name
	return app.html(article_name)
}

// index route
pub fn (mut app App) index() vweb.Result {
	app.s_html = 'index'
	return app.html('index')
}

// empty route
pub fn (mut app App) empty() vweb.Result {
	// forgot to set `app.s_html`
	// app.s_html = 'empty'
	return app.html('empty')
}

// route without attribute & custom route
pub fn (mut app App) about() vweb.Result {
	app.s_html = 'About'
	return app.html('About')
}

// nested index route
['/nested/']
pub fn (mut app App) nested_index() vweb.Result {
	app.s_html = 'nested index'
	return app.html('nested index')
}

// disallow dynamic routes
['/nested/:dynamic']
pub fn (mut app App) custom_dynamic(dynamic string) vweb.Result {
	app.s_html = dynamic
	return app.html(dynamic)
}

pub fn (mut app App) shutdown() vweb.Result {
	spawn app.gracefull_exit()
	return app.ok('good bye')
}

fn (mut app App) gracefull_exit() {
	eprintln('>> webserver: gracefull_exit')
	time.sleep(100 * time.millisecond)
	exit(0)
}
