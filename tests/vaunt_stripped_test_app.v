module main

import vaunt
import vweb
import os
import time

struct App {
	vweb.Context
pub mut:
	dev    bool   [vweb_global] // used by Vaunt internally
	s_html string
	// used by Vaunt to generate html
}

fn exit_after_timeout(timeout_in_ms int) {
	time.sleep(timeout_in_ms * time.millisecond)
	println('>> webserver: pid: ${os.getpid()}, exiting ...')
	exit(0)
}

fn main() {
	if os.args.len < 3 {
		panic('Usage: `vaunt_test_app.exe PORT TIMEOUT_IN_MILLISECONDS`')
	}
	http_port := os.args[1].int()
	assert http_port > 0
	timeout := os.args[2].int()
	assert timeout > 0
	spawn exit_after_timeout(timeout)

	mut app := &App{}
	vaunt.start(mut app, http_port, vaunt.GenerateSettings{})!
}

pub fn (mut app App) index() vweb.Result {
	app.s_html = 'index'
	return app.html(app.s_html)
}

pub fn (mut app App) shutdown() vweb.Result {
	spawn app.gracefull_exit()
	return app.ok('good bye')
}

fn (mut app App) gracefull_exit() {
	eprintln('>> webserver: gracefull_exit')
	time.sleep(100 * time.millisecond)
	exit(0)
}
