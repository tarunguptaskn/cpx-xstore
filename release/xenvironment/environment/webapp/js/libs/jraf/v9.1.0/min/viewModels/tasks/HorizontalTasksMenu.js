define(["knockout","jquery","ojs/ojcore","jraf/jrafcore","jraf/models/UIShellManager","jraf/models/tasks/TasksListModel","jraf/utils/ValidationUtils"],(function(t,i,e,s,a,r,n){"use strict";function o(i){if(!n.isObjectStrict(i)||!n.isNonemptyString(i.navListLabel)||!n.isFunction(i.getTasks))throw new TypeError("HorizontalTasksMenu: Missing required param(s)");var e=this;this.navListId=s.UIShell.generateUniqueId(),this.tasksHeaderId=s.UIShell.generateUniqueId(),this.tk=new r({getTasks:i.getTasks,taskId:i.taskId,favoritesEnabled:i.favoritesEnabled,favoritesType:i.favoritesType}),this.hierarchyDrillPath=this.tk.getHierarchyDrillPath(),this.drilledNode=this.tk.getDrilledNode(),this.drilledNodeLabel=t.pureComputed((function(){return this.drilledNode().label}),this),this.isHierarchyRoot=t.pureComputed((function(){return this.hierarchyDrillPath().length<1}),this),this.navigateUpHierarchy=function(){e.yd()},this.tasksListBodyModule={name:"jraf/tasks/TasksMenuBody",params:{navListId:this.navListId,navListLabel:i.navListLabel,openContentCallback:function(t){e.Rg(t)},tasksModel:this.tk}}}return o.prototype.yd=function(){if(!this.isHierarchyRoot()){var t=this.hierarchyDrillPath();this.ik(t[t.length-1].id)}},o.prototype.ik=function(t){for(var i=this.hierarchyDrillPath(),e=i.length-1;0<=e;e--){var s=i[e];if(this.Jj(),t===s.id)break}},o.prototype.sk=function(){return i("#"+this.navListId)},o.prototype.Jj=function(){e.Logger.info("HorizontalTasksMenu._navigateBack: Entering."),this.sk().find(".oj-navigationlist-previous-link").click()},o.prototype.Rg=function(t){a.closePopupMenu(),a.openContent(t)},o}));