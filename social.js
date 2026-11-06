(() => {
  'use strict';
  if (window.IskraSocial?.version==='1.0.3') return;
  window.IskraSocial?.close?.();
  document.querySelector('.social-overlay#iskra-shop')?.remove();
  const BOARD = 'iskrastage';
  const HEROES = ['Искра','Ледяная чародейка','Лесная охотница','Рыцарь рассвета','Страж грозы','Хранительница душ','Драконий рыцарь'];
  let sdk=null, player=null, connected=false, connecting=null, panel=null, content=null, status=null;
  let view='profile', selected=null, rows=[], own=null, loading=false, sending=false, authBusy=false;
  let fetched=false, lastFetch=-Infinity, lastSend=-Infinity, lastConnect=-Infinity, knownScore=0, notice='';
  const number=(v,max=Number.MAX_SAFE_INTEGER)=>Number.isFinite(Number(v))?Math.max(0,Math.min(max,Math.floor(Number(v)))):0;
  const authorized=()=>Boolean(player?.isAuthorized?.());
  const snapshot=()=>window.rpgState||{};
  function deadline(promise) {let timer;return Promise.race([promise,new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error('SDK request timeout')),8000);})]).finally(()=>clearTimeout(timer));}
  function info(s=snapshot()) {
    return {v:1,hero:number(s.hero_id,6),heroes:Array.isArray(s.owned_heroes)?s.owned_heroes.filter(x=>x===true).length:1,
      relics:Array.isArray(s.relics)?s.relics.filter(x=>number(x)>0).length:0,
      rebirths:number(s.rebirths),kills:number(s.kills),expeditions:Array.isArray(s.expedition?.cleared)?s.expedition.cleared.filter(x=>x===true).length:0};
  }
  function details(raw) {
    try {if(typeof raw!=='string'||raw.length>1000)return null;const p=JSON.parse(raw);if(p?.v!==1)return null;return {hero:number(p.hero,6),heroes:number(p.heroes,7),relics:number(p.relics,8),rebirths:number(p.rebirths),kills:number(p.kills),expeditions:number(p.expeditions,3)};}catch(_){return null;}
  }
  function element(tag,text,className) {const e=document.createElement(tag);if(text!==undefined)e.textContent=String(text);if(className)e.className=className;return e;}
  function button(text,action,className) {const e=element('button',text,className);e.type='button';e.onclick=action;return e;}
  function avatar(url,name) {
    const wrap=element('span',(name||'И').slice(0,1).toUpperCase(),'social-avatar');
    try {const u=new URL(url);if(u.protocol==='https:'){const img=element('img');img.src=u.href;img.alt='';img.referrerPolicy='no-referrer';img.onerror=()=>img.remove();wrap.append(img);}}catch(_){}
    return wrap;
  }
  function entry(e) {
    const p=e?.player||{};let photo='';try{photo=p.getAvatarSrc?.('medium')||'';}catch(_){}
    return {rank:number(e?.rank),score:number(e?.score),id:typeof p.uniqueID==='string'?p.uniqueID:'',name:typeof p.publicName==='string'&&p.publicName?p.publicName.slice(0,100):'Пользователь скрыт',photo,info:details(e?.extraData)};
  }
  function problem(e) {
    if(e?.code==='LEADERBOARD_PLAYER_NOT_PRESENT')return '';
    if(e?.status===404||e?.code===404||/404|not found/i.test(e?.message||''))return 'Рейтинг ещё подключается. Попробуй позже.';
    return 'Не удалось связаться с Яндексом. Играть можно дальше; попробуй ещё раз позже.';
  }
  async function available(name) {return Boolean(sdk?.isAvailableMethod&&await deadline(sdk.isAvailableMethod(name)));}
  async function ownEntry() {
    if(!authorized()||!await available('leaderboards.getPlayerEntry')){own=null;return;}
    try {own=entry(await deadline(sdk.leaderboards.getPlayerEntry(BOARD)));knownScore=Math.max(knownScore,own.score);}
    catch(e){if(e?.code==='LEADERBOARD_PLAYER_NOT_PRESENT'){own=null;return;}throw e;}
  }
  async function connect() {
    if(connected)return;
    if(connecting)return connecting;
    if(Date.now()-lastConnect<20000)return;
    lastConnect=Date.now();
    connecting=(async()=>{
      sdk=window.IskraPlatform?.getSdk?.()||null;
      // Old ZIP shells already loaded the official SDK. Reuse it once if needed.
      if(!sdk&&window.YaGames&&window.IskraPlatform?.getState?.().mode==='yandex')sdk=await deadline(window.YaGames.init());
      if(!sdk){notice='Рейтинг и профиль Яндекса доступны при запуске на Яндекс Играх.';return;}
      player=await deadline(sdk.getPlayer());await ownEntry();connected=true;
    })().catch(e=>{notice=problem(e);}).finally(()=>{connecting=null;render();});
    return connecting;
  }
  async function submit() {
    if(sending||!connected||!authorized()||window.IskraGuard?.getState?.().warning)return;
    const score=number(snapshot().best)-1;
    if(score<=knownScore||Date.now()-lastSend<20000)return;
    sending=true;lastSend=Date.now();
    try {
      if(!await available('leaderboards.setScore'))return;
      await deadline(sdk.leaderboards.setScore(BOARD,score,JSON.stringify(info())));knownScore=score;await ownEntry();
      notice='Рекорд сохранён в рейтинге.';
    }catch(e){notice=problem(e);}finally{sending=false;render();}
  }
  async function fetchBoard() {
    if(loading)return;
    if(Date.now()-lastFetch<20000){notice='Рейтинг обновляется не чаще раза в 20 секунд.';render();return;}
    await connect();if(!sdk?.leaderboards){render();return;}
    loading=true;lastFetch=Date.now();notice='Загружаем рейтинг…';render();
    try {
      const result=await deadline(sdk.leaderboards.getEntries(BOARD,{quantityTop:20,includeUser:authorized(),quantityAround:3}));
      rows=(Array.isArray(result.entries)?result.entries:[]).map(entry).sort((a,b)=>a.rank-b.rank);fetched=true;
      await ownEntry();notice='Рекорд — последний побеждённый этап. Добыча золота не повышает рейтинг.';
    }catch(e){notice=problem(e);}finally{loading=false;render();}
  }
  async function login() {
    if(authBusy)return;authBusy=true;render();
    try {await connect();if(!sdk?.auth)return;await sdk.auth.openAuthDialog();player=await deadline(sdk.getPlayer());await window.IskraCloud?.login(player);knownScore=0;own=null;await ownEntry();connected=true;notice=authorized()?'Ты вошёл в Яндекс. Рекорды будут сохраняться.':'Вход не завершён. Можно продолжать играть гостем.';await submit();}
    catch(_){notice='Вход отменён или недоступен. Можно продолжать играть гостем.';}
    finally {authBusy=false;render();}
  }
  function build() {
    if(panel)return;
    panel=element('section',undefined,'social-overlay');panel.id='iskra-shop';panel.hidden=true;
    panel.setAttribute('role','dialog');panel.setAttribute('aria-modal','true');panel.setAttribute('aria-labelledby','social-title');
    const card=element('div',undefined,'social-panel'),head=element('header');
    const title=element('h1','Герои Искры');title.id='social-title';head.append(title,button('×',close,'social-close'));card.append(head);
    const tabs=element('nav',undefined,'social-tabs');tabs.setAttribute('aria-label','Профиль и рейтинг');
    tabs.append(button('Мой профиль',()=>{view='profile';selected=null;render();},'social-profile-tab'),button('Лучшие герои',()=>{view='rating';selected=null;render();if(!fetched)fetchBoard();},'social-rating-tab'));card.append(tabs);
    content=element('div',undefined,'social-content');status=element('p',undefined,'social-status');status.setAttribute('role','status');status.setAttribute('aria-live','polite');card.append(content,status);panel.append(card);document.body.append(panel);
    panel.addEventListener('keydown',event=>{
      if(event.key==='Escape'){event.preventDefault();close();}
      if(event.key==='Tab'){const items=[...panel.querySelectorAll('button:not(:disabled)')];const first=items[0],last=items.at(-1);if(event.shiftKey&&document.activeElement===first){event.preventDefault();last?.focus();}else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first?.focus();}}
    });
  }
  function stats(parent,score,p,rank) {
    const grid=element('div',undefined,'social-stats');
    for(const [label,value] of [['Пройденный этап',score],['Место в рейтинге',rank?'#'+rank:'Пока нет'],['Героев открыто',p.heroes+' / 7'],['Реликвий найдено',p.relics+' / 8'],['Возрождения',p.rebirths],['Экспедиции',p.expeditions+' / 3']]){
      const item=element('div');item.append(element('strong',value),element('span',label));grid.append(item);
    }parent.append(grid);
  }
  function achievements(parent,p,score) {
    const items=[['Первый босс',score>=10],['За горизонтом',score>=100],['Полный отряд героев',p.heroes===7],['Сердце леса',p.expeditions>0],['Новая жизнь',p.rebirths>0]];
    parent.append(element('h2','Достижения'));const list=element('div',undefined,'social-achievements');
    for(const [label,done] of items)list.append(element('span',(done?'◆ ':'◇ ')+label,done?'earned':'locked'));parent.append(list);
  }
  function render() {
    if(!panel||panel.hidden)return;
    const focusClass=document.activeElement?.className;
    content.replaceChildren();panel.querySelector('.social-profile-tab').setAttribute('aria-pressed',String(view==='profile'));panel.querySelector('.social-rating-tab').setAttribute('aria-pressed',String(view==='rating'));status.textContent=notice;
    if(selected){
      content.append(button('← Назад к рейтингу',()=>{selected=null;render();},'social-back'));
      const head=element('div',undefined,'social-identity');head.append(avatar(selected.photo,selected.name),element('h2',selected.name));content.append(head);
      content.append(element('p','Рекорд: этап '+selected.score+' · место #'+selected.rank));
      if(selected.info){content.append(element('p','Герой: '+HEROES[selected.info.hero]));stats(content,selected.score,selected.info,selected.rank);achievements(content,selected.info,selected.score);}
      content.append(element('p','Сведения на момент сохранения рекорда.','social-muted'));return;
    }
    if(view==='profile'){
      let name='Путешественник',photo='';if(authorized()){try{name=player.getName()||'Игрок Яндекса';photo=player.getPhoto('medium')||'';}catch(_){name='Игрок Яндекса';}}
      const head=element('div',undefined,'social-identity');head.append(avatar(photo,name),element('h2',name));content.append(head);
      content.append(element('p','Герой: '+HEROES[number(snapshot().hero_id,6)],'social-muted'));
      const p=info(),score=Math.max(number(snapshot().best)-1,knownScore,0);stats(content,score,p,own?.rank);achievements(content,p,score);
      if(!authorized()){
        content.append(element('p','Войди в Яндекс, чтобы участвовать в рейтинге и показывать имя и аватар. Вход добровольный.','social-muted'));
        const b=button(authBusy?'Входим…':'Войти в Яндекс',login,'social-login');b.disabled=authBusy||!sdk;content.append(b);
      }else content.append(element('p','Рекорд хранится в Яндексе. Прогресс, снаряжение и текущий поход синхронизируются через облачные сохранения.','social-muted'));
      const cloud=element('p',window.IskraCloud?.getState().status||'Прогресс сохранён на устройстве','social-muted');cloud.id='social-cloud-status';cloud.setAttribute('role','status');content.append(cloud);
      if(authorized()){const b=button('Сохранить в облако',()=>window.IskraCloud?.flush(),'social-cloud-save');b.disabled=!window.IskraCloud?.getState().ready;content.append(b);}
    }else{
      const subtitle=element('div',undefined,'social-rating-head');subtitle.append(element('p',own?.rank?'Твоё место: #'+own.rank:'Лучшие результаты и ближайшие соперники'));
      const refresh=button(loading?'Загружаем…':'Обновить',fetchBoard,'social-refresh');refresh.disabled=loading;subtitle.append(refresh);content.append(subtitle);
      const list=element('div',undefined,'social-ranking');
      for(const row of rows){const b=button('',()=>{selected=row;render();},'social-row');b.append(element('span','#'+row.rank,'social-rank'),avatar(row.photo,row.name),element('span',row.name,'social-name'),element('strong','Этап '+row.score));if(row.id&&row.id===player?.getUniqueID?.())b.classList.add('social-own');list.append(b);}content.append(list);
      if(!rows.length)content.append(element('p',loading?'Загружаем героев…':fetched?'Рейтинг пока пуст. Победи первого противника и войди в Яндекс, чтобы оставить рекорд.':'Нажми «Обновить», чтобы загрузить рейтинг.','social-empty'));
    }
    if(typeof focusClass==='string'&&['social-profile-tab','social-rating-tab'].includes(focusClass))panel.querySelector('.'+focusClass)?.focus();
  }
  async function open(tab='profile') {
    build();view=tab==='rating'?'rating':'profile';selected=null;panel.hidden=false;
    window.IskraPlatform?.setShopOpen(true);render();panel.querySelector('.social-close').focus();
    await connect();await submit();if(view==='rating'&&!fetched)await fetchBoard();render();
  }
  function close() {if(panel)panel.hidden=true;window.IskraPlatform?.setShopOpen(false);if(!window.IskraPlatform?.isPaused())document.getElementById('canvas')?.focus();}
  setInterval(()=>{if(!window.rpgReady||!window.IskraPlatform?.getState?.().ready)return;connect().then(submit);},20000);
  window.addEventListener('iskra-cloud-status',()=>{const e=document.getElementById('social-cloud-status');if(e)e.textContent=window.IskraCloud.getState().status;});
  window.IskraSocial={version:'1.0.3',open,close,submit,getState(){return {board:BOARD,connected,authorized:authorized(),knownScore,rank:own?.rank||0,loading,sending,open:Boolean(panel&&!panel.hidden)};}};
})();
