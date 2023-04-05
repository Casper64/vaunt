module vblog

import vweb
import db.pg
import time
import os

const (
	vexe = os.getenv('VEXE')
)

pub fn init(db &pg.DB) ! {
	init_database(db)!
}

pub fn start_dev_server() ! {
	mut serverexe := os.join_path(os.cache_dir(), 'vblog_dev_server')
	$if windows {
		serverexe += '.exe'
	}


	// wait a bit for the api server to become active
	time.sleep(time.second)
	did_server_compile := os.system('${os.quoted_path(vblog.vexe)} -o ${os.quoted_path(serverexe)} ../verve/')
	assert did_server_compile == 0
	assert os.exists(serverexe)

	dist_path := os.real_path(os.getwd() + '/../dist')

	spawn os.system('${os.quoted_path(serverexe)} -d ${os.quoted_path(dist_path)} -p 5173')
	println('[VBlog] Dev server running on http://127.0.0.1:5173')
}
