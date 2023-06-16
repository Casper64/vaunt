module vaunt

import json
import net.urllib

// 			Generate Block Html
// =======================================

pub struct Block {
pub:
	id         string
	block_type string [json: 'type']
	data       string [required]
}

pub fn generate(data string) string {
	blocks := json.decode([]Block, data) or { []Block{} }

	mut html := ''

	for block in blocks {
		html += match block.block_type {
			'heading' {
				generate_heading(block)
			}
			'paragraph' {
				generate_paragraph(block)
			}
			'linkTool' {
				generate_link(block)
			}
			'image' {
				generate_image(block)
			}
			'embed' {
				generate_embed(block)
			}
			'quote' {
				generate_quote(block)
			}
			'table' {
				generate_table(block)
			}
			'code' {
				generate_code(block)
			}
			'list' {
				generate_list(block)
			}
			else {
				''
			}
		}
	}
	return html
}

pub struct HeadingData {
pub:
	text  string
	level int
}

pub fn generate_heading(block &Block) string {
	data := json.decode(HeadingData, block.data) or { HeadingData{} }
	id_name := sanitize_path(data.text)

	if data.level == 1 {
		return $tmpl('./templates/blocks/h1.html')
	} else if data.level == 2 {
		return $tmpl('./templates/blocks/h2.html')
	} else if data.level == 3 {
		return $tmpl('./templates/blocks/h3.html')
	} else {
		return ''
	}
}

pub struct ParagraphData {
pub:
	text string
}

pub fn generate_paragraph(block &Block) string {
	data := json.decode(ParagraphData, block.data) or { ParagraphData{} }
	return $tmpl('./templates/blocks/p.html')
}

pub fn generate_link(block &Block) string {
	data := json.decode(LinkData, block.data) or { LinkData{} }
	url := urllib.parse(data.link) or { urllib.URL{} }
	anchor := '${url.scheme}://${url.host}'

	return $tmpl('./templates/blocks/link.html')
}

pub struct ImageData {
pub:
	caption string
	file    map[string]string
}

pub fn generate_image(block &Block) string {
	data := json.decode(ImageData, block.data) or { ImageData{} }

	mut url := data.file['url']
	// check if image is local or not
	if url.starts_with('http://127.0.0.1') || url.starts_with('http://localhost') {
		url_s := urllib.parse(data.file['url']) or { urllib.URL{} }
		url = url_s.path
	}

	img_alt := if data.caption != '' { '[${data.caption}]' } else { '[image]' }
	return $tmpl('./templates/blocks/img.html')
}

pub struct EmbedData {
pub:
	service string
	source  string [skip]
	embed   string
	width   int
	height  int
	caption string
}

pub fn generate_embed(block &Block) string {
	data := json.decode(EmbedData, block.data) or { EmbedData{} }
	return $tmpl('./templates/blocks/embed.html')
}

pub struct QuoteData {
pub:
	text    string
	caption string
}

pub fn generate_quote(block &Block) string {
	data := json.decode(QuoteData, block.data) or { QuoteData{} }
	return $tmpl('./templates/blocks/quote.html')
}

pub struct TableData {
pub mut:
	with_headings bool       [json: withHeadings]
	content       [][]string
}

pub fn generate_table(block &Block) string {
	mut data := json.decode(TableData, block.data) or { TableData{} }

	mut table_headers := []string{}
	if data.with_headings {
		table_headers = data.content[0]
		data.content.delete(0)
	}

	table_rows := data.content

	return $tmpl('./templates/blocks/table.html')
}

pub struct CodeData {
pub:
	language string
pub mut:
	code string
}

pub fn generate_code(block &Block) string {
	mut data := json.decode(CodeData, block.data) or { CodeData{} }

	// escape html tags
	data.code = data.code.replace('<', '&lt;')
	data.code = data.code.replace('>', '&gt;')

	lang_class := 'language-${data.language.to_lower()}'

	return $tmpl('./templates/blocks/code.html')
}

pub struct ListData {
pub mut:
	style string
	items []ListItem
}

pub struct ListItem {
pub mut:
	content string
	items   []ListItem
}

fn generate_li(data ListItem, list_type string) string {
	if data.items.len > 0 {
		lis := data.items.map(fn [list_type] (item ListItem) string {
			return generate_li(item, list_type)
		})

		return '<li>${data.content}\n<${list_type}>${lis.join_lines()}</${list_type}></li>'
	} else {
		return '<li>${data.content}</li>'
	}
}

pub fn generate_list(block &Block) string {
	mut data := json.decode(ListData, block.data) or { ListData{} }

	list_type := if data.style == 'ordered' { 'ol' } else { 'ul' }
	lis := data.items.map(fn [list_type] (item ListItem) string {
		return generate_li(item, list_type)
	})

	return '<${list_type}>${lis.join_lines()}</${list_type}>'
}
