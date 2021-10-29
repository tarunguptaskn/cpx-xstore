define(["ojs/ojcore","jraf/jrafcore","knockout","libs/xenvironment/urlService"],(function(e,t,o,r){let s=this,n=e.Translations.getTranslatedString;function a(){var e=$.ajax({url:r.getServerUrl("storeState"),type:"GET",dataType:"text",crossDomain:!0,xhrFields:{withCredentials:!0}});e.done((function(e){switch(console.debug("Store state: "+e),e){case"STORE_CLOSED":case"STORE_CLOSING":s.isOpen(!1);break;case"STORE_OPEN":s.isOpen(!0)}})),e.fail((function(e,t,o){console.error("Could not get store state: "+o)}))}s.isOpen=o.observable(!1),s.currentStoreStateText=o.observable(""),s.storeInformation=o.observable(t.App.getAppDataProperty("storeInfo")),s.storeInformationText=o.observable(s.storeInformation().storeName+" "+s.storeInformation().storeNumber),s.storeOpenText=n("xenv.general.StoreOpen"),s.storeClosedText=n("xenv.general.StoreClosed"),s.accessibleStoreOpenStatusText=s.storeInformationText()+" "+s.storeOpenText,s.accessibleStoreClosedStatusText=s.storeInformationText()+" "+s.storeClosedText,a(),setInterval(a,5e3)}));