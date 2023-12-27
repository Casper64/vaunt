module vaunt

import os
import time

pub interface DynamicConfig {
	path string // NOTE: what did I want to use this for??
}

pub struct DynamicRoute {
	arguments []string @[required]
	path      string
}

pub struct MultipleDynamicRoute {
	arguments [][]string @[required]
	path      string
}

pub struct MarkdownDynamicRoute {
	md_dir string @[required]
	path   string
}

pub struct GenerateSettings {
	dynamic_routes map[string]DynamicConfig
}

// generate_dynamic will match `dynamic_conf` to see which kind of dynamic route it is
// and return a list of urls that are generated for that route.
fn generate_dynamic[T](mut app T, dist_path string, dynamic_conf DynamicConfig, initial_seo SEO, method FunctionData) ![]string {
	urls := match dynamic_conf {
		DynamicRoute {
			generate_dynamic_route[T](mut app, dist_path, dynamic_conf, initial_seo, method)!
		}
		MultipleDynamicRoute {
			generate_multiple_dynamic_route[T](mut app, dist_path, dynamic_conf, initial_seo,
				method)!
		}
		MarkdownDynamicRoute {
			generate_markdown_dynamic_route[T](mut app, dist_path, dynamic_conf, initial_seo,
				method)!
		}
		else {
			return error('[Vaunt] Error: no implementation for the dynamic configuration struct passed to "${method.name}".')
		}
	}
	return urls
}

// generate_dynamic_route is used for "normal" dynamic routes: with one dynamic argument
fn generate_dynamic_route[T](mut app T, dist_path string, conf DynamicRoute, initial_seo SEO, method FunctionData) ![]string {
	i_start := time.ticks()

	route, _ := get_route_url_from_method(method.name, method.attrs)
	if route.count(':') == 0 {
		return error('[Vaunt] Error: method "${method.name}" is not a dynamic route!')
	} else if route.count(':') > 1 {
		return error('[Vaunt] Error: method "${method.name}" has multiple dynamic arguments. You have to use `MultipleDynamicRoute` instead of `DynamicRoute` for this route.')
	}

	parts := route.split('/')
	mut urls := []string{}

	// TODO: enable for more than 1 dynamic argument
	for arg in conf.arguments {
		mut parts_clone := parts.clone()

		// replace one argument in the url
		for mut p in parts_clone {
			if p.starts_with(':') {
				p = arg
				break
			}
		}
		mut droute := parts_clone.join('/')
		durl := '/${droute}'

		mut output_file := if droute.ends_with('/') { droute + 'index' } else { droute }
		output_file += '.html'

		urls << output_file

		file_path := os.join_path(dist_path, output_file)
		output_route_html[T](mut app, method.name, [arg], initial_seo, file_path, durl)!
	} // for arg in ...

	i_end := time.ticks()
	println('[Vaunt] Generated dynamic pages for "${method.name}" with `DynamicRoute` in ${i_end - i_start}ms')

	return urls
}

// generate_multiple_dynamic_route is used for routes that have multiple dynamic arguments
fn generate_multiple_dynamic_route[T](mut app T, dist_path string, conf MultipleDynamicRoute, initial_seo SEO, method FunctionData) ![]string {
	i_start := time.ticks()

	route, _ := get_route_url_from_method(method.name, method.attrs)
	parts := route.split('/')
	mut urls := []string{}

	// TODO: enable for more than 1 dynamic argument
	for args in conf.arguments {
		mut parts_clone := parts.clone()

		// replace the arguments in the url
		mut arg_counter := 0
		for mut p in parts_clone {
			if arg_counter == args.len {
				break
			}
			if p.starts_with(':') {
				p = args[arg_counter]
				arg_counter++
			}
		}

		mut droute := parts_clone.join('/')
		durl := '/${droute}'

		mut output_file := if droute.ends_with('/') { droute + 'index' } else { droute }
		output_file += '.html'

		urls << output_file

		file_path := os.join_path(dist_path, output_file)
		output_route_html[T](mut app, method.name, args, initial_seo, file_path, durl)!
	} // for arg in ...

	i_end := time.ticks()
	println('[Vaunt] Generated dynamic pages for "${method.name}" with `DynamicRoute` in ${i_end - i_start}ms')

	return urls
}

// generate_markdown_dynamic_route is used for routes that use `/:path..` to get all markdown
// files in one folder
fn generate_markdown_dynamic_route[T](mut app T, dist_path string, conf MarkdownDynamicRoute, initial_seo SEO, method FunctionData) ![]string {
	i_start := time.ticks()

	route, _ := get_route_url_from_method(method.name, method.attrs)
	if !route.ends_with('...') {
		return error('[Vaunt] Error: dynamic markdown route should end with "..."')
	}
	// the ':path...' part
	dyn_arg := ':' + route.all_after_last(':')

	mut urls := []string{}
	mut files := os.walk_ext(conf.md_dir, '.md')

	top_dir := if conf.md_dir.ends_with('/') { conf.md_dir } else { '${conf.md_dir}/' }

	for path in files {
		// markdown file path is without extension and from the root folder.
		md_file := path.replace(top_dir, '')
		url := md_file.replace('.md', '')
		file_path := os.join_path(dist_path, route.replace(dyn_arg, url)) + '.html'

		output_route_html[T](mut app, method.name, [url], initial_seo, file_path, url)!

		urls << route.replace(dyn_arg, url) + '.html'
	}

	i_end := time.ticks()
	println('[Vaunt] Generated markdown pages for "${method.name}" with `DynamicRoute` in ${i_end - i_start}ms')

	return urls
}
