# Vaunt

**Current version:** 0.2

Vaunt is a static site generator with built-in cms and visual block editor
written in [V](https://vlang.io/).

**Disclamer:** Vaunt is still early software. There might be breaking changes
until 0.3, but these changes will be minor.

**License**
About the license: any website generated with Vaunt is license free since it doesn't 
contain any code used in this repository.

![vaunt_2](https://user-images.githubusercontent.com/43839798/232623199-0df92ccc-2b12-489c-9a35-b730b9c6476d.png)

## Features
- Static site generator
- easy to configure SEO (Search Engine Optimization)
- The CMS backend is optional
- Admin panel and visual block editor for content creation
- User configurable themes
- Image uploads automatically generate small, medium and large sizes

See [only use static generator](#only-static-generator) if you only want to convert your vweb 
application into a static website and don't need the admin panel.

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
	app_secret   = 'my-256-bit-secret' // secret key used to generate secure hashes
)

// Your theme settings
struct Theme{}

// Base app for Vaunt which you can extend
struct App {
	vweb.Context
	vweb.Controller
	vaunt.Util
pub:
	template_dir string                 [vweb_global]
	upload_dir   string                 [vweb_global]
pub mut:
	dev    bool   [vweb_global] // used by Vaunt internally
	db     pg.DB
	theme  Theme // Theme settings
}

fn main() {
	// insert your own credentials
	db := pg.connect(user: 'dev', password: 'password', dbname: 'vaunt')!
	
	theme := Theme{}
	
	// setup database and controllers
	controllers := vaunt.init(db, template_dir, upload_dir, theme, app_secret)!

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

pub fn (mut app App) before_request() {
	// copy database connection to Util
	app.Util.db = app.db
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

## Only static generator
You can also use Vaunt to generate a static version of your vweb app if you don't need
the CMS backend.

You can still use the [SEO](#search-engine-optimization-seo) utilities.

You only have to set `app.s_html` in the routes you want to generate.
See [custom routes](#custom-routes) and [generate](#generate) for more information.

**Example:**
```v
module main

import vaunt
import vweb

struct App {
	vweb.Context
pub mut:
	dev    bool   [vweb_global] // used by Vaunt internally
	s_html string // used by Vaunt to generate html
}

fn main() {
	mut app := &App{}
	vaunt.start(mut app, 8080)!
}

pub fn (mut app App) index() vweb.Result {
	// save html in `app.s_html` first before returning it
	app.s_html = 'index'
	return app.html(app.s_html)
}
```

## Admin panel
The admin panel is used to created articles via a visual editor. You can access the
admin panel by navigating to `"/admin"`.

### Create a user
To be able to access the admin you will need to create a superuser.

```bash
v run src --create-superuser
```

Follow the instructions after which you can log in with the created user and password.

### Authentication settings
By default, the API and admin panel can only be accessed when authenticated.
Vaunt includes 3 function with which you can protect your routes / app.

**Only allow authenticated users, else redirect to login page**:
```v ignore
vaunt.login_required(mut app.Context, app_secret)
```

**Only allow authenticated users, else send HTTP 401**:
```v ignore
login_required_401(mut app.Context, app_secret)
```

Or you can check if the current user is a superuser and set `vaunt.Util.is_superuser`

**Example**:
```v ignore
app.is_superuser = vaunt.is_superuser(mut app.Context, app_secret)
```

You can put either one of these functions in `pub fn (mut app App) before_request()`
to enable them for your whole app. Or call them in individual routes.

### Caveats
When you generate the site all forms of authentication will be skipped,
except if you return early.

## Routing
When creating a route the html that is returned must be saved in `app.s_html`
before returning. If you forget to store the generated html in `app.s_html` 
the generated output of the static site won't contain your html.

There are three dynamic routes that vaunt can generate html for:

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
	// save html in `app.s_html` first before returning it
	app.s_html = app.category_article_html(category_name, article_name, template_dir) or {
		return app.not_found()
	}
	return app.html(app.s_html)
}
```

### Article without a category
A method with name `article_page` and dynamic route `"/articles/:article_name"`.
`article_page` is used to generate the html page for each article.

If you press the `publish` button in the admin panel the html will be generated
and outputted to  `"[template_dir]/articles/[article_name].html"`.

**Example:**
```v ignore
['/articles/:article_name']
pub fn (mut app App) article_page(article_name string) vweb.Result {
	// save html in `app.s_html` first before returning it
	app.s_html = app.article_html(article_name, template_dir) or { return app.not_found() }
	return app.html(app.s_html)
}
```

### Tags
You can create tags in the admin panel and generate a html page for every tag. 
Add a`tag_page` method with dynamic route `"/tags/:tag_name"`.

The html pages are generated in `"[template_dir]/tags/[tag_name].html"`.

**Example:**
```v ignore
['/tags/:tag_name']
pub fn (mut app App) tag_page(tag_name string) vweb.Result {
	tag := app.get_tag(tag_name) or { return app.not_found() }

	content := 'tag: ${tag_name}'

	// save html in `app.s_html` first before returning it
	app.s_html = content
	return app.html(app.s_html)
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

```v ignore
// will generate in `about.html`
pub fn (mut app App) about() vweb.Result {
	app.s_html = 'About Vaunt'
	return app.html(app.s_html)
}
```

#### Index routes
Index routes (or routes ending with a "/") will have `index.html` as ending. 
So the route `/nested/` will put the html file at `nested/index.html`.

#### Dynamic routes
Currently custom dynamic routes are not supported.

## Generate
You can generate the static site by passing the `--generate` flag or `-g` for short.
All files needed to host your website will be in the generated `public` directory.
Including all static files.

```
v run [project] --generate
```

### Correct URL's

Typically, you would write a link to another page in vweb like this:
```html
<a href="/my-page">My page</a>
```

But when the website is generated the link breaks, because browsers expect html files. 
To fix this you can use the `url` method on `vaunt.Util`. This method adds `.html` after 
the passed route when the app is being generated.

**Example:**
```html
<a href="@{app.url('/my-page')}">My page</a>
```

> **Note**
> Don't add the quotes `""` in the href attribute!

**Result:**
```html
<a href="/my-page.html">My page</a>
```

## Search Engine Optimization (SEO)

SEO is used to place your website higher in the rankings of search engines like google.
One method to improve SEO is to provide metadata about the pages contents in the form 
of html `meta` tags. This method is used by Vaunt.

A common protocol is [OpenGraph](https://ogp.me/). You might have noticed that if you share 
a link via WhatsApp or any other messaging app you sometimes see this card markup with the
name of the page from the link with a small description and often an image. This card is 
generated with the [OpenGraph](https://ogp.me/) protocol. And it never hurts to enable it!

The integrated SEO settings can be enabled by adding `vaunt.SEO` to your `App` struct.
```v ignore
struct App {
// ...
pub mut:
    seo vaunt.SEO [vweb_global] // SEO configuration
// ...
}
```

And adding it to your html templates along with the [OpenGraph](https://ogp.me/) prefix.
```html
<html prefix="@app.seo.og.prefix">
<head>
    @{app.seo.html()}
</head>
</html>
```

### Articles

The meta tags for articles can be automatically generated if you use `SEO.set_article`.
Let's modify the `article_page` to enable SEO support (You can do the same for
`category_article_page`).

```v ignore
['/articles/:article_name']
pub fn (mut app App) article_page(article_name string) vweb.Result {
	// get the article by name
	article := vaunt.get_article_by_name(app.db, article_name) or { return app.not_found() }
	// set seo
	app.seo.set_article(article, app.req.url)

	// save html in `app.s_html` first before returning it
	app.s_html = app.article_html(article_name, template_dir) or { return app.not_found() }
	return app.html(content)
}
```

This will set the following meta tags:
- `meta` with `name="description"`
- `og:title`
- `og:description`
- `og:image`
- `og:url`
- `og:type = 'article'`
- `article:published_time`
- `article:modified_time`

> **Note**
> about twitter: the Twitter API's default behaviour is to fallback on
> OpenGraph tags, so there's no need to set double meta tags like 'twitter:description'

The most common properties of OpenGraph and Twitter are present in `SEO.og` and `SEO.twitter`
respectively. If you need any other properties you can add them to `other_properties`.

**Example:**
```v ignore
app.seo.og.other_properties['image:alt'] = 'Image Description'
```

Will result into
```html
<meta property="og:image:alt" content="Image Description">
```

### Routes
In other routes you can modify `app.seo` to your preferences. Let's add a title and 
description and set the page url for the about page.

```v ignore
// will generate in `about.html`
pub fn (mut app App) about() vweb.Result {
	app.seo.og.title = 'About Vaunt'
	app.seo.set_description('Vaunt is a cms written in V with a frontend editor in Vue. It was created by Casper Kuethe in 2023')
	app.seo.set_url(app.req.url)
	
	app.s_html = 'About Vaunt'
	return app.html(app.s_html)
}
```

> **Note**
> `SEO.set_url` will prefix `SEO.website_url` to the passed path.

This will set the following meta tags:
- `meta` with `name="description"`
- `og:title`
- `og:description`
- `og:url`

### Providing default options
Sometimes you want to define SEO properties for the whole website like the website url.
You can set those properties when you create the app. 

**Example**
```v ignore
mut app := &App{
	// ...
	seo: vaunt.SEO{
		// Provide the website's url
		website_url: 'https://example.com'
		twitter: vaunt.Twitter{
			// twitter:card
			card_type: .summary
			// twitter:site
			site: '@casper_kuethe'
			// twitter:creator
			creator: '@casper_kuethe'
		}
		og: vaunt.OpenGraph{
			// og:site_name
			site_name: 'Vaunt'
			article: vaunt.OpenGraphArticle{
				// article:author
				author: ['Casper Kuethe']
			}
		}
	}
}
```

For all available options see [the SEO api](#seo). 

### Sitemap
The `sitemap.xml` file is automatically generated if you provide `SEO.website_url`.


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
	// copy database connection to Util
	app.Util.db = app.db
	
	// only update when request is a route, assuming all resources contain a "."
	if app.req.url.contains('.') == false {
		app.theme_css = vaunt.update_theme(app.db, mut app.theme)
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

The generated css is stored in `app.theme_css` and is a style tag which contains the css.
You can directly include `app.theme_css` in your templates.

**Example:**
```html
<head>
    @{app.theme_css}
</head>
```

## Api

### Utility

Vaunt offers a few utility functions that you can use in your app for getting articles,
categories and other stuff:
see [util.v](src/util.v)

Most of the utility functions are available on the `Util` struct, and you could use them in 
templates, except for the functions that return a `Result` type.
```html
<ul>
    @for article in app.get_all_articles()
        <li>@article.name</li>
    @endfor
</ul>
```
#### Templates

```v
// url adds '.html' after the url if the site is being generated
// usage: `href="@{app.url('/my-page')}"`
pub fn (u &Util) url(url string) vweb.RawHtml

// get the correct url in your templates
// usage: `href="@{app.article_url(article)}"`
pub fn (u &Util) article_url(article Article) string

// article_html returns the html for that article
pub fn (u &Util) article_html(article_name string, template_dir string) !vweb.RawHtml

// category_article_html returns the html for that article with category
pub fn (u &Util) category_article_html(category_name string, article_name string, template_dir string) !vweb.RawHtml

// html_picture_from_article_thumbnail returns a `<picture>` tag containing the different
// sizes of the articles thumbnail, if they exist.
// usage: `@{app.html_picture_from_article_thumbnail(article)}`
pub fn (u &Util) html_picture_from_article_thumbnail(article Article) vweb.RawHtml 
```

#### Vweb Config
You can edit the vweb configuration in `vaunt.start`

**Example:**

```v
vaunt.start(mut app, 8080, host: '0.0.0.0', nr_workers: 4)
```

```v
[params]
pub struct RunParams {
	family               net.AddrFamily = .ip
	host                 string = '127.0.0.1'
	nr_workers           int    = 1
	pool_channel_slots   int    = 1000
	show_startup_message bool   = true
}
```

#### Database

```v
pub fn (u &Util) get_all_articles() []Article

pub fn (u &Util) get_articles_by_category(category int) []Article

pub fn (u &Util) get_articles_by_tag(name string) []Article
    
pub fn (u &Util) get_article_by_name(name string) !Article

pub fn (u &Util) get_article_by_id(id int) !Article

pub fn (u &Util) get_all_categories() []Category

pub fn (u &Util) get_category_by_id(id int) !Category

pub fn (u &Util) get_image_by_id(id int) !Image
    
pub fn (u &Util) get_all_tags() []Tag 

pub fn (u &Util) get_tags_from_article(article_id int) []Tag

pub fn (u &Util) get_tag(name string) !Tag

pub fn (u &Util) get_tag_by_id(id int) !Tag
```


### Articles
The `[]Article` type has a couple of built-in functions to filter the array.

```v
pub fn (a []Article) no_category() []Article {
	return a.filter(it.category_id == 0)
}

pub fn (a []Article) category(id int) []Article {
	return a.filter(it.category_id == id)
}

pub fn (a []Article) visible() []Article {
	return a.filter(it.show == true)
}

pub fn (a []Article) hidden() []Article {
	return a.filter(it.show == false)
}
```

You can use these functions in your templates.

**Example:**
```html
<!-- List all visible articles. See admin panel -->
<ul>
    @for article in app.get_all_articles().visible()
        <li>@article.name</li>
    @endfor
</ul>
```

### Tags
Create and edit tags in the admin panel. See the [Utility section](#utility) for helper functions.


### Database Models

```v oksyntax
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
}

[table: 'images']
pub struct Image {
pub mut:
	id         int    [primary; sql: serial]
	name       string [nonull]
	src        string [nonull]
	article_id int    [nonull]
}

[table: 'tags']
pub struct Tag {
pub mut:
	id         int    [primary; sql: serial]
	article_id int
	name       string [nonull]
	color      string [nonull]
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

### SEO

```v oksyntax
pub struct SEO {
pub mut:
	// twitter card configuration
	twitter Twitter
	// Open Graph configuration
	og OpenGraph
	// your websites url
	website_url string
	// your pages description. Is automatically set by `set_article`
	description string
	// If you need any other meta tags. The map key is the property attribute
	// and the map value is the content attribute.
	other_properties map[string]string
}
```

#### Twitter

Implementation from
[twitter card docs](https://developer.twitter.com/en/docs/twitter-for-websites/cards/guides/getting-started).

```v oksyntax
// TwitterCardType implement the meta `twitter:card` types 
pub enum TwitterCardType {
	summary
	summary_large_image
	app
}

pub struct Twitter {
pub mut:
	card_type TwitterCardType [name: 'card'] = .summary
	// @username for the website used in the card footer.
	site string
	// @username for the content creator / author.
	creator string
	// all other properties of twitter. The map key is the property attribute
	// and the map value is the content attribute.
	// All properties are prefixed with 'twitter:'
	other_properties map[string]string
}
```

#### OpenGraph
OpenGraph meta tags, implementation from [the OpenGraph website](https://ogp.me/).

```v oksyntax

pub struct OpenGraph {
pub:
	// add this as `prefix="@app.seo.og.prefix"` attribute to the `html` tag in your page
	prefix string [skip] = 'og: https://ogp.me/ns#'
pub mut:
	title            string
	og_type          string           [name: 'type']
	image_url        string           [name: 'image']
	url              string
	description      string
	audio            string
	determiner       string
	locale           string
	locale_alternate []string         [name: 'locale:alternate']
	site_name        string
	video            string
	article          OpenGraphArticle
	// all other properties of opengraph. The map key is the property attribute
	// and the map value is the content attribute.
	// All properties are prefixed with 'og:'
	other_properties map[string]string
}
```

OpenGraph `article:`

```v oksyntax
// OpenGraph article attributes; are filled in automatically for each article
// time fields must follow ISO_8601
pub struct OpenGraphArticle {
pub mut:
	published_time  string
	modified_time   string
	expiration_time string
	author          []string
	section         string
	tag             []string
}
```

## Extensibility
The frontend editor is made with [Vue](https://vuejs.org/) and 
[Editorjs](https://editorjs.io/). You can already extend the ditor with custom blocks.

In the future custom blocks will be able to be registerd in Vaunt by passing a function
that takes a EditorJs block as input and outputs html.

The goal of this project is to provide a backend cms which developers can extend to
create their own themes and extensions.
