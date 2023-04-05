module main

import vweb
import vblog
import db.pg
import os

const (
	pages_dir = os.abs_path('src/templates/pages')
)

struct App {
	vweb.Context
	vweb.Controller
pub mut:
	db pg.DB [vweb_global]
}

fn main() {
	db := pg.connect(user: 'dev', password: 'password', dbname: 'vblog')!
	vblog.init(db)!

	mut admin_app := vblog.ceate_admin_app(db)

	mut app := &App{
		db: db
		controllers: [
			vweb.controller('/api', &vblog.Api{
				db: db
				pages_dir: pages_dir
				articles_url: '/articles'
			}),
			vweb.controller('/admin', admin_app)
		]
	}

	os.chdir('src')!

	app.handle_static('static', true)
	vweb.run_at(app, port: 8080, family: .ip, nr_workers: 1)!
}

['/']
pub fn (mut app App) home() vweb.Result {
	title := 'Home'

	articles := vblog.get_all_articles(mut app.db)

	content := $tmpl('./templates/home.html')
	layout := $tmpl('./templates/layout.html')
	return app.html(layout)
}

['/articles/:article_id']
pub fn (mut app App) article_page(article_id int) vweb.Result {
	article := vblog.get_article(mut app.db, article_id) or { return app.not_found() }
	title := 'VBlog | ${article.name}'

	content := os.read_file('templates/pages/${article_id}.html') or {
		eprintln(err)
		return app.not_found()
	}
	layout := $tmpl('./templates/layout.html')
	return app.html(layout)
}
