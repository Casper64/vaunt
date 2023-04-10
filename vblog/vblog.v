module vblog

import vweb
import db.pg
import os
import flag
import time

const (
	vexe             = os.getenv('VEXE')
	port             = 8080
	generator_server = 'http://127.0.0.1:${port}'
)

pub fn init(db &pg.DB, pages_dir string, upload_dir string) ![]&vweb.ControllerPath {
	init_database(db)!

	vblog_dir := os.dir(@FILE)

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

pub fn start[T](mut app T, port int) ! {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('V Blog')
	fp.version('0.0.1')
	fp.description('Simple static site generator for articles')
	fp.skip_executable()
	f_user := fp.bool('user', `u`, false, 'user mode (not dev), ignored when generating the site')
	f_generate := fp.bool('generate', `g`, false, 'generate the site')
	f_output := fp.string('out', `o`, 'public', 'output dir')
	fp.finalize() or {
		println(fp.usage())
		return
	}

	if f_generate {
		app.dev = false
		start_site_generation[T](mut app, f_output)!
		return
	}

	// start web server in dev mode
	app.dev = !f_user

	// 127.0.0.1 becaust its soo much faster on windows
	vweb.run_at(app, host: '127.0.0.1', port: port, family: .ip, nr_workers: 1)!
}

fn start_site_generation[T](mut app T, output_dir string) ! {
	println('[V Blog] Starting site generation into "${output_dir}"...')
	std_msg := '\nSee the docs for more information on required methods.'

	mut routes := []string{}
	$for method in T.methods {
		routes << method.name

		// validate paths
		if method.name == 'article_page' {
			if method.attrs.any(it.starts_with('/articles/:')) == false {
				eprintln('error: expecting method "article_page" to be a dynamic route that starts with "/articles/"')
				return
			}
		}
	}
	// check if required routes are present
	if 'article_page' !in routes {
		eprintln('error: expecting method "article_page (int) vweb.Result" on "${T.name}"${std_msg}')
		return
	}
	if 'home' !in routes {
		eprintln('error: expecting method "home () vweb.Result on "${T.name}"${std_msg}')
		return
	}

	start := time.ticks()

	// the output directory's path
	dist_path := os.abs_path(output_dir)
	// clear old dir
	if os.exists(dist_path) {
		os.rmdir_all(dist_path)!
	}
	os.mkdir_all(dist_path)!

	// copy static files
	for static_file, static_path in app.static_files {
		// ignore trailing "/" in static files
		static_out_path := os.join_path(dist_path, static_file.all_after_first('/'))
		os.mkdir_all(os.dir(static_out_path))!
		os.cp(static_path, static_out_path)!
	}
	// copy upload dir
	upload_path := os.join_path(dist_path, 'uploads')
	os.mkdir(upload_path)!
	os.cp_all(app.upload_dir, upload_path, true)!

	// home page
	index_path := os.join_path(dist_path, 'index.html')

	i_start := time.ticks()
	app.home()
	i_end := time.ticks()
	println('generated home page in ${i_end - i_start}ms')

	mut index_f := os.create(index_path) or { panic(err) }
	index_f.write(app.s_html.bytes())!
	index_f.close()

	// articles
	articles_path := os.join_path(dist_path, 'articles')
	os.mkdir(articles_path)!

	articles := get_all_articles(mut app.db)
	for article in articles {
		if article.show == false {
			continue
		}

		// generate the article html
		file_art := generate(article.block_data)

		file_path := os.join_path_single(app.pages_dir, '${article.id}.html')
		mut f_art := os.create(file_path) or {
			return error('file "${file_path}" is not writeable')
		}
		f_art.write_string(file_art) or {
			return error('could not write file "${article.id}.html"')
		}
		f_art.close()

		// get html
		article_path := os.join_path(articles_path, article.id.str(), 'index.html')
		os.mkdir_all(os.dir(article_path))!

		a_start := time.ticks()
		app.article_page(article.id)
		a_end := time.ticks()
		println('generated article "${article.name}" in ${a_end - a_start}ms')

		mut f := os.create(article_path) or { panic(err) }
		f.write(app.s_html.bytes())!
		f.close()
	}

	end := time.ticks()

	println('[V Blog] Done! Outputted your website to "${output_dir} in ${end - start}ms')
}
