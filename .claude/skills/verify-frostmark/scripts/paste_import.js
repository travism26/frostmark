() => {
  // web.sh import fills in the code below. One paste event plus Cmd+V puts the whole code in the title
  // screen's Import box at once; typing it key by key outruns the bridge's 60 s eval timeout
  // headless, and a timed-out eval loses the tab. Coordinates are the 1440x900 title screen.
  const c = document.querySelector('canvas');
  const click = (x, y) => { for (const t of ['mousemove','mousedown','mouseup']) c.dispatchEvent(new MouseEvent(t, {bubbles:true, clientX:x, clientY:y, button:0, buttons: t==='mouseup'?0:1})); };
  click(720, 560);
  return new Promise(res => setTimeout(() => {
    const dt = new DataTransfer();
    dt.setData('text/plain', '$CODE');
    window.dispatchEvent(new ClipboardEvent('paste', {clipboardData: dt, bubbles: true}));
    for (const t of ['keydown','keyup']) c.dispatchEvent(new KeyboardEvent(t, {bubbles:true, key:'v', code:'KeyV', metaKey:true}));
    setTimeout(() => { click(720, 650); setTimeout(() => res('pasted ' + '$CODE'.length + ' characters and clicked Import code'), 300); }, 800);
  }, 300));
}
