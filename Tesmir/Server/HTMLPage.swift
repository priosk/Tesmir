import Foundation

enum HTMLPage {
    static let content: String = """
<!DOCTYPE html>
<html lang="ko">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>Tesmir 테슬미르</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  html, body { width: 100%; height: 100%; background: #000; overflow: hidden; font-family: -apple-system, sans-serif; }
  #container { position: relative; width: 100vw; height: 100vh; display: flex; align-items: center; justify-content: center; }
  #mirror-img { width: 100%; height: 100%; object-fit: contain; display: block; }
  #mjpeg-img { width: 100%; height: 100%; object-fit: contain; display: none; }
  #overlay { position: absolute; bottom: 0; left: 0; right: 0; padding: 12px 20px; background: linear-gradient(transparent, rgba(0,0,0,0.7)); display: flex; align-items: center; justify-content: space-between; transition: opacity 0.5s; pointer-events: none; }
  #overlay.hidden { opacity: 0; }
  #status-dot { width: 10px; height: 10px; border-radius: 50%; background: #ff3b30; display: inline-block; margin-right: 8px; transition: background 0.3s; }
  #status-dot.connected { background: #30d158; box-shadow: 0 0 6px #30d158; }
  #status-dot.connecting { background: #ffd60a; }
  #status-text { color: rgba(255,255,255,0.9); font-size: 13px; font-weight: 500; vertical-align: middle; }
  #branding { color: rgba(255,255,255,0.5); font-size: 12px; font-weight: 600; letter-spacing: 0.05em; }
  #waiting-screen { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; background: #0a0a0a; color: white; gap: 24px; transition: opacity 0.5s; }
  #waiting-screen.hidden { opacity: 0; pointer-events: none; }
  .logo-text { font-size: 36px; font-weight: 700; background: linear-gradient(135deg, #007aff, #5e5ce6); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
  .logo-sub { font-size: 16px; color: rgba(255,255,255,0.5); }
  .spinner { width: 40px; height: 40px; border: 3px solid rgba(255,255,255,0.15); border-top-color: #007aff; border-radius: 50%; animation: spin 1s linear infinite; }
  @keyframes spin { to { transform: rotate(360deg); } }
  .connect-hint { font-size: 13px; color: rgba(255,255,255,0.4); text-align: center; line-height: 1.6; max-width: 280px; }
  #fps-badge { position: absolute; top: 12px; right: 12px; background: rgba(0,0,0,0.5); color: rgba(255,255,255,0.6); font-size: 11px; font-weight: 600; padding: 3px 8px; border-radius: 8px; display: none; }
</style>
</head>
<body>
<div id="container">
  <img id="mirror-img" alt="" />
  <img id="mjpeg-img" src="" alt="" />
  <div id="waiting-screen">
    <div class="logo-text">Tesmir</div>
    <div class="logo-sub">테슬미르 · iPhone Mirror</div>
    <div class="spinner"></div>
    <div class="connect-hint">iPhone과 핫스팟으로 연결 중...<br>Connecting via iPhone hotspot...</div>
  </div>
  <div id="overlay">
    <div><span id="status-dot" class="connecting"></span><span id="status-text">연결 중... / Connecting...</span></div>
    <div id="branding">Tesmir</div>
  </div>
  <div id="fps-badge">0 FPS</div>
</div>
<script>
(function(){
  'use strict';
  var mirrorImg=document.getElementById('mirror-img'),mjpegImg=document.getElementById('mjpeg-img'),
      waitingScreen=document.getElementById('waiting-screen'),overlay=document.getElementById('overlay'),
      statusDot=document.getElementById('status-dot'),statusText=document.getElementById('status-text'),
      fpsBadge=document.getElementById('fps-badge');
  var ws=null,useMJPEG=false,reconnectTimer=null,reconnectDelay=2000,isConnected=false,frameCount=0,lastFpsTime=Date.now();
  setInterval(function(){
    var elapsed=(Date.now()-lastFpsTime)/1000;
    if(elapsed>0){var fps=Math.round(frameCount/elapsed);frameCount=0;lastFpsTime=Date.now();
      fpsBadge.textContent=fps+' FPS';fpsBadge.style.display=isConnected?'block':'none';}
  },1000);
  var overlayTimer=null;
  function scheduleOverlayHide(){if(overlayTimer)clearTimeout(overlayTimer);overlayTimer=setTimeout(function(){overlay.classList.add('hidden');},3000);}
  function showOverlay(){overlay.classList.remove('hidden');if(overlayTimer)clearTimeout(overlayTimer);}
  function setStatus(s,m){statusDot.className=s;statusText.textContent=m;}
  function onConnected(){isConnected=true;setStatus('connected','연결됨 · Connected');waitingScreen.classList.add('hidden');scheduleOverlayHide();reconnectDelay=2000;}
  function onDisconnected(){isConnected=false;showOverlay();setStatus('connecting','재연결 중... / Reconnecting...');fpsBadge.style.display='none';}
  function connectWebSocket(){
    if(ws){try{ws.close();}catch(e){}}
    var url=(location.protocol==='https:'?'wss:':'ws:')+'//' +location.host+'/stream';
    setStatus('connecting','연결 중... / Connecting...');
    try{ws=new WebSocket(url);ws.binaryType='arraybuffer';}catch(e){fallbackToMJPEG();return;}
    var t=setTimeout(function(){if(ws&&ws.readyState!==WebSocket.OPEN){ws.close();fallbackToMJPEG();}},5000);
    ws.onopen=function(){clearTimeout(t);onConnected();};
    ws.onmessage=function(e){if(e.data instanceof ArrayBuffer){
      var blob=new Blob([e.data],{type:'image/jpeg'}),old=mirrorImg.src;
      mirrorImg.src=URL.createObjectURL(blob);
      if(old&&old.startsWith('blob:'))URL.revokeObjectURL(old);
      frameCount++;
    }};
    ws.onerror=function(){clearTimeout(t);if(!useMJPEG)fallbackToMJPEG();};
    ws.onclose=function(){clearTimeout(t);if(!useMJPEG){onDisconnected();scheduleReconnect(connectWebSocket);}};
  }
  function fallbackToMJPEG(){
    useMJPEG=true;mirrorImg.style.display='none';mjpegImg.style.display='block';
    mjpegImg.src='http://'+location.host+'/mjpeg?'+Date.now();onConnected();
    mjpegImg.onerror=function(){onDisconnected();scheduleReconnect(function(){mjpegImg.src='http://'+location.host+'/mjpeg?'+Date.now();onConnected();});};
  }
  function scheduleReconnect(fn){if(reconnectTimer)clearTimeout(reconnectTimer);reconnectTimer=setTimeout(fn,reconnectDelay);reconnectDelay=Math.min(reconnectDelay*1.5,30000);}
  document.addEventListener('touchstart',function(){if(isConnected){showOverlay();scheduleOverlayHide();}});
  connectWebSocket();
})();
</script>
</body>
</html>
"""
}
