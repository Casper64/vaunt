module vblog

import vweb
import db.pg
import os

const (
	vexe = os.getenv('VEXE')
)

pub fn init(db &pg.DB, pages_dir string, upload_dir string) ![]&vweb.ControllerPath {
	init_database(db)!
	
	vblog_dir := os.dir(@FILE)
	// mut upload_dir := _upload_dir
	// // add trailing '/' after upload dir for compatibility
	// $if windows {
	// 	if _upload_dir.ends_with('/') == false && _upload_dir.ends_with('\\') == false {
	// 		upload_dir += '/'
	// 	} else if _upload_dir.ends_with('\\') {
	// 		upload_dir.last() = '/'
	// 	}
	// } $else {
	// 	if _upload_dir.ends_with('/') == false {
	// 		upload_dir += '/'
	// 	}
	// }
	println(upload_dir)
	

	// Upload App
	mut upload_app := &Upload{
		db: db
		upload_dir: upload_dir
	}
	// cache paths of all files already in the uploads dir
	upload_app.handle_static(upload_dir, true)

	// Admin app
	mut admin_app := &Admin{
		db: db
	}

	dist_path := os.join_path(vblog_dir, 'admin')

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

pub struct Upload {
	vweb.Context
pub mut:
	db           pg.DB  [required; vweb_global]
	upload_dir   string [required; vweb_global]
	current_path string [vweb_global]
}

// handle static image uploads
['/img/:img_path'; get]
pub fn (mut app Upload) get_image(img_path string) vweb.Result {
	file_path := os.join_path(app.upload_dir, 'img', img_path)

	// prevent directory traversal
	if file_path.starts_with(app.upload_dir) == false {
		return app.not_found()
	}
	if os.exists(file_path) {
		return app.file(file_path)
	} else {
		return app.not_found()
	}
}
