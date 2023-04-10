module vblog

import vweb
import db.pg
import os

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

