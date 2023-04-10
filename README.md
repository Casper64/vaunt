# Vaunt

**Disclamer:** Vaunt is still early software and for now used as a showcase of the
power that V and Vweb is capable of. There might be breaking changes in the future.

Vaunt is a cms writting in [V](https://vlang.io/) that you can use to generate static sites.

## Features
- Admin panel with visual editor
- Image uploads
- Fully static site generation
- Theming

## Roadmap
- Categories
- Custom routes
- Theming support in admin panel
- Custom blocks in the frontend editor

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
[default theme](https://github.com/Casper64/vaunt-default) example 
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

// Base app for Vaunt which you can extend
struct App {
	vweb.Context
	vweb.Controller
pub:
	template_dir string
	upload_dir   string
pub mut:
	db     pg.DB  [vweb_global]
	dev    bool   [vweb_global] // used by Vaunt internally
	s_html string // used by Vaunt to generate html
}

fn main() {
	// insert your own credentials
	db := pg.connect(user: 'dev', password: 'password', dbname: 'vaunt')!
	// setup database and controllers
	controllers := vaunt.init(db, template_dir, upload_dir)!

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

## Admin panel
The admin panel is used to created articles via a visual editor. You can access the 
admin panel by navigating to `"/admin"`. The UI should be self-explanatory.

## Routing
When creating a route the html that is returned must be save in `app.s_html`
before returning. If you forget to store the generated html in `app.s_html` 
the generated output of the static site won't contain your html.

The following routes **must** be defined for the site generation to work:

### Home Page
A method with name `home` and route `"/"`. `home` is used to generate the `index.html`
for you website.

**Example:**
```v ignore
['/']
pub fn (mut app App) home() vweb.Result {
    // save html in `app.s_html` first before returning it
    app.s_html = '<h1>The home page</h1>'
    return app.html(app.s_html)
}
```

### Article Page
A method with name `article_page` and dynamic route "/articles/:article_id".
`article_page` is used to generate the html page for each article.

If you press the `publish` button in the admin panel the html will be generated
and outputted to  `"[template_dir]/articles/[article_id].html"`.

**Example**
```v ignore
['/articles/:article_id']
pub fn (mut app App) article_page(article_id int) vweb.Result {
    article_file := os.join_path(app.template_dir, 'articles', '${article_id}.html')
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

#### Custom Routes
At this moment any custom routes won't be generated, but it's next in my planning.

## Generate
You can generate the static site by passing the `--generate` flag or `-g` for short.
All files needed to host your website will be in the generated `public` directory.
```
v run [project.v] --generate
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

### Utility

Vaunt offers a few utility functions you can use in your routes:

Get all articles:

**Example:**
```v ignore
articles := vaunt.get_all_articles(mut app.db)
```
**Definition:**
```v ignore
get_all_articles(mut db pg.DB) []Article
```

Get an article by id:

**Example:**
```v ignore
current_article := vaunt.get_article(mut app.db, 1)!
```
**Definition:**
```v ignore
get_article(mut db pg.DB, article_id int) !Article
```

Get an image by id:

**Example:**
```v ignore
image := vaunt.get_image(mut app.db, 1)!
```
**Definition:**
```v ignore
get_image(mut db pg.DB, image_id int) !Image
```

## Extensibility
The frontend editor is made with [Vue](https://vuejs.org/) and 
[Editorjs](https://editorjs.io/). You can already extend the ditor with custom blocks.

In the future custom blocks will be able to be registerd in Vaunt by passing a function
that takes a EditorJs block as input and outputs html.

The goal of this project is to provide a backend cms with developers can extend to
create their own themes and extensions.