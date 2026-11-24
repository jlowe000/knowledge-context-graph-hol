/* APEX authenticated workspace. Graphs use returned bindings; explanations use saved evidence events. */
document.addEventListener('DOMContentLoaded', () => {
 'use strict';
 const $=id=>document.getElementById(id),root=$('kcv-explorer');if(!root)return;
 const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
 let session=null,pending=null,busy=false,vocabulary=[],activeTopics=[],current=null,trigger=null,traceVersion=0;
 let graphCounter=0,olderTurns=false,olderObservations=false;
 const savedTurns=new Map(),savedObservations=new Map(),requestTokens=new Map();
 const requestToken=()=>crypto.randomUUID().replaceAll('-','');
 const personal=()=>Boolean(current&&current.state.personal_context_id);
 const readOnly=()=>Boolean(current&&current.state.read_only);
 const traceCache=new Map(),storageKey=`kcv:${apex.env.APP_ID}:${apex.env.APP_SESSION}`,dialog=$('kcv-explanation');
 function status(t,error=false){$('kcv-status').textContent=t;$('kcv-status').classList.toggle('kcv-error',error);}
 function permissions(){
  ['kcv-send','kcv-stage','kcv-apply','kcv-observe','kcv-adopt-head'].forEach(id=>$(id).disabled=busy||readOnly());
  if(current&&current.state.operation_pending){$('kcv-send').disabled=true;$('kcv-adopt-head').disabled=true;}
  ['kcv-message','kcv-observation','kcv-next','kcv-mode','kcv-method'].forEach(id=>$(id).disabled=busy||readOnly());
 }
 function lock(v){busy=v;root.querySelectorAll('button,select,textarea').forEach(n=>{if(!dialog.contains(n))n.disabled=v;});permissions();}
 function view(name){root.querySelectorAll('[data-panel]').forEach(n=>n.hidden=n.dataset.panel!==name);root.querySelectorAll('[data-view]').forEach(n=>n.setAttribute('aria-pressed',String(n.dataset.view===name)));}
 function json(text){try{return JSON.parse(String(text).trim().replace(/^\x60{3}(?:json)?\s*/i,'').replace(/\s*\x60{3}$/,''));}catch(_){return null;}}
 function short(t,n=48){t=String(t||'');return t.length>n?t.slice(0,n-1)+'…':t;}
 function value(parent,v,depth=0){
  if(v===null||v===undefined)return;
  if(typeof v!=='object'){parent.append(el('div',String(v)));return;}
  if(depth>5){parent.append(el('pre',JSON.stringify(v,null,2)));return;}
  if(Array.isArray(v)){const ul=el('ul');v.forEach(x=>{const li=el('li');value(li,x,depth+1);ul.append(li);});parent.append(ul);return;}
  Object.entries(v).forEach(([k,x])=>{const part=el('div',undefined,'kcv-answer-object');part.append(el('h4',k.replaceAll('_',' ')));value(part,x,depth+1);parent.append(part);});
 }
 function answerBody(card,body,showFormatWarning=false){const parsed=json(body);if(!parsed){if(showFormatWarning)card.append(el('p','Response formatting could not be parsed. The saved text is shown below; citation matching is unavailable. Open the explanation to inspect the recorded evidence.','kcv-error'));card.append(el('div',body));return;}const main=Object.fromEntries(Object.entries(parsed).filter(([k])=>!['graph_paths','citations'].includes(k)));value(card,main);if(parsed.citations){const d=el('details');d.append(el('summary','Citation references'));value(d,parsed.citations);card.append(d);}if(parsed.graph_paths){const d=el('details');d.append(el('summary','Paths reported in the answer'));d.append(el('p','Inspect the explanation for independently captured graph paths.','kcv-muted'),el('pre',JSON.stringify(parsed.graph_paths,null,2)));card.append(d);}}
 function publicUrl(raw){try{
  const u=new URL(raw),host=u.hostname.toLowerCase(),decoded=decodeURIComponent(u.href).toLowerCase();
  if(u.protocol!=='https:'||u.username||u.password||(u.port&&u.port!=='443')||/sharepoint|onedrive|seismic|1drv\.ms/.test(decoded)||/oraclecorp|oraweb|stbeehive|beehive|confluence|localhost|^(?:my|login|signin|sso|identity)\./.test(host)||/[?&](?:access_token|token|sig|signature|x-amz-signature|x-goog-signature|password|secret)=/.test(decoded))return null;
  const parts=decodeURIComponent(u.pathname).split('/').filter(Boolean),owners=['oracle','oracle-devrel','oracle-livelabs','oracle-samples','helidon-io','oci-landing-zones'];
  const official=host==='oracle.com'||host.endsWith('.oracle.com'),event=host==='static.rainfocus.com'&&u.pathname.startsWith('/oracle/oaiw26/sess/'),repo=['github.com','raw.githubusercontent.com'].includes(host)&&owners.includes(parts[0]),api=host==='api.github.com'&&parts[0]==='repos'&&owners.includes(parts[1]);
  return official||event||repo||api||host==='www.youtube.com'?u.href:null;
 }catch(_){return null;}}
 function locatorLabel(p){return p.locator_label||(Number.isInteger(p.pdf_page)&&p.pdf_page>0?`PDF page ${p.pdf_page}`:'Source passage');}
 function sourceBasisLinks(p){
  if(!Array.isArray(p.basis_locators)||p.basis_locators.length<2)return [];
  const links=new Map();p.basis_locators.forEach(b=>{if(!b||typeof b!=='object')return;const url=publicUrl(b.locator_url);if(url){const label=locatorLabel(b);links.set(url+'\n'+label,{url,label});}});return [...links.values()];
 }
 function packetOf(trace){const evidence=new Map(),paths=new Map();(trace.tool_calls||[]).filter(c=>c.tool==='EVIDENCE'&&c.status==='SUCCEEDED').forEach(c=>{(c.output.evidence||[]).forEach(p=>evidence.set(p.id,p));(c.output.graph_paths||[]).forEach(p=>paths.set(JSON.stringify(p),p));});return {evidence:[...evidence.values()],graph_paths:[...paths.values()]};}
 function eventLabel(c){return c.origin==='APPLICATION'?(c.tool==='EVIDENCE'?'Application evidence retrieval':`Application ${c.tool} step`):`${c.tool} ${c.origin==='AGENT'?'agent tool':'recorded tool'}`;}
 function traceProcess(t,turn){
  const calls=t.tool_calls||[],application=calls.filter(c=>c.origin==='APPLICATION'),other=calls.filter(c=>c.origin!=='APPLICATION'),context=t.context||{},hasApplication=application.length>0;
  const counts=[application.length?`${application.length} application evidence step(s)`:null,other.filter(c=>c.origin==='AGENT').length?`${other.filter(c=>c.origin==='AGENT').length} agent tool call(s)`:null,other.filter(c=>c.origin!=='AGENT').length?`${other.filter(c=>c.origin!=='AGENT').length} historical tool event(s), trigger not recorded`:null].filter(Boolean).join('; ')||'No evidence or tool event captured';
  const nodes=[{key:'q',label:'Your question',sub:'Recorded request',x:90,y:45,description:t.question},{key:'ctx',label:'Context revision',sub:t.revision_id,x:90,y:150,description:`Pinned objective and interests: ${context.objective||context.question}`},{key:'team',label:'Team request',sub:t.mode,x:hasApplication?570:330,y:150,description:hasApplication?'RUN_TEAM receives the evidence already retrieved and recorded by the application. The answer task interprets this packet; it does not choose whether retrieval occurs.':'RUN_TEAM requested using the recorded conversation. Internal routing is configured, not independently traced here.'},{key:'answer',label:'Answer stored',sub:`Turn ${turn.turn_id}`,x:810,y:150,description:'The returned model response is paired with this execution. Recorded evidence does not reveal private model reasoning.'}];
  const edges=hasApplication?[['team','answer']]:[['q','team'],['ctx','team']];
  calls.forEach((c,i)=>{const isApplication=c.origin==='APPLICATION',position=isApplication?application.indexOf(c):other.indexOf(c),y=isApplication?150+position*110:hasApplication?350+position*110:45+position*110;
   nodes.push({key:`event${i}`,label:isApplication?'Evidence retrieval':`${c.tool} tool`,sub:`${isApplication?'Application':c.origin==='AGENT'?'Agent':'Trigger unrecorded'} · ${c.status}`,x:isApplication?330:570,y,description:isApplication?`The application retrieved and recorded this evidence before the model request. ${(c.output&&c.output.evidence||[]).length} passages returned. ${c.status}. This was not an agent tool call.`:c.tool==='EVIDENCE'?`Captured evidence output: ${(c.output&&c.output.evidence||[]).length} passages. ${c.status}. ${c.origin==='AGENT'?'Triggered by an agent.':'This historical event did not record its trigger.'}`:`Recorded proposal result. No change is applied by this step. ${c.status}. ${c.origin==='AGENT'?'Triggered by an agent.':'This historical event did not record its trigger.'}`});
   if(isApplication)edges.push(['q',`event${i}`],['ctx',`event${i}`],[`event${i}`,'team']);else edges.push(['team',`event${i}`],[`event${i}`,'answer']);
  });
  if(!calls.length){nodes.push({key:'none',label:'No evidence step captured',sub:'Incomplete trace',x:570,y:150,description:'No recorded retrieval or tool result supports a claim that graph evidence was supplied for this response.'});edges.push(['team','none'],['none','answer']);}
  const capturedGraph=calls.find(c=>c.tool==='EVIDENCE'&&c.output&&c.output.base_graph);
  if(capturedGraph){nodes.push({key:'graphs',label:'Pinned graphs',sub:'Base + context overlay',x:hasApplication?90:330,y:275,description:`Captured base: ${capturedGraph.output.base_graph}. Context overlay: ${capturedGraph.output.overlay_graph}. These are the graph identities used by the recorded evidence query.`});edges.push(['graphs',`event${calls.indexOf(capturedGraph)}`]);}
  const events=[['Question recorded',t.started_at],...application.map(c=>[`${eventLabel(c)} · ${c.status.toLowerCase()}`,`${c.started_at} → ${c.finished_at}`]),['Team request',t.model_started_at||'Exact model request time was not recorded for this historical run.'],...other.map(c=>[`${eventLabel(c)} · ${c.status.toLowerCase()}`,`${c.started_at} → ${c.finished_at}`]),['Response stored',t.finished_at||'Unavailable']];
  const before=hasApplication?`${application.map(c=>`${eventLabel(c)} (${c.status})`).join(', ')} → `:'',after=other.length?` → ${other.map(c=>`${eventLabel(c)} (${c.status})`).join(', ')}`:hasApplication?'':' → no captured evidence step';
  return {nodes,edges,events,counts,text:`Question + pinned context${capturedGraph?' + pinned graphs':''} → ${before}team request${after} → stored response → citation references → matched evidence passages.`};
 }
 function network(host,nodes,edges,onSelect){
  host.replaceChildren();if(!nodes.length){host.append(el('p','No recorded graph paths are available.','kcv-muted'));return;}
  const ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg'),height=Math.max(300,...nodes.map(n=>n.y+45));svg.setAttribute('viewBox',`0 0 900 ${height}`);svg.setAttribute('aria-hidden','true');
  const byKey=new Map(nodes.map(n=>[n.key,n]));
  const arrowId=`kcv-arrow-${++graphCounter}`,defs=document.createElementNS(ns,'defs'),marker=document.createElementNS(ns,'marker'),tip=document.createElementNS(ns,'path');marker.id=arrowId;[['markerWidth',7],['markerHeight',7],['refX',6],['refY',3.5],['orient','auto']].forEach(([k,v])=>marker.setAttribute(k,v));tip.setAttribute('d','M0 0 L7 3.5 L0 7 Z');tip.style.fill='var(--kcv-border)';tip.style.stroke='none';marker.append(tip);defs.append(marker);svg.append(defs);
  edges.forEach(([a,b,label])=>{const x=byKey.get(a),y=byKey.get(b);if(!x||!y)return;const line=document.createElementNS(ns,'line');const dx=y.x-x.x,dy=y.y-x.y,clip=Math.min(dx?85/Math.abs(dx):Infinity,dy?28/Math.abs(dy):Infinity);line.setAttribute('x1',x.x+dx*clip);line.setAttribute('y1',x.y+dy*clip);line.setAttribute('x2',y.x-dx*clip);line.setAttribute('y2',y.y-dy*clip);line.setAttribute('marker-end',`url(#${arrowId})`);line.dataset.a=a;line.dataset.b=b;svg.append(line);});
  const grid=el('div',undefined,'kcv-node-grid');nodes.forEach(n=>{const b=el('button',n.label);b.type='button';b.style.left=`${(n.x-85)/9}%`;b.style.top=`${n.y/height*100}%`;b.style.width=`${170/9}%`;b.dataset.key=n.key;b.setAttribute('aria-pressed','false');if(n.sub)b.append(el('small',n.sub));b.addEventListener('click',()=>select(n));grid.append(b);});
  function select(n){const related=new Set([n.key]);edges.forEach(([a,b])=>{if(a===n.key)related.add(b);if(b===n.key)related.add(a);});grid.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',String(related.has(b.dataset.key))));svg.querySelectorAll('line').forEach(l=>l.classList.toggle('kcv-edge-active',l.dataset.a===n.key||l.dataset.b===n.key));onSelect(n);}
  host.append(svg,grid);return {select,byKey};
 }
 function sourceGraph(host,packet,context,sources,detail,cards){
  const paths=packet.graph_paths||[],topics=[...new Set(paths.map(p=>p.topic))],ids=[...new Set(paths.map(p=>p.content_item))],passages=packet.evidence||[],names=new Map((sources||[]).map(s=>[s.id,s.title]));
  if(!paths.length){host.replaceChildren(el('p','No captured topic paths. A proposal or incomplete trace may have no evidence retrieval.','kcv-muted'));return;}
  const rows=Math.max(topics.length,ids.length,passages.length),h=Math.max(300,rows*85),ys=(i,n)=>40+i*(h-80)/Math.max(1,n-1);
  const nodes=[{key:'context',label:context.person||'Context',sub:'Recorded interests',x:90,y:h/2,kind:'context'}];
  topics.forEach((t,i)=>nodes.push({key:t,label:t.replace(/^topic-/,'').replaceAll('-',' '),x:330,y:ys(i,topics.length),kind:'topic'}));
  ids.forEach((s,i)=>nodes.push({key:s,label:s,sub:short(names.get(s)||'Public source',40),x:570,y:ys(i,ids.length),kind:'source'}));
  passages.forEach((p,i)=>nodes.push({key:p.id,label:short(locatorLabel(p),48),sub:p.source_id||p.version_id,x:810,y:ys(i,passages.length),kind:'passage'}));
  const edgeSet=new Map();paths.forEach(p=>{[['context',p.topic,'focusesOn'],[p.content_item,p.topic,'coversTopic'],[p.content_item,p.evidence_id,'hasVersion / hasPassage']].forEach(e=>edgeSet.set(JSON.stringify(e),e));});
  const graph=network(host,nodes,[...edgeSet.values()],n=>{
   detail.hidden=false;detail.replaceChildren(el('strong',n.kind==='source'?`${n.label} · ${names.get(n.key)||'Source'}`:n.label));
   const matching=paths.filter(p=>n.kind==='context'||p.topic===n.key||p.content_item===n.key||p.evidence_id===n.key),selectedIds=new Set(matching.map(p=>p.content_item));
   if(n.kind==='context')detail.append(el('p',context.objective||context.question||'The context supplies the active interests.'));
   else detail.append(el('p',n.kind==='topic'?'This explicit topic connects the context to the highlighted sources.':n.kind==='source'?'This source is connected through the recorded topic relationships. Inspect its evidence passages below.':'This passage is reached through its source version; it is not a separately inferred claim.'));
   const list=el('ul');[...new Set(matching.map(p=>`${p.context_revision} → ${p.topic} ← ${p.content_item} → ${p.version} → ${p.evidence_id}`))].forEach(t=>list.append(el('li',t,'kcv-path')));detail.append(list);
   if(cards)cards.querySelectorAll('[data-source]').forEach(c=>c.dataset.selected=String(n.kind==='passage'?c.dataset.passage===n.key:selectedIds.has(c.dataset.source)));
  });if(graph)graph.select(nodes.find(n=>n.kind==='source')||nodes[0]);
 }
 function sourceCards(host,packet,sources,citations,full=false,parseStatus='PARSED'){
  host.replaceChildren();const names=new Map((sources||[]).map(s=>[s.id,s.title])),cited=new Set((citations||[]).filter(c=>c.matched).map(c=>c.id));
  (packet.evidence||[]).forEach(p=>{const card=el('article',undefined,'kcv-source'),url=publicUrl(p.locator_url),title=`${p.source_id} · ${names.get(p.source_id)||'Public source'} · ${locatorLabel(p)}`;card.dataset.source=p.source_id;card.dataset.passage=p.id;
   if(url){const a=el('a',title);a.href=url;a.target='_blank';a.rel='noopener noreferrer';card.append(a);}else card.append(el('strong',title));
   const basis=sourceBasisLinks(p);if(basis.length){const list=el('ul');basis.forEach(b=>{const li=el('li'),a=el('a',b.label);a.href=b.url;a.target='_blank';a.rel='noopener noreferrer';li.append(a);list.append(li);});card.append(el('small','Source locations supporting this summary','kcv-muted'),list);}
   if(full)card.append(el('span',parseStatus==='UNAVAILABLE'?'Citation matching unavailable':cited.has(p.id)?'Cited in this answer':'Returned, not explicitly cited','kcv-pill'));
   if(p.content_kind)card.append(el('small',p.content_kind.replaceAll('_',' '),'kcv-muted'));
   card.append(el('p',p.id,'kcv-muted'),el('p',full?(p.text||''):(p.text||'').slice(0,400)+'…'));host.append(card);
  });
 }
 function draw(data){
  const previous=current;current=data;const state=data.state,packet=data.packet||{},context=state.context;session=state.scenario_session;
  if(!state.personal_context_id)try{sessionStorage.setItem(storageKey,session);}catch(_){}
  if(!previous||previous.state.scenario_session!==session){savedTurns.clear();savedObservations.clear();olderTurns=(data.turns||[]).length===20;olderObservations=(data.observations||[]).length===20;}
  (data.turns||[]).forEach(t=>savedTurns.set(t.turn_id,t));(data.observations||[]).forEach(o=>savedObservations.set(o.observation_id,o));
  $('kcv-personal-bar').hidden=!personal();root.querySelector('.kcv-scenario-bar').hidden=personal();
  root.querySelector('.kcv-badge').textContent=personal()?'My saved context · public sources':'Fictional learners · public sources';
  $('kcv-personal-refinement').hidden=!personal();$('kcv-sample-refinement').hidden=personal();
  if(personal()){
   $('kcv-personal-title').textContent=data.personal.title;
   $('kcv-personal-revision').textContent=`This conversation uses revision ${state.context_revision}. ${state.latest_revision!==state.context_revision?'A newer ready revision is available. Earlier answers keep their recorded context.':'This is the latest ready revision.'}`;
   $('kcv-overview-link').href=data.personal.overview_url;$('kcv-edit-link').href=data.personal.edit_url;$('kcv-edit-link').hidden=readOnly();
   $('kcv-adopt-head').hidden=readOnly()||!state.latest_revision||state.latest_revision===state.context_revision;$('kcv-read-only').hidden=!readOnly();$('kcv-operation-pending').hidden=!state.operation_pending;$('kcv-model-reset-pending').hidden=!state.model_reset_pending;
  }
  $('kcv-context').value=context.id;$('kcv-context-summary').replaceChildren(el('strong',[context.person,context.role].filter(Boolean).join(' · ')||'Your saved context'),el('p',context.objective||context.question),el('p',`Objective: ${context.objective_clarity||'unknown'} · ${context.learning_purpose||'Purpose not yet set'}`,'kcv-muted'));
  $('kcv-identifiers').textContent=JSON.stringify({context_revision:state.context_revision,conversation_id:state.conversation_id,base_graph:state.base_graph,overlay_graph:state.overlay_graph},null,2);
  vocabulary=data.topics||[];activeTopics=Object.keys(context.topic_preferences||{});refinementFields();
  if(previous&&previous.state.scenario_session===session&&previous.state.context_revision!==state.context_revision){const before=new Set((previous.packet.graph_paths||[]).map(p=>p.content_item)),after=new Set((packet.graph_paths||[]).map(p=>p.content_item)),out=[...before].filter(x=>!after.has(x)),added=[...after].filter(x=>!before.has(x));$('kcv-change-summary').textContent=out.length||added.length?`Context revised. No longer selected: ${out.join(', ')||'none'}. Now selected: ${added.join(', ')||'none'}. Bounded selection; source knowledge is unchanged.`:'Objective/context revised. Topic-based source selection is unchanged.';}
  else if(!previous||previous.state.scenario_session!==session)$('kcv-change-summary').textContent='';
  renderTurns();renderObservations();permissions();
  sourceCards($('kcv-sources'),packet,data.sources);sourceGraph($('kcv-graph'),packet,context,data.sources,$('kcv-current-detail'),$('kcv-sources'));
  $('kcv-paths').replaceChildren(...(packet.graph_paths||[]).map(p=>el('div',`${p.context_revision} → focusesOn → ${p.topic} ← coversTopic ← ${p.content_item} → ${p.version} → ${p.evidence_id}`,'kcv-path')));
 }
 function renderTurns(){
  const turns=$('kcv-turns');turns.replaceChildren();[...savedTurns.values()].sort((a,b)=>a.turn_id-b.turn_id).forEach(t=>{
   const card=el('article',undefined,`kcv-turn ${t.role}`);card.append(el('strong',t.role==='user'?'You':'Knowledge explorer'),el('div',`Context revision ${t.revision_id}`,'kcv-turn-meta'));
   if(t.role==='assistant'&&t.response_status&&t.response_status!=='COMPLETED'){
    card.append(el('p','Exploration incomplete — the required evidence step did not complete successfully. This response is not a supported answer. Inspect its explanation before choosing whether to ask again.','kcv-error'));
    const raw=el('details');raw.append(el('summary','View the saved model response'));answerBody(raw,t.body,true);card.append(raw);
   }else answerBody(card,t.body,t.role==='assistant');
   if(t.role==='assistant'){const b=el('button','How was this answer built?','kcv-proof');b.type='button';b.dataset.turn=t.turn_id;b.addEventListener('click',()=>showTrace(t,b));card.append(b);}turns.append(card);
  });
  if(!savedTurns.size)turns.append(el('p','Start with a question. You can explore without a fully defined objective.','kcv-muted'));
  $('kcv-older-turns').hidden=!personal()||!olderTurns;
 }
 function renderObservations(){
  const host=$('kcv-observation-list');host.replaceChildren();
  [...savedObservations.values()].sort((a,b)=>b.observation_id-a.observation_id).forEach(o=>{const article=el('article',undefined,'kcv-turn');article.append(el('strong',(o.method||'Observation').replaceAll('_',' ')),el('p',o.observation),el('p',o.next_step||''),el('small',`Recorded against revision ${o.revision}`,'kcv-muted'));host.append(article);});
  $('kcv-older-observations').hidden=!personal()||!olderObservations;
 }
 async function earlier(kind){
  if(busy||!personal())return;const isTurns=kind==='history',rows=isTurns?savedTurns:savedObservations;if(!rows.size)return;
  const before=Math.min(...rows.keys());lock(true);status('Loading saved history…');
  try{const data=await apex.server.process('KCV_EXPLORER',{x01:kind,x02:session,x03:String(before)},{dataType:'json'});if(!data||!data.ok)throw new Error(data&&data.error||'History unavailable.');
   const page=isTurns?data.turns:data.observations;page.forEach(x=>rows.set(isTurns?x.turn_id:x.observation_id,x));
   if(isTurns){olderTurns=page.length===20;renderTurns();}else{olderObservations=page.length===20;renderObservations();}status(page.length?'Earlier saved records loaded.':'You have reached the beginning of the saved history.');
  }catch(e){status(e.message,true);}finally{lock(false);}
 }
 function refinementFields(){const op=$('kcv-operation').value,isObj=op==='SET_OBJECTIVE',selected=$('kcv-topic').value;$('kcv-objective').hidden=!isObj;root.querySelector('label[for="kcv-objective"]').hidden=!isObj;$('kcv-topic').hidden=isObj;root.querySelector('label[for="kcv-topic"]').hidden=isObj;const choices=op==='REMOVE_TOPIC'?activeTopics:vocabulary.filter(t=>!activeTopics.includes(t));$('kcv-topic').replaceChildren(...choices.map(t=>{const o=el('option',t);o.value=t;return o;}));if(choices.includes(selected))$('kcv-topic').value=selected;}
 async function call(action,message='',mode='',extra=''){
  if(busy)return;if(!session&&!['start','state','open_personal'].includes(action)){status('Start a conversation first.',true);return;}
  const key=JSON.stringify([session,action,message,mode,extra]);if(!requestTokens.has(key))requestTokens.set(key,requestToken());
  lock(true);status(action==='ask'?'Exploring the context and evidence. This may take a little time…':'Updating the scenario…');
  try{const data=await apex.server.process('KCV_EXPLORER',{x01:action,x02:session||'',x03:message,x04:mode,x05:extra,x06:requestTokens.get(key)},{dataType:'json'});if(!data||!data.ok){const error=new Error(data&&data.error||'No valid response was returned.');error.code=Number(data&&data.error_code);throw error;}requestTokens.delete(key);draw(data);
   if(action==='stage'){pending=data.change.pending_change;$('kcv-change-preview').textContent=JSON.stringify(data.change.plan,null,2);$('kcv-apply').hidden=false;}
   if(['start','apply'].includes(action)){pending=null;$('kcv-apply').hidden=true;$('kcv-change-preview').textContent='';}if(['start','open_personal'].includes(action))view('conversation');
   const latestAnswer=[...(data.turns||[])].filter(t=>t.role==='assistant').sort((a,b)=>b.turn_id-a.turn_id)[0];
   const incomplete=action==='ask'&&latestAnswer&&latestAnswer.response_status&&latestAnswer.response_status!=='COMPLETED';
   status(incomplete?'Exploration incomplete. The saved response has no completed evidence step. Open its explanation; no automatic retry was made.':action==='adopt_head'?'This conversation now uses the ready revision. Earlier answers and explanations remain unchanged.':action==='observe'?'Observation saved against this context revision.':action==='apply'?'Refinement applied. Open Evidence to compare the refreshed connections.':'Ready. Source qualifications and unanswered questions remain part of the picture.',Boolean(incomplete));return data;
  }catch(e){
   // Only this definitive pre-model failure may use a new token on a later user action.
   if(action==='ask'&&e.code===-20174)requestTokens.delete(key);
   // Read-only status refresh reveals an uncertain operation; never repeat the model request here.
   if(personal())try{const refreshed=await apex.server.process('KCV_EXPLORER',{x01:'state',x02:session},{dataType:'json'});if(refreshed&&refreshed.ok)draw(refreshed);}catch(_){}
   status(e.message,true);
  }finally{lock(false);}
 }
 function traceTab(name){root.querySelectorAll('.kcv-dialog-tabs button').forEach(b=>b.setAttribute('aria-selected',String(b.id===`kcv-tab-${name}`)));root.querySelectorAll('.kcv-dialog-body [role="tabpanel"]').forEach(p=>p.hidden=p.id!==`kcv-trace-${name}`);}
 async function showTrace(turn,button){
  trigger=button;const ticket=++traceVersion,key=`${session}:${turn.turn_id}`;['overview','sources','lineage','limits'].forEach(n=>$(`kcv-trace-${n}`).replaceChildren());$('kcv-trace-subtitle').textContent=`Answer ${turn.turn_id} · recorded revision ${turn.revision_id}`;$('kcv-trace-status').textContent='Loading saved response details…';traceTab('sources');dialog.showModal();
  try{let trace=traceCache.get(key);if(!trace){const data=await apex.server.process('KCV_EXPLORER',{x01:'trace',x02:session,x03:String(turn.turn_id)},{dataType:'json'});if(!data||!data.ok)throw new Error(data&&data.error||'Trace unavailable');trace=data.trace;traceCache.set(key,trace);}if(ticket===traceVersion&&dialog.open)renderTrace(trace,turn);
  }catch(e){if(ticket===traceVersion)$('kcv-trace-status').textContent=e.message;}
 }
 function renderTrace(t,turn){
  const overview=$('kcv-trace-overview'),sources=$('kcv-trace-sources'),lineage=$('kcv-trace-lineage'),limits=$('kcv-trace-limits');
  if(t.availability!=='RECORDED'){$('kcv-trace-status').textContent=t.message;overview.append(el('p',`Retained context revision: ${t.revision_id}`));traceTab('overview');return;}
  const historical=t.revision_id!==current.state.context_revision;const calls=t.tool_calls||[],packet=packetOf(t),context=t.context||{},process=traceProcess(t,turn);
  $('kcv-trace-status').textContent=`${historical?'Historical context; the current scenario has changed. ':''}Execution ${t.status.toLowerCase()}. ${process.counts}.`;
  overview.append(el('h3','Question and recorded context'),el('p',t.question));const dl=el('dl',undefined,'kcv-kv');[['Person',[context.person,context.role].filter(Boolean).join(' · ')||'Your saved context'],['Objective',context.objective||context.question],['Active topics',Object.keys(context.topic_preferences||{}).join(', ')],['Mode',t.mode],['Recorded start',t.started_at],['Recorded finish',t.finished_at||'Not finished']].forEach(([k,v])=>dl.append(el('dt',k),el('dd',v)));overview.append(dl);
  overview.append(el('h3','Source selection and interpretation'),el('p','The recorded collection and selected topics determine the evidence candidates. The question, objective, role, background and explicit constraints frame the answer; they are not additional evidence filters. Topic weights do not rank retrieval.'));
  const selection=calls.find(c=>c.tool==='EVIDENCE'&&c.output&&c.output.selection_context);if(selection){const details=el('details');details.append(el('summary','Recorded selection and framing'));value(details,{selection_context:selection.output.selection_context,interpretation_context:selection.output.interpretation_context});overview.append(details);}
  overview.append(el('h3','Recorded process'));process.events.forEach(([label,time])=>{const row=el('div',undefined,'kcv-event');row.append(el('strong',label),el('small',time));overview.append(row);});
  const technical=el('details');technical.append(el('summary','Execution identifiers and capture policy'),el('pre',JSON.stringify({execution_id:t.execution_id,revision_id:t.revision_id,conversation_id:t.conversation_id,profile:t.profile_name,trace_version:t.trace_version,retrieval_policy:t.retrieval_policy,history_turn_ids:t.history_turn_ids,supplied_continuation:t.supplied_continuation},null,2)));overview.append(technical);
  sources.append(el('h3','Why did these sources appear?'),el('p','Select a topic, source or passage to inspect its recorded connection. Lines represent explicit relationships; source versions are retained in the path details.','kcv-muted'));
  const graph=el('div',undefined,'kcv-graph'),detail=el('div',undefined,'kcv-detail'),cards=el('div',undefined,'kcv-sources');sources.append(graph,detail,el('h3','Evidence supplied for this answer'),cards);sourceCards(cards,packet,t.sources,t.citations,true,t.citation_parse_status);sourceGraph(graph,packet,context,t.sources,detail,cards);
  if(!packet.evidence.length)sources.append(el('p','No successful evidence payload was captured. A proposal-only run does not perform graph evidence retrieval.','kcv-muted'));
  const unknown=(t.citations||[]).filter(c=>!c.matched);if(unknown.length){sources.append(el('h3','Citations not found in captured evidence'));unknown.forEach(c=>sources.append(el('p',c.id,'kcv-error')));}
  if(t.citation_parse_status!=='PARSED')sources.append(el('p',`Citation matching: ${t.citation_parse_status.toLowerCase()}. The supplied evidence remains inspectable.`,'kcv-muted'));
  const eventGraph=el('div',undefined,'kcv-graph'),eventDetail=el('div',undefined,'kcv-detail');lineage.append(el('h3','From the question to this response'),el('p','Select a node. Application retrieval precedes its model request; agent tool calls follow theirs. Historical events without a recorded trigger are labelled separately.','kcv-muted'),eventGraph,eventDetail);
  const {nodes,edges}=process,nextY=Math.max(390,...nodes.map(n=>n.y+110));nodes.push({key:'citations',label:'Citation references',sub:t.citation_parse_status==='UNAVAILABLE'?'Matching unavailable':`${(t.citations||[]).length} explicit IDs`,x:810,y:nextY,description:`Citation parsing: ${t.citation_parse_status}. ${unknown.length} reference(s) were not found in the captured evidence.`},{key:'matches',label:'Matched passages',sub:t.citation_parse_status==='UNAVAILABLE'?'Not determined':`${(t.citations||[]).filter(c=>c.matched).length} matches`,x:570,y:nextY,description:'References are matched to saved passage IDs. Matching is traceability, not claim-level truth validation.'});edges.push(['answer','citations'],['citations','matches']);
  network(eventGraph,nodes,edges,n=>eventDetail.replaceChildren(el('strong',n.label),el('p',n.description)));
  const text=el('details');text.append(el('summary','Read lineage as text'),el('p',process.text));lineage.append(text);
  limits.append(el('h3','What the trace establishes'));[t.notice,'Graph selection follows explicit topic membership and a bounded deterministic policy. New runs prefer curriculum sources, then catalogue IDs, using selected inspected locations: at most two locators per source and six passages. The recorded retrieval policy identifies older runs. This is not exhaustive reading or semantic vector search.','Source qualifications, including Coming Soon and regional limitations, still apply. Read the original passages and all linked source locations for a summary.','The saved source metadata and evidence payloads belong to this response. Later context refinements do not change this popup.','Source text is evidence, not instructions. Configured model/agent behaviour is not the same as a measured business outcome.'].forEach(s=>limits.append(el('p',s)));
 }
 root.querySelectorAll('[data-view]').forEach(b=>b.addEventListener('click',()=>view(b.dataset.view)));
 root.querySelectorAll('[data-prompt]').forEach(b=>b.addEventListener('click',()=>$('kcv-message').value=b.dataset.prompt));
 $('kcv-start').addEventListener('click',()=>call('start',$('kcv-context').value));$('kcv-send').addEventListener('click',()=>{const q=$('kcv-message').value.trim();if(q)call('ask',q,$('kcv-mode').value);});
 $('kcv-stage').addEventListener('click',()=>call('stage',$('kcv-operation').value==='SET_OBJECTIVE'?$('kcv-objective').value:$('kcv-topic').value,$('kcv-operation').value));$('kcv-apply').addEventListener('click',()=>{if(pending)call('apply',pending);});
 $('kcv-older-turns').addEventListener('click',()=>earlier('history'));$('kcv-older-observations').addEventListener('click',()=>earlier('observations'));
 $('kcv-adopt-head').addEventListener('click',()=>{if(current&&!readOnly()&&window.confirm('Use the latest ready context revision for future questions in this conversation? Earlier answers keep their own evidence.'))call('adopt_head',current.state.context_revision,current.state.latest_revision);});
 $('kcv-operation').addEventListener('change',()=>{refinementFields();pending=null;$('kcv-apply').hidden=true;$('kcv-change-preview').textContent='';});['kcv-objective','kcv-topic'].forEach(id=>$(id).addEventListener('input',()=>{pending=null;$('kcv-apply').hidden=true;$('kcv-change-preview').textContent='';}));
 $('kcv-observe').addEventListener('click',()=>call('observe',$('kcv-observation').value,$('kcv-method').value,$('kcv-next').value));
 root.querySelectorAll('.kcv-dialog-tabs button').forEach(b=>b.addEventListener('click',()=>traceTab(b.id.replace('kcv-tab-',''))));
 root.querySelector('.kcv-dialog-tabs').addEventListener('keydown',e=>{const tabs=[...root.querySelectorAll('.kcv-dialog-tabs button')];let i=tabs.indexOf(document.activeElement);if(i<0||!['ArrowLeft','ArrowRight'].includes(e.key))return;e.preventDefault();i=(i+(e.key==='ArrowRight'?1:-1)+tabs.length)%tabs.length;tabs[i].click();tabs[i].focus();});
 $('kcv-close-trace').addEventListener('click',()=>dialog.close());dialog.addEventListener('close',()=>{traceVersion++;if(trigger&&trigger.isConnected)trigger.focus();});
 const routed=apex.item('P1_SESSION_ID').getValue();refinementFields();if(routed){session=routed;call('open_personal');}else{try{session=sessionStorage.getItem(storageKey);}catch(_){}if(session)call('state');}
});
