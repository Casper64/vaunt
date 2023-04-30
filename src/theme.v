module vaunt

import db.pg
import json
import vweb
import strconv

// Public theme data types:
pub type Color = string

// options of classes
pub struct ClassList {
pub:
	name string
	// key is the option name displayed in the editor and the value is the class
	options map[string]string
pub mut:
	selected string
}

// Why do I use this reflection?
// Well, in the frontend editor i need to have the option type available for
// rendering the options. Plus now each options is stored as single row in the
// database. No need to pass the whole json theme to the api only 1 update.
// I might change this code later to use x.json2 and use Sum types

// update_theme_db updates the database at the start of the app to ensure that
// all options are in the database
fn update_theme_db[T](db &pg.DB, theme &T) ! {
	options := sql db {
		select from ThemeOption
	} or { []ThemeOption{} }
	// keep track of all fields used in the struct
	mut field_names := options.map(fn (o ThemeOption) string {
		return o.name
	})

	$for field in T.fields {
		ind := field_names.index(field.name)
		if ind != -1 {
			field_names.delete(ind)
		}

		rows := sql db {
			select from ThemeOption where name == field.name
		}!

		mut should_insert := true
		if rows.len != 0 {
			if rows[0].option_type.int() != field.typ {
				// type has changed so we need to reinsert the row
				sql db {
					delete from ThemeOption where name == field.name
				}!
				should_insert = true
			} else {
				should_insert = false
			}
		}

		if should_insert {
			// field is not in db yet
			mut row := ThemeOption{}
			$if field.typ is Color {
				row.name = field.name
				row.option_type = 'Color'
				row.data = theme.$(field.name)
			} $else $if field.typ is ClassList {
				row.name = field.name
				row.option_type = 'ClassList'
				row.data = json.encode(theme.$(field.name))
			} $else {
				// No support for custom field types
				return error('field "${field.name}" of theme has an invalid type!')
			}
			sql db {
				insert row into ThemeOption
			}!
		}
	}
	// remove options in the database that are no longer used
	for other_field in field_names {
		sql db {
			delete from ThemeOption where name == other_field
		}!
	}
}

// update_theme retrieves all options from the database and updates the theme
pub fn update_theme[T](db &pg.DB, mut theme T) string {
	mut all_colors := map[string]string{}

	options := sql db {
		select from ThemeOption
	} or { []ThemeOption{} }

	// match each field type and set the value
	$for field in T.fields {
		$if field.typ is Color {
			color_fields := options.filter(it.option_type == 'Color' && it.name == field.name)
			theme.$(field.name) = color_fields[0].data
			all_colors[field.name] = color_fields[0].data
		} $else $if field.typ is ClassList {
			classlist_fields := options.filter(it.option_type == 'ClassList'
				&& it.name == field.name)
			if data := json.decode(ClassList, classlist_fields[0].data) {
				theme.$(field.name) = data
			}
		}
	}
	css := get_css_from_colors(all_colors)
	return '<style>${css}</style>'
}

fn get_css_from_colors(colors map[string]string) string {
	mut css := '\n:root {\n'

	for name, val in colors {
		css += '\t--color-${name}: ${val};\n'
		css += '\t--color-${name}-rgb: ${to_seperate_rgb(val)};\n'
	}

	css += '}\n'
	return css
}

fn to_seperate_rgb(hex_color string) string {
	mut rgb := ''
	for i := 1; i < 7; i += 2 {
		number := strconv.parse_int(hex_color[i..i + 2], 16, 0) or { 0 }
		rgb += '${number}, '
	}

	return rgb#[..-2]
}

// Theme Api routes:
struct ThemeHandler {
	vweb.Context
pub:
	middlewares map[string][]vweb.Middleware = {
		'/': [cors]
	}
pub mut:
	db pg.DB [required; vweb_global]
}

['/'; get; options]
pub fn (mut app ThemeHandler) theme() vweb.Result {
	options := sql app.db {
		select from ThemeOption
	} or { []ThemeOption{} }
	return app.json(options)
}

['/color'; get; options]
pub fn (mut app ThemeHandler) get_all_colors() vweb.Result {
	options := sql app.db {
		select from ThemeOption where option_type == 'Color'
	} or { []ThemeOption{} }

	mut colors := map[string]string{}
	for opt in options {
		colors[opt.name] = opt.data
	}

	return app.json(colors)
}

['/color'; post]
pub fn (mut app ThemeHandler) set_all_colors() vweb.Result {
	colors := json.decode(map[string]string, app.req.data) or {
		map[string]string{}
	}

	for key, val in colors {
		sql app.db {
			update ThemeOption set data = val where name == key
		} or {
			app.set_status(500, '')
			return app.text('error: could not update colors')
		}
	}

	return app.ok('')
}

['/color/:name'; get; options]
pub fn (mut app ThemeHandler) get_color(name string) vweb.Result {
	color := sql app.db {
		select from ThemeOption where name == name && option_type == 'Color'
	} or { []ThemeOption{} }

	if color.len == 0 {
		app.set_status(404, '')
		return app.text('')
	} else {
		return app.text(color[0].data)
	}
}

['/color/:name'; post]
pub fn (mut app ThemeHandler) set_color(name string) vweb.Result {
	color := app.req.data

	sql app.db {
		update ThemeOption set data = color where name == name
	} or {
		app.set_status(500, '')
		return app.text('error: could update Color')
	}
	return app.ok('')
}

['/classlist'; get; options]
pub fn (mut app ThemeHandler) get_all_classlists() vweb.Result {
	options := sql app.db {
		select from ThemeOption where option_type == 'ClassList'
	} or { []ThemeOption{} }

	mut classlists := map[string]ClassList{}
	for opt in options {
		classlists[opt.name] = json.decode(ClassList, opt.data) or { ClassList{} }
	}

	return app.json(classlists)
}

['/classlist'; post]
pub fn (mut app ThemeHandler) set_all_classlists() vweb.Result {
	classlists := json.decode(map[string]ClassList, app.req.data) or {
		map[string]ClassList{}
	}

	for key, val in classlists {
		data := json.encode(val)
		sql app.db {
			update ThemeOption set data = data where name == key
		} or {
			app.set_status(500, '')
			return app.text('error: could not update classlists')
		}
	}

	return app.ok('')
}

['/classlist/:name'; get; options]
pub fn (mut app ThemeHandler) get_classlist(name string) vweb.Result {
	classlist := sql app.db {
		select from ThemeOption where name == name && option_type == 'ClassList'
	} or { []ThemeOption{} }

	if classlist.len == 0 {
		app.set_status(404, '')
		return app.text('')
	} else {
		app.send_response_to_client('application/json', classlist[0].data)
		return app.ok('')
	}
}

['/classlist/:name'; post]
pub fn (mut app ThemeHandler) set_classlist(name string) vweb.Result {
	classlist := app.req.data
	sql app.db {
		update ThemeOption set data = classlist where name == name
	} or {
		app.set_status(500, '')
		return app.text('error: could not update ClassList')
	}

	return app.ok('')
}
