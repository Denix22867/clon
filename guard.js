/* Client-side input abuse protection. Purchase ownership is never erased. */
(() => {
  'use strict';
  const key='iskra-input-warning-v1';
  const windowMs=5000, minimumPerSecond=40, maxAcceptedPerSecond=12;
  let attempts=[], firstActiveAt=0, lastAttempt=-Infinity, lastAccepted=-Infinity, lastCheck=0, pending=null, resetCallback=null, resetting=false, overlay=null;
  try { const saved=JSON.parse(localStorage.getItem(key)); if(saved && (saved.done===true||Number.isFinite(saved.deadline))) pending=saved; } catch(_) {}
  function persist(){try {if(pending)localStorage.setItem(key,JSON.stringify(pending));else localStorage.removeItem(key);}catch(_) {}}
  function pause(value){window.IskraPlatform?.setGuardPaused(value);}
  function build(){
    if(overlay)return;
    overlay=document.createElement('section');overlay.id='iskra-guard';overlay.setAttribute('role','alertdialog');overlay.setAttribute('aria-modal','true');overlay.setAttribute('aria-labelledby','guard-title');
    overlay.innerHTML='<div class="guard-panel"><h1 id="guard-title">Обнаружены автоматические нажатия</h1><p class="guard-text">Останови нажатия и отключи автокликер в течение 10 секунд. Если продолжишь кликать всё это время, игровой прогресс будет полностью сброшен. Если остановишься — прогресс сохранится. Игра на паузе; оплаченные товары сохраняются.</p><strong id="guard-count" aria-live="polite">10</strong><button id="guard-ok" hidden>Начать заново</button></div>';
    document.body.append(overlay);
    overlay.querySelector('#guard-ok').onclick=()=>{pending=null;persist();attempts=[];firstActiveAt=0;lastAttempt=-Infinity;lastAccepted=-Infinity;overlay.remove();overlay=null;pause(false);};
  }
  function warn(){
    if(pending)return;
    pending={started:Date.now(),deadline:Date.now()+10000,counts:Array(10).fill(0),finalInputs:0,done:false,reset:false};persist();pause(true);build();draw();
  }
  function draw(){
    if(!pending)return;
    pause(true);build();
    if(pending.done){
      const reset=pending.reset===true;
      overlay.querySelector('h1').textContent=reset?'Прогресс сброшен':'Прогресс сохранён';
      overlay.querySelector('.guard-text').textContent=reset?'Автоматические нажатия продолжались все 10 секунд. Начни новый поход без автокликера. Оплаченные товары сохранены.':'Ты остановился во время предупреждения. Твой прогресс сохранён. Продолжай играть без автокликера.';
      overlay.querySelector('#guard-count').textContent='';
      overlay.querySelector('#guard-ok').textContent=reset?'Начать заново':'Продолжить игру';
      overlay.querySelector('#guard-ok').hidden=false;return;
    }
    const remaining=Math.max(0,Math.ceil((pending.deadline-Date.now())/1000));
    overlay.querySelector('#guard-count').textContent=String(remaining);
    persist();
    if(remaining===0){
      // A reset requires continued input in ALL ten warning seconds.
      // Stopping at any point, or only clicking occasionally, preserves progress.
      const continued=Array.isArray(pending.counts)&&pending.counts.length===10&&pending.counts.every(n=>n>=1);
      if(continued && (pending.finalInputs||0)<2 && Date.now()<pending.deadline+500)return;
      if(!continued || (pending.finalInputs||0)<2){pending.done=true;pending.reset=false;persist();draw();return;}
      if(resetCallback && !resetting){
        resetting=true;
        try {
          resetCallback();
          const progress=JSON.parse(localStorage.getItem('iskra-idle-v2'));
          if(progress?.best===1 && progress?.clicks===0 && progress?.rebirths===0){pending.done=true;pending.reset=true;persist();draw();}
        }catch(_){}
        finally {resetting=false;}
      }
    }
  }
  function recordWarningInput(){
    if(!pending || pending.done)return;
    const second=Math.floor((Date.now()-(pending.started||pending.deadline-10000))/1000);
    if(second>=0&&second<10){pending.counts ||= Array(10).fill(0);pending.counts[second]++;}
    else if(Date.now()>=pending.deadline && Date.now()<=pending.deadline+500) pending.finalInputs=(pending.finalInputs||0)+1;
  }

  function allowStrike(){
    if(pending){recordWarningInput();return false;}
    if(window.IskraPlatform?.isPaused())return false;
    const now=performance.now();
    if(now-lastAttempt>250) firstActiveAt=now;
    lastAttempt=now;
    attempts.push(now);const cutoff=now-windowMs;
    while(attempts.length && attempts[0]<cutoff)attempts.shift();
    if(now-lastCheck>=100){
      lastCheck=now;
      if(now-firstActiveAt>=windowMs && attempts.length>=minimumPerSecond*5){
        // Require five complete dense seconds. A burst or frame batching cannot reset progress.
        let sustained=true;
        for(let second=0;second<5;second++){
          const start=now-(second+1)*1000,end=now-second*1000;
          let count=0;for(const t of attempts)if(t>start&&t<=end)count++;
          if(count<minimumPerSecond){sustained=false;break;}
        }
        if(sustained){warn();return false;}
      }
    }
    if(now-lastAccepted<1000/maxAcceptedPerSecond)return false;
    lastAccepted=now;return true;
  }
  window.IskraGuard={allowStrike,bindGodotReset(callback){resetCallback=callback;if(pending)draw();},getState(){return {warning:Boolean(pending),remaining:pending?Math.max(0,Math.ceil((pending.deadline-Date.now())/1000)):0,reset:pending?.done===true&&pending?.reset===true,preserved:pending?.done===true&&pending?.reset!==true};}};
  setInterval(()=>{if(pending)draw();},100);
  window.addEventListener('pointerdown',recordWarningInput,true);
  window.addEventListener('keydown',event=>{if(event.code==='Space'&&!event.repeat)recordWarningInput();},true);
  window.addEventListener('pagehide',persist);
  document.addEventListener('visibilitychange',()=>{if(pending)draw();});
  if(pending){pending.deadline=Math.min(Number(pending.deadline)||Date.now(),Date.now()+10000);draw();}
})();
