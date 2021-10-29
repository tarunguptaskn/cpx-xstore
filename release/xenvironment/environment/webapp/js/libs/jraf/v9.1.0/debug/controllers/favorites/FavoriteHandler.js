define(["ojs/ojcore","knockout","jraf/services/ServiceManager","jraf/models/Content","jraf/models/UIShellManager","jraf/utils/ValidationUtils","jraf/models/favorites/FavoritesContent"],(function(e,t,i,r,n,o,a){"use strict";function s(e){if(!o.isObjectStrict(e)||!o.isNonemptyString(e.serviceKey))throw new TypeError("FavoriteHandler: Missing required serviceKey property");this._displayFavoriteTitleInTab=o.getBoolean(e.displayFavoriteTitleInTab,!1),this._favoritesService=i.getService(e.serviceKey),o.isFunction(e.openContentHandler)&&(this._openContentHandler=e.openContentHandler),o.isFunction(e.getLocalizedTitleHandler)&&(this._getLocalizedTitleHandler=e.getLocalizedTitleHandler)}return s.prototype.getFavoritesService=function(){return this._favoritesService},s.prototype.openContent=function(e){if(!o.isNumberStrict(e))throw new TypeError("FavoriteHandler.openContent: A favoriteId is required.");this._openContentHandler(e)},s.prototype._openContentHandler=function(e){var t=this,i=a.getInstance(this._favoritesService);i.whenReady().then((function(){var r=i.lookupFavoriteById(e);if(r){var o=i.getContent(r.contentId);if(o){var a=t._mergeFavoriteContext(o,r.favoriteContext);a=t._mergeFavoriteTitle(a,e),n.openContent(a)}}}))},s.prototype._mergeFavoriteContext=function(e,t){if(!t||!o.isObjectStrict(t)||!e.isModule())return e;var i={};return i[e.hasModuleOptions()?"moduleOptions":"moduleBinding"]={params:t},r.extendContent(e,i)},s.prototype._mergeFavoriteTitle=function(e,t){if(this._displayFavoriteTitleInTab){var i={targetProperties:{targetTitle:this.getLocalizedTitle(t)()}};return r.extendContent(e,i)}return e},s.prototype.getLocalizedTitle=function(e,t){if(!o.isNumberStrict(e))throw new TypeError("FavoriteHandler.getLocalizedTitle: A favoriteId is required.");return this._getLocalizedTitleHandler(e,t)},s.prototype._getLocalizedTitleHandler=function(e,i){var r=a.getInstance(this._favoritesService),n=r.lookupFavoriteById(e);return t.pureComputed((function(){if(n){var e=n.contentTitle;if(n.customName()&&o.isNonemptyString(n.customName().trim())&&!i)e=n.customName();else if(!o.isNonemptyString(n.objectId)&&!n.isFolder&&o.isNonemptyString(n.contentId)){e=r.getContent(n.contentId).getTitle()}return e}return null}))},s}));