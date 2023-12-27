module vaunt

import vweb
import crypto.hmac
import crypto.sha256
import encoding.base64
import json
import time
import orm
import os
import crypto.bcrypt
import net.http

// bcrypt has a max length of 72 characters. I choose to enforce a maximum of
// 64 characters since it is a power of 2.
const min_password_length = 8
const max_password_length = 64
const bcrypt_cost = 10
const jwt_cookie_name = 'vaunt_token'
const cookie_live_time = time.now().add(time.hour * 24 * 30) // cookie expire time

// 			Auth endpoint
// ==============================

pub struct Auth {
	vweb.Context
	secret string @[vweb_global]
pub mut:
	db orm.Connection @[required]
}

pub fn (mut app Auth) not_found() vweb.Result {
	return app.login()
}

@[get]
pub fn (mut app Auth) login() vweb.Result {
	html := $tmpl('./templates/login.html')
	return app.html(html)
}

@['/login'; post]
pub fn (mut app Auth) login_user(username string, password string) vweb.Result {
	// if jwt is valid make a cookie and redirect to admin
	if user := verify_user(app.db, username, password) {
		token := make_token(user, app.secret)

		app.set_cookie(make_cookie(token, vaunt.cookie_live_time))
		return app.redirect('/admin')
	} else {
		app.form_error = 'Invalid username or password'
		return app.login()
	}
}

pub fn (mut app Auth) logout() vweb.Result {
	// reset cookie
	app.set_cookie(make_cookie('', time.now()))
	return app.redirect('/')
}

// make_cookie returns a cookie with value `token` and the `expires` time.
// It is filled with secure default values according to OWASP
fn make_cookie(token string, expires time.Time) http.Cookie {
	return http.Cookie{
		name: vaunt.jwt_cookie_name
		http_only: true
		value: token
		path: '/'
		expires: expires
		max_age: 3600 * 24 * 30
		secure: true
		same_site: .same_site_strict_mode
	}
}

// 			User
// =======================

@[table: 'users']
pub struct User {
	id       int    @[primary; sql: serial]
	username string @[sql_type: 'TEXT'; unique]
	password string @[sql_type: 'TEXT']
}

// verify_user checks `db` if a user exists with username=`uname` and password=`upass`
fn verify_user(db orm.Connection, uname string, upass string) !User {
	mut expected_hash := ''
	rows := sql db {
		select from User where username == uname
	}!

	// don't return but leave `expected_hash` empty. I think this prevents timing attacks?
	if rows.len != 0 {
		expected_hash = rows[0].password
	}

	bcrypt.compare_hash_and_password(upass.bytes(), expected_hash.bytes())!

	return rows[0]
}

fn get_password_hash(password string) !string {
	return bcrypt.generate_from_password(password.bytes(), vaunt.bcrypt_cost)!
}

// 			JWT
// =======================
struct JwtHeader {
	alg string
	typ string
}

struct JwtPayload {
	sub  string
	name string
	iat  time.Time
}

// make a JWT token for `user`. `secret` should be 256 bits
pub fn make_token(user User, secret string) string {
	jwt_header := JwtHeader{'HS256', 'JWT'}
	jwt_payload := JwtPayload{
		sub: '${user.id}'
		name: '${user.username}'
		iat: time.now()
	}

	header := base64.url_encode(json.encode(jwt_header).bytes())
	payload := base64.url_encode(json.encode(jwt_payload).bytes())
	signature := base64.url_encode(hmac.new(secret.bytes(), '${header}.${payload}'.bytes(),
		sha256.sum, sha256.block_size))
	jwt := '${header}.${payload}.${signature}'
	return jwt
}

// auth_verify verifies if the JWT `token` is valid
fn auth_verify(secret string, token string) bool {
	token_split := token.split('.')
	signature_mirror := hmac.new(secret.bytes(), '${token_split[0]}.${token_split[1]}'.bytes(),
		sha256.sum, sha256.block_size)
	signature_from_token := base64.url_decode(token_split[2])
	return hmac.equal(signature_from_token, signature_mirror)
}

// 			Auth Utility
// ===============================
pub fn login_required(mut ctx vweb.Context, secret string) bool {
	if token := ctx.get_cookie(vaunt.jwt_cookie_name) {
		if quick_verify(token) && auth_verify(secret, token) {
			return true
		}
	}
	ctx.redirect('/auth/login')
	return false
}

pub fn login_required_401(mut ctx vweb.Context, secret string) bool {
	if token := ctx.get_cookie(vaunt.jwt_cookie_name) {
		if quick_verify(token) && auth_verify(secret, token) {
			return true
		}
	}
	ctx.set_status(401, '')
	ctx.text('HTTP 401: Forbidden')
	return false
}

// is_superuser checks the cookies and returns true if a user is logged in -> superuser
pub fn is_superuser(mut ctx vweb.Context, secret string) bool {
	token := ctx.get_cookie(vaunt.jwt_cookie_name) or { return false }
	if quick_verify(token) == false {
		return false
	}
	return auth_verify(secret, token)
}

// prevent empty tokens from erroring
fn quick_verify(token string) bool {
	return token.count('.') == 2 && token.len >= 64
}

// 			CLI
// =======================

// create_super_user creates a superuser via CLI
fn create_super_user(db orm.Connection) ! {
	current_users := sql db {
		select from User
	}!

	println('\n[Vaunt] Creating super user')
	mut username := ''
	for {
		username = os.input('Username (case-insensitive): ')
		if username.len < 5 {
			println('Username must be at least 5 characters!')
			continue
		} else if username.contains_any(' ') {
			println("Username can't contain any spaces!")
			continue
		}

		username = username.trim_space()
		username = username.to_lower()

		// avoid duplicate usernames
		if current_users.any(fn [username] (u User) bool {
			return u.username == username
		}) == true {
			println('A user with this username already exists!')
		} else {
			break
		}
	}

	mut password := ''
	mut verify_password := ''
	for {
		for {
			password = os.input_password('Password: ') or { '' }
			if password.len < vaunt.min_password_length || password.len > vaunt.max_password_length {
				println('Password must be between 8 and 64 characters!')
			} else {
				break
			}
		}

		verify_password = os.input_password('Confirm password: ') or { '' }
		if password != verify_password {
			println("Passwords don't match!")
		} else {
			break
		}
	}

	user := User{
		username: username
		password: get_password_hash(password)!
	}

	sql db {
		insert user into User
	}!

	println('[Vaunt] Created user "${username}". You can now login')
}
