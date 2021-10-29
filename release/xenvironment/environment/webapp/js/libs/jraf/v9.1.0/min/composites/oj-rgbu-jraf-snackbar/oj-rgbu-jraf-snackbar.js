define(["knockout","jquery","ojs/ojtranslation","ojs/ojlogger","jraf/utils/ValidationUtils","jraf/composites/utils/TranslationLoaderUtil","module","ojs/ojanimation"],(function(t,r,n,i,s,e,a){"use strict";var o=n.getTranslatedString;function c(r){var n=this,i=r.uniqueId;this.snackbarAnchorId=i+"_anchor",this.dialogId=i+"_dialog",this.dialogHeaderId=i+"_dialogHeader",this.loadingTranslations=c.y.getTranslations(),this.activeSnack=t.observable(null),this._r=[],this.Tr=Promise.resolve(),this.Ir=0,this.firePrimary=function(){n.Lr()},this.fireSecondary=function(){n.Pr()},this.handleDialogClose=function(){n.Br()},this.closeDialog=function(){n.qr()},this.showAllMessages=function(){n.Dr()},this.componentInitializing=this.loadingTranslations.then((function(t){n.translations=t}))}return c.LEVEL_INFO="info",c.LEVEL_WARNING="warning",c.LEVEL_ERROR="error",c.LEVEL_SUCCESS="success",c.ANIMATION_CLASS="oj-rgbu-jraf-snackbar-animating",c.ACTIVE_CLASS="oj-rgbu-jraf-snackbar-active",c.ANIMATION_EXIT_CLASS="oj-rgbu-jraf-snackbar-animate-exit",c.ANIMATION_DURATION=500,c.Hr=c.DEFAULT_DISMISS_TIMEOUT=3e3,c.STATUS_EVENT_TYPE="ojRgbuJrafSnackbarStatus",c.y=new e("oj-rgbu-jraf-snackbar",a.id),c.prototype.activated=function(){return this.componentInitializing},c.prototype.disconnected=function(){window.clearTimeout(this.Jr)},c.prototype.openSnack=function(t){var r=this.Ur(t);return this.zr(r),r.Nr},c.prototype.Ur=function(t){if(!s.isObjectStrict(t)||!s.isNonemptyString(t.message)&&!s.isArray(t.messageList)||!s.isNonemptyString(t.severity))throw new TypeError("Snackbar._parseSnack: Missing required parameters");var r=this.Or(t.severity),n={Nr:this.Rr(),message:t.message,severity:t.severity,severityIcon:"oj-rgbu-jraf-snackbar-snack-icon "+r,dialogHeaderSeverityIcon:"oj-rgbu-jraf-snackbar-snack-header-icon "+r,severityLabel:this.Vr(t.severity),Gr:s.getBoolean(t.disableTimeout,!1),Kr:s.isNumber(t.timeout)?+t.timeout:c.Hr,hasMultipleMessages:!1};return s.isArray(t.messageList)&&(n.messageList=t.messageList,n.hasMultipleMessages=!0,n.message||(n.message=this.Qr(t)),n.dialogDismissBehavior=n.Gr?"none":"icon"),this.Wr(n,t),n},c.prototype.Rr=function(){return this.Ir++},c.prototype.Or=function(t){return t===c.LEVEL_INFO?"oj-rgbu-jraf-snackbar-snack-info":t===c.LEVEL_WARNING?"oj-rgbu-jraf-snackbar-snack-warning":t===c.LEVEL_ERROR?"oj-rgbu-jraf-snackbar-snack-error":t===c.LEVEL_SUCCESS?"oj-rgbu-jraf-snackbar-snack-success":(i.warn("Snackbar._getSeverityIcon: Invalid level "+t),"")},c.prototype.Vr=function(t){return t===c.LEVEL_INFO?this.translations.info:t===c.LEVEL_WARNING?this.translations.warning:t===c.LEVEL_ERROR?this.translations.error:t===c.LEVEL_SUCCESS?this.translations.success:(i.warn("Snackbar._getSeverityLabel: Invalid level "+t),null)},c.prototype.Qr=function(t){var r=t.severity,s="",e=t.messageList.length;return r===c.LEVEL_INFO?s=this.translations.bulkMessage.info:r===c.LEVEL_WARNING?s=this.translations.bulkMessage.warning:r===c.LEVEL_ERROR?s=this.translations.bulkMessage.error:r===c.LEVEL_SUCCESS?s=this.translations.bulkMessage.success:i.warn("Snackbar._getBulkMessageLabel: Invalid level "+r),n.applyParameters(s,[e])},c.prototype.Wr=function(t,r){var n=this,i=s.getBoolean(r.showDismiss,!1),e=r.primaryButton,a=r.secondaryButton;if(i&&(e={label:this.translations.dismiss,callback:function(){n.closeSnack(t.Nr)}}),!s.isObjectStrict(a)||s.isObjectStrict(e)||i||(e=a,a=null),t.Gr&&!e)throw new TypeError("Snackbar._initializeButtons: Must have a button to declare dismiss only");e&&(t.primaryButton=this.T(e)),a&&(t.secondaryButton=this.T(a))},c.prototype.T=function(t){var r=o(t.label),n=t.callback;if(s.isNonemptyString(r)&&s.isFunction(n))return{label:r,callback:n};throw new TypeError("Snackbar._parseButton: Invalid button params:\n "+JSON.stringify(t))},c.prototype.zr=function(t){var r=this;this.Tr=this.Tr.then((function(){if(r._r.push(t),!r.activeSnack())return r.Yr()}))},c.prototype.Yr=function(){var t=this,r=this._r.shift();return this.activeSnack(r),this.Zr(r.severity),this.$r().then((function(){t.ia(r)}))},c.prototype.ia=function(t){var r=this;this.Jr&&window.clearTimeout(this.Jr),t.Gr||(this.Jr=window.setTimeout((function(){r.closeSnack(t.Nr)}),t.Kr))},c.prototype.closeSnack=function(t){var r=this;this.na||!this.activeSnack()||void 0!==t&&t!==this.activeSnack().Nr||(this.na=!0,this.Tr=this.Tr.then((function(){return r.qr(),r.Zr(null),r.ta()})).then((function(){if(r.activeSnack(null),r.na=!1,0<r._r.length)return r.Yr()})))},c.prototype.Zr=function(t){var r=document.getElementById(this.snackbarAnchorId),n=new CustomEvent(c.STATUS_EVENT_TYPE,{detail:t,bubbles:!0});r.dispatchEvent(n)},c.prototype.Lr=function(){var t=this.activeSnack().primaryButton;this.sa(t.callback)},c.prototype.Pr=function(){var t=this.activeSnack().secondaryButton;this.sa(t.callback)},c.prototype.sa=function(t){var r=this.activeSnack().Nr;t(),this.closeSnack(r)},c.prototype.$r=function(){var t=document.getElementById(this.snackbarAnchorId);return t.classList.add(c.ACTIVE_CLASS),t.classList.add(c.ANIMATION_CLASS),new Promise((function(r){window.setTimeout((function(){t.classList.remove(c.ANIMATION_CLASS),r()}),c.ANIMATION_DURATION)}))},c.prototype.ta=function(){var t=this,r=document.getElementById(this.snackbarAnchorId);return r.classList.remove(c.ACTIVE_CLASS),r.classList.add(c.ANIMATION_CLASS),r.classList.add(c.ANIMATION_EXIT_CLASS),new Promise((function(r){window.setTimeout((function(){t.ra().then(r)}),c.ANIMATION_DURATION)}))},c.prototype.ra=function(){var t=document.getElementById(this.snackbarAnchorId);return t.classList.remove(c.ANIMATION_CLASS),t.classList.remove(c.ANIMATION_EXIT_CLASS),new Promise((function(t){window.setTimeout(t,50)}))},c.prototype.qr=function(){document.getElementById(this.dialogId).close()},c.prototype.Dr=function(){this.Jr&&window.clearTimeout(this.Jr),this.dialogSnackId=this.activeSnack().Nr,document.getElementById(this.dialogId).open()},c.prototype.Br=function(){this.closeSnack(this.dialogSnackId)},c.setDefaultDismissTime=function(t){if(!(s.isNumber(t)&&0<+t))throw new TypeError("Snackbar.setDefaultDismissTime: Timeout must be a positive number");c.Hr=t},c}));