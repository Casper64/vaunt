module vaunt

import json
import net.urllib
import os
import vweb

// 			Generate Block Html
// =======================================

pub struct Block {
pub:
	id         string
	block_type string @[json: 'type']
	data       string @[required]
}

// generate returns the html form of `blocks`.
pub fn generate(blocks []Block) string {
	mut html := ''

	for idx, block in blocks {
		html += match block.block_type {
			'heading' {
				generate_heading(block, idx)
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
			'alert' {
				generate_alert(block)
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

pub fn generate_heading(block &Block, block_index int) string {
	data := json.decode(HeadingData, block.data) or { HeadingData{} }
	data_id := sanitize_path(data.text)
	id_name := data_id + '-' + block_index.str()

	if data.level == 1 {
		return $tmpl('./templates/blocks/h1.html')
	} else if data.level == 2 {
		return $tmpl('./templates/blocks/h2.html')
	} else if data.level == 3 {
		return $tmpl('./templates/blocks/h3.html')
	} else if data.level == 4 {
		return $tmpl('./templates/blocks/h4.html')
	} else if data.level == 5 {
		return $tmpl('./templates/blocks/h5.html')
	} else if data.level == 6 {
		return $tmpl('./templates/blocks/h6.html')
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

	// properties for the html `picture` `srcset`.
	mut url_small, mut url_medium := '', ''

	name := os.file_name(url)
	alt := if data.caption != '' { '[${data.caption}]' } else { '[${name}]' }

	if url.starts_with('http://127.0.0.1') || url.starts_with('http://localhost') {
		// image is local
		url_s := urllib.parse(data.file['url']) or { urllib.URL{} }
		url = url_s.path

		url_small = os.dir(url) + '/small/' + name
		url_medium = os.dir(url) + '/medium/' + name

		wd := os.getwd()
		// check if the small and medium image path exist
		if os.exists(os.join_path(wd, url_small[1..])) == false {
			url_small = ''
		}
		if os.exists(os.join_path(wd, url_medium[1..])) == false {
			url_medium = ''
		}
	}

	picture := get_html_picture_from_src(url, alt)

	return $tmpl('./templates/blocks/img.html')
}

// get_html_picture_from_url returns a `picture` html element containing 3
// sizes of the image: small (640px), medium (1280px) and full-size, if they exist
// in the `uploads` folder.
pub fn get_html_picture_from_src(url string, alt string) vweb.RawHtml {
	// properties for the html `picture` `srcset`.
	mut url_small, mut url_medium := '', ''

	name := os.file_name(url)
	url_small = os.dir(url) + '/small/' + name
	url_medium = os.dir(url) + '/medium/' + name

	wd := os.getwd()
	// check if the small and medium image path exist
	if os.exists(os.join_path(wd, url_small[1..])) == false {
		url_small = ''
	}
	if os.exists(os.join_path(wd, url_medium[1..])) == false {
		url_medium = ''
	}

	return $tmpl('./templates/blocks/picture.html')
}

pub struct EmbedData {
pub:
	service string
	source  string @[skip]
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
	with_headings bool       @[json: withHeadings]
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

pub struct AlertData {
pub:
	typ  string
	text string
}

pub fn generate_alert(block &Block) string {
	mut data := json.decode(AlertData, block.data) or { AlertData{} }
	return $tmpl('./templates/blocks/alert.html')
}
