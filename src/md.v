module vaunt

import json
import markdown
import net.html

// get_blocks_from_markdown converts the markdown string `md` to Vaunt blocks.
// These blocks can be added to an article if they are JSON encoded.
pub fn get_blocks_from_markdown(md string) []Block {
	// since the markdown is user uploaded the user is responsible for any html that is still left.
	// only removing the script tags and some basic tags is enough for Vaunt's purpose
	sanitized := md.replace('javascript:', '').replace('vbscript:', '').replace('file:',
		'').replace('<script', '&lt;script')
	md_html := '<html><body>${markdown.to_html(sanitized)}</body></html>'
	doc := html.parse(md_html)
	elements := doc.get_tags(name: 'body')[0].children.clone()
	blocks := generate_blocks(elements)
	return blocks
}

fn generate_blocks(elements []&html.Tag) []Block {
	mut blocks := []Block{}
	for tag in elements {
		match tag.name {
			'h1' {
				blocks << insert_heading(tag, 1)
			}
			'h2' {
				blocks << insert_heading(tag, 2)
			}
			'h3' {
				blocks << insert_heading(tag, 3)
			}
			'p' {
				if tag.children.len > 0 && tag.children[0].name == 'img' {
					blocks << insert_image(tag.children[0])
				} else {
					blocks << insert_paragraph(tag)
				}
			}
			'pre' {
				blocks << insert_code(tag.children[0])
			}
			'ol' {
				blocks << insert_list(tag, 'ordered')
			}
			'ul' {
				blocks << insert_list(tag, 'unordered')
			}
			'blockquote' {
				blocks << insert_blockquote(tag.children[0])
			}
			'table' {
				blocks << insert_table(tag)
			}
			else {}
		}
	}

	return blocks
}

fn replace_inline_stuff(old_text string) string {
	mut text := old_text

	// replace inner code
	text = text.replace('<code>', '<code class="inline-code">')

	// replace <strong> with <b>
	text = text.replace('<strong>', '<b>')
	text = text.replace('</strong>', '</b>')
	return text
}

fn insert_heading(tag &html.Tag, level int) Block {
	heading := HeadingData{
		text: tag.text()
		level: level
	}

	return Block{
		block_type: 'heading'
		data: json.encode(heading)
	}
}

fn insert_paragraph(tag &html.Tag) Block {
	// remove outer tag
	mut content := replace_tag_name(tag.str(), 'p')
	content = replace_inline_stuff(content)

	return Block{
		block_type: 'paragraph'
		data: json.encode(ParagraphData{
			text: content
		})
	}
}

fn insert_image(tag &html.Tag) Block {
	data := ImageData{
		caption: tag.attributes['alt']
		file: {
			'url': tag.attributes['src']
		}
	}

	return Block{
		block_type: 'image'
		data: json.encode(data)
	}
}

fn insert_code(tag &html.Tag) Block {
	mut lang := tag.class_set.pick() or { '' }
	lang = lang.replace('language-', '').to_upper()
	if lang == '' {
		lang = 'BASH'
	}

	data := CodeData{
		code: tag.text()
		language: lang
	}

	return Block{
		block_type: 'code'
		data: json.encode(data)
	}
}

// TODO: enable nested list
fn insert_list(tag &html.Tag, list_type string) Block {
	mut data := ListData{
		style: list_type
	}

	for child in tag.children {
		if child.name == 'li' {
			content := replace_tag_name(child.str(), 'li')
			data.items << ListItem{
				content: replace_inline_stuff(content)
			}
		}
	}

	return Block{
		block_type: 'list'
		data: json.encode(data)
	}
}

fn insert_blockquote(tag &html.Tag) Block {
	mut content := replace_tag_name(tag.str(), 'blockquote')
	content = replace_tag_name(content, 'p')
	content = replace_inline_stuff(content)
	mut data := QuoteData{
		text: content
	}

	return Block{
		block_type: 'quote'
		data: json.encode(data)
	}
}

fn insert_table(tag &html.Tag) Block {
	mut data := TableData{}

	headings := tag.get_tags('th')
	if headings.len > 0 {
		data.with_headings = true
		data.content << []string{}
		for th in headings {
			mut content := replace_tag_name(th.str(), 'th')
			content = replace_inline_stuff(content)
			data.content[0] << content
		}
	}

	rows := tag.get_tags('tr')
	for tr in rows {
		mut content := []string{}

		columns := tr.get_tags('td')
		for td in columns {
			mut txt := replace_tag_name(td.str(), 'td')
			txt = replace_inline_stuff(txt)
			content << txt
		}

		if content.len > 0 {
			data.content << [content]
		}
	}

	return Block{
		block_type: 'table'
		data: json.encode(data)
	}
}

[inline]
fn replace_tag_name(txt string, tag string) string {
	return txt.replace('<${tag}>', '').replace('</${tag}>', '')
}
