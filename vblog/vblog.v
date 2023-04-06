module vblog

import vweb
import db.pg
import os

const (
	vexe = os.getenv('VEXE')
)

pub fn init(db &pg.DB, pages_dir string, upload_dir string) ![]&vweb.ControllerPath {
	init_database(db)!

	// Upload App
	mut upload_app := &Upload{
		db: db
		upload_dir: upload_dir
	}
	// todo: catch all route
	upload_app.handle_static(upload_dir, true)

	// Admin app
	mut admin_app := &Admin{
		db: db
	}

	dist_path := os.real_path('${os.getwd()}/dist')

	admin_app.mount_static_folder_at('${dist_path}/admin', '/')
	admin_app.serve_static('/index.html', '${dist_path}/index.html')

	controllers := [
		vweb.controller('/api', &Api{
			db: db
			pages_dir: pages_dir
			upload_dir: upload_dir
			articles_url: '/articles'
		}),
		vweb.controller('/admin', admin_app),
		vweb.controller('/uploads', upload_app),
	]
	return controllers
}

struct Admin {
	vweb.Context
pub mut:
	db pg.DB [required; vweb_global]
}

['/']
fn (mut app Admin) index() vweb.Result {
	if '/index.html' in app.static_files.keys() {
		return app.file(app.static_files['/index.html'])
	}

	return app.not_found()
}

fn ceate_admin_app(db pg.DB) &Admin {
	mut app := &Admin{
		db: db
	}

	dist_path := os.real_path('${os.getwd()}/dist')

	app.mount_static_folder_at('${dist_path}/admin', '/')
	app.serve_static('/index.html', '${dist_path}/index.html')

	return app
}

pub struct Upload {
	vweb.Context
pub mut:
	db           pg.DB  [required; vweb_global]
	upload_dir   string [required; vweb_global]
	current_path string [vweb_global]
}
