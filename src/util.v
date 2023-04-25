module vaunt

import vweb.assets

pub struct Util {
pub mut:
	styles        []string
	asset_manager &assets.AssetManager = assets.new_manager()
}

pub fn (u &Util) category_article_url(category_name string, article_name string) string {
	mut url := '/articles/${category_name}/${article_name}'
	url = url.replace(' ', '-')
	return url.to_lower()
}

pub fn (u &Util) article_url(article_name string) string {
	mut url := '/articles/${article_name}'
	url = url.replace(' ', '-')
	return url.to_lower()
}
