module vaunt

import vweb.assets

pub struct Util {
pub mut:
	styles        []string
	asset_manager &assets.AssetManager = assets.new_manager()
}
