import os
import time
import net.http

const sport = 12383
const sport2 = 12384
const localserver = '127.0.0.1:${sport}'
const exit_after_time = 12000 // milliseconds

const vexe = os.getenv('VEXE')
const serverexe = os.join_path(os.cache_dir(), 'vaunt_stripped_test_server.exe')

const output_dir = os.abs_path('tests/public')

// setup of vaunt webserver
fn testsuite_begin() {
	if os.exists(serverexe) {
		os.rm(serverexe) or {}
	}
	if os.exists('tests/uploads') {
		os.rmdir_all('tests/uploads')!
	}
	if os.exists('tests/public') {
		os.rmdir_all('tests/public')!
	}
}

fn test_vaunt_app_can_be_compiled() {
	did_server_compile := os.system('${os.quoted_path(vexe)} -o ${os.quoted_path(serverexe)} tests/vaunt_stripped_test_app.v')
	assert did_server_compile == 0
	assert os.exists(serverexe)
}

fn test_vaunt_runs_in_background() {
	mut suffix := ''
	$if !windows {
		suffix = ' > /dev/null &'
	}
	server_exec_cmd := '${os.quoted_path(serverexe)} ${sport} ${exit_after_time} ${suffix}'
	$if windows {
		spawn os.system(server_exec_cmd)
	} $else {
		res := os.system(server_exec_cmd)
		assert res == 0
	}
	$if macos {
		time.sleep(1000 * time.millisecond)
	} $else {
		time.sleep(100 * time.millisecond)
	}
}

fn test_generate_succeeds() {
	result := os.execute('${os.quoted_path(vexe)} run tests/vaunt_stripped_test_app.v  ${sport2} ${exit_after_time} --generate --out ${output_dir}')
	dump(result.output)
	assert result.exit_code == 0

	// test custom output dir
	assert result.output.contains('"${output_dir}"') == true
	assert os.exists(output_dir) == true
}

fn test_single_file() {
	files := os.ls(output_dir)!

	assert files.len == 1

	file_path := os.join_path(output_dir, 'index.html')
	assert os.exists(file_path) == true

	content := os.read_file(file_path)!
	assert content == 'index'
}

fn testsuite_end() {
	// This test is guaranteed to be called last.
	// It sends a request to the server to shutdown.
	x := http.fetch(
		url: 'http://${localserver}/shutdown'
		method: .get
	) or {
		assert err.msg() == ''
		return
	}
	assert x.status() == .ok
	assert x.body == 'good bye'
}
