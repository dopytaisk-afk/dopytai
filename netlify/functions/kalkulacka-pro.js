"use strict";
// Isolated PR #11 sandbox only. Does not grant calculator access yet.
const HOST="https://deploy-preview-11--sparkly-choux-e2b050.netlify.app";
const DB="https://pwtvquyefpucjufvwnxp.supabase.co";
const PRODUCT="prod_Vh7Mahv3IGqyLt";
const PLANS={monthly:{id:"price_1Ufj87KFSmmgtcDgO5480WMu",amount:799,interval:"month"},yearly:{id:"price_1UfjBKKFSmmgtcDgmKVWsb1q",amount:7900,interval:"year"}};
const json=(statusCode,data)=>({statusCode,headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"},body:JSON.stringify(data)});
function config(){
 const key=process.env.SUPABASE_SERVICE_ROLE_KEY,stripe=process.env.STRIPE_SECRET_KEY;
 if(process.env.CONTEXT!=="deploy-preview"||String(process.env.REVIEW_ID)!=="11"||process.env.DOPYTAI_PAYMENT_ENV!=="test"||String(process.env.SUPABASE_URL||"").replace(/\/$/,"")!==DB||!key||!stripe?.startsWith("sk_test_"))throw Error("PRO sandbox configuration");
 return {key,stripe};
}
async function db(c,path,method="GET",body,prefer){
 const res=await fetch(DB+"/rest/v1/"+path,{method,headers:{apikey:c.key,Authorization:"Bearer "+c.key,"Content-Type":"application/json",...(prefer?{Prefer:prefer}:{})},...(body?{body:JSON.stringify(body)}:{})});
 if(!res.ok)throw Error("PRO DB HTTP "+res.status);
 const raw=await res.text();return raw?JSON.parse(raw):null;
}
async function stripe(c,path,params,idempotency){
 const res=await fetch("https://api.stripe.com/v1/"+path,{method:params?"POST":"GET",headers:{Authorization:"Bearer "+c.stripe,"Stripe-Version":"2025-03-31.basil",...(params?{"Content-Type":"application/x-www-form-urlencoded"}:{}),...(idempotency?{"Idempotency-Key":idempotency}:{})},...(params?{body:new URLSearchParams(params).toString()}:{})});
 const result=await res.json();
 if(!res.ok)throw Error("PRO Stripe HTTP "+res.status+" "+String(result.error?.code||""));
 if(result.livemode===true)throw Error("Unexpected live object");
 return result;
}
async function identity(c,event){
 const token=/^Bearer\s+(.+)$/i.exec(event.headers?.authorization||event.headers?.Authorization||"")?.[1];
 if(!token)return null;
 const res=await fetch(DB+"/auth/v1/user",{headers:{apikey:c.key,Authorization:"Bearer "+token}});
 if(!res.ok)return null;
 const user=await res.json();if(!user.id)return null;
 const firms=await db(c,"firmy?select=id,stav&auth_user_id=eq."+encodeURIComponent(user.id)+"&limit=2");
 if(firms.length!==1||firms[0].stav!=="aktivna")return null;
 return {id:user.id,firm:firms[0].id};
}
async function mapping(c,u,create=false){
 const query="kalkulacka_pro_customers?auth_user_id=eq."+encodeURIComponent(u.id)+"&select=*&limit=1";
 let rows=await db(c,query);
 if(!rows.length&&create){
  const customer=await stripe(c,"customers",{"metadata[dopytai_pro_user]":u.id,"metadata[firma_id]":String(u.firm)},"dopytai-pro-customer-"+u.id);
  await db(c,"kalkulacka_pro_customers?on_conflict=auth_user_id","POST",{auth_user_id:u.id,firma_id:u.firm,stripe_customer_id:customer.id},"resolution=ignore-duplicates,return=minimal");
  rows=await db(c,query);
 }
 if(rows.length&&String(rows[0].firma_id)!==String(u.firm))throw Error("PRO identity mismatch");
 return rows[0]||null;
}
async function subscriptions(c,m){
 if(!m)return [];
 const out=[];let cursor="";
 do{
  const data=await stripe(c,"subscriptions?status=all&limit=100&customer="+encodeURIComponent(m.stripe_customer_id)+(cursor?"&starting_after="+encodeURIComponent(cursor):""));
  if(!Array.isArray(data.data))throw Error("Invalid Stripe subscriptions");
  out.push(...data.data);
  cursor=data.has_more?data.data.at(-1)?.id:"";
  if(data.has_more&&!cursor)throw Error("Invalid Stripe pagination");
 }while(cursor);
 return out.filter(s=>s.livemode===false&&s.customer===m.stripe_customer_id&&s.metadata?.dopytai_pro_user===m.auth_user_id&&s.items?.data?.some(i=>Object.values(PLANS).some(p=>p.id===i.price?.id)));
}
function active(subs){
 const now=Math.floor(Date.now()/1000);
 return subs.some(s=>s.status==="active"&&!s.pause_collection&&s.items.data.some(i=>Object.values(PLANS).some(p=>p.id===i.price?.id)&&Number(i.current_period_end||s.current_period_end)>now));
}
async function hasPro(event){const c=config();const u=await identity(c,event);return u&&active(await subscriptions(c,await mapping(c,u)))?u:null;}
exports.hasPro=hasPro;
exports.handler=async event=>{
 if(event.httpMethod!=="POST")return json(405,{error:"Method not allowed"});
 try{
  const c=config();let b;try{if((event.body||"").length>4000)throw Error();b=JSON.parse(event.body||"{}")}catch{return json(400,{error:"Neplatná požiadavka"})}
  const u=await identity(c,event);if(!u)return json(401,{error:"Prihláste sa do aktívneho firemného účtu."});
  if(b.action==="status"){const m=await mapping(c,u);return json(200,{active:active(await subscriptions(c,m))})}
  if(b.action==="portal"){const m=await mapping(c,u);if(!m)return json(404,{error:"Predplatné ešte nemáte."});const portal=await stripe(c,"billing_portal/sessions",{customer:m.stripe_customer_id,return_url:HOST+"/kalkulacka.html"});return json(200,{url:portal.url})}
  if(b.action!=="checkout"||!Object.prototype.hasOwnProperty.call(PLANS,b.plan))return json(400,{error:"Neplatný plán."});
  const selected=PLANS[b.plan],price=await stripe(c,"prices/"+selected.id);
  if(price.livemode!==false||!price.active||price.product!==PRODUCT||price.currency!=="eur"||price.unit_amount!==selected.amount||price.recurring?.interval!==selected.interval||price.recurring?.interval_count!==1)throw Error("PRO price mismatch");
  const m=await mapping(c,u,true);
  const blocked=s=>!["canceled","incomplete_expired"].includes(s.status);
  if((await subscriptions(c,m)).some(blocked))return json(409,{error:"Predplatné už existuje. Spravujte ho v zákazníckom portáli."});
  const a=await db(c,"rpc/kalkulacka_pro_reserve_checkout","POST",{p_user:u.id,p_plan:b.plan});
  if(a.plan!==b.plan)return json(409,{error:"Už máte rozpracovanú platbu pre iný plán. Dokončite ju alebo počkajte na vypršanie."});
  const expiry=Math.floor(Date.parse(a.expires_at)/1000);
  if(expiry-Math.floor(Date.now()/1000)<1805)return json(409,{error:"Rozpracovaná platba čoskoro vyprší. Skúste neskôr."});
  if((await subscriptions(c,m)).some(blocked))return json(409,{error:"Predplatné už existuje."});
  const session=await stripe(c,"checkout/sessions",{mode:"subscription",customer:m.stripe_customer_id,"payment_method_types[0]":"card","line_items[0][price]":selected.id,"line_items[0][quantity]":"1",client_reference_id:u.id,"metadata[dopytai_pro_user]":u.id,"subscription_data[metadata][dopytai_pro_user]":u.id,"subscription_data[metadata][firma_id]":String(u.firm),success_url:HOST+"/kalkulacka.html?pro=success",cancel_url:HOST+"/kalkulacka.html?pro=cancel",expires_at:String(expiry)},"dopytai-pro-checkout-"+a.attempt_id);
  if(session.livemode!==false||!session.url)throw Error("Invalid checkout");
  return json(200,{url:session.url});
 }catch(e){console.error("DopytAI PRO sandbox:",e.message);return json(502,{error:"Predplatné sa nepodarilo overiť alebo pripraviť."})}
};
