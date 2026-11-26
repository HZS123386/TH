// The native form starts the report; Flutter opens the accepted report in the same tab.
(() => {
  const main = document.getElementById('fate-birth');
  const host = document.getElementById('fate-flutter');
  const byId = id => document.getElementById(id);
  const countries = {th:'TH', en:'SG', zh:'CN', vi:'VN', my:'MM', km:'KH', lo:'LA', ms:'MY', id:'ID'};
  const stages = ['unspecified','considering','searching','offer'];
  const retryKey = 'fate-birth-reload';
  const submissionKey = 'fate-birth-submission';
  const noticeVersion = 'h5-data-use-3';
  const params = new URLSearchParams(location.search);
  let language = document.documentElement.lang;
  let topic = params.get('reading') === 'love' || params.get('topic') === 'love' ? 'love'
    : params.get('topic') === 'career' ? 'career' : 'life';
  let career = topic === 'career';
  let copy, place, submitToFlutter, pending, waiting = false, failed = false, outdated = false;
  let edited = false, searchTimer, locationRequest, offset = 0, total = 0;
  let originalProfile, originalPlace, creating = false, acceptedReport;
  let submission, retrySubmission = false;
  let checkedSubmission = false, activePicker, locationTouchActive = false;
  let generationVisual;
  const labels = window.fateBirthCopies || {};
  const firstPages = new Map();

  async function fetchPlaces(country, query, offset, signal) {
    const args = new URLSearchParams({country,level:['CN','TH'].includes(country) ? 'locality' : 'city',query,offset:String(offset)});
    const response = await fetch('/api/thai-locations?' + args,{signal});
    if (!response.ok) throw Error('places');
    const result = await response.json();
    if (!Array.isArray(result?.items) || result.items.some(item => !item || typeof item !== 'object')) {
      throw new SyntaxError('Invalid location list');
    }
    return result;
  }

  function firstPage(country) {
    if (!firstPages.has(country)) {
      const abort = new AbortController();
      const timer = setTimeout(() => abort.abort(),12000);
      firstPages.set(country,fetchPlaces(country,'',0,abort.signal)
        .catch(error => { firstPages.delete(country); throw error; })
        .finally(() => clearTimeout(timer)));
    }
    return firstPages.get(country);
  }

  function track(action, page = 'birth_form') {
    try {
      const visit = JSON.parse(window.fateH5.visitContext());
      const owner = visit.id && window.fateH5.ownerKey();
      if (owner) window.fateH5.trackActivity(JSON.stringify({...visit,activity:{page,action}}),owner,'/api/landing/visits');
    } catch { /* Analytics are optional. */ }
  }

  function show(visible) {
    if (!visible && byId('birth-picker')?.open) byId('birth-picker').close();
    main.hidden = !visible;
    host.inert = visible;
    document.documentElement.toggleAttribute('data-birth-visible',visible);
  }

  function placeName(item) {
    const field = language === 'zh' ? 'nameChinese' : language === 'th' ? 'nameThai' : 'nameEnglish';
    return item[field] || item.nameEnglish || item.nameChinese || item.nameThai || '';
  }

  function latestBirthDate() {
    const today = window.fateH5.today(place?.timeZone || 'Asia/Bangkok');
    return today < '2099-12-31' ? today : '2099-12-31';
  }

  function updatePickerField(field) {
    const input = byId('birth-' + field);
    byId('birth-' + field + '-trigger').disabled = input.disabled;
    if (!copy) return;
    let display = input.value;
    if (field === 'date') {
      display = display ? new Intl.DateTimeFormat(language,{
        year:'numeric',month:'long',day:'numeric',calendar:'gregory',timeZone:'UTC'
      }).format(new Date(display + 'T00:00:00Z')) : copy.jy.dateParts.placeholder;
    }
    byId('birth-' + field + '-value').textContent = display || '--:--';
  }

  function setWheelValue(wheel, value, align = false) {
    const selected = Math.max(wheel.minimum,Math.min(wheel.maximum,value));
    wheel.items.children[wheel.value - wheel.minimum]?.removeAttribute('data-selected');
    wheel.value = selected;
    const item = wheel.items.children[selected - wheel.minimum];
    item.setAttribute('data-selected','');
    wheel.rail.setAttribute('aria-valuenow',String(selected));
    wheel.rail.setAttribute('aria-valuetext',item.textContent);
    if (align) wheel.rail.scrollTop = item.getBoundingClientRect().height * (selected - wheel.minimum);
  }

  function setWheelBounds(wheel, maximum, value) {
    if (wheel.maximum === maximum) {
      if (value !== wheel.value) setWheelValue(wheel,value,true);
      return;
    }
    wheel.maximum = maximum;
    wheel.rail.setAttribute('aria-valuemax',String(maximum));
    const options = [];
    for (let number = wheel.minimum; number <= maximum; number++) {
      const item = document.createElement('div');
      item.className = 'birth-wheel-item';
      item.dataset.value = String(number);
      item.textContent = wheel.text(number);
      options.push(item);
    }
    wheel.items.replaceChildren(...options);
    setWheelValue(wheel,value,true);
  }

  function makeWheel(minimum, label, text, onChange) {
    const rail = document.createElement('div'), items = document.createElement('div');
    rail.className = 'birth-wheel';
    rail.tabIndex = 0;
    rail.setAttribute('role','spinbutton');
    rail.setAttribute('aria-label',label);
    rail.setAttribute('aria-valuemin',String(minimum));
    items.className = 'birth-wheel-items';
    items.setAttribute('aria-hidden','true');
    rail.append(items);
    const wheel = {rail,items,minimum,text};
    const select = (value,align) => {
      const before = wheel.value;
      setWheelValue(wheel,value,align);
      if (wheel.value !== before) onChange?.();
    };
    rail.addEventListener('scroll',() => {
      if (!byId('birth-picker').open || !rail.isConnected) return;
      const height = items.firstElementChild.getBoundingClientRect().height;
      if (!height) return;
      const value = minimum + Math.round(rail.scrollTop / height);
      if (value !== wheel.value) select(value,false);
    },{passive:true});
    rail.addEventListener('click',event => {
      const item = event.target.closest('.birth-wheel-item');
      if (item) select(Number(item.dataset.value),true);
    });
    rail.addEventListener('keydown',event => {
      const steps = {ArrowUp:1,ArrowDown:-1,PageUp:10,PageDown:-10};
      let value;
      if (Object.hasOwn(steps,event.key)) value = wheel.value + steps[event.key];
      else if (event.key === 'Home') value = minimum;
      else if (event.key === 'End') value = wheel.maximum;
      else return;
      event.preventDefault();
      select(value,true);
    });
    return wheel;
  }

  function limitDateWheels(month, day) {
    const [yearWheel,monthWheel,dayWheel] = activePicker.wheels;
    const [lastYear,lastMonth,lastDay] = activePicker.maximum;
    const year = yearWheel.value;
    setWheelBounds(monthWheel,year === lastYear ? lastMonth : 12,month ?? monthWheel.value);
    const chosenMonth = monthWheel.value;
    const daysInMonth = new Date(Date.UTC(year,chosenMonth,0)).getUTCDate();
    const dayLimit = year === lastYear && chosenMonth === lastMonth ? Math.min(daysInMonth,lastDay) : daysInMonth;
    setWheelBounds(dayWheel,dayLimit,day ?? dayWheel.value);
  }

  function openPicker(field) {
    const dialog = byId('birth-picker'), input = byId('birth-' + field);
    if (!copy || dialog.open || input.disabled) return;
    closeOptions();
    track('select_birth_' + field);
    firstPage(countries[language]).catch(() => {});
    const wrapper = byId('birth-picker-wheels');
    const dates = field === 'date';
    const pad = number => String(number).padStart(2,'0');
    let wheels;
    if (dates) {
      input.max = latestBirthDate();
      const parts = copy.jy.dateParts;
      const months = new Intl.DateTimeFormat(language,{month:'short',calendar:'gregory',timeZone:'UTC'});
      const refresh = () => limitDateWheels();
      const label = (part,number) => {
        if (language === 'zh') return number + parts[part];
        return part === 'month' ? months.format(new Date(Date.UTC(2000,number - 1,1))) : String(number);
      };
      wheels = ['year','month','day'].map((part,index) =>
        makeWheel(index === 0 ? Number(input.min.slice(0,4)) : 1,parts[part],number => label(part,number),
          index < 2 ? refresh : undefined));
      activePicker = {field,wheels,maximum:input.max.split('-').map(Number)};
    } else {
      wheels = ['hour','minute'].map(unit => {
        const parts = new Intl.NumberFormat(language,{style:'unit',unit,unitDisplay:'long'}).formatToParts(1);
        return makeWheel(0,parts.find(part => part.type === 'unit').value,pad);
      });
      activePicker = {field,wheels};
    }
    byId('birth-picker-title').textContent = copy.jy[field];
    wrapper.toggleAttribute('data-time',!dates);
    wrapper.replaceChildren(...wheels.map(wheel => wheel.rail));
    dialog.showModal();
    if (dates) {
      const [year,month,day] = (input.value || '1990-07-15').split('-').map(Number);
      setWheelBounds(wheels[0],activePicker.maximum[0],year);
      limitDateWheels(month,day);
    } else {
      const [hour,minute] = (input.value || '07:15').split(':').map(Number);
      setWheelBounds(wheels[0],23,hour);
      setWheelBounds(wheels[1],59,minute);
    }
  }

  function confirmPicker() {
    const {field,wheels} = activePicker;
    const input = byId('birth-' + field);
    const parts = wheels.map(wheel => String(wheel.value).padStart(2,'0'));
    input.value = parts.join(field === 'date' ? '-' : ':');
    input.dispatchEvent(new Event('input',{bubbles:true}));
    input.dispatchEvent(new Event('change',{bubbles:true}));
    byId('birth-picker').close();
  }

  function progress() {
    const date = byId('birth-date'), time = byId('birth-time');
    if (!date.value && !time.value && !time.disabled && !place) return 'empty';
    if (!date.value || !date.validity.valid || date.value > latestBirthDate()) return 'date';
    if (!time.disabled && !/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(time.value)) return 'time';
    return place?.countryCode === countries[language] && place.timeZone ? 'complete' : 'place';
  }

  function closeOptions() {
    clearTimeout(searchTimer);
    locationRequest?.abort();
    byId('birth-options').hidden = true;
    byId('birth-city').setAttribute('aria-expanded','false');
  }

  function choosePlace(item) {
    markEdited();
    place = item;
    byId('birth-city').value = placeName(item);
    byId('birth-date').max = latestBirthDate();
    closeOptions();
    track('form_progress_' + progress());
    byId('birth-city').focus();
  }

  function optionButton(label, action) {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = label;
    let gesture, touchActivation = 0;
    const point = event => event.touches?.[0] || event.changedTouches?.[0] || event;
    const releaseLocationTouch = () => setTimeout(() => { locationTouchActive = false; },0);
    const start = event => {
      if (event.pointerType === 'mouse') return;
      const current = point(event);
      locationTouchActive = true;
      gesture = {x:current.clientX,y:current.clientY,moved:false};
    };
    const move = event => {
      if (!gesture) return;
      const current = point(event);
      if (Math.abs(current.clientX - gesture.x) > 8 || Math.abs(current.clientY - gesture.y) > 8) gesture.moved = true;
    };
    const end = event => {
      if (!gesture) return;
      const activate = !gesture.moved;
      gesture = null;
      releaseLocationTouch();
      if (!activate) return;
      event.preventDefault();
      touchActivation = Date.now();
      action();
    };
    const cancel = () => { gesture = null; releaseLocationTouch(); };
    // Facebook's iOS WebView can blur the search field and remove the menu
    // before its delayed click. Complete a short tap on pointer-up, but leave
    // vertical drags untouched so the native momentum scroller can run.
    if (window.PointerEvent) {
      button.addEventListener('pointerdown',start);
      button.addEventListener('pointermove',move);
      button.addEventListener('pointerup',end);
      button.addEventListener('pointercancel',cancel);
    } else {
      button.addEventListener('touchstart',start,{passive:true});
      button.addEventListener('touchmove',move,{passive:true});
      button.addEventListener('touchend',end,{passive:false});
      button.addEventListener('touchcancel',cancel);
    }
    button.addEventListener('click',event => {
      if (Date.now() - touchActivation < 1000) { event.preventDefault(); return; }
      action();
    });
    return button;
  }

  async function searchPlaces(more = false) {
    if (!copy) return;
    locationRequest?.abort();
    const request = locationRequest = new AbortController();
    const menu = byId('birth-options'), city = byId('birth-city');
    const country = countries[language], query = place ? '' : city.value.trim();
    if (!more) { menu.replaceChildren(); offset = total = 0; }
    menu.querySelector('[data-next]')?.remove();
    const status = document.createElement('p');
    status.textContent = copy.jy.regionPending;
    menu.append(status);
    menu.hidden = false;
    city.setAttribute('aria-expanded','true');
    const viewport = window.visualViewport;
    const rect = city.getBoundingClientRect();
    menu.classList.toggle('open-above',(viewport ? viewport.height + viewport.offsetTop : innerHeight) - rect.bottom < 155 && rect.top > 155);
    let result;
    try {
      result = !more && !query ? await firstPage(country) : await fetchPlaces(country,query,more ? offset : 0,request.signal);
      if (request.signal.aborted) return;
      status.remove();
      const rows = result.items;
      for (const item of rows.filter(row => row.countryCode === country)) {
        const name = placeName(item);
        const button = optionButton(name,() => choosePlace(item));
        button.setAttribute('role','option');
        const region = item[language === 'zh' ? 'provinceNameChinese' : language === 'th' ? 'provinceNameThai' : 'provinceNameEnglish'] || item.provinceNameEnglish;
        const detail = [...new Set([region,item.nameEnglish].filter(value => value && value !== name))].join(' · ');
        if (detail) { const small = document.createElement('small'); small.textContent = detail; button.append(small); }
        menu.append(button);
      }
      offset += rows.length;
      total = rows.length ? result.total ?? offset : offset;
      if (!offset) { status.textContent = copy.ui.noCity; menu.append(status); }
      if (offset < total) {
        const next = optionButton(copy.ui.morePlaces,() => searchPlaces(true));
        next.dataset.next = '';
        menu.append(next);
      }
    } catch (error) {
      if (request.signal.aborted) return;
      // Only a search that still shows an error needs client diagnostics; HTTP failures are recorded by the API.
      if (!result && (error instanceof TypeError || error instanceof SyntaxError || error.name === 'AbortError')) {
        window.fateH5.trackFailure('/api/thai-locations',error instanceof SyntaxError ? 'badResult' : 'network','GET');
      }
      status.textContent = copy.ui.network;
      const retry = optionButton(copy.jy.regionRetry,() => { status.remove(); searchPlaces(more); });
      retry.dataset.next = '';
      menu.append(retry);
    }
  }

  function setLabels() {
    const j = copy.jy;
    document.documentElement.lang = language;
    document.title = j.title;
    const marriage = !career && language !== 'zh';
    const words = {...j,...j.portrait,
      formTitle: marriage ? copy.marriage.title : j.formTitle,
      formCaption: marriage ? copy.marriage.form_hint : j.formCaption};
    for (const node of main.querySelectorAll('[data-copy]')) node.textContent = words[node.dataset.copy];
    byId('birth-language').value = language;
    byId('birth-language').setAttribute('aria-label',j.language);
    byId('birth-city').placeholder = j.citySearch;
    byId('birth-date').max = latestBirthDate();
    byId('birth-picker-confirm').textContent = copy.ui.confirm;
    byId('birth-picker-close').textContent = copy.ui.close;
    updatePickerField('date');
    updatePickerField('time');
    byId('birth-career').hidden = !career;
    const question = byId('birth-question'), selected = question.value;
    question.replaceChildren(new Option(j.questionTitle,''),
      ...j.questions.map((item,i) => new Option(item.join('  '),stages[i])), new Option(j.writeQuestion,'custom'));
    question.value = selected || '';
    byId('birth-custom').hidden = question.value !== 'custom';
    byId('birth-custom').placeholder = j.questionTitle;
    byId('birth-custom').setAttribute('aria-label',j.writeQuestion);
    byId('birth-submit').textContent = outdated ? j.openLatest : j.topics[topic].action;
    byId('birth-retry').textContent = byId('birth-generation-retry').textContent = copy.generation.retry;
    const boards = copy.themes.map(group => {
      const board = document.createElement('div');
      board.className = 'birth-board';
      const illustration = document.createElement('span');
      illustration.className = 'birth-art';
      illustration.setAttribute('aria-hidden','true');
      const list = document.createElement('ul');
      for (const title of group) { const li = document.createElement('li'); li.textContent = title; list.append(li); }
      board.append(illustration,list);
      return board;
    });
    byId('birth-boards').replaceChildren(...boards);
  }

  async function localize(lang) {
    language = lang;
    // Raw Flutter previews use the same translation asset; release builds inline the small form subset.
    if (!labels[lang]) {
      const response = await fetch('assets/assets/copy/' + lang + '.json');
      if (!response.ok) throw Error('copy');
      const data = await response.json();
      labels[lang] = {jy:data.jy[lang],ui:data.ui[lang],marriage:data.marriage[lang],generation:data.generation[lang],
        preparing:data.jy[lang].interpretation.steps.basics.status,
        themes:Object.values(data.jyThemes).map(group => group.map(item => item[lang]))};
    }
    if (lang !== language || !main.firstElementChild) return;
    copy = labels[lang];
    setLabels();
  }

  function values() {
    const question = byId('birth-question').value;
    return {language,date:byId('birth-date').value,time:byId('birth-time').value,
      unknown:byId('birth-unknown').checked,place,question:career ? question : '',
      customQuestion:career && question === 'custom' ? byId('birth-custom').value : ''};
  }

  function restore(data) {
    byId('birth-date').value = data.date || '';
    byId('birth-time').value = data.time || '';
    byId('birth-time').disabled = byId('birth-unknown').checked = !!data.unknown;
    place = data.place?.countryCode === countries[language] ? data.place : null;
    byId('birth-city').value = place ? placeName(place) : '';
    byId('birth-date').max = latestBirthDate();
    updatePickerField('date');
    updatePickerField('time');
    byId('birth-question').value = data.customQuestion ? 'custom' : data.question || '';
    byId('birth-custom').hidden = byId('birth-question').value !== 'custom';
    byId('birth-custom').value = data.customQuestion || '';
    if (place?.id && !place.placeType) {
      const initial = place;
      const args = new URLSearchParams({country:initial.countryCode,level:'detail',query:initial.id});
      fetch('/api/thai-locations?' + args).then(r => r.ok ? r.json() : null).then(result => {
        const resolved = result?.resolved;
        if (place === initial && resolved?.id === initial.id && resolved.timeZone === initial.timeZone &&
            resolved.countryCode === countries[language]) {
          place = resolved;
          byId('birth-city').value = placeName(resolved);
        }
      }).catch(() => {});
    }
  }

  function say(message) { byId('birth-message').textContent = message || ''; }

  function markEdited() {
    edited = true;
    if (pending && !creating) {
      pending = null;
      waiting = false;
      byId('birth-submit').disabled = byId('birth-language').disabled = false;
    }
    if (!failed) say('');
  }

  function engineFailed() {
    failed = true;
    if (!main.firstElementChild || main.hidden || !copy) return;
    if (creating) {
      // Let the create response arrive before offering a reload that could lose its ID.
      byId('birth-generation-status').textContent = fateBootTranslations[language].failed;
      byId('birth-generation-retry').hidden = !acceptedReport && !retrySubmission;
      return;
    }
    pending = null;
    waiting = false;
    say(fateBootTranslations[language].failed);
    byId('birth-submit').disabled = false;
    byId('birth-retry').hidden = false;
  }

  function engineReady() {
    if (!failed || !submitToFlutter) return;
    failed = false;
    if (!retrySubmission) {
      byId('birth-retry').hidden = byId('birth-generation-retry').hidden = true;
      if (creating) byId('birth-generation-status').textContent = acceptedReport ? copy.generation.preview : copy.preparing;
      else say('');
    }
    queueMicrotask(dispatch);
  }

  window.addEventListener('fate-app-ready',engineReady);
  window.addEventListener('online',() => { if (retrySubmission) startReport(submission); });

  function reopenAcceptedReport(id) {
    const url = new URL('report.html',document.baseURI);
    url.search = new URLSearchParams({id,lang:language});
    try {
      // Keep the visit on this history entry when tab storage cannot carry the accepted report.
      const visit = JSON.parse(window.fateH5.visitContext());
      history.replaceState({openingReport:id,...(visit.id ? {fateVisit:visit} : {})},'',url);
    } catch {
      url.searchParams.set('from_form','1');
      location.replace(url);
      return;
    }
    location.reload();
  }

  function retry() {
    if (retrySubmission) { startReport(submission); return; }
    if (acceptedReport) {
      reopenAcceptedReport(acceptedReport.id);
      return;
    }
    // Keep edited fields only for this explicit reload, then consume the draft once.
    try { sessionStorage.setItem(retryKey,JSON.stringify({path:location.pathname + location.search,at:Date.now(),form:values()})); } catch {}
    location.reload();
  }

  function reportInput() {
    const form = values();
    const samePlace = originalPlace && place.id === originalPlace.id && place.timeZone === originalPlace.timeZone;
    const start = window.fateH5.today('Asia/Bangkok');
    const question = form.customQuestion.trim();
    const preset = career && stages.includes(form.question) && !question;
    return {
      report_kind: career ? 'fortune' : 'marriage',
      profile: {
        display_name:'', birth_date:form.date, birth_time:form.unknown ? null : form.time,
        birthplace:(samePlace && originalProfile?.birthplace) || (place.nameEnglish || '') + ', ' + place.countryCode,
        timezone:place.timeZone, language, country_code:place.countryCode, location_id:place.id || null,
        latitude:samePlace ? originalProfile?.latitude ?? null : null,
        longitude:samePlace ? originalProfile?.longitude ?? null : null
      },
      year:preset ? Number(start.slice(0,4)) : new Date().getFullYear(),
      ...(preset ? {career_question:{stage:form.question,start}} : {}),
      ...(question ? {user_question:question} : {})
    };
  }

  async function reportRequest(path, owner, visit, body, submissionId) {
    const method = body ? 'POST' : 'GET';
    const headers = {'Accept-Language':language, 'X-Report-Key':owner};
    if (visit.id) headers['X-Visit-Id'] = visit.id;
    if (body) headers['Content-Type'] = 'application/json';
    if (submissionId) headers['Idempotency-Key'] = submissionId;
    const abort = new AbortController();
    const timer = setTimeout(() => abort.abort(),15000);
    try {
      const response = await fetch(path,{method,headers,cache:'no-store',signal:abort.signal,body:body && JSON.stringify(body)});
      if (!response.ok) {
        const detail = await response.json().catch(() => ({}));
        if ([detail.code,detail.detail].includes('landing_notice_outdated')) throw Error('noticeOutdated');
        const reason = response.status === 429 ? 'busy' : [409,422].includes(response.status) ? 'badResult' : 'network';
        throw Object.assign(Error(reason),{status:response.status,code:detail.code || detail.detail});
      }
      return await response.json();
    } catch (error) {
      if (visit.id && (error instanceof TypeError || error instanceof SyntaxError || abort.signal.aborted)) {
        const endpoint = path.split('?')[0].replace(/(\/submissions\/)\S+$/,'$1{submission_id}');
        window.fateH5.trackFailure(endpoint,error instanceof SyntaxError ? 'badResult' : 'network',method);
      }
      throw error;
    } finally { clearTimeout(timer); }
  }

  function setFormWaiting(busy) {
    const form = byId('birth-form');
    for (const child of form.children) {
      if (child.id !== 'birth-message' && child.id !== 'birth-retry') child.inert = busy;
    }
    byId('birth-submit').disabled = byId('birth-language').disabled = busy;
  }

  function returnToForm(message) {
    if (creating) {
      track('view');
      track('form_progress_' + progress());
    }
    creating = waiting = false;
    const screen = byId('birth-generation');
    screen.hidden = true;
    main.removeAttribute('data-generating');
    setFormWaiting(false);
    if (outdated) byId('birth-submit').textContent = copy.jy.openLatest;
    say(message);
    byId('birth-submit').focus();
    byId('birth-retry').hidden = !failed;
  }

  function showGeneration() {
    const screen = byId('birth-generation');
    document.activeElement?.blur?.();
    byId('birth-generation-title').textContent = copy.generation.previewTitle;
    byId('birth-generation-status').textContent = copy.preparing;
    byId('birth-generation-retry').hidden = true;
    main.setAttribute('data-generating','');
    screen.hidden = false;
    show(true);
    main.scrollTop = 0;
    screen.focus({preventScroll:true});

    // Let WebKit paint the feedback before navigation. The timeout prevents a
    // backgrounded in-app browser from waiting forever for animation frames.
    const painted = new Promise(resolve => {
      let complete = false;
      const finish = () => {
        if (complete) return;
        complete = true;
        clearTimeout(timer);
        resolve();
      };
      const timer = setTimeout(finish,160);
      requestAnimationFrame(() => requestAnimationFrame(finish));
    });
    return Promise.all([painted,new Promise(resolve => setTimeout(resolve,320))]);
  }

  async function ownerDigest(owner) {
    if (!crypto.subtle?.digest) return null;
    try { return fateHex(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(owner)))); }
    catch { return null; }
  }

  async function saveSubmission(value) {
    submission = value;
    try {
      if (value) sessionStorage.setItem(submissionKey,JSON.stringify(value));
      else sessionStorage.removeItem(submissionKey);
      if (!history.state?.[submissionKey]) return;
    } catch { /* Some embedded browsers allow history state even when tab storage is disabled. */ }
    if (value) {
      const {owner,...receipt} = value;
      receipt.device = await ownerDigest(owner);
      try { history.replaceState({...history.state,[submissionKey]:receipt},''); } catch {}
    } else {
      const state = {...history.state};
      if (!state[submissionKey]) return;
      delete state[submissionKey];
      try { history.replaceState(state,''); } catch {}
    }
  }

  async function restoreSubmission() {
    if (checkedSubmission) return;
    checkedSubmission = true;
    const form = byId('birth-form');
    let saved;
    try { saved = JSON.parse(sessionStorage.getItem(submissionKey)); } catch {}
    if (!saved && history.state?.[submissionKey]) {
      saved = history.state[submissionKey];
      if (saved.path === location.pathname + location.search && /^[A-Za-z0-9_-]{8,128}$/.test(saved.reportId || '')) {
        reopenAcceptedReport(saved.reportId);
        return true;
      }
      const owner = window.fateH5.ownerKey();
      const digest = await ownerDigest(owner);
      if (!owner || !digest || saved.device !== digest) { await saveSubmission(null); return; }
      saved = {...saved,owner};
    }
    if (!form.isConnected || creating) return;
    if (!saved || saved.path !== location.pathname + location.search) return;
    if (saved.owner !== window.fateH5.ownerKey() || !saved.input?.profile ||
        !/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(saved.id)) {
      await saveSubmission(null);
      return;
    }
    const profile = saved.input.profile;
    career = saved.input.report_kind === 'fortune';
    originalProfile = profile;
    originalPlace = saved.place;
    restore({date:profile.birth_date,time:profile.birth_time,unknown:!profile.birth_time,place:saved.place,
      question:saved.input.career_question?.stage,customQuestion:saved.input.user_question});
    edited = true;
    startReport(saved);
    return true;
  }

  async function findSubmission(record) {
    try {
      return await reportRequest('/api/life-reports/submissions/' + record.id,record.owner,record.visit);
    } catch (error) {
      if (error.status === 404 && error.code === 'life_submission_not_found') return null;
      throw error;
    }
  }

  async function startReport(saved) {
    const first = !creating;
    const form = byId('birth-form');
    retrySubmission = false;
    creating = waiting = true;
    setFormWaiting(true);
    byId('birth-retry').hidden = true;
    const generationShown = showGeneration();
    if (first) track('view','generating_preview');
    let consentAccepted = false;
    try {
      const owner = window.fateH5.ownerKey();
      if (saved && saved.owner !== owner) throw Error('storage');
      const record = saved || {id:fateUuid(),owner,input:reportInput(),place,visit:JSON.parse(window.fateH5.visitContext()),
        path:location.pathname + location.search,notice:noticeVersion,sent:false};
      await saveSubmission(record);
      const {input,visit} = record;
      let report = record.sent ? await findSubmission(record) : null;
      if (!form.isConnected) return;
      if (!report) {
        const config = await reportRequest('/api/landing/config',owner,visit);
        if (!config?.notice_version) throw Error('consentError');
        if (config.notice_version !== noticeVersion || record.notice !== noticeVersion) throw Error('noticeOutdated');
        const consent = await reportRequest('/api/landing/consents',owner,visit,{notice_version:noticeVersion,granted:true});
        if (consent?.accepted !== true || consent.notice_version !== noticeVersion) throw Error('consentError');
        if (!form.isConnected) return;
        consentAccepted = true;
        try { localStorage.setItem('fate-data-use-version',noticeVersion); } catch {}
        if (!record.sent) {
          track('consent_accept','generating_preview');
          track('generate','generating_preview');
        }
        record.sent = true;
        await saveSubmission(record);
        report = await reportRequest('/api/life-reports?wait=false',owner,visit,{
          ...input,...(visit.id ? {landing_visit:visit} : {})
        },record.id);
      }
      if (typeof report?.id !== 'string' || !/^[A-Za-z0-9_-]{8,128}$/.test(report.id)) throw Error('badResult');
      if (!form.isConnected) return;
      acceptedReport = report;
      try {
        sessionStorage.setItem('active-preview',report.id);
      } catch {
        // A refresh can now go straight to the owned report without retaining the birth details.
        history.replaceState({...history.state,[submissionKey]:{path:record.path,reportId:report.id}},'');
      }
      if (history.state?.[submissionKey]?.reportId !== report.id) await saveSubmission(null);
      else submission = null;
      byId('birth-generation-status').textContent = report.preview_state === 'ready' ? copy.generation.ready : copy.generation.preview;
      await generationShown;
      // The landing page owns report creation. Opening the accepted report must
      // never wait for Flutter to initialize or for the Dart bridge to attach.
      reopenAcceptedReport(report.id);
      return;
    } catch (error) {
      if (!form.isConnected) return;
      if (submission?.sent && ![400,401,403,409,422].includes(error.status) &&
          !['badResult','noticeOutdated','consentError','storage'].includes(error.message)) {
        retrySubmission = true;
        byId('birth-generation-status').textContent = copy.generation[error.message] || copy.ui.network;
        byId('birth-generation-retry').hidden = false;
        return;
      }
      await saveSubmission(null);
      outdated = error.message === 'noticeOutdated';
      const reason = consentAccepted || outdated || error.message === 'storage' ? error.message : 'consentError';
      if (consentAccepted) track('generation_failed','generating_preview');
      returnToForm(copy.jy[reason] || copy.generation[reason] || copy.ui[reason] || copy.ui.network);
    }
  }

  async function dispatch() {
    if (failed || !submitToFlutter || !pending) return;
    const send = submitToFlutter, data = pending;
    pending = null;
    try {
      const error = await send(JSON.stringify(data));
      if (!error) {
        if (data.page === 'report' && submission) await saveSubmission(null);
        return;
      }
      if (send !== submitToFlutter) return;
      throw Error(error);
    } catch (error) {
      if (send !== submitToFlutter) return;
      if (acceptedReport && error.message !== 'badResult') {
        byId('birth-generation-status').textContent = copy.ui.network;
        byId('birth-generation-retry').hidden = false;
        return;
      }
      if (acceptedReport) {
        acceptedReport = null;
        await saveSubmission(null);
        try { sessionStorage.removeItem('active-preview'); } catch {}
      }
      returnToForm(copy.ui[error.message] || copy.ui.network);
    }
  }

  function submit(event) {
    event.preventDefault();
    if (!copy || waiting) return;
    if (outdated) { const url = new URL(location.href); url.searchParams.set('preview','notice-' + Date.now()); location.assign(url.href); return; }
    track('click_generate_report');
    const step = progress();
    track('form_progress_' + step);
    if (step !== 'complete') {
      const field = step === 'time' ? 'time' : step === 'place' ? 'city' : 'date';
      say(copy.ui[{time:'timeRequired',city:'invalidPlace',date:'invalidDate'}[field]]);
      byId('birth-' + (field === 'city' ? field : field + '-trigger')).focus();
      track('invalid_form');
      return;
    }
    startReport();
  }

  function mount() {
    if (main.firstElementChild) return;
    main.append(byId('fate-birth-template').content.cloneNode(true));
    const form = byId('birth-form'), city = byId('birth-city');
    form.addEventListener('submit',submit);
    form.addEventListener('input',markEdited);
    for (const field of ['date','time']) {
      byId('birth-' + field + '-trigger').addEventListener('click',() => openPicker(field));
      byId('birth-' + field).addEventListener('input',() => updatePickerField(field));
      byId('birth-' + field).addEventListener('change',() => track('form_progress_' + progress()));
    }
    byId('birth-picker-confirm').addEventListener('click',confirmPicker);
    byId('birth-picker-close').addEventListener('click',() => byId('birth-picker').close());
    byId('birth-picker').addEventListener('close',() => {
      if (!byId('birth-picker').open) activePicker = undefined;
    });
    byId('birth-unknown').addEventListener('change',event => {
      byId('birth-time').disabled = event.target.checked;
      updatePickerField('time');
      track('form_progress_' + progress());
    });
    byId('birth-question').addEventListener('change',event => {
      byId('birth-custom').hidden = event.target.value !== 'custom';
      byId('birth-custom').value = '';
    });
    city.addEventListener('click',() => { if (byId('birth-options').hidden) { track('select_birthplace'); searchPlaces(); } });
    city.addEventListener('input',() => {
      place = null;
      closeOptions();
      searchTimer = setTimeout(searchPlaces,180);
      track('form_progress_' + progress());
    });
    form.addEventListener('keydown',event => {
      if (event.key === 'Escape') { closeOptions(); return; }
      if (!event.target.closest('.birth-location')) return;
      const buttons = [...byId('birth-options').querySelectorAll('button')];
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        if (byId('birth-options').hidden) { track('select_birthplace'); searchPlaces(); return; }
        buttons[Math.max(0,Math.min(buttons.length-1,buttons.indexOf(event.target)+(event.key === 'ArrowDown' ? 1 : -1)))]?.focus();
      }
    });
    form.addEventListener('focusout',event => {
      if (!event.target.closest('.birth-location') || event.relatedTarget?.closest('.birth-location')) return;
      // WebKit embedded browsers often omit relatedTarget. Let the pending
      // pointer/click finish before deciding whether the menu really lost focus.
      setTimeout(() => {
        if (!locationTouchActive && !document.activeElement?.closest('.birth-location')) closeOptions();
      },0);
    });
    byId('birth-language').addEventListener('change',async event => {
      const lang = event.target.value, previous = language;
      closeOptions();
      try {
        await localize(lang);
        if (language !== lang) return;
        edited = true;
        if (place?.countryCode !== countries[lang]) { place = null; city.value = ''; }
        const url = new URL(location.href);
        url.searchParams.set('lang',lang);
        history.replaceState(history.state,'',url);
        byId('birth-date').max = latestBirthDate();
        say('');
        track('form_progress_' + progress());
      } catch { await localize(previous); say(copy.ui.network); }
    });
    byId('birth-retry').addEventListener('click',retry);
    byId('birth-generation-retry').addEventListener('click',retry);
    const warmGenerationVisual = () => {
      generationVisual = new Image();
      generationVisual.decoding = 'async';
      generationVisual.src = new URL('assets/assets/images/report-loading-animated.webp',document.baseURI).href;
    };
    if ('requestIdleCallback' in window) requestIdleCallback(warmGenerationVisual,{timeout:2500});
    else setTimeout(warmGenerationVisual,1200);
    localize(language).then(async () => {
      if (!form.isConnected) return;
      try {
        const raw = sessionStorage.getItem(retryKey);
        sessionStorage.removeItem(retryKey);
        const saved = JSON.parse(raw);
        if (saved && saved.at > Date.now()-300000 && saved.path === location.pathname+location.search && !edited) {
          restore(saved.form); edited = true;
        }
      } catch {}
      // A refresh can resume an in-flight submission with the original ID.
      if (!await restoreSubmission() && form.isConnected && !creating) {
        show(true);
        track('view');
        track('form_progress_' + progress());
      }
      if (failed) engineFailed();
    }).catch(() => {
      if (!form.isConnected) return;
      show(true);
      track('view');
      say(fateBootTranslations[language].failed);
      byId('birth-retry').hidden = false;
    });
    trackFatePageView();
  }

  window.fateBirthForm = {
    engineFailed,
    get submitting() { return creating; },
    get editing() { return !main.hidden && (edited || creating); },
    attach(raw, send) {
      const initial = JSON.parse(raw);
      const first = !main.firstElementChild;
      if (first) language = initial.language;
      topic = initial.topic;
      career = initial.career;
      mount();
      if (copy) setLabels();
      originalProfile = initial.input?.profile;
      originalPlace = initial.place;
      if (initial.input && !edited && !creating) {
        const input = initial.input, profile = input.profile || {};
        restore({date:profile.birth_date,time:profile.birth_time,unknown:!profile.birth_time,place:initial.place,
          question:input.career_question?.stage,customQuestion:input.user_question});
        if (!main.hidden) track('form_progress_' + progress());
      }
      submitToFlutter = send;
      engineReady();
      queueMicrotask(dispatch);
    },
    detach() {
      if (main.firstElementChild) closeOptions();
      show(false);
      submitToFlutter = pending = place = copy = acceptedReport = originalPlace = originalProfile = null;
      waiting = creating = edited = outdated = retrySubmission = false;
      // Remove event listeners together with the controls before the router returns home.
      main.replaceChildren();
    }
  };
  main.addEventListener('pointerdown',event => {
    if (main.firstElementChild && !event.target.closest('.birth-location')) closeOptions();
  });
  let resuming = false;
  try { resuming = /^[A-Za-z0-9_-]{8,128}$/.test(sessionStorage.getItem('active-preview') || ''); } catch {}
  const home = location.pathname.endsWith('/') || location.pathname.endsWith('/index.html') ||
    location.pathname + '/' === new URL(document.baseURI).pathname;
  if (home && !resuming && !window.fateBoot.upgrading) mount();
})();
