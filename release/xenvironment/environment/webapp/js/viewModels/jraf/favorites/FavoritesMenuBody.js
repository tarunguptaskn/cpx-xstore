define(["ojs/ojcore","knockout","jquery","jraf/jrafcore","jraf/models/favorites/FavoritesContent","jraf/models/favorites/FavoritesConfig","jraf/utils/ValidationUtils","ojs/ojnavigationlist","ojs/ojbutton"],(function(t,e,i,o,r,n,s){"use strict";var a=t.Translations.getTranslatedString;function d(t){if(!(s.isObjectStrict(t)&&s.isNonemptyString(t.favoritesNavListId)&&e.isObservable(t.menuDataLoaded)&&e.isObservable(t.drilledPath)&&s.isArray(t.drilledPath())&&s.isFunction(t.openContentCallback)))throw new TypeError("FavoritesMenuBody: Invalid configuration.");var i=this;this.favoritesListItemTemplateId=o.UIShell.generateUniqueId(),this.pinFavoriteLabel=a("jraf.sidebar.favorites.pinFavorite"),this.unpinFavoriteLabel=a("jraf.sidebar.favorites.unpinFavorite"),this.favoritesListDescription=a("jraf.sidebar.favorites.favoritesListDescription"),this.loadingText=a("jraf.messages.loading"),this._favoriteHandler=n.getInstance().getFavoriteHandler(t.favoriteHandlerKey),this._favoritesContent=r.getInstance(this._favoriteHandler.getFavoritesService(),t.favoriteHandlerKey),this.hidePinnedFavorites=e.observable(s.getBoolean(t.hidePinnedFavorites,!1)),this.favoritesNavListId=t.favoritesNavListId,this.menuDataLoaded=t.menuDataLoaded,this._openContentCallback=t.openContentCallback,this.drilledPath=t.drilledPath,this.favoritesFlatNavListId=o.UIShell.generateUniqueId(),this.flatListEnabled=s.isFunction(t.flatListEnabled)?t.flatListEnabled:e.observable(!1),this._initDataSource(),this.beforeExpand=function(t,e){return i._handleBeforeExpand(t)},this.beforeCollapse=function(t,e){return i._handleBeforeCollapse()},this.beforeSelect=function(t,e){return i._handleFavoriteSelection(t)},this.togglePin=function(t,e){return i._togglePin(e)},this.getLocalizedTitle=function(t){return i._getLocalizedTitle(t)},this.getFavoriteGuid=function(t){return i._getFavoriteGuid(t)}}return d.prototype._initDataSource=function(){this.favoriteToGuidMap={},this.guidToFavoriteMap={},this.favorites=this._favoritesContent.getFavorites(),this.favoritesContentLoaded=this._favoritesContent.getFavoritesContentLoaded(),this._refreshFavoritesMenu(),this._refreshFolderSubscriptions(),this.menuDataLoaded(!0)},d.prototype.connected=function(){var t=this;this.favoritesSubscription||(this.favoritesSubscription=this.favorites.subscribe((function(){t._refreshFavoritesMenu(),t._refreshFolderSubscriptions()})))},d.prototype._refreshFolderSubscriptions=function(){var t=this;this._disposeOfFolderSubscriptions(),this.folderSubscriptions=[],this.favorites().forEach((function(e){if(e.isFolder){var i=e.children.subscribe((function(){t._refreshFavoritesMenu()}));t.folderSubscriptions.push(i)}}))},d.prototype._refreshFavoritesMenu=function(){var e=this,o=document.getElementById(this.favoritesNavListId);t.Context.getContext(o).getBusyContext().whenReady().then((function(){i("#"+e.favoritesNavListId).ojNavigationList("refresh")}));var r=document.getElementById(this.favoritesFlatNavListId);t.Context.getContext(r).getBusyContext().whenReady().then((function(){i("#"+e.favoritesFlatNavListId).ojNavigationList("refresh")}))},d.prototype._togglePin=function(t){t.isPinned()?this._favoritesContent.unpinFavorite(t.entryId):this._favoritesContent.pinFavorite(t.entryId)},d.prototype._getLocalizedTitle=function(t){return this._favoriteHandler.getLocalizedTitle(t.entryId)},d.prototype._getFavoriteGuid=function(t){var e=this.favoriteToGuidMap[t.entryId];return e||(e=o.UIShell.generateUniqueId(),this.favoriteToGuidMap[t.entryId]=e,this.guidToFavoriteMap[e]=t),e},d.prototype._handleBeforeExpand=function(t){var e=t.detail.key,i=this.guidToFavoriteMap[e];return this.drilledPath.push({favorite:i,guid:e}),!0},d.prototype._handleBeforeCollapse=function(){return this.drilledPath.pop(),!0},d.prototype._handleFavoriteSelection=function(e){t.Logger.info("UIShellTasksMenu._handleBeforeSelect: Entering.");var i=this.guidToFavoriteMap[e.detail.key];return!(!i||!i.isFolder)||(this._openContentCallback(i.entryId),e.preventDefault(),!1)},d.prototype.disconnected=function(){this.favoritesSubscription&&(this.favoritesSubscription.dispose(),this.favoritesSubscription=null)},d.prototype._disposeOfFolderSubscriptions=function(){this.folderSubscriptions&&this.folderSubscriptions.forEach((function(t){t.dispose()}))},d}));