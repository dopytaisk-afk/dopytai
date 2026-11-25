"use strict";
const crypto=require("node:crypto");
const fs=require("node:fs");
const path=require("node:path");
const {PDFDocument,rgb}=require("pdf-lib");
const fontkit=require("@pdf-lib/fontkit");
const HOST="deploy-preview-11--sparkly-choux-e2b050.netlify.app";
const TEST_SUPABASE="https://pwtvquyefpucjufvwnxp.supabase.co";
const json=(statusCode,data)=>({statusCode,headers:{"content-type":"application/json; charset=utf-8","cache-control":"no-store","x-content-type-options":"nosniff"},body:JSON.stringify(data)});
const hash=(text,key)=>crypto.createHmac("sha256",key).update(text).digest("hex");
const trim=(v,max=160)=>typeof v==="string"?v.trim().slice(0,max):"";
const esc=(s)=>String(s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
const euro=(num)=>Number(num).toLocaleString("sk-SK",{minimumFractionDigits:2,maximumFractionDigits:2})+" €";
const date=(s)=>/^\d{4}-\d{2}-\d{2}$/.test(s||"")?s:"";
const validEmail=(raw)=>{const s=trim(raw,254).toLowerCase();return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s)?s:""};
function parseQuote(value){
 if(!value||typeof value!=="object"||Array.isArray(value))throw Error("Neplatná ponuka");
 const fields={};
 for(const [key,len] of Object.entries({company:140,ico:16,contact:260,customer:140,place:160,subject:400,offerNo:50,terms:600}))fields[key]=trim(value[key],len);
 fields.date=date(value.date);fields.until=date(value.until);
 const source=value.rows;if(!Array.isArray(source)||source.length<1||source.length>80)throw Error("Ponuka musí obsahovať 1 až 80 položiek");
 fields.rows=source.map(row=>{
  if(!row||!["Práca","Materiál","Doprava"].includes(row.type))throw Error("Neplatný typ položky");
  const name=trim(row.name,160),unit=trim(row.unit,16),qty=Number(row.qty),price=Number(row.price);
  if(!name||!unit||!Number.isFinite(qty)||!Number.isFinite(price)||qty<=0||qty>1000000||price<0||price>1000000)throw Error("Neplatné množstvo alebo cena");
  return {type:row.type,name,unit,qty,price};
 });
 fields.discount=Number(value.discount)||0;fields.vat=Number(value.vat)||0;
 if(fields.discount<0||fields.discount>100||![0,5,10,19,20,23].includes(fields.vat))throw Error("Neplatná DPH alebo zľava");
 if(!fields.customer||!fields.company)throw Error("Vyplňte zákazníka aj dodávateľa");
 if(JSON.stringify(fields).length>35000)throw Error("Ponuka je príliš veľká");
 if(value.logo){
  if(typeof value.logo!=="string"||value.logo.length>80000||!/^data:image\/jpeg;base64,[A-Za-z0-9+/]+={0,2}$/.test(value.logo))throw Error("Neplatné logo");
  const bytes=Buffer.from(value.logo.split(",")[1],"base64");
  if(bytes[0]!==255||bytes[1]!==216)throw Error("Neplatné logo");
  fields.logo=value.logo;
 }
 return fields;
}
function config(event){
 // Netlify Functions may receive an internal Host header; do not use it as a deploy identity.
 // Check trusted deployment metadata when present, and require preview-scoped secrets and TEST DB below.
 const context=process.env.CONTEXT;
 const branch=process.env.BRANCH;
 const review=process.env.REVIEW_ID;
 const prime=process.env.DEPLOY_PRIME_URL;
 if(context && context!=="deploy-preview"){
  return {error:"Server nebeží v Netlify Deploy Preview. Produkcia nemá prístup k bezplatnému PDF."};
 }
 if(review && String(review)!=="11"){
  return {error:"Toto je iný testovací PR, nie PR #11."};
 }
 if(branch && branch!=="feature/kalkulacka-ponuk"){
  return {error:"Táto funkcia patrí testovacej vetve kalkulačky."};
 }
 if(prime){
  let primeHost="";
  try{primeHost=new URL(prime).hostname.toLowerCase()}catch(_){}
  if(primeHost!==HOST)return {error:"Netlify nezodpovedá testovaciemu náhľadu PR #11."};
 }
 const url=String(process.env.SUPABASE_URL||"").replace(/\/$/,"");
 if(url!==TEST_SUPABASE){
  return {error:"TEST konfigurácia: SUPABASE_URL nesmeruje na projekt DopytAI-TEST. PDF nebolo odoslané."};
 }
 const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
 const secret=process.env.DOPYTAI_KALKULACKA_FREE_SECRET;
 const missing=[];
 if(!key)missing.push("SUPABASE_SERVICE_ROLE_KEY");
 if(!secret||secret.length<32)missing.push("DOPYTAI_KALKULACKA_FREE_SECRET");
 if(!process.env.RESEND_API_KEY)missing.push("RESEND_API_KEY");
 if(missing.length){
  return {error:"V TEST nasadení chýba nastavenie: "+missing.join(", ")+". Neodosielajte žiadne tajné hodnoty do chatu."};
 }
 return {url,key,secret};
}
async function db(cfg,endpoint,options={}){
 const r=await fetch(cfg.url+"/rest/v1/"+endpoint,{...options,headers:{apikey:cfg.key,Authorization:"Bearer "+cfg.key,"Content-Type":"application/json",...(options.headers||{})}});
 if(!r.ok){
  // Log only the database error code, request target and status; never tokens, payloads or key material.
  let code="unknown";
  try{const error=await r.json();code=String(error.code||error.error_code||"unknown").slice(0,50)}catch(_){}
  const target=String(endpoint).split("?")[0];
  console.error("Anonymous quote Supabase request denied",{target,status:r.status,code});
  throw new Error("DB HTTP "+r.status+" ("+target+", "+code+")");
 }
 const txt=await r.text();return txt?JSON.parse(txt):null;
}
async function makePdf(q){
 const pdf=await PDFDocument.create();pdf.registerFontkit(fontkit);
 const font=await pdf.embedFont(fs.readFileSync(path.join(__dirname,"Roboto-Regular.ttf")),{subset:true});
 const navy=rgb(16/255,46/255,82/255),lime=rgb(181/255,223/255,35/255),pale=rgb(242/255,246/255,250/255),muted=rgb(.35,.45,.55),white=rgb(1,1,1);
 const W=595.28,H=841.89,L=43,R=W-L,C=R-L;
 let page=pdf.addPage([W,H]),y=H-43;
 const width=(s,z)=>font.widthOfTextAtSize(String(s),z);
 const text=(s,x,t,z=10,color=navy,strong=false)=>{const opts={x,y:t-z,size:z,font,color};page.drawText(String(s),opts);if(strong)page.drawText(String(s),{...opts,x:x+0.32})};
 const right=(s,x,t,z=10,color=navy,strong=false)=>text(s,x-width(s,z)-(strong?0.32:0),t,z,color,strong);
 const rect=(x,t,w,h,color)=>page.drawRectangle({x,y:t-h,width:w,height:h,color});
 const wrap=(s,w,z=10)=>{
  const out=[];for(const para of String(s||"—").split(/\r?\n/)){let line="";
   for(const word of para.split(/\s+/)){let v=line?line+" "+word:word;
    if(width(v,z)<=w){line=v;continue}if(line)out.push(line);line=word;
    while(width(line,z)>w&&line.length>1){let n=line.length-1;while(n>1&&width(line.slice(0,n),z)>w)n--;out.push(line.slice(0,n));line=line.slice(n)}
   }out.push(line);
  }return out;
 };
 const lines=(a,x,t,z=10,color=navy)=>{for(const s of a){text(s,x,t,z,color);t-=z+4}return t};
 const footer=()=>{rect(L,48,C,1,pale);text("Cenová ponuka bola vytvorená pomocou DopytAI.",L,39,8,muted);right(String(pdf.getPageCount()),R,39,8,muted)};
 const next=()=>{footer();page=pdf.addPage([W,H]);y=H-43};
 const ensure=h=>{if(y-h<65)next()};
 const section=s=>{ensure(30);text(s,L,y,12,navy,true);y-=23};
 const paragraph=s=>{for(const line of wrap(s,C,10)){ensure(15);text(line,L,y);y-=14}y-=10};
 const dateSK=s=>s?s.split("-").reverse().join(". "):"—";
 let left=y;
 if(q.logo){const img=await pdf.embedJpg(Uint8Array.from(Buffer.from(q.logo.split(",")[1],"base64")));if(img.width>420||img.height>220)throw Error("Logo má neplatné rozmery");const d=img.scale(Math.min(1,112/img.width,57/img.height));page.drawImage(img,{x:L,y:left-d.height,width:d.width,height:d.height});left-=d.height+10}
 text("DODÁVATEĽ",L,left,8,muted);left-=15;
 left=lines(wrap(q.company,245,17),L,left,17);
 if(q.ico)left=lines(wrap("IČO: "+q.ico,245),L,left);
 if(q.contact)left=lines(wrap(q.contact,245),L,left);
 const mx=R-218;right("Cenová ponuka",R,y,23,navy,true);let mt=y-37;
 for(const [k,v] of [["Číslo",q.offerNo||"—"],["Dátum",dateSK(q.date)],["Platnosť do",dateSK(q.until)]]){
  const a=wrap(v,130,9),h=Math.max(24,a.length*13+10);rect(mx,mt,218,h-1,pale);text(k,mx+9,mt-6,9,muted);lines(a,mx+82,mt-6,9);mt-=h;
 }
 y=Math.min(left,mt)-12;rect(L,y,C,4,lime);y-=24;
 const pw=(C-14)/2,a=wrap(q.customer,pw-24,11),b=wrap(q.place,pw-24,11),ph=Math.max(67,34+Math.max(a.length,b.length)*15);
 ensure(ph+15);
 for(const [x,k,v] of [[L,"ODBERATEĽ",a],[L+pw+14,"MIESTO REALIZÁCIE",b]]){rect(x,y,pw,ph,pale);rect(x,y,4,ph,lime);text(k,x+12,y-11,8,muted);lines(v,x+12,y-28,11)}
 y-=ph+22;section("Predmet ponuky");paragraph(q.subject);section("Položkový rozpočet");
 const cols=[25,65,151,62,43,82,C-428],xs=[L];for(const w of cols)xs.push(xs[xs.length-1]+w);
 const header=()=>{rect(L,y,C,27,navy);["Č.","Typ","Položka","Množstvo","MJ","Jedn. cena","Spolu"].forEach((s,i)=>i>=5?right(s,xs[i+1]-6,y-8,8,white):text(s,xs[i]+5,y-8,8,white));y-=27};
 ensure(55);header();
 const totals={Práca:0,Materiál:0,Doprava:0};
 for(const [i,row] of q.rows.entries()){
  const total=Math.round(row.qty*row.price*100)/100;totals[row.type]+=total;
  const cells=[String(i+1),row.type,row.name,String(row.qty),row.unit,euro(row.price),euro(total)].map((s,k)=>wrap(s,cols[k]-10,8.5));
  const h=Math.max(27,Math.max(...cells.map(a=>a.length))*12.5+12);
  if(y-h<65){next();header()}
  if(i%2===1)rect(L,y,C,h,pale);
  cells.forEach((a,k)=>a.forEach((s,n)=>k>=5?right(s,xs[k+1]-5,y-6-n*12.5,8.5):text(s,xs[k]+5,y-6-n*12.5,8.5)));
  y-=h;rect(L,y,C,.5,pale);
 }
 y-=17;ensure(177);
 const subtotal=totals.Práca+totals.Materiál+totals.Doprava;
 const discounted=Math.round(subtotal*(100-q.discount))/100;
 const tax=Math.round(discounted*q.vat)/100,final=discounted+tax;
 const tx=R-278;rect(tx,y,278,173,pale);
 for(const [k,v] of [["Práca",totals.Práca],["Materiál",totals.Materiál],["Doprava",totals.Doprava],["Zľava ("+q.discount+" %)",subtotal-discounted],["DPH ("+q.vat+" %)",tax]]){text(k,tx+12,y-8,10);right(euro(v),R-12,y-8,10);y-=25}
 rect(tx,y,278,48,navy);rect(tx,y,6,48,lime);text("Celkom",tx+15,y-15,13,white,true);right(euro(final),R-12,y-14,14,white,true);y-=70;
 section("Poznámky a podmienky");paragraph(q.terms);footer();
 return Buffer.from(await pdf.save()).toString("base64");
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{error:"Method not allowed"});
 const cfg=config(event);if(cfg.error)return json(503,{error:cfg.error});
 let body;try{if((event.body||"").length>125000)throw Error();body=JSON.parse(event.body||"{}")}catch{return json(400,{error:"Neplatné údaje"})}
 if(body.action==="pro_pdf"){
  try{
   const u=await require("./kalkulacka-pro").hasPro(event);
   if(!u)return json(403,{error:"Na neobmedzené PDF potrebujete aktívne predplatné PRO."});
   const q=parseQuote(body.quote);
   if(!q.offerNo)q.offerNo="PDF-"+(q.date||new Date().toISOString().slice(0,10)).replace(/-/g,"")+"-"+crypto.randomUUID().replace(/-/g,"").slice(0,16).toUpperCase();
   return json(200,{ok:true,pdf:await makePdf(q),filename:"DopytAI-cenova-ponuka.pdf"});
  }catch(e){console.error("PRO PDF failed",e.message);return json(502,{error:"PDF alebo predplatné sa nepodarilo overiť."})}
 }
 if(body.action==="request"){
  const email=validEmail(body.email);if(!email)return json(400,{error:"Zadajte platnú e-mailovú adresu"});
  let quote;try{quote=parseQuote(body.quote)}catch(e){return json(400,{error:e.message})}
  const emailHash=hash(email,cfg.secret);const ip=trim(event.headers?.["x-nf-client-connection-ip"]||"",70);
  const ipHash=ip?hash(ip,cfg.secret):null;
  try{
   const used=await db(cfg,"kalkulacka_free_used?select=challenge_id&email_hash=eq."+emailHash+"&limit=3");
   if(used.length>=3)return json(409,{error:"Všetky 3 bezplatné PDF na tento e-mail sú využité. Pre ďalšie ponuky sa zaregistrujte a vyberte predplatné."});
   const from=new Date(Date.now()-24*3600*1000).toISOString();
   const recent=await db(cfg,"kalkulacka_free_challenges?select=id&email_hash=eq."+emailHash+"&created_at=gte."+encodeURIComponent(from)+"&limit=7");
   if(recent.length>=6)return json(429,{error:"Dosiahnutý denný limit overovacích e-mailov. Skúste to zajtra."});
   if(ipHash){
    const many=await db(cfg,"kalkulacka_free_challenges?select=id&ip_hash=eq."+ipHash+"&created_at=gte."+encodeURIComponent(from)+"&limit=13");
    if(many.length>=12)return json(429,{error:"Príliš veľa požiadaviek. Skúste to neskôr."});
   }
   const id=crypto.randomUUID(),token=crypto.randomBytes(32).toString("hex");
   await db(cfg,"kalkulacka_free_challenges",{method:"POST",body:JSON.stringify({id,email_hash:emailHash,ip_hash:ipHash,token_hash:hash(token,cfg.secret),quote_payload:quote,expires_at:new Date(Date.now()+30*60000).toISOString()})});
   const link="https://"+HOST+"/kalkulacka-overenie.html?id="+encodeURIComponent(id)+"&token="+encodeURIComponent(token);
   const r=await fetch("https://api.resend.com/emails",{method:"POST",headers:{Authorization:"Bearer "+process.env.RESEND_API_KEY,"Content-Type":"application/json"},body:JSON.stringify({from:"DopytAI <info@dopytai24.sk>",to:[email],subject:"DopytAI – overenie bezplatnej cenovej ponuky",html:'<div style="font-family:Arial;padding:24px"><h2>DopytAI – vaša cenová ponuka</h2><p>Overte e-mail a získajte jednu z troch bezplatných cenových ponúk PDF.</p><p><a href="'+esc(link)+'" style="background:#087cf0;color:#fff;padding:14px;text-decoration:none;border-radius:8px">Overiť e-mail a získať PDF</a></p><p>Odkaz je platný 30 minút. Ak ste o ponuku nežiadali, e-mail ignorujte.</p></div>'})});
   if(!r.ok)return json(502,{error:"Overovací e-mail sa nepodarilo odoslať. Skúste to neskôr."});
   return json(200,{ok:true,message:"Poslali sme overovací odkaz na váš e-mail. Už využitých PDF: "+used.length+" z 3."});
  }catch(e){console.error("Anonymous quote request failed",e.message);return json(502,{error:"Overovanie sa nepodarilo. Skúste to neskôr."})}
 }
 if(body.action==="redeem"){
  const id=trim(body.id,40),token=trim(body.token,100);
  if(!/^[a-f0-9-]{36}$/i.test(id)||!/^[a-f0-9]{64}$/i.test(token))return json(400,{error:"Neplatný odkaz."});
  try{
   const ch=await db(cfg,"kalkulacka_free_challenges?select=quote_payload,claimed_at,expires_at&token_hash=eq."+hash(token,cfg.secret)+"&id=eq."+encodeURIComponent(id)+"&limit=1");
   if(ch.length!==1||ch[0].claimed_at||Date.parse(ch[0].expires_at)<Date.now())return json(410,{error:"Odkaz už bol použitý alebo jeho platnosť vypršala."});
   const quote=parseQuote(ch[0].quote_payload);
   // Stable reference for anonymous PDFs only; saved company numbering remains untouched.
   if(!quote.offerNo)quote.offerNo="PDF-"+(quote.date||new Date().toISOString().slice(0,10)).replace(/-/g,"")+"-"+id.replace(/-/g,"").slice(0,16).toUpperCase();
   const pdf=await makePdf(quote);
   const result=await db(cfg,"rpc/kalkulacka_claim_free_pdf",{method:"POST",body:JSON.stringify({p_challenge_id:id,p_token_hash:hash(token,cfg.secret)})});
   if(!result)return json(409,{error:"Odkaz už bol použitý alebo boli vyčerpané 3 bezplatné PDF na tento e-mail. Ďalšie ponuky získate po registrácii a predplatnom."});
   return json(200,{ok:true,pdf,filename:"DopytAI-cenova-ponuka.pdf"});
  }catch(e){console.error("Anonymous quote redemption failed",e.message);return json(502,{error:"PDF sa nepodarilo vytvoriť. Skúste to neskôr."})}
 }
 return json(400,{error:"Neznáma požiadavka"});
};