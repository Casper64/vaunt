module main

import vaunt
import vweb
import os
import db.sqlite
import time

const template_dir = os.abs_path('tests/templates') // where you want to store templates
const upload_dir = os.abs_path('tests/uploads') // where you want to store uploads

struct Theme {}

// Base app for Vaunt which you can extend
struct App {
	vweb.Context
	vaunt.Util
pub:
	controllers  []&vweb.ControllerPath
	template_dir string                 @[vweb_global]
	upload_dir   string                 @[vweb_global]
pub mut:
	dev    bool      @[vweb_global] // used by Vaunt internally
	theme  Theme
	db     sqlite.DB
	s_html string // used by Vaunt to generate html
}

fn exit_after_timeout(timeout_in_ms int) {
	time.sleep(timeout_in_ms * time.millisecond)
	println('>> webserver: pid: ${os.getpid()}, exiting ...')
	exit(0)
}

fn main() {
	if os.args.len != 4 {
		panic('Usage: `vaunt_test_app.exe PORT TIMEOUT_IN_MILLISECONDS DB_FILE`')
	}
	http_port := os.args[1].int()
	assert http_port > 0
	timeout := os.args[2].int()
	assert timeout > 0
	spawn exit_after_timeout(timeout)

	theme := Theme{}

	// insert your own credentials
	db := sqlite.connect(os.args[3])!

	// setup database and controllers
	controllers := vaunt.init(db, template_dir, upload_dir, theme, 'secret')!

	// create the app
	mut app := &App{
		template_dir: template_dir
		upload_dir: upload_dir
		db: db
		controllers: controllers
	}

	// serve all css files from 'static'
	app.handle_static('tests/static', true)

	// start the Vaunt server
	vaunt.start(mut app, http_port, vaunt.GenerateSettings{})!
}

pub fn (mut app App) before_request() {
	app.Util.db = app.db
}

@['/']
pub fn (mut app App) home() vweb.Result {
	// save html in `app.s_html` first before returning it
	app.s_html = '<h1>The home page</h1>'
	return app.html(app.s_html)
}

@['/articles/:category_name/:article_name']
pub fn (mut app App) category_article_page(category_name string, article_name string) vweb.Result {
	// save html in `app.s_html` first before returning it
	app.s_html = app.category_article_html(category_name, article_name, template_dir) or {
		return app.not_found()
	}
	return app.html(app.s_html)
}

@['/articles/:article_name']
pub fn (mut app App) article_page(article_name string) vweb.Result {
	// save html in `app.s_html` first before returning it
	app.s_html = app.article_html(article_name, template_dir) or { return app.not_found() }
	return app.html(app.s_html)
}

@['/tags/:tag_name']
pub fn (mut app App) tag_page(tag_name string) vweb.Result {
	app.s_html = tag_name
	return app.html(tag_name)
}

pub fn (mut app App) not_found() vweb.Result {
	app.set_status(404, 'Not Found')
	return app.html('<h1>"${app.req.url}" does not exist')
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
