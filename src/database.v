module vaunt

import db.pg

fn init_database(db &pg.DB) ! {
	println('[Vaunt] Starting db...')

	sql db {
		create table Category
		create table Article
		create table Image
		create table ThemeOption
		create table Tag
	}!
}

[table: 'categories']
pub struct Category {
pub mut:
	id   int    [primary; sql: serial]
	name string [unique]
}

[table: 'articles']
pub struct Article {
pub mut:
	id          int    [primary; sql: serial]
	name        string [unique]
	category_id int
	description string
	show        bool
	thumbnail   int
	image_src   string // need this in json, but there is no skip_sql yet
	block_data  string [nonull]
	created_at  string [default: 'CURRENT_TIMESTAMP'; sql_type: 'TIMESTAMP']
	updated_at  string [default: 'now()'; sql_type: 'TIMESTAMP']
	// tags []Tag [fkey: 'article_id'] // doesn't work???
}

// should use many to many relation, but that's not yet possible with orm
// so there will be duplicates in the database :/
[table: 'tags']
pub struct Tag {
pub mut:
	id         int    [primary; sql: serial]
	article_id int
	name       string [nonull]
	color      string [nonull]
}

[table: 'images']
pub struct Image {
pub mut:
	id         int    [primary; sql: serial]
	name       string [nonull]
	src        string [nonull]
	article_id int    [nonull]
}

[table: 'themeOptions']
struct ThemeOption {
pub mut:
	id          int    [primary; sql: serial]
	name        string [nonull]
	option_type string [nonull]
	data        string
}
