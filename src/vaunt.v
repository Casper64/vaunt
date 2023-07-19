module vaunt

import flag
import net
import orm
import os
import vweb

const (
	std_err_msg = '\nSee the docs for more information on required methods.'
)

pub fn init[T](db orm.Connection, template_dir string, upload_dir string, theme &T, secret string) ![]&vweb.ControllerPath {
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

interface DbInterface {
	db voidptr
}

[params]
pub struct RunParams {
	family               net.AddrFamily = .ip
	host                 string = '127.0.0.1'
	nr_workers           int    = 1
	pool_channel_slots   int    = 1000
	show_startup_message bool   = true
}

pub fn start[T](mut app T, port int, params RunParams) ! {
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
		$if T is DbInterface {
			create_super_user(app.db)!
		} $else {
			eprintln('error: cannot create user: missing field "db".\nYou have to use the CMS backend to set users: `vaunt.init`')
		}
		return
	}

	// start web server in dev mode
	app.dev = !f_user

	combined_params := vweb.RunParams{
		...params
		port: port
	}

	// 127.0.0.1 because its soo much faster on windows
	vweb.run_at(app, combined_params)!
}
