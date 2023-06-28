module vaunt

import time
import os
import vweb
import net.http

// These interfaces are used to make using these methods optional to the user
interface AppWithTemplateDir {
	template_dir string
}

interface AppWithUploadDir {
	upload_dir string
}

interface AppWithTagPage {
mut:
	tag_page(string) vweb.Result
}

interface AppWithArticlePage {
mut:
	article_page(string) vweb.Result
}

interface AppWithArticleCategoryPage {
mut:
	category_article_page(string, string) vweb.Result
}

interface AppWithUtilUrl {
	url(string) vweb.RawHtml
mut:
	dev bool
}

fn start_site_generation[T](mut app T, output_dir string) ! {
	println('[Vaunt] Starting site generation into "${output_dir}"...')

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

	$if T is AppWithUploadDir {
		// copy upload dir
		upload_path := os.join_path(dist_path, os.base(app.upload_dir))
		os.mkdir(upload_path)!
		os.cp_all(app.upload_dir, upload_path, true)!
	}

	$if T is AppWithUtilUrl {
		app.Util.dev = false
	}

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

			// validate routes
			if method.name == 'article_page' {
				if method.attrs.any(it.starts_with('/articles/:')) == false {
					eprintln('[Vaunt] Error: expecting method "article_page" to be a dynamic route that starts with "/articles/"${std_err_msg}')
					return
				}
			} else if method.name == 'category_article_page' {
				if method.attrs.any(it.starts_with('/articles/:')) == false {
					eprintln('[Vaunt] Error: expecting method "category_article_page" to be a dynamic route that starts with "/articles/"${std_err_msg}')
					return
				}
			} else if method.name == 'tag_page' {
				if method.attrs.any(it.starts_with('/tags/:')) == false {
					eprintln('[Vaunt] Error: expecting method "tag_page" to be a dynamic route that starts with "/tags/"${std_err_msg}')
					return
				}
			} else if method.attrs.any(it.contains(':')) {
				eprintln('error while generating "${method.name}": generating custom dynamic routes is not supported yet!')
			} else if method.name != 'not_found' && validate_route_http_method(method.attrs) {
				i_start := time.ticks()

				mut route := method.name
				mut url := '/${route}'

				// get route name from attributes if any
				for attr in method.attrs {
					if attr.starts_with('/') == false {
						continue
					}
					route = method.attrs[0]

					// add index pages for routes like "/" -> "index.html" or "/pages/" -> "pages/index.html
					url = route
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

				// change app.req.url according to the current route
				app.Context = vweb.Context{
					...app.Context
					req: http.Request{
						...app.Context.req
						url: url
					}
				}

				// run method, resulting html should be in `app.s_html`
				app.$method()
				if verify_app_method_result(mut app, method.name) {
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
	$if T is AppWithTemplateDir {
		// articles
		$if T is AppWithArticlePage || T is AppWithArticleCategoryPage {
			println('[Vaunt] Generating article pages...')
			urls << generate_articles(mut app, dist_path) or { panic(err) }
		}

		// tags
		$if T is AppWithTagPage {
			println('[Vaunt] Generating tag pages...')
			urls << generate_tags(mut app, dist_path) or { panic(err) }
		}
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

	println('[Vaunt] Done! Outputted your website to "${output_dir}" in ${end - start}ms')
}

fn generate_articles[T](mut app T, dist_path string) ![]string {
	$if T !is DbInterface {
		return error('App does not have a "db" field!')
	}
	$if T !is AppWithTemplateDir {
		return error('App does not have a "template_dir" field!')
	}

	articles_path := os.join_path(dist_path, 'articles')
	os.mkdir(articles_path)!

	// all urls for the articles
	mut urls := []string{}

	// get initial SEO
	mut initial_seo := SEO{}
	$if T is SEOInterface {
		initial_seo = app.seo
	}

	mut articles := get_all_articles(app.db)
	for article in articles {
		if article.show == false {
			continue
		}
		a_start := time.ticks()

		// generate the article html
		file_art := generate(article.block_data)

		file_path, mut article_path := get_publish_paths(app.db, app.template_dir, article) or {
			eprintln('warning: category of article "${article.name}" does not exist!')
			continue
		}

		// change app.req.url according to the current route
		current_url := '/articles/${article_path}'
		app.Context = vweb.Context{
			...app.Context
			req: http.Request{
				...app.Context.req
				url: current_url
			}
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

		mut method_name := 'article_page'

		// no category
		article_name := sanitize_path(article.name)
		if article.category_id == 0 {
			$if T is AppWithArticlePage {
				app.article_page(article_name)
			} $else {
				eprintln('[Vaunt] Error: can\'t generate html for article "${article.name}" since the method `article_page` does not exists!\nSee the docs for more information on required methods.')
				continue
			}
		} else {
			category := get_category_by_id(app.db, article.category_id)!
			category_name := sanitize_path(category.name)
			method_name = 'category_article_page'

			$if T is AppWithArticleCategoryPage {
				app.category_article_page(category_name, article_name)
			} $else {
				eprintln('[Vaunt] Error: can\'t generate html for article "${article.name}" since the article has a category and the method `category_article_page` does not exists!\nSee the docs for more information on required methods.')
				continue
			}
		}

		if verify_app_method_result(mut app, '${method_name} (article_name=${article.name})') == false {
			continue
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

fn generate_tags[T](mut app T, dist_path string) ![]string {
	$if T !is DbInterface {
		return error('App does not have a "db" field!')
	}

	tags_path := os.join_path(dist_path, 'tags')
	os.mkdir(tags_path)!

	// all urls for the articles
	mut urls := []string{}

	// get initial SEO
	mut initial_seo := SEO{}
	$if T is SEOInterface {
		initial_seo = app.seo
	}

	tags := get_all_tags(app.db)
	for tag in tags {
		t_start := time.ticks()

		mut tag_path := sanitize_path(tag.name)
		tag_file_path := os.join_path(tags_path, '${tag_path}.html')

		// change app.req.url according to the current route
		current_url := '/tags/${tag_path}'
		app.Context = vweb.Context{
			...app.Context
			req: http.Request{
				...app.Context.req
				url: current_url
			}
		}

		// get html
		tag_path += '.html'
		urls << 'tags/${tag_path}'
		app.tag_page(tag.name)
		if verify_app_method_result(mut app, 'tag_page (name=${tag.name})') == false {
			continue
		}

		if app.s_html.len == 0 {
			eprintln('warning: tag "${tag.name}" produced no html! Did you forget to set `app.s_html`? Skipping output')
			continue
		}

		mut f := os.create(tag_file_path)!
		f.write(app.s_html.bytes())!
		f.close()

		// reset app
		app.s_html = ''
		$if T is SEOInterface {
			app.seo = initial_seo
		}

		t_end := time.ticks()
		println('[Vaunt] Generated tag page "${tag.name}" in ${t_end - t_start}ms')
	}

	return urls
}

// verify_app_method_result checks if the app route returned a valid result. Only 200 status
// codes and no empty values of `s_html`
fn verify_app_method_result[T](mut app T, method_name string) bool {
	defer {
		app.status = '200 OK'
	}
	if app.status.starts_with('200') == false {
		eprintln('warning: method "${method_name}" returned non-200 status! Skipping...')
		return false
	} else if app.s_html.len == 0 {
		eprintln('warning: method "${method_name}" produced no html! Did you forget to set `app.s_html`?')
		return false
	}

	return true
}

fn validate_route_http_method(attrs []string) bool {
	if attrs.len == 0 {
		return true
	}

	mut methods := []string{}
	for attr in attrs {
		if attr.starts_with('/') {
			continue
		}
		methods << attr.to_upper()
	}
	if methods.len != 0 && 'GET' !in methods {
		return false
	}

	return true
}
