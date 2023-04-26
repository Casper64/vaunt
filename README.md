# Vaunt

**Disclamer:** Vaunt is still early software and for now used as a showcase of the
power that V and Vweb is capable of. There might be breaking changes in the future.

Vaunt is a cms with visual editor written in [V](https://vlang.io/) that you can 
use to generate static sites.

![vaunt_2](https://user-images.githubusercontent.com/43839798/232623199-0df92ccc-2b12-489c-9a35-b730b9c6476d.png)

## Features
- Admin panel with visual editor
- Image uploads
- Fully static site generation
- User configurable themes

## Requirements
Make sure you have V installed. You can check out the 
[documentation](https://github.com/vlang/v/#installing-v-from-source) to install V.

If you have installed V make sure you have the latest version installed by running `v up`.

## Installation
Run the following command to install Vaunt with the V package manager:
```
v install --git https://github.com/Casper64/vaunt
```

Now you are able to import Vaunt directly into your projects with `import vaunt`!

## Database
For now Vaunt only supports PostgreSQL. You can start a database with 
```
sudo -u postgres psql -c "create database vaunt"
```

## Quick Start
Go to the [Vaunt default theme](https://github.com/Casper64/vaunt-default) 
to start making your website!

## Themes
It is possible to create themes with Vaunt. Go to the 
[Vaunt default theme](https://github.com/Casper64/vaunt-default) example 
to get a quick start with Vaunt.

## Usage

In the following example we start a basic Vaunt app.

```v oksyntax
module main

import vaunt
import vweb
import os
import db.pg

const (
	template_dir = os.abs_path('templates') // where you want to store templates
	upload_dir   = os.abs_path('uploads') // where you want to store uploads
)

// Your theme settings
struct Theme{}

// Base app for Vaunt which you can extend
struct App {
	vweb.Context
	vaunt.Util
pub:
	controllers  []&vweb.ControllerPath
	template_dir string                 [vweb_global]
	upload_dir   string                 [vweb_global]
pub mut:
	dev    bool   [vweb_global] // used by Vaunt internally
	db     pg.DB
	theme  Theme // Theme settings
	s_html string // used by Vaunt to generate html
}

fn main() {
	// insert your own credentials
	db := pg.connect(user: 'dev', password: 'password', dbname: 'vaunt')!
	
	theme := Theme{}
	
	// setup database and controllers
	controllers := vaunt.init(db, template_dir, upload_dir, theme)!

	// create the app
	mut app := &App{
		template_dir: template_dir
		upload_dir: upload_dir
		db: db
		controllers: controllers
	}

	// serve all css files from 'static'
	app.handle_static('static', true)
	// start the Vaunt server
	vaunt.start(mut app, 8080)!
}
```

> **Note**
> The `App` struct showed in the example contains all fields that **must** be present.
> They are used by Vaunt internally and your code won't work without them!

As you can see a Vaunt app is just a Vweb app with some predefined properties. 
And you can add other properties and methods to `App` as it is a regular Vweb application.
The controllers that are generated control the api, admin panel and file uploads.

You can start the application with `v watch run main.v` for single files. If you have 
multiple `.v` files you can put them in the `src` folder and run `v watch run src`.

## Admin panel
The admin panel is used to created articles via a visual editor. You can access the 
admin panel by navigating to `"/admin"`. The UI should be self-explanatory.

## Theme Settings
It is possible to make you theme configurable in the admin panel.

![vaunt_theme](https://user-images.githubusercontent.com/43839798/232623129-68a42746-8fc4-4b49-bde8-7d516b66f31f.gif)

All fields of the `Theme` will be saved in the database and rendered in the admin panel.

### Colors
You can add a color option with the type `vaunt.Color`. For example we could
modify the `Theme` struct from the earlier example to include a background color:

```v oksyntax
struct Theme {
pub mut:
	background vaunt.Color
}
```

### Class Lists
Let's say we want the option to display navigation links aligned left, centered
or right. We can use the `ClassList` struct for that.

**Example:**
```v oksyntax
struct Theme {
pub mut:
    background vaunt.Color
    nav_align  vaunt.ClassList
}

// ...

fn main() {
    // ...
    theme := Theme{
		background: '#ffffff'
		nav_align: vaunt.ClassList{
			name: 'Navigation links aligmnent'
			selected: 'nav-center'
			options: {
				'nav-left':   'left'
				'nav-center': 'center'
				'nav-right':  'right'
			}
		}
	}
    // ...
}
```

In the example above the default background color is set to white and the options
for the navigation links are set as following: 

`name` will be the name displayed in the admin panel.
`selected` will be the default option
`options` is a map where the keys are the class names and the values are the names 
displayed in the admin panel.

### Usage

Using the vweb's `before_request` middleware you can fetch the latest theme settings
before the page is rendered. See the 
[Vaunt default theme](https://github.com/Casper64/vaunt-default) for a more 
comprehensive implementation.

**Example:**

```v ignore
// fetch the new latest theme before processing a request
pub fn (mut app App) before_request() {
	// only update when request is a route, assuming all resources contain a "."
	if app.req.url.contains('..') == false {
		colors_css := vaunt.update_theme(app.db, mut app.theme)
		// store the generated css
		app.styles << colors_css
	}
}
```

All options are available in templates using `app.theme`.

**Example:**
```html
<nav class="@{app.theme.nav_align.selected}"></nav>
```
Will produce:
```html
<nav class="nav-center"></nav>
```

The colors are generated as css variable. The return value of `vaunt.update_theme` 
(`app.styles` is an array). will be
```css
:root {
    --color-background: #ffffff;
}
```
You can put this css directly into your html
```html
<head>
    @for style in app.styles
    <style>@{style}</style>
    @end
</head>
```

## Routing
When creating a route the html that is returned must be save in `app.s_html`
before returning. If you forget to store the generated html in `app.s_html` 
the generated output of the static site won't contain your html.

The following routes **must** be defined for the site generation to work:
- Route for article with a category
- Route for article without a category

### Article with a category
A method with name `category_article_page` and dynamic route 
`"/articles/:category_name/:article_name"`. `category_article_page` is used to 
generate the html page for each article that belongs to a category.

If you press the `publish` button in the admin panel the html will be generated
and outputted to  `"[template_dir]/articles/[category_name]/[article_name].html"`.

**Example:**
```v ignore
['/articles/:category_name/:article_name']
pub fn (mut app App) category_article_page(category_name string, article_name string) vweb.Result {
	article_file := os.join_path(app.template_dir, 'articles', category_name, '${article_name}.html')
	// read the generated article html file
	
	content := os.read_file(article_file) or {
		eprintln(err)
		return app.not_found()
	}

	// save html in `app.s_html` first before returning it
	app.s_html = content
	return app.html(content)
}
```

### Article without a category
A method with name `article_page` and dynamic route `"/articles/:article_name"`.
`article_page` is used to generate the html page for each article.

If you press the `publish` button in the admin panel the html will be generated
and outputted to  `"[template_dir]/articles/[article_name].html"`.

**Example**
```v ignore
['/articles/:article_name']
pub fn (mut app App) article_page(article_name string) vweb.Result {
	article_file := os.join_path(app.template_dir, 'articles', '${article_name}.html')
	
	// read the generated article html file
	content := os.read_file(article_file) or {
		eprintln(err)
		return app.not_found()
	}

	// save html in `app.s_html` first before returning it
	app.s_html = content
	return app.html(content)
}
```

### Custom Routes
All methods on your App that return `vweb.Result` are considered routes.
Vaunt will make sure to output files that are reachable the same way
as while running the dev server.

**Example:**
A method with attribute `['/about']` will produce the html file `about.html`.
As expected a method with attribute `['/nested/about']` will put html file at
`nested/about.html`.

#### Index routes
Index routes (or routes ending with a "/") will have `index.html` as ending. 
So the route `/nested/` will put the html file at `nested/index.html`.

#### Dynamic routes
Currently custom dynamic routes are not supported.

## Generate
You can generate the static site by passing the `--generate` flag or `-g` for short.
All files needed to host your website will be in the generated `public` directory.
```
v run [project] --generate
```

## Api

### Database Models

```v oksyntax
[table: 'articles']
pub struct Article {
pub mut:
	id          int    [primary; sql: serial]
	name        string [unique]
	description string
	show        bool
	thumbnail   int
	image_src   string // need this in json, but there is no skip_sql yet
	block_data  string [nonull]
	created_at  string [default: 'CURRENT_TIMESTAMP'; sql_type: 'TIMESTAMP']
	updated_at  string [default: 'now()'; sql_type: 'TIMESTAMP']
}

[table: 'images']
pub struct Image {
pub mut:
	id         int    [primary; sql: serial]
	name       string [nonull]
	src        string [nonull]
	article_id int    [nonull]
}
```

### Theme Types

```v oksyntax
pub type Color = string

// options of classes
pub struct ClassList {
pub:
	name string
	// The value is the option name displayed in the editor 
	// and the key is the class name
	options map[string]string
pub mut:
	selected string
}
```

### Utility

Vaunt offers a few utility functions you can use in your app:
see [util.v](src/util.v)

## Extensibility
The frontend editor is made with [Vue](https://vuejs.org/) and 
[Editorjs](https://editorjs.io/). You can already extend the ditor with custom blocks.

In the future custom blocks will be able to be registerd in Vaunt by passing a function
that takes a EditorJs block as input and outputs html.

The goal of this project is to provide a backend cms with developers can extend to
create their own themes and extensions.
