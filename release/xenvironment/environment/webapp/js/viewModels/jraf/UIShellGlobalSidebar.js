define(["ojs/ojcore","knockout","jquery","jraf/jrafcore","jraf/models/UIShellManager","jraf/models/NavigationConfig","jraf/models/favorites/PinnedFavoritesState","jraf/models/favorites/FavoritesConfig","jraf/models/favorites/FavoritesContent","jraf/utils/ValidationUtils","jraf/models/Content","ojs/ojknockouttemplateutils","ojs/ojnavigationlist","ojs/ojmodule","ojs/ojarraytabledatasource","ojs/ojconveyorbelt","ojs/ojmenu","jraf/utils/CustomBindings","ojs/ojknockout"],(function(e,t,n,i,o,a,r,s,d,u,l,v){"use strict";var h=e.Translations.getTranslatedString;function I(e){if(!(u.isObjectStrict(e)&&t.isPureComputed(e.opened)&&t.isPureComputed(e.selectedMenuItemId)&&Array.isArray(e.menuItems)&&u.isBoolean(e.pinnedFavoritesEnabled)))throw new TypeError("UIShellGlobalSidebar: Invalid param(s).");var n=this;this.sidebarMenuListItemTemplateId=i.UIShell.generateUniqueId(),this.pinnedFavoritesContextMenuId=i.UIShell.generateUniqueId(),this.sidebarPinnedFavoritesNavListId=i.UIShell.generateUniqueId(),this.sidebarMenuNavListId=i.UIShell.generateUniqueId(),this.settingsMenuNavListId=i.UIShell.generateUniqueId(),this.sidebarMenuAriaLabel=h("jraf.sidebar.sidebarMenuAriaLabel"),this.pinnedFavoritesMenuAriaLabel=h("jraf.sidebar.favorites.pinnedFavoritesMenuAriaLabel"),this.pinnedFavoriteMenuUnpin=h("jraf.sidebar.favorites.pinnedFavoriteMenuUnpin"),this.pinnedFavoriteMenuUnpinAndRemove=h("jraf.sidebar.favorites.pinnedFavoriteMenuUnpinAndRemove"),this.pinnedFavoriteMenuEditFavorites=h("jraf.sidebar.favorites.pinnedFavoriteMenuEditFavorites"),this.editFavoritesPageTitle=h("jraf.sidebar.favorites.editFavoritesPageTitle"),this.selectedMenuItemId=e.selectedMenuItemId,this.menuOpened=e.opened,this.menuItems=e.menuItems,this.pinnedFavoritesEnabled=e.pinnedFavoritesEnabled,this.hasFavoritesMenuItem=t.observable(!1),this.showPinnedFavorites=t.pureComputed((function(){return n.hasFavoritesMenuItem()&&n.pinnedFavoritesEnabled})),this.showSettingsMenu=t.observable(!1),this.beforeMenuItemSelect=function(e,t){return n._handleBeforeMenuItemSelect(e,t)},this.beforePinnedFavoriteSelect=function(e,t){return n._handleBeforePinnedFavoriteSelect(e,t)},this.pinnedFavoriteContextBeforeOpen=function(e,t){return n._handleBeforeOpenPinnedFavoriteContextMenu(e,t)},this.pinnedFavoriteContextSelect=function(e,t){return n._handleSelectPinnedFavoriteContextMenu(e,t)},this.getSidebarMenuListTemplate=function(){return v.getRenderer(n.sidebarMenuListItemTemplateId,!0)}}return I.PINNED_HEIGHT=38,I.prototype.connected=function(){e.Logger.info("UIShellGlobalSidebar.connected: Connecting UIShellGlobalSidebar module."),this.menuItemIdsMap||this._initializeNavigationMenuItemsDataSource()},I.prototype._initializeNavigationMenuItemsDataSource=function(){var n=this;this.menuItemIdsMap={},this.menuItemUiData=[],this.settingsItemUiData=[];for(var o=0;o<this.menuItems.length;o++){var s=this.menuItems[o],d=i.UIShell.generateUniqueId();this.menuItemIdsMap[d]=s.getId();var u=this._getIconClassComputed(s),l=this._getMenuItemSelectedComputed(s),v={guid:d,iconLabel:s.getIconLabel(),icon:u,selected:l,badgingEnabled:s.isBadgingEnabled(),badgeValue:s.getBadgeValue(),jrafTestId:"navigation-bar-side-menu-"+o};a.SETTINGS_ID===s.getId()?this.settingsItemUiData.push(v):this.menuItemUiData.push(v),a.FAVORITES_ID===s.getId()&&this.hasFavoritesMenuItem(!0)}this.navigationMenuItemsDataSource=new e.ArrayTableDataSource(this.menuItemUiData,{idAttribute:"guid"}),this.settingsItemUiData.length>0&&(this.settingsMenuItemsDataSource=new e.ArrayTableDataSource(this.settingsItemUiData,{idAttribute:"guid"}),this.showSettingsMenu(!0)),this.showPinnedFavorites()&&(this.pinnedFavorites=r.getInstance().getPinnedFavorites(),this.conveyorBeltHeight=t.pureComputed((function(){return this._getConveyorBeltMinHeight(this.pinnedFavorites().length)+"px"}),this),this.pinnedFavoritesSubscription=this.pinnedFavorites.subscribe((function(){n._refreshPinnedFavoritesWhenReady()})))},I.prototype._getMenuItemDataId=function(e){return this.menuItemIdsMap[e]},I.prototype._getMenuItem=function(e){var t=this.menuItems.filter((function(t){return t.getId()===e}),this);if(1!==t.length)throw new Error("UIShellGlobalSidebar._getMenuItem: Did not find unique menu item identified by id: "+e);return t[0]},I.prototype._refreshPinnedFavoritesWhenReady=function(){var t=this,i=document.getElementById(this.sidebarPinnedFavoritesNavListId);e.Context.getContext(i).getBusyContext().whenReady().then((function(){n("#"+t.sidebarPinnedFavoritesNavListId).ojNavigationList("refresh")}))},I.prototype.getPinnedFavoriteIcon=function(e){var t=r.favoriteIcons[e.favorite.favoriteType];return"oj-navigationlist-item-icon jraf-sidebar-menu-icon "+(t=t||r.favoriteIcons.unknown)},I.prototype.getPinnedFavoriteIconLabel=function(e){return s.getInstance().getFavoriteHandler(e.favoriteHandlerKey).getLocalizedTitle(e.favorite.entryId)},I.prototype.getPinnedFavoriteIconLabelForJrafTestId=function(e){return"navigation-bar-top-menu-favorite-"+e.favorite.localPinSequence()},I.prototype._handleBeforeMenuItemSelect=function(t,n){e.Logger.info("UIShellGlobalSidebar._handleBeforeMenuItemSelect: Entering.");var i=t.currentTarget.id,a=document.getElementById(i).getContextByNode(t.target).key,r=this._getMenuItemDataId(a);e.Logger.info("UIShellGlobalSidebar._handleBeforeMenuItemSelect: Menu ID is "+r);var s=this._getMenuItem(r);return s.hasContent()?(o.openContent(s.getContent()),o.closeMenu({closeOverlayMenuOnly:!0})):this.menuOpened()&&this.selectedMenuItemId()===r?(e.Logger.info("UIShellGlobalSidebar._handleBeforeMenuItemSelect: Closing overlay only."),o.closeMenu({closeOverlayMenuOnly:!0})):(e.Logger.info("UIShellGlobalSidebar._handleBeforeMenuItemSelect: Opening."),o.overlayMenu({menuItemId:r})),!1},I.prototype._handleBeforePinnedFavoriteSelect=function(t,n){e.Logger.info("UIShellGlobalSidebar._handleBeforePinnedFavoriteSelect: Entering.");var i=t.detail.key,o=r.getInstance().lookupPinnedFavoriteById(i),a=o.favoriteHandlerKey;return s.getInstance().getFavoriteHandler(a).openContent(o.favorite.entryId),t.preventDefault(),!1},I.prototype._handleBeforeOpenPinnedFavoriteContextMenu=function(e,t){return this.pinnedFavoriteContextTarget=e.detail.openOptions.launcher.get(0).id,!0},I.prototype._handleSelectPinnedFavoriteContextMenu=function(e,t){var n=e.target.value;"Unpin"===n?this._unpinFavoriteTarget():"UnpinAndRemove"===n?this._unpinAndRemoveFavoriteTarget():"EditFavorites"===n&&this._handleEditFavorites()},I.prototype._unpinFavoriteTarget=function(){var e=r.getInstance().lookupPinnedFavoriteById(this.pinnedFavoriteContextTarget);e&&this._getFavoritesContent(e.favoriteHandlerKey).unpinFavorite(e.favorite.entryId)},I.prototype._getFavoritesContent=function(e){var t=s.getInstance().getFavoriteHandler(e);return d.getInstance(t.getFavoritesService(),e)},I.prototype._unpinAndRemoveFavoriteTarget=function(){var e=r.getInstance().lookupPinnedFavoriteById(this.pinnedFavoriteContextTarget);e&&this._getFavoritesContent(e.favoriteHandlerKey).removeFavorite(e.favorite.contentId,e.favorite.objectid)},I.prototype._handleEditFavorites=function(){o.openContent(this._getEditFavoritesPageContent())},I.prototype._getEditFavoritesPageContent=function(){var e=r.getInstance().lookupPinnedFavoriteById(this.pinnedFavoriteContextTarget);if(e)return l.createModuleGlobalModalPageContent(this.editFavoritesPageTitle,{name:"jraf/favorites/EditFavoritesPage",params:{hidePinnedFavorites:!this.pinnedFavoritesEnabled,favoriteHandlerKey:e.favoriteHandlerKey}})},I.prototype._getMenuItemSelectedComputed=function(e){return t.computed((function(){return this.menuOpened()&&e.getId()===this.selectedMenuItemId()}),this)},I.prototype._getIconClassComputed=function(e){return t.computed((function(){var t=this.menuOpened()&&e.getId()===this.selectedMenuItemId();return this._getMenuItemIconClassString(e,t)}),this)},I.prototype._getMenuItemIconClassString=function(e,t){return"oj-navigationlist-item-icon jraf-sidebar-menu-icon "+e.getIcon(t)},I.prototype.disconnected=function(){e.Logger.info("UIShellGlobalSidebar.disconnected: Disconnecting UIShellGlobalSidebar module."),this.menuItemIdsMap=null,this.pinnedFavoritesSubscription&&(this.pinnedFavoritesSubscription.dispose(),this.pinnedFavoritesSubscription=null)},I.prototype._getConveyorBeltMinHeight=function(e){var t=I.PINNED_HEIGHT;return 0===e&&(t=0),t},I}));