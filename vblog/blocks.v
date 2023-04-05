module vblog

// import json

// [params]
// struct BlockHeaderParams {
// 	article_id int    [required]
// 	text       string
// 	parent_id  int
// 	order      int
// }

// fn (mut app Api) get_block_count(article int) int {
// 	// fetch amount of blocks
// 	total_blocks := sql app.db {
// 		select from Block where article_id == article
// 	}
// 	return total_blocks.len
// }

// fn (mut app Api) insert_block(mut block Block) ?Block {
// 	sql app.db {
// 		insert block into Block
// 	}
// 	id := app.db.last_id()

// 	if id == 0 {
// 		eprintln('failed to insert block ${block}')
// 		return none
// 	}
// 	block.id = id
// 	return block
// }

// fn (mut app Api) create_block_header(header_type int, b BlockHeaderParams) ?Block {
// 	fields := {
// 		'text': b.text
// 	}

// 	mut order := b.order
// 	if order == 0 {
// 		order = app.get_block_count(b.article_id)
// 	}

// 	mut block := Block{
// 		block_type: header_type
// 		article_id: b.article_id
// 		parent_id: b.parent_id
// 		data: json.encode(fields)
// 		order: order
// 	}

// 	return app.insert_block(mut block)
// }

// [params]
// struct BlockTextparams {
// 	article_id int    [required]
// 	text       string
// 	parent_id  int
// 	order      int
// }

// fn (mut app Api) create_block_text(b BlockTextparams) ?Block {
// 	fields := [{
// 		'type': 'normal',
// 		'text': b.text
// 	}]

// 	mut order := b.order
// 	if order == 0 {
// 		order = app.get_block_count(b.article_id)
// 	}

// 	mut block := Block{
// 		block_type: int(BlockType.text)
// 		article_id: b.article_id
// 		parent_id: b.parent_id
// 		data: json.encode(fields)
// 		order: order
// 	}

// 	return app.insert_block(mut block)
// }

// fn (mut app Api) create_block(article_id int, block_type int) ?Block {
// 	if block_type < 3 {
// 		return app.create_block_header(block_type, article_id: article_id)
// 	} else if block_type == 3 {
// 		return app.create_block_text(article_id: article_id)
// 	}

// 	return none
// }
