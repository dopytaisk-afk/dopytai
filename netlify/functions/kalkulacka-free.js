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
const euro=(num)=>Number(num).toLocaleString("sk-SK",{minimumFractionDigits:2,maximumFractionDigits:2})+" EUR";
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
 const dark=rgb(.08,.18,.31),blue=rgb(.03,.49,.94),soft=rgb(.42,.49,.57);
 let page=pdf.addPage([595.28,841.89]),y=794;
 const text=(val,x,yy,size=10,color=dark)=>page.drawText(String(val),{x,y:yy,size,font,color});
 const wrap=(str,maxWidth,size=10)=>{
  const words=String(str||"").replace(/\s+/g," ").split(" "),out=[];let line="";
  for(const word of words){let candidate=line?line+" "+word:word;
   if(font.widthOfTextAtSize(candidate,size)<=maxWidth){line=candidate;continue}
   if(line)out.push(line);
   line=word;
   while(font.widthOfTextAtSize(line,size)>maxWidth&&line.length>1){let n=line.length-1;while(n>1&&font.widthOfTextAtSize(line.slice(0,n),size)>maxWidth)n--;out.push(line.slice(0,n));line=line.slice(n)}
  }if(line)out.push(line);return out.slice(0,40);
 };
 const nextPage=()=>{page=pdf.addPage([595.28,841.89]);y=795};
 const paragraph=(value,size=10,before=0)=>{y-=before;for(const line of wrap(value,490,size)){if(y<75)nextPage();text(line,48,y,size);y-=size+6}};
 text("DopytAI",48,y,23,blue);text("CENOVÁ PONUKA",295,y,21,dark);y-=36;
 paragraph("Dodávateľ: "+q.company,11);if(q.ico)paragraph("IČO: "+q.ico);if(q.contact)paragraph("Kontakt: "+q.contact);
 y-=12;paragraph("Zákazník: "+q.customer);paragraph("Miesto: "+(q.place||"—"));paragraph("Predmet: "+(q.subject||"—"));paragraph("Dátum: "+(q.date||"—")+"    Platnosť do: "+(q.until||"—"));y-=10;
 page.drawLine({start:{x:48,y},end:{x:548,y},thickness:1,color:blue});y-=25;
 const totals={Práca:0,Materiál:0,Doprava:0};
 for(const [i,row] of q.rows.entries()){
  const total=Math.round(row.qty*row.price*100)/100;totals[row.type]+=total;
  paragraph((i+1)+". "+row.type+" – "+row.name,11,4);
  paragraph(row.qty+" "+row.unit+" × "+euro(row.price)+" = "+euro(total),10);
 }
 y-=15;const subtotal=totals.Práca+totals.Materiál+totals.Doprava;
 const discounted=Math.round(subtotal*(100-q.discount))/100;
 const tax=Math.round(discounted*q.vat)/100;const final=discounted+tax;
 paragraph("Práca: "+euro(totals.Práca));paragraph("Materiál: "+euro(totals.Materiál));
 paragraph("Doprava: "+euro(totals.Doprava));paragraph("Zľava: "+q.discount+" %");paragraph("DPH: "+q.vat+" %");
 paragraph("CELKOM: "+euro(final),16,12);
 if(q.terms){paragraph("Poznámky:",11,16);paragraph(q.terms,9)}
 paragraph("Vytvorené pomocou DopytAI • bezplatná skúšobná ponuka",8,18);
 return Buffer.from(await pdf.save()).toString("base64");
}
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{error:"Method not allowed"});
 const cfg=config(event);if(cfg.error)return json(503,{error:cfg.error});
 let body;try{if((event.body||"").length>45000)throw Error();body=JSON.parse(event.body||"{}")}catch{return json(400,{error:"Neplatné údaje"})}
 if(body.action==="request"){
  const email=validEmail(body.email);if(!email)return json(400,{error:"Zadajte platnú e-mailovú adresu"});
  let quote;try{quote=parseQuote(body.quote)}catch(e){return json(400,{error:e.message})}
  const emailHash=hash(email,cfg.secret);const ip=trim(event.headers?.["x-nf-client-connection-ip"]||"",70);
  const ipHash=ip?hash(ip,cfg.secret):null;
  try{
   const used=await db(cfg,"kalkulacka_free_used?select=email_hash&email_hash=eq."+emailHash+"&limit=1");
   if(used.length)return json(409,{error:"Na túto adresu už bola bezplatná ponuka využitá. Pokračujte registráciou."});
   const from=new Date(Date.now()-24*3600*1000).toISOString();
   const recent=await db(cfg,"kalkulacka_free_challenges?select=id&email_hash=eq."+emailHash+"&created_at=gte."+encodeURIComponent(from)+"&limit=4");
   if(recent.length>=3)return json(429,{error:"Dosiahnutý denný limit overovacích e-mailov."});
   if(ipHash){
    const many=await db(cfg,"kalkulacka_free_challenges?select=id&ip_hash=eq."+ipHash+"&created_at=gte."+encodeURIComponent(from)+"&limit=13");
    if(many.length>=12)return json(429,{error:"Príliš veľa požiadaviek. Skúste to neskôr."});
   }
   const id=crypto.randomUUID(),token=crypto.randomBytes(32).toString("hex");
   await db(cfg,"kalkulacka_free_challenges",{method:"POST",body:JSON.stringify({id,email_hash:emailHash,ip_hash:ipHash,token_hash:hash(token,cfg.secret),quote_payload:quote,expires_at:new Date(Date.now()+30*60000).toISOString()})});
   const link="https://"+HOST+"/kalkulacka-overenie.html?id="+encodeURIComponent(id)+"&token="+encodeURIComponent(token);
   const r=await fetch("https://api.resend.com/emails",{method:"POST",headers:{Authorization:"Bearer "+process.env.RESEND_API_KEY,"Content-Type":"application/json"},body:JSON.stringify({from:"DopytAI <info@dopytai24.sk>",to:[email],subject:"DopytAI – overenie bezplatnej cenovej ponuky",html:'<div style="font-family:Arial;padding:24px"><h2>DopytAI – vaša cenová ponuka</h2><p>Overte svoju adresu a stiahnite si jednu bezplatnú ponuku PDF.</p><p><a href="'+esc(link)+'" style="background:#087cf0;color:#fff;padding:14px;text-decoration:none;border-radius:8px">Overiť e-mail a získať PDF</a></p><p>Odkaz je platný 30 minút. Ak ste o ponuku nežiadali, e-mail ignorujte.</p></div>'})});
   if(!r.ok)return json(502,{error:"Overovací e-mail sa nepodarilo odoslať. Skúste to neskôr."});
   return json(200,{ok:true,message:"Poslali sme overovací odkaz na váš e-mail."});
  }catch(e){console.error("Anonymous quote request failed",e.message);return json(502,{error:"Overovanie sa nepodarilo. Skúste to neskôr."})}
 }
 if(body.action==="redeem"){
  const id=trim(body.id,40),token=trim(body.token,100);
  if(!/^[a-f0-9-]{36}$/i.test(id)||!/^[a-f0-9]{64}$/i.test(token))return json(400,{error:"Neplatný odkaz."});
  try{
   const ch=await db(cfg,"kalkulacka_free_challenges?select=quote_payload,claimed_at,expires_at&token_hash=eq."+hash(token,cfg.secret)+"&id=eq."+encodeURIComponent(id)+"&limit=1");
   if(ch.length!==1||ch[0].claimed_at||Date.parse(ch[0].expires_at)<Date.now())return json(410,{error:"Odkaz už bol použitý alebo jeho platnosť vypršala."});
   const pdf=await makePdf(parseQuote(ch[0].quote_payload));
   const result=await db(cfg,"rpc/kalkulacka_claim_free_pdf",{method:"POST",body:JSON.stringify({p_challenge_id:id,p_token_hash:hash(token,cfg.secret)})});
   if(!result)return json(409,{error:"Bezplatná ponuka už bola využitá. Pre ďalšie ponuky sa zaregistrujte."});
   return json(200,{ok:true,pdf,filename:"DopytAI-cenova-ponuka.pdf"});
  }catch(e){console.error("Anonymous quote redemption failed",e.message);return json(502,{error:"PDF sa nepodarilo vytvoriť. Skúste to neskôr."})}
 }
 return json(400,{error:"Neznáma požiadavka"});
};