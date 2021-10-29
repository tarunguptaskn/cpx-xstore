define(["jraf/utils/ValidationUtils","jraf/services/ServiceRegistry"],(function(e,r){"use strict";var i=new r,t={IDENTITY_SERVICE_NAME:"IdentityService",NOTIFICATIONS_SERVICE_NAME:"NotificationsService",FAVORITES_SERVICE_NAME:"FavoritesService",TASKS_SERVICE_NAME:"TasksService",ACCESS_CONTROL_SERVICE_NAME:"AccessControlService",GLOBAL_CONFIG_SERVICE_NAME:"GlobalAreaConfigurationService",APP_NAVIGATOR_SERVICE_NAME:"AppNavigatorService",MDF_SERVICE_NAME:"MdfService",ANALYTICS_SERVICE_NAME:"AnalyticsService",registerService:function(e,r){i.registerService(e,r)},registerServices:function(r){if(!e.isObjectStrict(r))throw new TypeError("ServiceManager.registerServices: Invalid input.");for(var i in r)t.registerService(i,r[i])},removeService:function(e){i.removeService(e)},reset:function(){i=new r},getService:function(e){return i.getService(e)},registerIdentityService:function(e){t.registerService(t.IDENTITY_SERVICE_NAME,e)},getIdentityService:function(){return t.getService(t.IDENTITY_SERVICE_NAME)},registerNotificationsService:function(e){t.registerService(t.NOTIFICATIONS_SERVICE_NAME,e)},getNotificationsService:function(){return t.getService(t.NOTIFICATIONS_SERVICE_NAME)},registerFavoritesService:function(e){t.registerService(t.FAVORITES_SERVICE_NAME,e)},getFavoritesService:function(){return t.getService(t.FAVORITES_SERVICE_NAME)},registerTasksService:function(e){t.registerService(t.TASKS_SERVICE_NAME,e)},getTasksService:function(){return t.getService(t.TASKS_SERVICE_NAME)},registerAccessControlService:function(e){t.registerService(t.ACCESS_CONTROL_SERVICE_NAME,e)},getAccessControlService:function(){return t.getService(t.ACCESS_CONTROL_SERVICE_NAME)},registerGlobalAreaConfigurationService:function(e){t.registerService(t.GLOBAL_CONFIG_SERVICE_NAME,e)},getGlobalAreaConfigurationService:function(){return t.getService(t.GLOBAL_CONFIG_SERVICE_NAME)},registerAppNavigatorService:function(e){t.registerService(t.APP_NAVIGATOR_SERVICE_NAME,e)},getAppNavigatorService:function(){return t.getService(t.APP_NAVIGATOR_SERVICE_NAME)},registerMdfService:function(e){t.registerService(t.MDF_SERVICE_NAME,e)},getMdfService:function(){return t.getService(t.MDF_SERVICE_NAME)},registerAnalyticsService:function(e){t.registerService(t.ANALYTICS_SERVICE_NAME,e)},getAnalyticsService:function(){return t.getService(t.ANALYTICS_SERVICE_NAME)}};return t}));