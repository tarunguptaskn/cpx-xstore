/**
 * Copyright (c) 2014, 2016, Oracle and/or its affiliates.
 * The Universal Permissive License (UPL), Version 1.0
 * as shown at https://oss.oracle.com/licenses/upl/
 */
define(['./DvtToolkit'], function(dvt) {
  "use strict";
  // Internal use only.  All APIs and functionality are subject to change at any time.

!function(e){e.Legend=function(){},e.Obj.createSubclass(e.Legend,e.BaseComponent),e.Legend.newInstance=function(t,n,i){var o=new e.Legend;return o.Init(t,n,i),o},e.Legend.getDefaults=function(e){return(new n).getDefaults(e)},e.Legend.prototype.Init=function(t,o,r){e.Legend.superclass.Init.call(this,t,o,r),this.setId("legend1000"+Math.floor(1e9*Math.random())),this.Defaults=new n(t),this.EventManager=new i(this),this.EventManager.addListeners(this),this._peers=[],this._navigablePeers=[],this._bounds=null,this._titles=[]},e.Legend.prototype.SetOptions=function(e){this.getOptionsCache().clearCache(),e?(this.Options=this.Defaults.calcOptions(e),this._transferVisibilityProperties(this.Options.sections)):this.Options||(this.Options=this.GetDefaults())},e.Legend.prototype.getPreferredSize=function(t,n,i){this.SetOptions(t),this.getOptions().isLayout=!0;var o=new e.Rectangle(0,0,n,i),r=s.render(this,o);return this.getOptions().isLayout=!1,new e.Dimension(r.w,r.h)},e.Legend.prototype.render=function(t,n,i){this.getCache().clearCache(),this.SetOptions(t),isNaN(n)||isNaN(i)||(this.Width=n,this.Height=i),this.getOptions().isLayout=!1;for(var r=this.getNumChildren(),a=0;a<r;a++){this.getChildAt(a).destroy()}this.removeChildren(),this._peers=[],this._navigablePeers=[],this._bounds=null,this._titles=[],e.Agent.isTouchDevice()||this.EventManager.setKeyboardHandler(new o(this.EventManager,this)),this.UpdateAriaAttributes();var l=new e.Rectangle(0,0,this.Width,this.Height);this._contentDimensions=s.render(this,l);var g=this.getOptions().highlightedCategories;return g&&g.length>0&&this.highlight(g),this.RenderComplete(),this._contentDimensions},e.Legend.prototype.highlight=function(t){this.getOptions().highlightedCategories=t&&t.length>0?t.slice():null,e.CategoryRolloverHandler.highlight(t,this.__getObjects(),!0)},e.Legend.prototype.processEvent=function(t,n){if("categoryHighlight"==t.type&&"dim"==this.getOptions().hoverBehavior){var i=this.__getObjects();this!=n&&this.highlight(t.categories);for(var o=0;o<i.length;o++)if(e.Obj.compareValues(this.getCtx(),i[o].getId(),t.categories)){this.container.scrollIntoView(i[o].getDisplayables()[0]);break}}this==n&&this.dispatchEvent(t)},e.Legend.prototype.__registerObject=function(t){if(t.getDisplayables()[0]instanceof e.IconButton)this._navigablePeers.push(t);else{var n=this.getOptions().hideAndShowBehavior;(null!=t.getDatatip()||t.isDrillable()||"none"!=n&&"off"!=n)&&this._navigablePeers.push(t),this._peers.push(t)}},e.Legend.prototype.__getObjects=function(){return this._peers},e.Legend.prototype.__getKeyboardObjects=function(){return this._navigablePeers},e.Legend.prototype.__setBounds=function(e){this._bounds=e.clone()},e.Legend.prototype.__getBounds=function(){return this._bounds},e.Legend.prototype.__registerTitle=function(e){this._titles.push(e)},e.Legend.prototype.__getTitles=function(){return this._titles},e.Legend.prototype.getAutomation=function(){return new t(this)},e.Legend.prototype.getKeyboardFocus=function(){return null!=this.EventManager?this.EventManager.getFocus():null},e.Legend.prototype.setKeyboardFocus=function(t,n){if(null!=this.EventManager){for(var i=this.__getKeyboardObjects(),o=0;o<i.length;o++)if(e.Obj.compareValues(this.getCtx(),i[o].getId(),t.getId())){this.EventManager.setFocusObj(i[o]),n&&i[o].showKeyboardFocusEffect();break}var r=this.getKeyboardFocus();if(r){var s=r.getDisplayables()[0];s.setAriaProperty("label",r.getAriaLabel()),this.getCtx().setActiveElement(s)}}},e.Legend.prototype.getDimensions=function(t){var n=new e.Rectangle(0,0,this.Width,this.Height);return t&&t!==this?this.ConvertCoordSpaceRect(n,t):n},e.Legend.prototype.getContentDimensions=function(e){return e&&e!==this?this.ConvertCoordSpaceRect(this._contentDimensions,e):this._contentDimensions},e.Legend.prototype._transferVisibilityProperties=function(e){if(e&&!(e.length<=0))for(var t=this.getOptions().hiddenCategories,n=0;n<e.length;n++){var i=e[n];i.sections&&this._transferVisibilityProperties(i.sections);var o=i.items;if(o&&!(o.length<=0))for(var r=0;r<o.length;r++){var a=o[r],l=s.getItemCategory(a,this);"hidden"==a.categoryVisibility&&t.indexOf(l)<0&&t.push(l),a.categoryVisibility=null}}},e.Legend.prototype.UpdateAriaAttributes=function(){if(this.IsParentRoot()){var t=this.getOptions(),n=t.translations,i=t.hideAndShowBehavior;("off"!=i&&"none"!=i||"dim"==t.hoverBehavior)&&(this.getCtx().setAriaRole("application"),this.getCtx().setAriaLabel(e.ResourceUtils.format(n.labelAndValue,[n.labelDataVisualization,e.TextUtils.processAriaLabel(this.GetComponentDescription())])))}},e.Legend.prototype.isNavigable=function(){return this._navigablePeers.length>0},e.Legend.getItemCount=function(t){var n=t.getOptionsCache().getFromCache("itemsCount");if(null!=n)return n;n=0;for(var i=t.getOptions().sections,o=0;o<i.length;o++){var r=i[o];n+=e.Legend.getSectionItemsCount(r)}return t.getOptionsCache().putToCache("itemsCount",n),n},e.Legend.getSectionItemsCount=function(t){var n=0;if(t.items&&(n+=t.items.length),t.sections)for(var i=t.sections,o=0;o<i.length;o++)n+=e.Legend.getSectionItemsCount(i[o]);return n};var t=function(e){this._legend=e,this._options=this._legend.getOptions()};e.Obj.createSubclass(t,e.Automation),t.prototype.GetSubIdForDomElement=function(e){var t=this._legend.getEventManager().GetLogicalObject(e);if(t&&t instanceof r){var n=t.getData(),i=this._getIndicesFromItem(n,this._options);if(i)return"section"+i}return null},t.prototype._getIndicesFromItem=function(e,t){if(t.sections&&t.sections.length>0){for(var n=0;n<t.sections.length;n++){if(t.sections[n]==e)return"["+n+"]";var i=this._getIndicesFromItem(e,t.sections[n]);if(i)return"["+n+"]"+i}return null}if(t.items&&t.items.length>0){for(var o=0;o<t.items.length;o++)if(t.items[o]==e)return":item["+o+"]";return null}},t.prototype.getIndicesFromSeries=function(e,t){if(t.sections&&t.sections.length>0){for(var n=0;n<t.sections.length;n++){var i=this.getIndicesFromSeries(e,t.sections[n]);if(i)return"["+n+"]"+i}return null}if(t.items&&t.items.length>0){for(var o=0;o<t.items.length;o++)if(t.items[o].text==e.name)return":item["+o+"]";return null}},t.prototype.getLegendItem=function(e,t){var n=t.indexOf("["),i=t.indexOf("]");if(n>=0&&i>=0){var o=t.substring(n+1,i),r=t.indexOf(":"),s=(t=t.substring(i+1)).indexOf("["),a=t.indexOf("]");return s>=0&&a>=0?this.getLegendItem(e.sections[o],t):0==r?e.items[o]:e.sections[o]}},t.prototype.getDomElementForSubId=function(t){if(t==e.Automation.TOOLTIP_SUBID)return this.GetTooltipElement(this._legend);for(var n=this.getLegendItem(this._options,t),i=this._legend.__getObjects(),o=0;o<i.length;o++){if(n==i[o].getData())return i[o].getDisplayables()[0].getElem()}return null},t.prototype.getTitle=function(){return this._options.title},t.prototype.getItem=function(e){var t,n=e.shift(),i=this._options;if(!i.sections||0===i.sections.length)return null;for(;null!=n;)e.length>0?i=i.sections[n]:t=i.items[n],n=e.shift();return t?{text:t.text?t.text:null}:null},t.prototype.getSection=function(e){var t,n=e.shift(),i=this._options;if(!i.sections||0===i.sections.length)return null;for(;null!=n;)e.length>0?i=i.sections[n]:t=i.sections[n],n=e.shift();return{title:t.title?t.title:null,items:t.items?this._generateItemObjects(t.items):null,sections:t.sections?this._generateSectionObjects(t.sections):null}},t.prototype._generateItemObjects=function(e){for(var t=[],n=0;n<e.length;n++)t.push({text:e[n].text});return t},t.prototype._generateSectionObjects=function(e){for(var t=[],n=0;n<e.length;n++)t.push({title:e[n].title?e[n].title:null,items:e[n].items?this._generateItemObjects(e[n].items):null,sections:e[n].sections?this._generateSectionObjects(e[n].sections):null});return t};var n=function(e){this.Init({alta:n.SKIN_ALTA},e)};e.Obj.createSubclass(n,e.BaseComponentDefaults),n.SKIN_ALTA={skin:e.CSSStyle.SKIN_ALTA,orientation:"vertical",position:null,backgroundColor:null,borderColor:null,textStyle:new e.CSSStyle(e.BaseComponentDefaults.FONT_FAMILY_ALTA_11+"color: #333333;"),titleStyle:new e.CSSStyle(e.BaseComponentDefaults.FONT_FAMILY_ALTA_11+"color: #737373;"),_sectionTitleStyle:new e.CSSStyle(e.BaseComponentDefaults.FONT_FAMILY_ALTA_11+"color: #737373;"),titleHalign:"start",hiddenCategories:[],hideAndShowBehavior:"off",hoverBehavior:"none",hoverBehaviorDelay:200,scrolling:"asNeeded",halign:"start",valign:"top",drilling:"off",dnd:{drag:{series:{}},drop:{legend:{}}},_color:"#a6acb1",_markerShape:"square",_lineWidth:3,layout:{outerGapWidth:3,outerGapHeight:3,titleGapWidth:17,titleGapHeight:9,symbolGapWidth:7,symbolGapHeight:4,rowGap:4,columnGap:10,sectionGapHeight:16,sectionGapWidth:24},isLayout:!1},n.getGapSize=function(t,n){var i=Math.min(e.TextUtils.getTextStringHeight(t.getCtx(),t.getOptions().textStyle)/14,1);return Math.ceil(n*i)},n.prototype.getNoCloneObject=function(e){return{sections:{items:{_dataContext:!0}}}};var i=function(e){this.Init(e.getCtx(),e.processEvent,e,e),this._legend=e};e.Obj.createSubclass(i,e.EventManager),i.prototype.OnClick=function(e){i.superclass.OnClick.call(this,e);var t=this.GetLogicalObject(e.target);if(t){var n=this.processHideShowEvent(t),o=this.handleClick(t,e);(n||o)&&e.stopPropagation()}},i.prototype.OnMouseOver=function(e){i.superclass.OnMouseOver.call(this,e);var t=this.GetLogicalObject(e.target);t&&this.UpdateActiveElement(t)},i.prototype.HandleTouchClickInternal=function(e){var t=this.GetLogicalObject(e.target);if(t){var n=e.touchEvent,i=this.processHideShowEvent(t),o=this.handleClick(t,e);(i||o)&&n&&n.preventDefault()}},i.prototype.processHideShowEvent=function(t){var n=this._legend.getOptions().hideAndShowBehavior;if("none"==n||"off"==n)return!1;var i=t.getCategories?t.getCategories():null;if(!i||i.length<=0)return!1;var o=t.getCategories()[0],r=this._legend.getOptions().hiddenCategories||[];r=r.slice();for(var a=t.getDisplayables(),l=0;l<a.length;l++){var g=a[l];g instanceof e.SimpleMarker?g.setHollow(t.getColor()):g instanceof e.Rect&&t.updateAriaLabel()}var h,c=i[0];return s.isCategoryHidden(o,this._legend)?(r.splice(r.indexOf(o),1),h=e.EventFactory.newCategoryShowEvent(c,r)):(r.push(o),h=e.EventFactory.newCategoryHideEvent(c,r)),this._legend.getOptions().hiddenCategories=r,this.FireEvent(h,this._legend),!0},i.prototype.handleClick=function(t,n){if(t instanceof r&&t.isDrillable()){var i=t.getId();return this.FireEvent(e.EventFactory.newChartDrillEvent(i,i,null),this._legend),!0}var o=t instanceof e.SimpleObjPeer?t.getParams():null;return!(!o||!o.isCollapsible)&&(this.toggleSectionCollapse(n,o.id),!0)},i.prototype.ProcessRolloverEvent=function(t,n,i){var o=this._legend.getOptions();if(!("none"==o.hoverBehavior||n.getDisplayables&&n.getDisplayables()[0]instanceof e.IconButton)){var r=n.getCategories?n.getCategories():[];o.highlightedCategories=i?r.slice():null;var s=e.EventFactory.newCategoryHighlightEvent(o.highlightedCategories,i),a=e.CSSStyle.getTimeMilliseconds(o.hoverBehaviorDelay);this.RolloverHandler.processEvent(s,this._legend.__getObjects(),a,!0)}},i.prototype.onCollapseButtonClick=function(e,t){var n=t.getId();this.toggleSectionCollapse(e,n)},i.prototype.toggleSectionCollapse=function(t,n){for(var i=this._legend.getOptions(),o=i.expanded,r=this._legend.getOptions(),s=null,a=0;a<n.length;a++)r=r.sections[n[a]];if(o?o.has(r.id)?(i.expanded=o.delete([r.id]),s=!1):(i.expanded=o.add([r.id]),s=!0):r.expanded="off"==r.expanded?"on":"off",t.type==e.MouseEvent.CLICK){var l=this.GetLogicalObject(t.target);l.getNextNavigable&&this.setFocusObj(l.getNextNavigable(t))}var g=this._legend.getKeyboardFocus(),h=!!g&&g.isShowingKeyboardFocusEffect();if(this._legend.render(),g&&this._legend.setKeyboardFocus(g,h),this.hideTooltip(),null!=s){t=new e.EventFactory.newExpandCollapseEvent(s?"expand":"collapse",r.id,r,this._legend.getOptions()._widgetConstructor,i.expanded);this.FireEvent(t,this._legend)}},i.prototype.GetTouchResponse=function(){return this._legend.getOptions()._isScrollingLegend?e.EventManager.TOUCH_RESPONSE_TOUCH_HOLD:e.EventManager.TOUCH_RESPONSE_TOUCH_START},i.prototype.isDndSupported=function(){return!0},i.prototype.GetDragSourceType=function(e){var t=this.DragSource.getDragObject();return t instanceof r&&null!=t.getData()._dataContext?"series":null},i.prototype.GetDragDataContexts=function(t){var n=this.DragSource.getDragObject();if(n instanceof r){var i=n.getData()._dataContext;return t&&(i=e.JsonUtils.clone(i,null,{component:!0,componentElement:!0}),e.ToolkitUtils.cleanDragDataContext(i)),[i]}return[]},i.prototype.GetDropTargetType=function(e){var t=this._legend.stageToLocal(this.getCtx().pageToStageCoords(e.pageX,e.pageY)),n=this._legend.getOptions().dnd.drop,i=this._legend.__getBounds();return Object.keys(n.legend).length>0&&i.containsPoint(t.x,t.y)?"legend":null},i.prototype.GetDropEventPayload=function(e){return{}},i.prototype.ShowDropEffect=function(e){if("legend"==this.GetDropTargetType(e)){var t=this._legend.getOptions()._dropColor,n=this._legend.getCache().getFromCache("background");n&&(n.setSolidFill(t),n.setClassName("oj-active-drop"))}},i.prototype.ClearDropEffect=function(){var t=this._legend.getCache().getFromCache("background");if(t){var n=this._legend.getOptions().backgroundColor;n?t.setSolidFill(n):t.setInvisibleFill(),e.ToolkitUtils.removeClassName(t.getElem(),"oj-invalid-drop"),e.ToolkitUtils.removeClassName(t.getElem(),"oj-active-drop")}},i.prototype.ShowRejectedDropEffect=function(e){if("legend"==this.GetDropTargetType(e)){var t=this._legend.getCache().getFromCache("background");t&&t.setClassName("oj-invalid-drop")}};var o=function(e,t){this.Init(e,t)};e.Obj.createSubclass(o,e.KeyboardHandler),o.prototype.Init=function(e,t){o.superclass.Init.call(this,e),this._legend=t},o.prototype.processKeyDown=function(t){var n=t.keyCode,i=this._eventManager.getFocus(),r=i&&i.getDisplayables()[0]instanceof e.IconButton,s=null;if(null==i&&n==e.KeyboardEvent.TAB){var a=this._legend.__getKeyboardObjects();a.length>0&&(e.EventManager.consumeEvent(t),s=this.getDefaultNavigable(a))}else i&&(n==e.KeyboardEvent.TAB?(e.EventManager.consumeEvent(t),s=i):n==e.KeyboardEvent.ENTER||n==e.KeyboardEvent.SPACE?(n==e.KeyboardEvent.ENTER&&this._eventManager.handleClick(i,t),r?this._eventManager.onCollapseButtonClick(t,i.getDisplayables()[0]):this._eventManager.processHideShowEvent(i),e.EventManager.consumeEvent(t)):!r||n!=e.KeyboardEvent.LEFT_ARROW&&n!=e.KeyboardEvent.RIGHT_ARROW?s=o.superclass.processKeyDown.call(this,t):(this._eventManager.onCollapseButtonClick(t,i.getDisplayables()[0]),e.EventManager.consumeEvent(t)));return s&&this._legend.container.scrollIntoView(s.getDisplayables()[0]),s};var r=function(e,t,n,i,o,r){this.Init(e,t,n,i,o,r)};e.Obj.createSubclass(r,e.Obj),r.prototype.Init=function(t,n,i,o,r,a){if(this._legend=t,this._displayables=n,this._item=i,this._category=s.getItemCategory(this._item,this._legend),this._id=this._category?this._category:i.title,this._drillable=a,this._tooltip=o,this._datatip=r,this._isShowingKeyboardFocusEffect=!1,this._drillable)for(var l=0;l<this._displayables.length;l++)this._displayables[l].setCursor(e.SelectionEffectUtils.getSelectingCursor())},r.associate=function(e,t,n,i,o,s){if(!e||!n)return null;var a=new r(t,e,n,i,o,s);t.__registerObject(a);for(var l=0;l<e.length;l++)t.getEventManager().associate(e[l],a);return a},r.prototype.getData=function(){return this._item},r.prototype.getColor=function(){return this._item.color},r.prototype.getId=function(){return this._id},r.prototype.getDisplayables=function(){return this._displayables},r.prototype.getCategories=function(e){return null!=this._category?[this._category]:null},r.prototype.isDrillable=function(){return this._drillable},r.prototype.getAriaLabel=function(){var t=[],n=this._legend.getOptions().translations,i=this._legend.getOptions().hideAndShowBehavior,o=s.isCategoryHidden(this._category,this._legend),r=this.getData();return this._displayables[0]instanceof e.IconButton?(t.push(n[s.isSectionCollapsed(r,this._legend)?"stateCollapsed":"stateExpanded"]),e.Displayable.generateAriaLabel(r.title,t)):("off"!=i&&"none"!=i&&t.push(n[o?"stateHidden":"stateVisible"]),this.isDrillable()&&t.push(n.stateDrillable),null!=r.shortDesc?e.Displayable.generateAriaLabel(r.shortDesc,t):t.length>0?e.Displayable.generateAriaLabel(r.text,t):null)},r.prototype.updateAriaLabel=function(){!e.Agent.deferAriaCreation()&&this._displayables[0]&&this._displayables[0].setAriaProperty("label",this.getAriaLabel())},r.prototype.getNextNavigable=function(t){if(t.type==e.MouseEvent.CLICK)return this;var n=this._legend.__getKeyboardObjects();return e.KeyboardHandler.getNextNavigable(this,t,n,!0,this._legend)},r.prototype.getKeyboardBoundingBox=function(t){return this._displayables[0]?this._displayables[0].getDimensions(t):new e.Rectangle(0,0,0,0)},r.prototype.getTargetElem=function(){return this._displayables[0]?this._displayables[0].getElem():null},r.prototype.showKeyboardFocusEffect=function(){this._isShowingKeyboardFocusEffect=!0,this._displayables[0]&&(this._displayables[0]instanceof e.IconButton?this._displayables[0].showKeyboardFocusEffect():this._displayables[0].setSolidStroke(e.Agent.getFocusColor()))},r.prototype.hideKeyboardFocusEffect=function(){this._isShowingKeyboardFocusEffect=!1,this._displayables[0]&&(this._displayables[0]instanceof e.IconButton?this._displayables[0].hideKeyboardFocusEffect():this._displayables[0].setStroke(null))},r.prototype.isShowingKeyboardFocusEffect=function(){return this._isShowingKeyboardFocusEffect},r.prototype.getTooltip=function(e){return this._tooltip},r.prototype.getDatatip=function(e){return this._datatip},r.prototype.getDatatipColor=function(e){return this._item.color},r.prototype.isDragAvailable=function(e){return!0},r.prototype.getDragTransferable=function(e,t){return[this.getId()]},r.prototype.getDragFeedback=function(e,t){return this.getDisplayables()};var s=new Object;e.Obj.createSubclass(s,e.Obj),s._DEFAULT_LINE_WIDTH_WITH_MARKER=2,s._LINE_MARKER_SIZE_FACTOR=.6,s._DEFAULT_SYMBOL_SIZE=10,s._BUTTON_SIZE=12,s._FOCUS_GAP=2,s.render=function(t,i){var o=t.getOptions(),r=t.getCtx(),a=e.Agent.isRightToLeft(r);t.__setBounds(i),o.isLayout||s._renderBackground(t,i);var l=new e.SimpleScrollableContainer(r,i.w,i.h),g=new e.Container(r);l.getScrollingPane().addChild(g),t.addChild(l),t.container=l;var h=n.getGapSize(t,o.layout.outerGapWidth),c=n.getGapSize(t,o.layout.outerGapHeight);if(i.x+=h,i.y+=c,i.w-=2*h,i.h-=2*c,i.w<=0||i.h<=0)return new e.Dimension(0,0);var u=s._renderContents(t,g,new e.Rectangle(i.x,i.y,i.w,i.h));if(0==u.w||0==u.h)return new e.Dimension(0,0);l.prepareContentPane(),u.h>i.h?(u.h=i.h,o._isScrollingLegend=!0):o._isScrollingLegend=!1;var d=0,p=0,y=null!=o.hAlign?o.hAlign:o.halign;"center"==y?d=i.x-u.x+(i.w-u.w)/2:"end"==y&&(d=a?i.x-u.x:i.x-u.x+i.w-u.w);var _=null!=o.vAlign?o.vAlign:o.valign;"middle"==_?p=i.y-u.y+(i.h-u.h)/2:"bottom"==_&&(p=i.y-u.y+i.h-u.h);var f=new e.Rectangle(u.x+d-h,u.y+p-c,u.w+2*h,u.h+2*c);if(o.isLayout)return f;(d||p)&&g.setTranslate(d,p);for(var v=t.__getTitles(),b=0;b<v.length;b++)e.LayoutUtils.align(u,v[b].halign,v[b].text,v[b].text.getDimensions().w);return f},s._renderContents=function(e,t,i){var o=e.getOptions();i=i.clone();var r=s._renderTitle(e,t,o.title,i,null,!0);if(r){var a=r.getDimensions(),l=n.getGapSize(e,o.layout.titleGapHeight);i.y+=a.h+l,i.h-=Math.floor(a.h+l)}var g=s._renderSections(e,t,o.sections,i,[]);return r?a.getUnion(g):g},s._renderBackground=function(t,n){var i=t.getOptions(),o=i.backgroundColor,r=i.borderColor,s=i.dnd?i.dnd.drop.legend:{},a=i.dnd?i.dnd.drag.series:{};if(o||r||Object.keys(s).length>0||Object.keys(a).length>0){var l=new e.Rect(t.getCtx(),n.x,n.y,n.w,n.h);o?l.setSolidFill(o):l.setInvisibleFill(),r&&(l.setSolidStroke(r),l.setPixelHinting(!0)),t.addChild(l),t.getCache().putToCache("background",l)}},s._renderTitle=function(t,n,i,o,r,s,a,l){var g=t.getOptions(),h=n.getCtx(),c=e.Agent.isRightToLeft(h);if(!i)return null;var u=new e.OutputText(h,i,o.x,o.y),d=g.titleStyle;if(r){var p=g._sectionTitleStyle.clone();d=r.titleStyle?p.merge(new e.CSSStyle(r.titleStyle)):p}if(u.setCSSStyle(d),e.TextUtils.fitText(u,o.w,1/0,n)){if(c&&u.setX(o.x+o.w-u.getDimensions().w),g.isLayout)n.removeChild(u);else{var y={id:a,button:l};if(y.isCollapsible=r&&("on"==r.collapsible||1==r.collapsible),t.getEventManager().associate(u,new e.SimpleObjPeer(u.getUntruncatedTextString(),null,null,y)),s){var _=r&&r.titleHalign?r.titleHalign:g.titleHalign;t.__registerTitle({text:u,halign:_})}}return u}return null},s._renderSections=function(t,i,o,r,a){if(!o||0==o.length)return new e.Rectangle(0,0,0,0);var l=t.getOptions();l.symbolWidth||l.symbolHeight?(l.symbolWidth?l.symbolHeight||(l.symbolHeight=l.symbolWidth):l.symbolWidth=l.symbolHeight,l.symbolWidth=parseInt(l.symbolWidth),l.symbolHeight=parseInt(l.symbolHeight)):(l.symbolWidth=s._DEFAULT_SYMBOL_SIZE,l.symbolHeight=s._DEFAULT_SYMBOL_SIZE);for(var g,h=n.getGapSize(t,l.layout.sectionGapHeight),c=n.getGapSize(t,l.layout.titleGapHeight),u=n.getGapSize(t,l.layout.sectionGapWidth),d=s._getRowHeight(t),p="vertical"!=l.orientation,y=null,_=r.clone(),f=0;f<o.length;f++){var v=a.concat([f]),b=s.isSectionCollapsed(o[f],t)?c:h;p?(g=s._renderHorizontalSection(t,i,o[f],_,d)).w>_.w?(_.w<r.w&&(r.y+=g.h+b,r.h-=g.h+b),g=g.w<=r.w?s._renderHorizontalSection(t,i,o[f],r,d):s._renderVerticalSection(t,i,o[f],r,d,v,!0),r.y+=g.h+b,r.h-=g.h+b,_=r.clone()):(_.w-=g.w+u,e.Agent.isRightToLeft(t.getCtx())||(_.x+=g.w+u)):(g=s._renderVerticalSection(t,i,o[f],r,d,v,!1),r.y+=g.h+b,r.h-=g.h+b),y=y?y.getUnion(g):g}return y},s._createButton=function(t,n,i,o,a,l,g,h,c,u,d){var p=e.ToolkitUtils.getIconStyle(t,o[a]),y=new e.IconButton(t,"borderless",{style:p,size:s._BUTTON_SIZE},null,c,u,d);y.setTranslate(l,g);var _=r.associate([y],n,i,h,null,!1);return y.setAriaRole("button"),_.updateAriaLabel(),y},s._renderVerticalSection=function(t,i,o,r,a,l,g){if(o){var h,c=t.getOptions(),u=n.getGapSize(t,c.layout.symbolGapWidth),d=n.getGapSize(t,c.layout.rowGap),p=n.getGapSize(t,c.layout.columnGap),y=t.getCtx(),_=e.Agent.isRightToLeft(y),f=null!=o.sections&&o.sections.length>0,v=null!=o.items&&o.items.length>0,b=r.clone();"off"!=c.scrolling&&(b.h=1/0);var m,C="on"==o.collapsible||1==o.collapsible;if(C){var S=_?b.x+b.w-s._BUTTON_SIZE:b.x;if(!c.isLayout){var x=s.isSectionCollapsed(o,t),O=x?"closed":"open",w=c.translations[x?"tooltipExpand":"tooltipCollapse"],T=t.getEventManager();m=s._createButton(y,t,o,c._resources,O,S,b.y,w,l,T.onCollapseButtonClick,T),i.addChild(m)}h=new e.Rectangle(S,b.y,s._BUTTON_SIZE,s._BUTTON_SIZE);var E=n.getGapSize(t,c.layout.symbolGapWidth);_||(b.x+=s._BUTTON_SIZE+E),b.w-=s._BUTTON_SIZE+E}var L=s._renderTitle(t,i,o.title,b,o,!C&&l.length<=1,l,m),D=L?L.getDimensions():new e.Rectangle(_?b.x+b.w:b.x,b.y,0,0),I=h?D.getUnion(h):D;if(!v&&!f||s.isSectionCollapsed(o,t))return I;if(I.h>0){var A=n.getGapSize(t,c.layout.titleGapHeight);b.y+=I.h+A,b.h-=I.h+A}if(f){var M=s._renderSections(t,i,o.sections,b,l);I=I.getUnion(M)}if(!v)return I;var F=s._calcColumns(t,b,a,o.items,g),G=F.numCols,R=F.numRows,k=F.width,H=b.y;if(0==R||0==G)return I;var B=R*(a+d)-d,N=Math.min(G*(k+p)-p,b.w),P=new e.Rectangle(_?b.x+b.w-N:b.x,b.y,N,B);if(I=I.getUnion(P),c.isLayout)return I;for(var j=k-c.symbolWidth-u,U=0,W=1,K=o.items.length,z=0;z<K;z++){var V=o.items[z];if(s._createLegendItem(t,i,V,b,j,a,z),b.y+=a+d,++U===R&&W!==G&&(b.y=H,b.w-=k+p,_||(b.x+=k+p),U=0,W++),U===R)break}return I}},s._renderHorizontalSection=function(t,i,o,r,a){if(o){var l=t.getOptions(),g=l.symbolWidth,h=n.getGapSize(t,l.layout.symbolGapWidth),c=n.getGapSize(t,l.layout.columnGap),u=n.getGapSize(t,l.layout.titleGapWidth),d=null!=o.items&&o.items.length>0,p=e.Agent.isRightToLeft(t.getCtx()),y=r.clone(),_=s._renderTitle(t,i,o.title,r,o,!1),f=_?_.getDimensions():new e.Rectangle(p?r.x+r.w:r.x,r.y,0,0);if(!d)return f;f.w>0&&(y.w-=f.w+u,p||(y.x+=f.w+u));var v,b,m,C=[],S=r.w-y.w,x=o.items.length;for(m=0;m<x;m++)v=o.items[m],S+=(b=Math.ceil(e.TextUtils.getTextStringWidth(t.getCtx(),v.text,l.textStyle)))+g+h+c,C.push(b);x>0&&(S-=c);var O,w=new e.Rectangle(p?r.x+r.w-S:r.x,r.y,S,Math.max(a,f.h));if(l.isLayout||S>r.w)return i.removeChild(_),w;if(_){t.getCache().putToCache("horizRowAlign",!0),t.getCache().putToCache("sectionRect",w);var T=_.getDimensions(),E=w.y+w.h/2-T.h/2-T.y;_.setTranslate(0,E)}for(m=0;m<x;m++)v=o.items[m],s._createLegendItem(t,i,v,y,C[m],a,m),O=C[m]+g+h,y.w-=O+c,p||(y.x+=O+c);return t.getCache().putToCache("horizRowAlign",!1),t.getCache().putToCache("sectionRect",null),w}},s._calcColumns=function(t,i,o,r,s){for(var a=t.getOptions(),l=[],g=0;g<r.length;g++)l.push(r[g].text);var h,c,u,d=e.TextUtils.getMaxTextStringWidth(t.getCtx(),l,a.textStyle),p=a.symbolWidth,y=n.getGapSize(t,a.layout.symbolGapWidth),_=n.getGapSize(t,a.layout.rowGap),f=n.getGapSize(t,a.layout.columnGap),v=Math.ceil(p+y+d);s?(u=Math.min(Math.max(Math.floor((i.w+f)/(v+f)),1),r.length),h=Math.min(Math.floor((i.h+_)/(o+_)),Math.ceil(r.length/u)),u=Math.ceil(r.length/h),h=Math.ceil(r.length/u)):i.h==1/0?(u=1,h=r.length):(h=Math.min(Math.floor((i.h+_)/(o+_)),r.length),u=Math.ceil(r.length/h),h=Math.ceil(r.length/u));var b=(i.w-f*(u-1))/u;return(c=Math.min(v,b))<p?{width:0,numCols:0,numRows:0}:{width:c,numCols:u,numRows:h}},s._getRowHeight=function(t){var i=t.getOptions(),o=e.TextUtils.getTextStringHeight(t.getCtx(),i.textStyle),r=i.symbolHeight+n.getGapSize(t,i.layout.symbolGapHeight);return Math.ceil(Math.max(o,r))},s._createLegendItem=function(t,i,o,a,l,g,h){var c,u=t.getOptions(),d=t.getCtx(),p=e.Agent.isRightToLeft(d),y=u.symbolWidth,_=n.getGapSize(t,u.layout.symbolGapWidth),f=p?a.x+a.w-y:a.x,v=p?a.x+a.w-y-_:a.x+y+_,b=s._createLegendSymbol(t,f,a.y,g,o,h),m=o.text;if(null!=m){var C=u.textStyle;(c=s._createLegendText(i,l,m,C))&&(c.setX(v),e.TextUtils.centerTextVertically(c,a.y+g/2),p&&c.alignRight());var S=t.getCache().getFromCache("sectionRect");if(t.getCache().getFromCache("horizRowAlign")&&S&&"vertical"!=u.orientation){var x=c.getDimensions().h,O=S.y+S.h/2-Math.max(u.symbolHeight,x)/2-a.y;b.setTranslate(0,O),c.setTranslate(0,O)}}i.addChild(b);var w=new e.Rect(d,p?v-l-s._FOCUS_GAP:f-s._FOCUS_GAP,a.y-s._FOCUS_GAP,y+_+l+2*s._FOCUS_GAP,g+2*s._FOCUS_GAP);w.setInvisibleFill();var T=u.hideAndShowBehavior;"none"!=T&&"off"!=T&&w.setCursor("pointer"),i.addChild(w);var E=[w,b];null!=c&&E.push(c);var L=r.associate(E,t,o,null!=c?c.getUntruncatedTextString():null,o.shortDesc,s._isItemDrillable(t,o));s.isCategoryHidden(s.getItemCategory(o,t),t)&&(b.setHollow(L.getColor()),b.setStyle().setClassName()),("none"!=T&&"off"!=T||null!=o.shortDesc)&&(w.setAriaRole("img"),L.updateAriaLabel())},s._isItemDrillable=function(e,t){return"on"==t.drilling||"off"!=t.drilling&&"on"==e.getOptions().drilling},s._createLegendText=function(t,n,i,o){var r=new e.OutputText(t.getCtx(),i);return r.setCSSStyle(o),r=e.TextUtils.fitText(r,n,1/0,t)?r:null},s._createLegendSymbol=function(t,n,i,o,r,a){var l=t.getOptions(),g=t.getCtx(),h=null!=r.type?r.type:r.symbolType;r.markerShape||(r.markerShape=l._markerShape),r.color||(r.color=l._color),r.lineWidth||(r.lineWidth="lineWithMarker"==h?s._DEFAULT_LINE_WIDTH_WITH_MARKER:l._lineWidth);var c,u=l.symbolWidth,d=l.symbolHeight,p=i+o/2,y=n+u/2;if("line"==h)c=s._createLine(g,n,i,u,o,r);else if("lineWithMarker"==h)c=s._createLine(g,n,i,u,o,r),s.isCategoryHidden(s.getItemCategory(r,t),t)||c.addChild(s._createMarker(t,y,p,u*s._LINE_MARKER_SIZE_FACTOR,d*s._LINE_MARKER_SIZE_FACTOR,r));else if("image"==h)c=s._createImage(t,n,i,u,d,o,r);else if("_verticalBoxPlot"==h)d=Math.max(4*Math.round(d/4),4),(c=new e.Container(g)).addChild(s._createMarker(t,y,p+d/4,u,d/2,s._getBoxPlotOptions(r,"q2"))),c.addChild(s._createMarker(t,y,p-d/4,u,d/2,s._getBoxPlotOptions(r,"q3")));else if("_horizontalBoxPlot"==h){var _=e.Agent.isRightToLeft(g),f=(u=Math.max(4*Math.round(u/4),4))/4*(_?1:-1);(c=new e.Container(g)).addChild(s._createMarker(t,y+f,p,u/2,d,s._getBoxPlotOptions(r,"q2"))),c.addChild(s._createMarker(t,y-f,p,u/2,d,s._getBoxPlotOptions(r,"q3")))}else c=s._createMarker(t,y,p,u,d,r);return c},s._createImage=function(t,n,i,o,r,s,a){var l=t.getCtx(),g=i+s/2,h=n+o/2;return new e.ImageMarker(l,h,g,o,r,null,a.source)},s._createMarker=function(t,n,i,o,r,s){var a,l=t.getCtx(),g=(t.getOptions(),s.markerShape),h=s.symbolType&&"lineWithMarker"==s.symbolType&&s.markerColor?s.markerColor:s.color,c=s.markerStyle||s.markerSvgStyle?s.markerStyle||s.markerSvgStyle:s.style||s.svgStyle,u=s.markerClassName||s.markerSvgClassName?s.markerClassName||s.markerSvgClassName:s.className||s.svgClassName,d=s.pattern;if(d&&"none"!=d?((a=new e.SimpleMarker(l,g,0,0,o,r,null,null,!0)).setFill(new e.PatternFill(d,h,"#FFFFFF")),a.setTranslate(n,i)):(a=new e.SimpleMarker(l,g,n,i,o,r,null,null,!0)).setSolidFill(h),s.borderColor){var p=s._borderWidth?s._borderWidth:1;a.setSolidStroke(s.borderColor,null,p)}return"square"!=g&&"rectangle"!=g||a.setPixelHinting(!0),a.setClassName(u).setStyle(c),a},s._createLine=function(t,n,i,o,r,s){var a=i+r/2;o=o%2==1?o+1:o;var l,g=new e.Line(t,n,Math.round(a),n+o,Math.round(a)),h=s.lineStyle;"dashed"==h?l={dashArray:"4,2,4"}:"dotted"==h&&(l={dashArray:"2"});var c=new e.Stroke(s.color,1,s.lineWidth,!1,l);return g.setClassName(s.className||s.svgClassName).setStyle(s.style||s.svgStyle),g.setStroke(c),g.setPixelHinting(!0),g},s._getBoxPlotOptions=function(e,t){return{markerShape:"rectangle",color:e._boxPlot[t+"Color"],pattern:e._boxPlot["_"+t+"Pattern"],className:e._boxPlot[t+"ClassName"]||e._boxPlot[t+"svgClassName"],style:e._boxPlot[t+"Style"]||e._boxPlot[t+"svgStyle"]}},s.getItemCategory=function(e,t){var n=null,i=null!=t.getOptions().data;return e.categories&&e.categories.length>0?n=e.categories[0]:i||(n=e.id?e.id:e.text),n},s.isCategoryHidden=function(e,t){var n=t.getOptions().hiddenCategories;return!(!n||n.length<=0)&&-1!==n.indexOf(e)},s.isSectionCollapsed=function(e,t){var n=t.getOptions();return"off"==e.expanded||0==e.expanded||n.expanded&&0==n.expanded.has(e.id)}}(dvt);
  return dvt;
});
