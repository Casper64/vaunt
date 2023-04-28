module vaunt

import vweb
import db.pg
import os

pub struct Admin {
	vweb.Context
pub mut:
	db pg.DB [required; vweb_global]
}

['/']
fn (mut app Admin) index() vweb.Result {
	if '/index.html' in app.static_files.keys() {
		return app.file(app.static_files['/index.html'])
	}

	app.set_status(404, '')
	return app.text('Not Found')
}

// always fallback to index.html. vue-router will handle the routes from there
pub fn (mut app Admin) not_found() vweb.Result {
	return app.index()
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
	mut file_path := os.join_path(app.upload_dir, 'img', img_path)
	// resolve '../' and '\'
	file_path = os.norm_path(file_path)

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
