define(["knockout","jquery","ojs/ojcore","ojs/ojlogger","ojs/ojvalidation-base","ojs/ojmodel","jraf/models/components/MultipleSortDataSource","jraf/composites/utils/TranslationLoaderUtil","module","jqueryui-amd/keycode","ojs/ojdatagrid","ojs/ojcollectiondatagriddatasource","ojs/ojpagingdatagriddatasource","ojs/ojvalidation-datetime","ojs/ojvalidation-number","ojs/ojinputtext","ojs/ojselectsingle"],(function(t,e,r,n,i,o,s,a,l){"use strict";function u(t){var e=this;this.X=t,this.M(this.X.properties),u.y.getTranslations().then((function(t){e.xn(t)}))}return u.DATA_TYPE_STRING="string",u.DATA_TYPE_ICON="icon",u.DATA_TYPE_DATE="date",u.DATA_TYPE_NUMBER="number",u.DATA_TYPE_CUSTOM="custom",u.RTL_SCROLL_TYPE_RIGHT_POSITIVE="origin-right-positive",u.RTL_SCROLL_TYPE_RIGHT_NEGATIVE="origin-right-negative",u.RTL_SCROLL_TYPE_LEFT="origin-left",u.DATE_FORMAT_OPTIONS={formatType:"datetime",dateFormat:"short",timeFormat:"medium"},u.CELL_ICON_CLASS="oj-rgbu-jraf-simple-grid-cell-icon",u.DEFAULT_ROW_HEADER_CLASS="oj-rgbu-jraf-simple-grid-row-header",u.y=new a("oj-rgbu-jraf-simple-grid",l.id),u.prototype.nn=function(t){return"string"==typeof t&&0<t.length},u.prototype.tn=function(t){return t&&"object"==typeof t&&!Array.isArray(t)},u.prototype.Fn=function(t){return"function"==typeof t},u.prototype.hh=function(t){if(!this.tn(t))return!1;var r=t.key||t.keyIdentifier;return r?"Enter"===r:t.keyCode===e.ui.keyCode.ENTER},u.prototype.Sn=function(t){if(!this.nn(t))return{};var e={};return t.split(";").forEach((function(t){if(this.nn(t)){var r=t.split(":");2===r.length&&(e[r[0].trim()]=r[1].trim())}}),this),e},u.prototype.M=function(e){var r=this;this.dataGridId=this.X.uniqueId+"_dataGrid",this.filterBarId=this.X.uniqueId+"_filterBar",this.filterPlaceholder=t.observable(e.translations&&e.translations.filterPlaceholder),this.msgNoData=e.translations&&e.translations.msgNoData,this.msgNoFilteredData=e.translations&&e.translations.msgNoFilteredData,this.messageNoData=t.observable(null),this.En=i.Validation.converterFactory("datetime").createConverter(u.DATE_FORMAT_OPTIONS),this.gridLabel=t.observable(e.label);var n="oj-rgbu-jraf-simple-grid-data-grid";this.nn(e.tableClassNames)&&(n+=" "+e.tableClassNames),this.gridClassNames=t.observable(n),this.gridStyle=t.observable(this.Sn(e.tableStyle)),this.Mn=e.disableSorting,this.Xn=e.collection,this.An=e.rowHeaderClassNameFunction,this.Wn=e.rowHeaderStyleFunction,this.zn(e.columns),this.Dn(e),this.Xn.on(o.Events.EventType.ALLADDED,this.Gn.bind(this)),this.rowHeaderConfigured="string"==typeof e.rowHeader,this.showFilterBarRowHeader=t.observable(!this.Xn.isEmpty()),this.Xn.on(o.Events.EventType.SYNC,this.In.bind(this)),this.selection=t.observableArray([]),Array.isArray(e.selection)&&this.selection(e.selection),this.selection.subscribe((function(t){e.selection=t.slice(),r.Rn(t)})),this.selectMode=e.multipleSelect?"multiple":"single",this.selectionListener=this.Fn(e.selectionListener)?e.selectionListener:null,this.Bn(),this.Jn(),this.On()},u.prototype.zn=function(e){this.columns=t.observableArray(),this.Kn=t.pureComputed((function(){return this.columns().map((function(t){return t.value}))}),this),this.Qn=t.pureComputed((function(){var t={};return this.columns().forEach((function(e){t[e.value]=e.label})),t}),this),this.Yn(e)},u.prototype.Yn=function(t){var e=t.filter((function(t){return"boolean"!=typeof t.shown||t.shown}),this).map((function(t){return this.Zn(t)}),this);this.columns(e)},u.prototype.Zn=function(e){var r;e.dataType===u.DATA_TYPE_NUMBER&&(r=i.Validation.converterFactory("number").createConverter(e.numberConverterOptions));var n={value:e.valueName,label:e.label||e.valueName,typeInfo:e.dataType||u.DATA_TYPE_STRING,callback:e.callback,width:e.width,cellAlignment:e.cellAlignment,headerClassNameFunction:e.headerClassNameFunction,headerStyleFunction:e.headerStyleFunction,cellClassNameFunction:e.cellClassNameFunction,cellStyleFunction:e.cellStyleFunction,customRenderer:e.customRenderer,numberConverter:r,filterEnabled:e.filterEnabled,filterWidth:t.observable(e.width),sortable:!this.Mn&&e.sortable};if(e.filterEnabled){var o=t.isWritableObservable(e.filterValue)?e.filterValue:t.observable(t.unwrap(e.filterValue));n.filterOptions=e.filterOptions,n.filterValue=o}return n},u.prototype.Dn=function(t){var e={columns:this.Kn(),rowHeader:t.rowHeader};this.dataSource=new s(this.Xn,e),t.paging&&(this.$n=!0,this.dataSource=new r.PagingDataGridDataSource(this.dataSource)),this.tr()},u.prototype.tr=function(){this.sn("ojRgbuJrafSimpleGridDataSourceInitialized",!1)},u.prototype.sn=function(t,e){var r={bubbles:!0,cancelable:e};return this.X.element.dispatchEvent(new CustomEvent(t,r))},u.prototype.xn=function(t){this.filterPlaceholder(this.filterPlaceholder()||t.filterPlaceholder),this.msgNoData=this.msgNoData||t.msgNoData,this.msgNoFilteredData=this.msgNoFilteredData||t.msgNoFilteredData,this.nr()},u.prototype.nr=function(){this.messageNoData(this.sr()?this.msgNoFilteredData:this.msgNoData)},u.prototype.Bn=function(){var t=this;this.prepareColumn=function(e){return t.er(e.data)},this.getSortableValue=function(e){return t.hr(e)},this.getColumnHeaderClass=function(e){return t.ur(e)},this.getColumnHeaderStyle=function(e){return t.cr(e)},this.getRowHeaderClass=function(e){return t.fr(e)},this.getRowHeaderStyle=function(e){return t.ar(e)},this.prepareCell=function(e){return t.lr(e)},this.getCellClass=function(e){return t.dr(e)},this.getCellStyle=function(e){return t.vr(e)},this.handleFilterChanged=function(){return t.mr()},this.handleGridScroll=function(e){t.jr(e)},this.handleFilterBarScroll=function(){t.pr()},this.handleColumnResize=function(e){t.gr(e)}},u.prototype.Jn=function(){if(this.filterBarRowHeaderStyle={maxWidth:"0px"},this.rowHeaderConfigured){var t=this.br();this.filterBarRowHeaderStyle={minWidth:t+"px"}}},u.prototype.br=function(){var t=document.createElement("div");t.style.visibilty="hidden",t.className=this.fr();var e=this.Sn(this.ar());Object.getOwnPropertyNames(e).forEach((function(r){t.style[r]=e[r]})),this.X.element.appendChild(t);var r=t.getBoundingClientRect(),n=Math.round(r.width);return this.X.element.removeChild(t),n},u.prototype.On=function(){this.yr=this.wr(),this.yr?this.xr=this.kr():this.xr=void 0},u.prototype.wr=function(){return 0<e("html[dir=rtl]").length},u.prototype.kr=function(){var t=e('<div dir="rtl" style="font-size: 12px; width: 5px; height: 10px; position: absolute; top: -5000px; overflow: scroll">XXXX</div>').appendTo("body")[0],r=u.RTL_SCROLL_TYPE_RIGHT_POSITIVE;return 0<t.scrollLeft?r=u.RTL_SCROLL_TYPE_LEFT:(t.scrollLeft=1,0===t.scrollLeft&&(r=u.RTL_SCROLL_TYPE_RIGHT_NEGATIVE)),e(t).remove(),r},u.prototype.Fr=function(t){var e="number"==typeof t.index?t.index:t.indexes.column;return this.columns()[e]},u.prototype.hr=function(t){var e=this.Fr(t);return"boolean"==typeof e.sortable?e.sortable?"enable":"disable":"auto"},u.prototype.Gn=function(){document.getElementById(this.dataGridId).refresh(),this.On()},u.prototype.In=function(){this.showFilterBarRowHeader(!this.Xn.isEmpty())},u.prototype.Rn=function(t){this.selectionListener&&this.selectionListener(t)},u.prototype.er=function(t){return{insert:this.Qn()[t]}},u.prototype.lr=function(t){var r=this.Fr(t),n=r.callback,o=r.typeInfo;if(n){var s=this,a=e(t.parentElement);a.click((function(e){n(e,t)})),a.on("keydown",(function(e){s.hh(e)&&n(e,t)}))}return o===u.DATA_TYPE_ICON?{insert:this.Sr(t.data)}:o===u.DATA_TYPE_DATE&&t.data?{insert:this.En.format(i.IntlConverterUtils.dateToLocalIso(t.data))}:o===u.DATA_TYPE_NUMBER&&t.data?{insert:r.numberConverter.format(t.data)}:o===u.DATA_TYPE_CUSTOM&&"function"==typeof r.customRenderer?{insert:r.customRenderer(t)}:null!==t.data&&void 0!==t.data?{insert:""+t.data}:void 0},u.prototype.Sr=function(t){if(!this.tn(t)||!this.nn(t.icon)||!this.nn(t.label))return n.warn("oj-rgbu-jraf-simple-grid: icon columns must be configured with an object specifying the icon and its label."),"";var e=document.createElement("span");return e.classList.add(u.CELL_ICON_CLASS),e.classList.add(t.icon),e.title=t.label,e.setAttribute("aria-label",t.label),e.setAttribute("role","img"),e},u.prototype.dr=function(t){var e=this.Fr(t),r=this.Cr(e);return this.Fn(e.cellClassNameFunction)&&(r+=" "+e.cellClassNameFunction(t)),r},u.prototype.vr=function(t){var e=this.Fr(t),r="";return this.Fn(e.cellStyleFunction)&&(r=e.cellStyleFunction(t)),r},u.prototype.ur=function(t){var e=this.Fr(t),r=this.Cr(e);return this.Fn(e.headerClassNameFunction)&&(r+=" "+e.headerClassNameFunction(t)),r},u.prototype.cr=function(t){var e=this.Fr(t),r="";return this.nn(e.width)&&(r+="width:"+e.width+";"),this.Fn(e.headerStyleFunction)&&(r+=e.headerStyleFunction(t)),r},u.prototype.fr=function(t){var e=u.DEFAULT_ROW_HEADER_CLASS;return this.Fn(this.An)&&(e=this.An(t)),e},u.prototype.ar=function(t){var e="";return this.Fn(this.Wn)&&(e+=this.Wn(t)),e},u.prototype.Cr=function(t){if(t.typeInfo===u.DATA_TYPE_ICON||t.typeInfo===u.DATA_TYPE_DATE)return"oj-helper-justify-content-center";var e=t.cellAlignment;return"start"===e||"left"===e?"oj-helper-justify-content-flex-start":"end"===e||"right"===e?"oj-helper-justify-content-flex-end":"center"===e?"oj-helper-justify-content-center":"oj-helper-justify-content-flex-end"},u.prototype.mr=function(){var t=this;this.Xn.filterCriteria=this.Er(),this.Xn.refresh(),this.nr(),window.setTimeout((function(){t.pr()}),0)},u.prototype.Er=function(){var e=this.columns().filter((function(e){return t.unwrap(e.filterValue)})).map((function(e){return{column:e.value,value:t.unwrap(e.filterValue)}}));return{filterMethod:this.X.properties.filterMethod,filters:e}},u.prototype.clearFilters=function(){this.sr()&&(this.columns().forEach((function(t){t.filterEnabled&&t.filterValue(void 0)})),this.mr())},u.prototype.sr=function(){var t=this.Xn.filterCriteria;return t&&0<t.filters.length},u.prototype.Mr=function(){var t=this.Xn.filterCriteria;t&&1<t.filters.length&&this.mr()},u.prototype.jr=function(t){var e=t.detail.scrollX;this.Xr(e)},u.prototype.Ar=function(){var t=document.getElementById(this.dataGridId).scrollPosition.x;this.Xr(t)},u.prototype.Xr=function(t){var e=document.getElementById(this.filterBarId);if(e){var r=t;this.yr&&(this.xr===u.RTL_SCROLL_TYPE_LEFT?r=e.scrollWidth-(e.clientWidth+t):this.xr===u.RTL_SCROLL_TYPE_RIGHT_NEGATIVE&&(r=-t)),e.scrollLeft!==r&&(e.scrollLeft=r)}},u.prototype.pr=function(){var t=document.getElementById(this.filterBarId),e=document.getElementById(this.dataGridId);if(e&&t){var r=t.scrollLeft;this.yr&&(this.xr===u.RTL_SCROLL_TYPE_LEFT?r=t.scrollWidth-(t.scrollLeft+t.clientWidth):this.xr===u.RTL_SCROLL_TYPE_RIGHT_NEGATIVE&&(r=-t.scrollLeft)),e.scrollPosition.x!==r&&(e.scrollPosition={x:r})}},u.prototype.gr=function(t){for(var e=t.detail.header,r=t.detail.newDimensions.width+"px",n=this.columns(),i=0;i<n.length;i++)if(n[i].value===e){n[i].filterWidth(r),n[i].width=r;break}},u.prototype.propertyChanged=function(t){var e=t.property;"external"===t.updatedFrom&&("selection"===e?this.selection(t.value):"filteringEnabled"===e?(this.clearFilters(),this.Ar()):"filterMethod"===e&&this.Mr())},u.prototype.getDataSource=function(){return this.dataSource},u.prototype.getContextByNode=function(t){return document.getElementById(this.dataGridId).getContextByNode(t)},u.prototype.refresh=function(){return this.$n&&this.Xn.refresh(),this.Gn()},u.prototype.reset=function(){this.Yn(this.X.properties.columns),this.Dn(this.X.properties),document.getElementById(this.dataGridId).setProperty("data",this.dataSource)},u.prototype.resetColumnHeaders=function(){var t=this.X.properties.columns.reduce((function(t,e){return t[e.valueName]=e.label||e.valueName,t}),{}),e=this.columns().map((function(e){var r=t[e.value];return r&&(e.label=r),e}));this.columns(e),document.getElementById(this.dataGridId).refresh()},u}));