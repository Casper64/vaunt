module vblog

import vweb
import db.pg
import time
import os

const (
	vexe = os.getenv('VEXE')
)

pub fn init(db &pg.DB) ! {
	init_database(db)!
}

struct Admin {
	vweb.Context
pub mut:
	db pg.DB [required; vweb_global]
}

['/']
fn (mut app Admin) index() vweb.Result {
	// println('admin: ${app.static_files}')
	if '/index.html' in app.static_files.keys() {
		return app.file(app.static_files['/index.html'])
	}

	return app.not_found()
}

pub fn ceate_admin_app(db pg.DB) &Admin {
	mut app := &Admin{
		db: db
	}

	dist_path := os.real_path('${os.getwd()}/dist')

	app.mount_static_folder_at('${dist_path}/admin', '/')
	app.serve_static('/index.html', '${dist_path}/index.html')

	return app
}
