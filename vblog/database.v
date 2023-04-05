module vblog

import db.pg

fn init_database(db &pg.DB) ! {
	println('[Vblog] Starting db...')

	sql db {
		create table Article
	}!
}

[table: 'articles']
pub struct Article {
pub mut:
	id          int    [primary; sql: serial]
	name        string [nonull]
	description string
	block_data  string [nonull]
	created_at  string [default: 'CURRENT_TIMESTAMP'; sql_type: 'TIMESTAMP']
	updated_at  string [default: 'now()'; sql_type: 'TIMESTAMP']
}

struct ArticleRequest {
	name        string
	description string
}

// pub enum BlockType {
// 	h1
// 	h2
// 	h3
// 	text
// 	image
// }

// struct Block {
// pub mut:
// 	id         int    [primary; sql: serial]
// 	block_id   int    [nonull]
// 	block_type string [nonull]
// 	data       string [nonull]
// 	article_id int
// }
