module vaunt

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

pub fn init[T](db &pg.DB, template_dir string, upload_dir string, theme &T) ![]&vweb.ControllerPath {
	init_database(db)!
	update_theme_db(db, theme)!

	vaunt_dir := os.dir(@FILE)

	// ensure articles dir exists
	os.mkdir_all(os.join_path(template_dir, 'articles'))!
	// ensure upload dir exists
	os.mkdir_all(upload_dir)!

	// Api app
	mut api_app := &Api{
		db: db
		template_dir: template_dir
		upload_dir: upload_dir
		articles_url: '/articles'
	}

	mut theme_app := &ThemeHandler{
		db: db
	}

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

	dist_path := os.join_path(vaunt_dir, 'admin')

	admin_app.mount_static_folder_at('${dist_path}/admin', '/')
	admin_app.serve_static('/index.html', '${dist_path}/index.html')

	controllers := [
		vweb.controller('/api/theme', theme_app),
		vweb.controller('/api', api_app),
		vweb.controller('/admin', admin_app),
		vweb.controller('/uploads', upload_app),
	]
	return controllers
}

pub fn start[T](mut app T, port int) ! {
	mut fp := flag.new_flag_parser(os.args)
	fp.application('Vaunt')
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

	// 127.0.0.1 because its soo much faster on windows
	vweb.run_at(app, host: '127.0.0.1', port: port, family: .ip, nr_workers: 1)!
}

fn start_site_generation[T](mut app T, output_dir string) ! {
	println('[Vaunt] Starting site generation into "${output_dir}"...')
	std_msg := '\nSee the docs for more information on required methods.'

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
	upload_path := os.join_path(dist_path, os.base(app.upload_dir))
	os.mkdir(upload_path)!
	os.cp_all(app.upload_dir, upload_path, true)!

	println('[Vaunt] Generating custom pages...')

	app.before_request()

	mut routes := []string{}
	$for method in T.methods {
		$if method.return_type is vweb.Result {
			routes << method.name

			// validate routes
			if method.name == 'article_page' {
				if method.attrs.any(it.starts_with('/articles/:')) == false {
					eprintln('error: expecting method "article_page" to be a dynamic route that starts with "/articles/"')
					return
				}
			} else if method.attrs.any(it.contains(':')) {
				eprintln('error while generating "${method.name}": generating custom dynamic routes is not supported yet!')
			} else if method.attrs.len > 1 {
				eprintln('error while generating "${method.name}": custom routes can only have 1 property: the route')
			} else {
				i_start := time.ticks()

				mut route := method.name
				if method.attrs.len == 1 {
					route = method.attrs[0]
					// add index pages for routes like "/" -> "index.html" or "/pages/" -> "pages/index.html
					if route.ends_with('/') {
						route += 'index'
					}
					// skip leading "/"
					route = route[1..]
				}

				output_file := '${route}.html'

				file_path := os.join_path(dist_path, output_file)
				// make dirs for nested routes
				os.mkdir_all(os.dir(file_path))!

				// run method, resulting html should be in `app.s_html`
				app.$method()
				if app.s_html.len == 0 {
					eprintln('warning: method "${method.name}" produced no html! Did you forget to set `app.s_html`?')
				}

				mut index_f := os.create(file_path)!
				index_f.write(app.s_html.bytes())!
				index_f.close()

				// reset app
				app.s_html = ''

				i_end := time.ticks()
				println('[Vaunt] Generated page "${output_file}" in ${i_end - i_start}ms')
			}
		}
	}
	// articles
	if 'article_page' !in routes {
		eprintln('[Vaunt] Error: expecting method "article_page (int) vweb.Result" on "${T.name}"${std_msg}')
		return
	} else {
		println('[Vaunt] Generating article pages...')
		generate_articles(mut app, dist_path) or { panic(err) }
	}

	end := time.ticks()

	println('[Vaunt] Done! Outputted your website to "${output_dir} in ${end - start}ms')
}

fn generate_articles[T](mut app T, dist_path string) ! {
	articles_path := os.join_path(dist_path, 'articles')
	os.mkdir(articles_path)!

	mut articles := get_all_articles(mut app.db)
	for mut article in articles {
		if article.show == false {
			continue
		}
		// windows saving only as '\r' in the editor??
		article.name = article.name.replace('\r', '')

		a_start := time.ticks()

		// generate the article html
		file_art := generate(article.block_data)

		file_path := os.join_path(app.template_dir, 'articles', '${article.id}.html')
		mut f_art := os.create(file_path) or {
			return error('file "${file_path}" is not writeable')
		}
		f_art.write_string(file_art) or {
			return error('could not write file "${article.id}.html"')
		}
		f_art.close()

		// get html
		article_path := os.join_path(articles_path, '${article.id}.html')
		os.mkdir_all(os.dir(article_path))!

		app.article_page(article.id)
		if app.s_html.len == 0 {
			eprintln('warning: article "${article.name}" produced no html! Did you forget to set `app.s_html`?')
		}

		mut f := os.create(article_path) or { panic(err) }
		f.write(app.s_html.bytes())!
		f.close()

		// reset app
		app.s_html = ''

		a_end := time.ticks()
		println('[Vaunt] Generated article "${article.name}" in ${a_end - a_start}ms')
	}
}
