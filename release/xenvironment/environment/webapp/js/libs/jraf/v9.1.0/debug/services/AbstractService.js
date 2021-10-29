define(["ojs/ojcore","jraf/utils/ValidationUtils"],(function(e,r){"use strict";function t(e){if(!r.isNonemptyString(e))throw new TypeError("AbstractService: Missing base URI.");this.baseUri=e,t._instantiated=!0,t.superclass.Init.apply(this)}return t.SERVICE_VERSION="1.4.0",e.Object.createSubclass(t,e.Object,"AbstractService"),t.prototype.getBaseUri=function(){return this.baseUri},t.prototype.GetStandardHeaders=function(){var r={Accept:"application/json","Content-Type":"application/json","Content-Language":e.Config.getLocale()};return t._ignoreServiceVersion?r["Accept-Versioning"]=!1:r["Accept-Version"]=t._versionOverride||t.SERVICE_VERSION,r},t.prototype.ConvertAjaxPromise=function(e){return this.ConvertAjaxPromiseDetailedErrors(e).catch((function(e){return Promise.reject(e.message)}))},t.prototype.ConvertAjaxPromiseDetailedErrors=function(e){var r=this;return new Promise((function(t,i){e.done((function(){t.apply(this,arguments)})),e.fail((function(e,t,n){i({message:r.GetFailureReason(e,n),status:e.status})}))}))},t.prototype.GetFailureReason=function(t,i){if(!r.isObjectStrict(t)||!r.isNonemptyString(t.responseText))return i;var n,o=t.responseText;try{n=JSON.parse(o)}catch(r){e.Logger.info("AbstractService._getFailureReason: responseText was not JSON.")}return r.isArray(n)&&r.isObjectStrict(n[0])&&r.isNonemptyString(n[0].message)?n[0].message:o},t.prototype.BuildEndpoint=function(e,r){var t=this.baseUri;return"/"!==t.slice(-1)&&(t+="/"),t+=r+e},t.overrideVersion=function(e){if(t._instantiated)throw new Error("AbstractService.overrideVersion: Cannot override global version after services instantiate");if(!r.isNonemptyString(e))throw new TypeError("AbstractService.overrideVersion: Version must be a string");t._versionOverride=e},t.ignoreServiceVersion=function(){if(t._instantiated)throw new Error("AbstractService.overrideVersion: Cannot set global version ignore after services instantiate");t._ignoreServiceVersion=!0},t}));