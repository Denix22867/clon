(() => {
  'use strict';
  if(window.IskraCloud) return;
  const LOCAL='iskra-idle-v2', META='iskra-cloud-meta-v1', KEY='iskraSaveV1';
  let player=null, owner='', ready=false, connecting=null, writing=false, dirty=false, callback=null, lastWrite=0, status='Локальное сохранение', conflict=null;
  const read=(key)=>{try{return JSON.parse(localStorage.getItem(key));}catch(_){return null;}};
  const put=(key,value)=>{try{localStorage.setItem(key,JSON.stringify(value));return true;}catch(_){return false;}};
  const valid=s=>s&&s.version===2&&Number.isFinite(s.stage)&&s.stage>=1&&Number.isFinite(s.best)&&s.best>=1&&
    ['gold','earned','played','saved_at','stage','best','hp','boss_time','sword','gloves','amulet','shards','rebirths','kills','clicks','farm_stage','chests','flame_cd','frenzy_cd','power_left','gold_left','treasures','treasure_goal'].every(k=>s[k]===undefined||Number.isFinite(s[k]))&&
    ['allies','relics'].every(k=>Array.isArray(s[k])&&s[k].length===8&&s[k].every(v=>Number.isFinite(v)&&v>=0))&&
    (s.claimed===undefined||Array.isArray(s.claimed))&&(s.expedition===undefined||(s.expedition&&typeof s.expedition==='object'&&!Array.isArray(s.expedition)))&&JSON.stringify(s).length<150000;
  const meaningful=s=>valid(s)&&(s.tutorial_done===true||s.best>1||s.kills>0||s.rebirths>0||s.sword>1);
  const same=(a,b)=>{const copy=s=>{const c={...s};delete c.saved_at;return JSON.stringify(c);};return copy(a)===copy(b);};
  function notify(text){status=text;window.dispatchEvent(new Event('iskra-cloud-status'));}
  function deadline(p){let t;return Promise.race([p,new Promise((_,reject)=>{t=setTimeout(()=>reject(Error('timeout')),8000);})]).finally(()=>clearTimeout(t));}
  function choose(local,remote){
    return new Promise(resolve=>{
      const wasOpen=Boolean(window.IskraSocial?.getState?.().open);window.IskraPlatform?.setShopOpen(true);
      const overlay=document.createElement('section');overlay.className='social-overlay';overlay.id='iskra-cloud-choice';overlay.style.cssText='position:fixed;inset:0;z-index:2147483647;display:grid;place-items:center;padding:16px;background:#030b16eb;color:#f1e4c6;font:16px/1.5 Georgia,serif';overlay.setAttribute('role','dialog');overlay.setAttribute('aria-modal','true');
      const card=document.createElement('div');card.className='social-panel';card.style.cssText='width:min(100%,520px);max-height:90dvh;overflow:auto;padding:24px;background:#0b1d21;border:1px solid #d6b36b;border-radius:8px;box-sizing:border-box';
      const title=document.createElement('h2');title.textContent='Найдены два сохранения';card.append(title);
      const note=document.createElement('p');note.textContent='Выбери, с какого продолжить. Они не объединяются. Копии обоих останутся на этом устройстве.';card.append(note);
      const buttons=[];
      for(const [label,data,source] of [['На устройстве',local,'local'],['В Яндексе',remote,'cloud']]){
        const b=document.createElement('button');b.className='social-login';b.style.cssText='display:block;width:100%;margin-top:16px;padding:16px;background:#233b38;border:1px solid #d6b36b;border-radius:5px;color:#ffe4a0;font:inherit;cursor:pointer';b.textContent=label+' · этап '+Math.max(0,data.best-1)+' · возрождений '+(data.rebirths||0);b.onclick=()=>{overlay.remove();conflict=null;if(!wasOpen)window.IskraPlatform?.setShopOpen(false);resolve(source);};card.append(b);buttons.push(b);
      }
      overlay.append(card);document.body.append(overlay);conflict={local,remote};buttons[0].focus();
      overlay.onkeydown=e=>{if(e.key==='Tab'){e.preventDefault();buttons[document.activeElement===buttons[0]?1:0].focus();}};
    });
  }
  async function connect(explicitPlayer){
    if(connecting)return connecting;
    connecting=(async()=>{
      try{
        let sdk=window.IskraPlatform?.getSdk?.();
        if(!sdk&&window.IskraPlatform?.getState?.().mode==='yandex'){
          await deadline(window.IskraPlatform.init());sdk=window.IskraPlatform.getSdk?.();
          if(!sdk&&window.YaGames)sdk=await deadline(window.YaGames.init());
        }
        if(!sdk&&!explicitPlayer){notify('Прогресс сохранён на этом устройстве');return;}
        const next=explicitPlayer||await deadline(sdk.getPlayer());
        if(!next?.isAuthorized?.()){ready=false;notify('Войди в Яндекс для облачных сохранений');return;}
        const id=next.getUniqueID();if(ready&&owner===id)return;
        ready=false;player=next;owner=id;notify('Проверяем облачное сохранение…');
        // Never upload until a successful read: an outage must not replace a remote save.
        const result=await deadline(player.getData([KEY]));const envelope=result?.[KEY];
        if(envelope!=null&&!(envelope.schema===1&&envelope.owner===owner&&valid(envelope.data)))throw Error('invalid cloud save');
        const local=read(LOCAL),meta=read(META)||{};let selected='local';
        if(envelope){
          if(!meaningful(local)&&!(meta.owner===owner&&meta.resetAt>=(envelope.updatedAt||0)))selected='cloud';
          else if(valid(local)&&!same(local,envelope.data)){
            put('iskra-cloud-backup-local',local);put('iskra-cloud-backup-remote',envelope);
            selected=await choose(local,envelope.data);
          }
        }else if(meta.owner&&meta.owner!==owner&&meaningful(local)){
          // A save from another account requires an explicit choice; don't silently attach it.
          put('iskra-cloud-backup-local',local);
          selected=await choose(local,{version:2,stage:1,best:1,allies:Array(8).fill(0),relics:Array(8).fill(0),saved_at:Date.now()/1000});
          if(selected==='cloud')put(LOCAL,{version:2,stage:1,best:1,allies:Array(8).fill(0),relics:Array(8).fill(0),saved_at:Date.now()/1000,tutorial_done:false});
        }
        if(selected==='cloud'&&envelope){put(LOCAL,envelope.data);if(window.rpgReady)callback?.(JSON.stringify(envelope.data));}
        else if(selected==='cloud')callback?.(JSON.stringify(read(LOCAL)));
        put(META,{owner,resetAt:meta.owner===owner?meta.resetAt||0:0});ready=true;dirty=true;notify('Облачное сохранение подключено');flush();
      }catch(_){ready=false;notify('Облако недоступно. Прогресс сохранён на устройстве; повторим позже.');}
      finally{connecting=null;}
    })();return connecting;
  }
  async function flush(force=false){
    if(!ready||!player?.isAuthorized?.()||player.getUniqueID()!==owner||!dirty||writing||(!force&&Date.now()-lastWrite<30000))return;
    const data=read(LOCAL);if(!valid(data))return;
    writing=true;dirty=false;lastWrite=Date.now();notify('Сохраняем в Яндекс…');
    try{
      // Keep writes serialized even if the network is slow; no racing older saves.
      await player.setData({[KEY]:{schema:1,owner,updatedAt:Date.now(),data}},true);
      notify(dirty?'Есть новые изменения. Сохраним автоматически.':'Прогресс сохранён в Яндексе');
    }catch(_){dirty=true;notify('Не удалось сохранить в облако. Локальная копия сохранена; повторим позже.');}
    finally{writing=false;}
  }
  window.IskraCloud={
    start(cb){callback=cb;connect().finally(()=>cb(''));},
    login(p){return connect(p);},
    save(raw){try{const data=JSON.parse(raw);if(!valid(data))return;put(LOCAL,data);dirty=true;flush();}catch(_){}},
    reset(){const meta=read(META)||{};put(META,{...meta,resetAt:Date.now()});dirty=true;},
    flush(){return flush(true);},
    getState(){return {ready,dirty,writing,status,conflict:Boolean(conflict)};}
  };
  setInterval(()=>{if(ready)flush();else if(window.rpgReady)connect();},30000);
  document.addEventListener('visibilitychange',()=>{if(document.hidden&&Date.now()-lastWrite>=15000)flush(true);});
})();
