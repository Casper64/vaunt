module vaunt

import vweb
import db.pg
import os
import flag
import time

pub fn init[T](db &pg.DB, template_dir string, upload_dir string, theme &T, secret string) ![]&vweb.ControllerPath {
	init_database(db)!
	update_theme_db(db, theme)!

	vaunt_dir := os.dir(@FILE)

	// ensure articles dir exists
	os.mkdir_all(os.join_path(template_dir, 'articles'))!
	// ensure upload dir exists
	os.mkdir_all(upload_dir)!

	mut auth_app := &Auth{
		secret: secret
		db: db
	}

	// Api app
	mut api_app := &Api{
		secret: secret
		db: db
		template_dir: template_dir
		upload_dir: upload_dir
		articles_url: '/articles'
	}

	mut theme_app := &ThemeHandler{
		secret: secret
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
		secret: secret
		db: db
	}

	dist_path := os.join_path(vaunt_dir, 'admin')

	admin_app.mount_static_folder_at('${dist_path}/admin', '/')
	admin_app.serve_static('/index.html', '${dist_path}/index.html')

	controllers := [
		vweb.controller('/auth', auth_app),
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
	fp.version('0.2')
	fp.description('Simple static site generator for articles')
	fp.skip_executable()

	f_user := fp.bool('user', `u`, false, 'user mode (not dev), ignored when generating the site')
	f_generate := fp.bool('generate', `g`, false, 'generate the site')
	f_output := fp.string('out', `o`, 'public', 'output dir')
	f_create_user := fp.bool('create-superuser', ` `, false, 'create a new superuser')

	fp.finalize() or {
		println(fp.usage())
		return
	}

	if f_generate {
		app.dev = false
		start_site_generation[T](mut app, f_output)!
		return
	}

	if f_create_user {
		create_super_user(mut app.db)!
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

	// get initial SEO
	mut initial_seo := SEO{}
	$if T is SEOInterface {
		initial_seo = app.seo
	}
	mut urls := []string{}

	app.before_request()

	mut routes := []string{}
	$for method in T.methods {
		$if method.return_type is vweb.Result {
			routes << method.name

			// validate routes at comptime
			if method.name == 'article_page' {
				if method.attrs.any(it.starts_with('/articles/:')) == false {
					eprintln('error: expecting method "article_page" to be a dynamic route that starts with "/articles/"')
					return
				}
			} else if method.name == 'category_article_page' {
				if method.attrs.any(it.starts_with('/articles/:')) == false {
					eprintln('error: expecting method "category_article_page" to be a dynamic route that starts with "/articles/"')
					return
				}
			} else if method.attrs.any(it.contains(':')) {
				eprintln('error while generating "${method.name}": generating custom dynamic routes is not supported yet!')
			} else if method.attrs.len > 1 {
				eprintln('error while generating "${method.name}": custom routes can only have 1 property: the route')
			} else if method.name != 'not_found' {
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
				urls << output_file

				file_path := os.join_path(dist_path, output_file)
				// make dirs for nested routes
				os.mkdir_all(os.dir(file_path))!

				// run method, resulting html should be in `app.s_html`
				app.$method()
				if app.s_html.len == 0 {
					eprintln('warning: method "${method.name}" produced no html! Did you forget to set `app.s_html`?')
				} else {
					mut index_f := os.create(file_path)!
					index_f.write(app.s_html.bytes())!
					index_f.close()

					// reset app
					app.s_html = ''
					$if T is SEOInterface {
						app.seo = initial_seo
					}

					i_end := time.ticks()
					println('[Vaunt] Generated page "${output_file}" in ${i_end - i_start}ms')
				}
			}
		}
	}
	// articles
	if 'article_page' !in routes {
		eprintln('[Vaunt] Error: expecting method "article_page (string) vweb.Result" on "${T.name}"${std_msg}')
		return
	} else if 'category_article_page' !in routes {
		eprintln('[Vaunt] Error: expecting method "category_article_page (string, string) vweb.Result" on "${T.name}"${std_msg}')
	} else {
		println('[Vaunt] Generating article pages...')
		urls << generate_articles(mut app, dist_path) or { panic(err) }
	}

	// sitemap.xml
	$if T is SEOInterface {
		println('[Vaunt] Generating sitemap.xml...')

		if app.seo.website_url == '' {
			println('warning: `SEO.website_url` is not set! Skipping sitemap.xml')
		} else {
			mut sitemap_urls := [app.seo.website_url]
			for url in urls {
				if url == 'index.html' {
					continue
				}

				mut website_url := app.seo.website_url
				if app.seo.website_url.ends_with('/') == false {
					// make sure the full url has a '/' after the website name
					website_url += '/'
				}

				sitemap_urls << website_url + url
			}
			sitemap := generate_sitemap(sitemap_urls)

			mut f := os.create(os.join_path(dist_path, 'sitemap.xml'))!
			f.write_string(sitemap)!
			f.close()
		}
	}

	end := time.ticks()

	println('[Vaunt] Done! Outputted your website to "${output_dir} in ${end - start}ms')
}

fn generate_articles[T](mut app T, dist_path string) ![]string {
	articles_path := os.join_path(dist_path, 'articles')
	os.mkdir(articles_path)!

	// all urls for the articles
	mut urls := []string{}

	// get initial SEO
	mut initial_seo := SEO{}
	$if T is SEOInterface {
		initial_seo = app.seo
	}

	mut articles := get_all_articles(mut app.db)
	for article in articles {
		if article.show == false {
			continue
		}
		a_start := time.ticks()

		// generate the article html
		file_art := generate(article.block_data)

		file_path, mut article_path := get_publish_paths(mut app.db, app.template_dir,
			article) or {
			eprintln('warning: category of article "${article.name}" does not exist!')
			continue
		}

		// create all directories for the category
		os.mkdir_all(os.dir(file_path)) or { return error('file "${file_path}" is not writeable') }

		mut f_art := os.create(file_path) or {
			return error('file "${file_path}" is not writeable')
		}
		f_art.write_string(file_art) or {
			return error('could not write file "${article.name}.html"')
		}
		f_art.close()

		// get html
		article_path += '.html'
		urls << 'articles/${article_path}'

		article_file_path := os.join_path(articles_path, article_path)
		os.mkdir_all(os.dir(article_file_path))!

		// no category
		article_name := sanitize_path(article.name)
		if article.category_id == 0 {
			app.article_page(article_name)
		} else {
			category := get_category_by_id(mut app.db, article.category_id)!
			category_name := sanitize_path(category.name)
			app.category_article_page(category_name, article_name)
		}

		if app.s_html.len == 0 {
			eprintln('warning: article "${article.name}" produced no html! Did you forget to set `app.s_html`?')
		}

		mut f := os.create(article_file_path)!
		f.write(app.s_html.bytes())!
		f.close()

		// reset app
		app.s_html = ''
		$if T is SEOInterface {
			app.seo = initial_seo
		}

		a_end := time.ticks()
		println('[Vaunt] Generated article "${article.name}" in ${a_end - a_start}ms')
	}

	return urls
}
