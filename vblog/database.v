module vblog

import db.pg

fn init_database(db &pg.DB) ! {
	println('[Vblog] Starting db...')

	sql db {
		create table Article
		create table Image
	}!
}

[table: 'articles']
pub struct Article {
pub mut:
	id          int    [primary; sql: serial]
	name        string [nonull]
	description string
	show        bool
	thumbnail   int
	image_src   string	// need this in json, but there is no skip_sql yet
	block_data  string [nonull]
	created_at  string [default: 'CURRENT_TIMESTAMP'; sql_type: 'TIMESTAMP']
	updated_at  string [default: 'now()'; sql_type: 'TIMESTAMP']
}

[table: 'images']
pub struct Image {
pub mut:
	id   int    [primary; sql: serial]
	name string [nonull]
	src  string [nonull]
}