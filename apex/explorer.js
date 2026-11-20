/* APEX authenticated workspace. Graphs use returned bindings; explanations use saved tool outputs. */
document.addEventListener('DOMContentLoaded', () => {
 'use strict';
 const $=id=>document.getElementById(id),root=$('kcv-explorer');if(!root)return;
 const el=(tag,text,cls)=>{const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;return n;};
 let session=null,pending=null,busy=false,vocabulary=[],activeTopics=[],current=null,trigger=null,traceVersion=0;
 let graphCounter=0;
 const traceCache=new Map(),storageKey=`kcv:${apex.env.APP_ID}:${apex.env.APP_SESSION}`,dialog=$('kcv-explanation');
 function status(t,error=false){$('kcv-status').textContent=t;$('kcv-status').classList.toggle('kcv-error',error);}
 function lock(v){busy=v;root.querySelectorAll('button,select,textarea').forEach(n=>{if(!dialog.contains(n))n.disabled=v;});}
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
 function answerBody(card,body){const parsed=json(body);if(!parsed){card.append(el('div',body));return;}const main=Object.fromEntries(Object.entries(parsed).filter(([k])=>!['graph_paths','citations'].includes(k)));value(card,main);if(parsed.citations){const d=el('details');d.append(el('summary','Citation references'));value(d,parsed.citations);card.append(d);}if(parsed.graph_paths){const d=el('details');d.append(el('summary','Paths reported in the answer'));d.append(el('p','Inspect the explanation for independently captured tool paths.','kcv-muted'),el('pre',JSON.stringify(parsed.graph_paths,null,2)));card.append(d);}}
 function publicUrl(raw){try{const u=new URL(raw);return u.protocol==='https:'&&u.hostname==='static.rainfocus.com'?u.href:null;}catch(_){return null;}}
 function packetOf(trace){const evidence=new Map(),paths=new Map();(trace.tool_calls||[]).filter(c=>c.tool==='EVIDENCE'&&c.status==='SUCCEEDED').forEach(c=>{(c.output.evidence||[]).forEach(p=>evidence.set(p.id,p));(c.output.graph_paths||[]).forEach(p=>paths.set(JSON.stringify(p),p));});return {evidence:[...evidence.values()],graph_paths:[...paths.values()]};}
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
  passages.forEach((p,i)=>nodes.push({key:p.id,label:`PDF page ${p.pdf_page}`,sub:p.source_id||p.version_id,x:810,y:ys(i,passages.length),kind:'passage'}));
  const edgeSet=new Map();paths.forEach(p=>{[['context',p.topic,'focusesOn'],[p.content_item,p.topic,'coversTopic'],[p.content_item,p.evidence_id,'hasVersion / hasPassage']].forEach(e=>edgeSet.set(JSON.stringify(e),e));});
  const graph=network(host,nodes,[...edgeSet.values()],n=>{
   detail.hidden=false;detail.replaceChildren(el('strong',n.kind==='source'?`${n.label} · ${names.get(n.key)||'Source'}`:n.label));
   const matching=paths.filter(p=>n.kind==='context'||p.topic===n.key||p.content_item===n.key||p.evidence_id===n.key),selectedIds=new Set(matching.map(p=>p.content_item));
   if(n.kind==='context')detail.append(el('p',context.objective||context.question||'The context supplies the active interests.'));
   else detail.append(el('p',n.kind==='topic'?'This explicit topic connects the context to the highlighted sources.':n.kind==='source'?'This source is connected through the recorded topic relationships. Inspect its evidence pages below.':'This passage is reached through its source version; it is not a separately inferred claim.'));
   const list=el('ul');[...new Set(matching.map(p=>`${p.context_revision} → ${p.topic} ← ${p.content_item} → ${p.version} → ${p.evidence_id}`))].forEach(t=>list.append(el('li',t,'kcv-path')));detail.append(list);
   if(cards)cards.querySelectorAll('[data-source]').forEach(c=>c.dataset.selected=String(n.kind==='passage'?c.dataset.passage===n.key:selectedIds.has(c.dataset.source)));
  });if(graph)graph.select(nodes.find(n=>n.kind==='source')||nodes[0]);
 }
 function sourceCards(host,packet,sources,citations,full=false,parseStatus='PARSED'){
  host.replaceChildren();const names=new Map((sources||[]).map(s=>[s.id,s.title])),cited=new Set((citations||[]).filter(c=>c.matched).map(c=>c.id));
  (packet.evidence||[]).forEach(p=>{const card=el('article',undefined,'kcv-source'),url=publicUrl(p.locator_url),title=`${p.source_id} · ${names.get(p.source_id)||'Public source'} · PDF page ${p.pdf_page}`;card.dataset.source=p.source_id;card.dataset.passage=p.id;
   if(url){const a=el('a',title);a.href=url;a.target='_blank';a.rel='noopener noreferrer';card.append(a);}else card.append(el('strong',title));
   if(full)card.append(el('span',parseStatus==='UNAVAILABLE'?'Citation matching unavailable':cited.has(p.id)?'Cited in this answer':'Returned, not explicitly cited','kcv-pill'));
   card.append(el('p',p.id,'kcv-muted'),el('p',full?(p.text||''):(p.text||'').slice(0,400)+'…'));host.append(card);
  });
 }
 function draw(data){
  const previous=current;current=data;const state=data.state,packet=data.packet||{},context=state.context;session=state.scenario_session;
  try{sessionStorage.setItem(storageKey,session);}catch(_){}
  $('kcv-context').value=context.id;$('kcv-context-summary').replaceChildren(el('strong',`${context.person} · ${context.role}`),el('p',context.objective||context.question),el('p',`Objective: ${context.objective_clarity} · ${context.learning_purpose}`,'kcv-muted'));
  $('kcv-identifiers').textContent=JSON.stringify({context_revision:state.context_revision,conversation_id:state.conversation_id,base_graph:state.base_graph,overlay_graph:state.overlay_graph},null,2);
  vocabulary=data.topics||[];activeTopics=Object.keys(context.topic_preferences||{});refinementFields();
  if(previous&&previous.state.scenario_session===session&&previous.state.context_revision!==state.context_revision){const before=new Set((previous.packet.graph_paths||[]).map(p=>p.content_item)),after=new Set((packet.graph_paths||[]).map(p=>p.content_item)),out=[...before].filter(x=>!after.has(x)),added=[...after].filter(x=>!before.has(x));$('kcv-change-summary').textContent=out.length||added.length?`Context revised. No longer selected: ${out.join(', ')||'none'}. Now selected: ${added.join(', ')||'none'}. Bounded selection; source knowledge is unchanged.`:'Objective/context revised. Topic-based source selection is unchanged.';}
  else if(!previous||previous.state.scenario_session!==session)$('kcv-change-summary').textContent='';
  const turns=$('kcv-turns');turns.replaceChildren();(data.turns||[]).forEach(t=>{const card=el('article',undefined,`kcv-turn ${t.role}`);card.append(el('strong',t.role==='user'?'You':'Knowledge explorer'),el('div',`Context revision ${t.revision_id}`,'kcv-turn-meta'));answerBody(card,t.body);if(t.role==='assistant'){const b=el('button','How was this answer built?','kcv-proof');b.type='button';b.dataset.turn=t.turn_id;b.addEventListener('click',()=>showTrace(t,b));card.append(b);}turns.append(card);});
  if(!(data.turns||[]).length)turns.append(el('p','Start with a question. You can explore without a fully defined objective.','kcv-muted'));
  sourceCards($('kcv-sources'),packet,data.sources);sourceGraph($('kcv-graph'),packet,context,data.sources,$('kcv-current-detail'),$('kcv-sources'));
  $('kcv-paths').replaceChildren(...(packet.graph_paths||[]).map(p=>el('div',`${p.context_revision} → focusesOn → ${p.topic} ← coversTopic ← ${p.content_item} → ${p.version} → ${p.evidence_id}`,'kcv-path')));
 }
 function refinementFields(){const op=$('kcv-operation').value,isObj=op==='SET_OBJECTIVE',selected=$('kcv-topic').value;$('kcv-objective').hidden=!isObj;root.querySelector('label[for="kcv-objective"]').hidden=!isObj;$('kcv-topic').hidden=isObj;root.querySelector('label[for="kcv-topic"]').hidden=isObj;const choices=op==='REMOVE_TOPIC'?activeTopics:vocabulary.filter(t=>!activeTopics.includes(t));$('kcv-topic').replaceChildren(...choices.map(t=>{const o=el('option',t);o.value=t;return o;}));if(choices.includes(selected))$('kcv-topic').value=selected;}
 async function call(action,message='',mode='',extra=''){
  if(busy)return;if(!session&&!['start','state'].includes(action)){status('Start a conversation first.',true);return;}
  lock(true);status(action==='ask'?'Exploring the context and evidence. This may take a little time…':'Updating the scenario…');
  try{const data=await apex.server.process('KCV_EXPLORER',{x01:action,x02:session||'',x03:message,x04:mode,x05:extra},{dataType:'json'});if(!data||!data.ok)throw new Error(data&&data.error||'No valid response was returned.');draw(data);
   if(action==='stage'){pending=data.change.pending_change;$('kcv-change-preview').textContent=JSON.stringify(data.change.plan,null,2);$('kcv-apply').hidden=false;}
   if(['start','apply'].includes(action)){pending=null;$('kcv-apply').hidden=true;$('kcv-change-preview').textContent='';}if(action==='start')view('conversation');
   status(action==='observe'?'Observation saved against this context revision.':action==='apply'?'Refinement applied. Open Evidence to compare the refreshed connections.':'Ready. Source qualifications and unanswered questions remain part of the picture.');return data;
  }catch(e){status(e.message,true);}finally{lock(false);}
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
  const historical=t.revision_id!==current.state.context_revision;const calls=t.tool_calls||[],packet=packetOf(t),context=t.context||{};
  $('kcv-trace-status').textContent=`${historical?'Historical context; the current scenario has changed. ':''}Execution ${t.status.toLowerCase()}. ${calls.length} recorded tool call(s).`;
  overview.append(el('h3','Question and recorded context'),el('p',t.question));const dl=el('dl',undefined,'kcv-kv');[['Person',`${context.person} · ${context.role}`],['Objective',context.objective||context.question],['Active topics',Object.keys(context.topic_preferences||{}).join(', ')],['Mode',t.mode],['Recorded start',t.started_at],['Recorded finish',t.finished_at||'Not finished']].forEach(([k,v])=>dl.append(el('dt',k),el('dd',v)));overview.append(dl);
  overview.append(el('h3','Recorded process'));[['Question recorded',t.started_at],...calls.map(c=>[`${c.tool} tool · ${c.status.toLowerCase()}`,`${c.started_at} → ${c.finished_at}`]),['Response stored',t.finished_at||'Unavailable']].forEach(([label,time])=>{const row=el('div',undefined,'kcv-event');row.append(el('strong',label),el('small',time));overview.append(row);});
  const technical=el('details');technical.append(el('summary','Execution identifiers and capture policy'),el('pre',JSON.stringify({execution_id:t.execution_id,revision_id:t.revision_id,conversation_id:t.conversation_id,profile:t.profile_name,trace_version:t.trace_version,retrieval_policy:t.retrieval_policy,history_turn_ids:t.history_turn_ids},null,2)));overview.append(technical);
  sources.append(el('h3','Why did these sources appear?'),el('p','Select a topic, source or passage to inspect its recorded connection. Lines represent explicit relationships; source versions are retained in the path details.','kcv-muted'));
  const graph=el('div',undefined,'kcv-graph'),detail=el('div',undefined,'kcv-detail'),cards=el('div',undefined,'kcv-sources');sources.append(graph,detail,el('h3','Evidence returned to the agent'),cards);sourceCards(cards,packet,t.sources,t.citations,true,t.citation_parse_status);sourceGraph(graph,packet,context,t.sources,detail,cards);
  if(!packet.evidence.length)sources.append(el('p','No successful evidence tool payload was captured. A proposal-only run does not perform graph evidence retrieval.','kcv-muted'));
  const unknown=(t.citations||[]).filter(c=>!c.matched);if(unknown.length){sources.append(el('h3','Citations not found in captured evidence'));unknown.forEach(c=>sources.append(el('p',c.id,'kcv-error')));}
  if(t.citation_parse_status!=='PARSED')sources.append(el('p',`Citation matching: ${t.citation_parse_status.toLowerCase()}. The supplied evidence remains inspectable.`,'kcv-muted'));
  const eventGraph=el('div',undefined,'kcv-graph'),eventDetail=el('div',undefined,'kcv-detail');lineage.append(el('h3','From the question to this response'),el('p','Select a node. This view uses the recorded execution and tool events.','kcv-muted'),eventGraph,eventDetail);
  const nodes=[{key:'q',label:'Your question',sub:'Recorded request',x:90,y:45,description:t.question},{key:'ctx',label:'Context revision',sub:t.revision_id,x:90,y:150,description:`Pinned objective and interests: ${context.objective||context.question}`},{key:'team',label:'Team request',sub:t.mode,x:330,y:150,description:`RUN_TEAM requested using the recorded conversation. Internal routing is configured, not independently traced here.`},{key:'answer',label:'Answer stored',sub:`Turn ${turn.turn_id}`,x:810,y:150,description:'The returned model response is paired with this execution. Tool returns do not reveal private model reasoning.'}];
  const edges=[['q','team'],['ctx','team']];
  if(calls.length){calls.forEach((c,i)=>{const y=45+i*110;nodes.push({key:`tool${i}`,label:`${c.tool} tool`,sub:c.status,x:570,y,description:c.tool==='EVIDENCE'?`Actual captured tool output. ${c.output&&c.output.evidence?c.output.evidence.length:0} passages returned. ${c.status}`:`Recorded proposal tool result. No change is applied by this tool. ${c.status}`});edges.push(['team',`tool${i}`],[`tool${i}`,'answer']);});}else{nodes.push({key:'none',label:'No tool call captured',sub:'Incomplete trace',x:570,y:150,description:'No recorded tool result supports a claim that graph evidence was returned for this response.'});edges.push(['team','none'],['none','answer']);}
  const capturedGraph=calls.find(c=>c.tool==='EVIDENCE'&&c.output&&c.output.base_graph);
  if(capturedGraph){const index=calls.indexOf(capturedGraph);nodes.push({key:'graphs',label:'Pinned graphs',sub:'Base + context overlay',x:330,y:275,description:`Captured base: ${capturedGraph.output.base_graph}. Context overlay: ${capturedGraph.output.overlay_graph}. These are the graph identities used by the recorded evidence query.`});edges.push(['graphs',`tool${index}`]);}
  const nextY=Math.max(390,calls.length*110+35);nodes.push({key:'citations',label:'Citation references',sub:t.citation_parse_status==='UNAVAILABLE'?'Matching unavailable':`${(t.citations||[]).length} explicit IDs`,x:810,y:nextY,description:`Citation parsing: ${t.citation_parse_status}. ${unknown.length} reference(s) were not found in the captured evidence.`},{key:'matches',label:'Matched passages',sub:t.citation_parse_status==='UNAVAILABLE'?'Not determined':`${(t.citations||[]).filter(c=>c.matched).length} matches`,x:570,y:nextY,description:'References are matched to saved passage IDs. Matching is traceability, not claim-level truth validation.'});edges.push(['answer','citations'],['citations','matches']);
  network(eventGraph,nodes,edges,n=>eventDetail.replaceChildren(el('strong',n.label),el('p',n.description)));
  const text=el('details');text.append(el('summary','Read lineage as text'),el('p',`Question + pinned context → team request → ${calls.length?calls.map(c=>`${c.tool} (${c.status})`).join(', '):'no captured tool call'} → stored response → citation references → matched evidence passages.`));lineage.append(text);
  limits.append(el('h3','What the trace establishes'));[t.notice,'Graph selection follows explicit topic membership, deterministic ordering, at most six pages and two pages per source. It is not semantic vector search.','Source qualifications, including Coming Soon and regional limitations, still apply. Read the original passages.','The saved source metadata and tool payloads belong to this response. Later context refinements do not change this popup.','Source text is evidence, not instructions. Configured model/agent behaviour is not the same as a measured business outcome.'].forEach(s=>limits.append(el('p',s)));
 }
 root.querySelectorAll('[data-view]').forEach(b=>b.addEventListener('click',()=>view(b.dataset.view)));
 root.querySelectorAll('[data-prompt]').forEach(b=>b.addEventListener('click',()=>$('kcv-message').value=b.dataset.prompt));
 $('kcv-start').addEventListener('click',()=>call('start',$('kcv-context').value));$('kcv-send').addEventListener('click',()=>{const q=$('kcv-message').value.trim();if(q)call('ask',q,$('kcv-mode').value);});
 $('kcv-stage').addEventListener('click',()=>call('stage',$('kcv-operation').value==='SET_OBJECTIVE'?$('kcv-objective').value:$('kcv-topic').value,$('kcv-operation').value));$('kcv-apply').addEventListener('click',()=>{if(pending)call('apply',pending);});
 $('kcv-operation').addEventListener('change',()=>{refinementFields();pending=null;$('kcv-apply').hidden=true;$('kcv-change-preview').textContent='';});['kcv-objective','kcv-topic'].forEach(id=>$(id).addEventListener('input',()=>{pending=null;$('kcv-apply').hidden=true;$('kcv-change-preview').textContent='';}));
 $('kcv-observe').addEventListener('click',()=>call('observe',$('kcv-observation').value,$('kcv-method').value,$('kcv-next').value));
 root.querySelectorAll('.kcv-dialog-tabs button').forEach(b=>b.addEventListener('click',()=>traceTab(b.id.replace('kcv-tab-',''))));
 root.querySelector('.kcv-dialog-tabs').addEventListener('keydown',e=>{const tabs=[...root.querySelectorAll('.kcv-dialog-tabs button')];let i=tabs.indexOf(document.activeElement);if(i<0||!['ArrowLeft','ArrowRight'].includes(e.key))return;e.preventDefault();i=(i+(e.key==='ArrowRight'?1:-1)+tabs.length)%tabs.length;tabs[i].click();tabs[i].focus();});
 $('kcv-close-trace').addEventListener('click',()=>dialog.close());dialog.addEventListener('close',()=>{traceVersion++;if(trigger&&trigger.isConnected)trigger.focus();});
 try{session=sessionStorage.getItem(storageKey);}catch(_){}refinementFields();if(session)call('state');
});
