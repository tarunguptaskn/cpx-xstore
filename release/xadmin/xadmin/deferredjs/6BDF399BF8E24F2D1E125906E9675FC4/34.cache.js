$wnd.xadmin.runAsyncCallback34("function Fxd(a,b){a.a=b}\nfunction Gxd(a,b){a.b=b}\nfunction Hxd(a,b){a.c=b}\nfunction Ixd(a,b){a.f=b}\nfunction Jxd(a,b){a.g=b}\nfunction Bwd(a){this.a=a}\nfunction Dwd(a){this.a=a}\nfunction Gwd(a){this.a=a}\nfunction Lwd(a){this.a=a}\nfunction Owd(a){this.a=a}\nfunction Qwd(a){this.a=a}\nfunction jyd(a){this.a=a}\nfunction gwd(a,b){this.a=a;this.b=b}\nfunction Fwd(a,b){ayd(a.a.a.e,b)}\nfunction cyd(a,b){cl(a.f.g,!b)}\nfunction eyd(a,b){jk(a.f,b);b&&lyd(a.f)}\nfunction fwd(a,b){DGc(a.a,b);Tvd(a.a,a.b)}\nfunction Zvd(a,b){DGc(a.a,b);Qvd(a.a,a.c,a.b)}\nfunction Ovd(a,b,c){MGc(a.a,new $vd(a,c,b))}\nfunction Svd(a,b){MGc(a.a,new gwd(a,b))}\nfunction _xd(a,b){Ck(a.a,b,(jy(),jy(),iy))}\nfunction dyd(a,b){Ck(a.f.g,b,(jy(),jy(),iy))}\nfunction Zxd(){Zxd=Qoc;Yxd=(aOj(),xNj)}\nfunction uwd(){uwd=Qoc;twd=OJk(VDl)}\nfunction hyd(a){this.a=a;Uf.call(this)}\nfunction $vd(a,b,c){this.a=a;this.b=b;this.c=c}\nfunction Jwd(a,b){vwd(a.a,UDl+b.Cd());cyd(a.a.e,false)}\nfunction Kwd(a,b){vwd(a.a,b);eyd(a.a.e,xwd(a.a));cyd(a.a.e,false)}\nfunction bwd(a,b){DGc(a.a,b);Rvd(a.a,a.c,a.e,a.d,a.f,a.g,a.i,a.b)}\nfunction Pvd(a,b,c,d,e,f,g,h){MGc(a.a,new cwd(a,h,b,c,d,e,f,g))}\nfunction qPd(a,b,c){return 'Processed '+a+' of '+c+' with '+b+' errors'}\nfunction ywd(a){uwd();this.d=0;this.e=a;_xd(this.e,new Owd(this));dyd(this.e,new Qwd(this))}\nfunction cwd(a,b,c,d,e,f,g,h){this.a=a;this.b=b;this.c=c;this.e=d;this.d=e;this.f=f;this.g=g;this.i=h}\nfunction vwd(a,b){var c;a.d=(ruk(),ioc(ooc(Date.now()),pQk));c=xpi(a.a,0);zVc(c.d.e,b);J2j(c.d)}\nfunction $xd(b){try{return Vqk(BXc(b.f.b))}catch(a){a=goc(a);if(ZI(a,54)){return -1}else throw hoc(a)}}\nfunction Tvd(b,c){var d;d=new yLc(b,Ysl,'getEnrollmentProgress');try{xLc(d,Zsl,0);wLc(d,c,(NLc(),JLc))}catch(a){a=goc(a);if(!ZI(a,27))throw hoc(a)}}\nfunction lyd(a){var b,c;cl(a.g,true);v_j(a.a);c=XI(CXc(a.b));((c==null?'':c)==null||(b=XI(CXc(a.b)),b==null?'':b).length==0)&&IXc(a.b,'443',false)}\nfunction ayd(a,b){if(!b){jk(a.e,false);return}b.a==0?j5j(a.c):k5j(a.c);zVc(a.d,qPd(b.b,b.a,b.c));n5j(a.c,b.b/b.c);jk(a.e,true);b.b==b.c&&Sf(new hyd(a),5000)}\nfunction Vxd(a){var b,c;c=new ywd((b=(Ymi(a.a),new fyd),b));Fxd(c,new ypi(Toi(a.a)));Gxd(c,JPd(jni(a.a)));Hxd(c,rwd(Wmi(a.a)));Ixd(c,vpi(Toi(a.a)));Jxd(c,tB(Qmi(a.a)));return c}\nfunction Qvd(b,c,d){var e,f,g;f=new yLc(b,Ysl,TDl);try{g=xLc(f,Zsl,1);nLc(g,''+aLc(g,MRk));nLc(g,''+aLc(g,c));wLc(f,d,(NLc(),LLc))}catch(a){a=goc(a);if(ZI(a,27)){e=a;vwd(d.a,UDl+e.i);cyd(d.a.e,false)}else throw hoc(a)}}\nfunction wwd(a,b){var c;cyd(a.e,true);if(!b||z_j(a.e.f.a,false)){zo((mo(),new Dwd(a)),500);c=new Lwd(a);b?Pvd(a.c,a.b.b,BXc(a.e.f.c),$xd(a.e),BXc(a.e.f.d),BXc(a.e.f.e),BXc(a.e.f.f),c):Ovd(a.c,a.b.b,c)}else{cyd(a.e,false)}}\nfunction xwd(a){var b,c;if(!a.f){DJk(twd,(AIk(),yIk),'Client context undefined');return false}b=v$j(a.f);if(!b){DJk(twd,(AIk(),yIk),'User role undefined');return false}c=hcj(b,'ADMN_XOFFICE_CS_STORE_ENROLL');if(!c){DJk(twd,(AIk(),wIk),'Privilege not assigned');return false}return true}\nfunction byd(a,b){zVc(a.b,WDl+b+'\" to communicate with cloud services, select the Enroll button. No connection details are required.');zVc(a.f.i,WDl+b+'\" with Xstore Office Cloud Service, please provide the appropriate connection details, including your Identity Cloud Service (IDCS) Credentials, and then select the Enroll button.')}\nfunction Rvd(b,c,d,e,f,g,h,i){var j,k,l;k=new yLc(b,Ysl,TDl);try{l=xLc(k,Zsl,6);nLc(l,''+aLc(l,MRk));nLc(l,''+aLc(l,MRk));nLc(l,''+aLc(l,'I'));nLc(l,''+aLc(l,MRk));nLc(l,''+aLc(l,MRk));nLc(l,''+aLc(l,MRk));nLc(l,''+aLc(l,c));nLc(l,''+aLc(l,d));sLc(l.a,''+e);nLc(l,''+aLc(l,f));nLc(l,''+aLc(l,g));nLc(l,''+aLc(l,h));wLc(k,i,(NLc(),LLc))}catch(a){a=goc(a);if(ZI(a,27)){j=a;vwd(i.a,UDl+j.i);cyd(i.a.e,false)}else throw hoc(a)}}\nfunction fyd(){Zxd();var a,b,c;this.b=new AVc;new A_j;this.e=new CUc;this.d=new AVc;this.c=new o5j;ENj(Yxd);b=new CUc;a=new CVc(XDl);(VDc(),a.ic).style[kQk]=(lt(),ROk);a.ic.style[eRk]=(kw(),Yel);a.ic.style[eSk]=tTk;a.ic.className=uWk;vk(a.ic,_el,true);zMc(b,a,b.ic);c=new CUc;wVc(this.b);Wj(this.b).style[eSk]=tTk;zUc(c,this.b);this.a=new HNc('Enroll');Tj(this.a,Xel);zUc(c,this.a);c.ic.style[xfl]=Gfl;c.ic.style[qfl]=Gfl;c.ic.style[eSk]=Gfl;c.ic.style[XNk]='75.0%';zMc(b,c,b.ic);this.f=new myd;Wj(this.f).style['borderTop']=Nsl;Wj(this.f).style[xfl]=Gfl;Wj(this.f).style[qfl]=Gfl;Wj(this.f).style[eSk]=Gfl;Wj(this.f).style[XNk]='75.0%';zUc(b,this.f);Wj(this.e).style[GTk]=wWk;zUc(this.e,this.d);zUc(this.e,this.c);jk(this.e,false);zUc(b,this.e);Hsc(this,new DPc(b))}\nfunction myd(){var a;CUc.call(this);this.a=new A_j;this.i=new AVc;wVc(this.i);Wj(this.i).style[eRk]=(kw(),Gfl);Wj(this.i).style[eSk]=tTk;this.c=new $$c;Z$c(this.c,250);dl(this.c,true);this.b=new $$c;Z$c(this.b,5);this.d=new $$c;Z$c(this.d,30);this.e=new $$c;Z$c(this.e,250);t_j(this.a,this.e);this.f=new a_c;Z$c(this.f,250);t_j(this.a,this.f);t_j(this.a,this.c);e_j(this.a,this.b,new jyd(this.b),(Zxd(),'The value must be a valid port number.'));e_j(this.a,this.d,new N0j(this.d,(R0j(),P0j),'^rgbu-omni-[-a-z0-9]+-xocs[-0-9]*$'),'The tenancy ID will be the portion of the URL provided during provisioning that starts with \"rgbu-omni-\" and ends with \"-xocs\".');a=new adk;(VDc(),a.ic).style[GTk]=wWk;Xck(a,f5k,this.e);Xck(a,UUk,this.f);Xck(a,'Host',this.c);Xck(a,'Port',this.b);Xck(a,'Tenancy ID',this.d);jk(a.b,true);this.g=new HNc('Enroll with Xstore Office Cloud Service');Tj(this.g,Xel);zUc(this,this.i);zMc(this,a,this.ic);zUc(this,this.g)}\nvar TDl='enrollStores',UDl='Error : ',VDl='StoreAuthEnrollPresenter',WDl='To enroll all stores in \"',XDl='Store Enrollment';Poc(3267,1,{},$vd);_.Pe=function awd(a){Zvd(this,TI(a,29))};_.Re=function _vd(a){Jwd(this.b,a)};var KZ=Drk(Xsl,'StoreAuthorizationService_Proxy/1',3267);Poc(3268,1,{},cwd);_.Pe=function ewd(a){bwd(this,TI(a,29))};_.Re=function dwd(a){Jwd(this.b,a)};_.d=0;var LZ=Drk(Xsl,'StoreAuthorizationService_Proxy/2',3268);Poc(3269,1,{},gwd);_.Pe=function iwd(a){fwd(this,TI(a,29))};_.Re=function hwd(a){};var MZ=Drk(Xsl,'StoreAuthorizationService_Proxy/3',3269);Poc(3715,1,$Tk,ywd);_.yk=function zwd(){var a;a=new Bwd(this);OA(this.g,new U5j(this.e,a,this));eyd(this.e,xwd(this));byd(this.e,this.b.b)};_.zk=function Awd(){};_.d=0;var twd;var XZ=Drk($sl,VDl,3715);Poc(3718,1,{},Bwd);_.Ak=function Cwd(){cyd(this.a.e,false)};var RZ=Drk($sl,'StoreAuthEnrollPresenter/1',3718);Poc(3719,1,{},Dwd);_.Te=function Ewd(){if(poc(this.a.d,(ruk(),ooc(Date.now())))){ayd(this.a.e,null);return false}Svd(this.a.c,new Gwd(this));return true};var TZ=Drk($sl,'StoreAuthEnrollPresenter/2',3719);Poc(3720,1,{},Gwd);_.Pe=function Iwd(a){Fwd(this,TI(a,985))};_.Re=function Hwd(a){};var SZ=Drk($sl,'StoreAuthEnrollPresenter/2/1',3720);Poc(3721,1,{},Lwd);_.Pe=function Nwd(a){Kwd(this,XI(a))};_.Re=function Mwd(a){Jwd(this,a)};var UZ=Drk($sl,'StoreAuthEnrollPresenter/3',3721);Poc(3716,1,YTk,Owd);_.ff=function Pwd(a){wwd(this.a,false)};var VZ=Drk($sl,'StoreAuthEnrollPresenter/lambda$0$Type',3716);Poc(3717,1,YTk,Qwd);_.ff=function Rwd(a){wwd(this.a,true)};var WZ=Drk($sl,'StoreAuthEnrollPresenter/lambda$1$Type',3717);Poc(3265,1,UTk);_.Se=function lxd(){var a;a=Vxd(Xmi(this.b.a));this.a.Xk(a)};Poc(4284,FQk,GQk,fyd);_.Lk=function gyd(){return XDl};var Yxd;var m$=Drk(ctl,'StoreAuthEnrollView',4284);Poc(4287,247,{},hyd);_.Wd=function iyd(){jk(this.a.e,false)};var j$=Drk(ctl,'StoreAuthEnrollView/1',4287);Poc(4285,1,Iel,jyd);_.Yk=function kyd(){var b;try{b=Vqk(BXc(this.a));return b>0&&b<=NRk}catch(a){a=goc(a);if(ZI(a,54)){return false}else throw hoc(a)}};var k$=Drk(ctl,'StoreAuthEnrollView/ValidPortRule',4285);Poc(4286,8,qSk,myd);var l$=Drk(ctl,'StoreAuthEnrollView/XofficeCloudEnrollPanel',4286);_Mk(un)(34);\n//# sourceURL=xadmin-34.js\n")
