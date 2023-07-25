module main

import vaunt
import vweb
import os
import db.sqlite
import time

const (
	template_dir = os.abs_path('tests/templates') // where you want to store templates
	upload_dir   = os.abs_path('tests/uploads') // where you want to store uploads
	md_dir       = os.abs_path('tests/md') // where you want to serve markdown files from
)

struct Theme {}

// Base app for Vaunt which you can extend
struct App {
	vweb.Context
	vaunt.Util
pub:
	controllers  []&vweb.ControllerPath
	template_dir string                 [vweb_global]
	upload_dir   string                 [vweb_global]
pub mut:
	dev    bool      [vweb_global] // used by Vaunt internally
	seo    vaunt.SEO [vweb_global]
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
	if os.args.len < 4 {
		panic('Usage: `vaunt_test_app.exe PORT TIMEOUT_IN_MILLISECONDS DB_FILE`')
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
	db := sqlite.connect(os.args[3])!

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

	settings := vaunt.GenerateSettings{
		dynamic_routes: {
			'custom_dynamic':       vaunt.DynamicRoute{
				arguments: ['a', 'b', 'c']
			}
			'multiple_dynamics':    vaunt.MultipleDynamicRoute{
				arguments: [['1', 'a'], ['2', 'b'], ['3', 'c']]
			}
			'from_markdown_folder': vaunt.MarkdownDynamicRoute{
				md_dir: md_dir
			}
		}
	}

	// start the Vaunt server
	vaunt.start(mut app, http_port, settings)!
}

pub fn (mut app App) before_request() {
	app.Util.db = app.db
}

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

['/tags/:tag_name']
pub fn (mut app App) tag_page(tag_name string) vweb.Result {
	app.s_html = tag_name
	return app.html(tag_name)
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

pub fn (mut app App) req_url() vweb.Result {
	app.s_html = app.req.url
	return app.text(app.req.url)
}

// nested index route
['/nested/']
pub fn (mut app App) nested_index() vweb.Result {
	app.s_html = 'nested index'
	return app.html('nested index')
}

['/dyn/:dynamic']
pub fn (mut app App) custom_dynamic(dynamic string) vweb.Result {
	app.s_html = dynamic
	return app.html(app.s_html)
}

['/mult/:a/:b']
pub fn (mut app App) multiple_dynamics(a string, b string) vweb.Result {
	app.s_html = '${a}/${b}'
	return app.html(app.s_html)
}

['/md/:path...']
pub fn (mut app App) from_markdown_folder(path string) vweb.Result {
	raw_html := vaunt.get_html_from_markdown(md_dir, path) or {
		// markdown file does not exist
		return app.not_found()
	}
	app.s_html = raw_html
	return app.html(app.s_html)
}

['/posting'; post]
pub fn (mut app App) only_post() vweb.Result {
	app.s_html = 'post'
	return app.html(app.s_html)
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
