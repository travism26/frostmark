() => {
  const c = document.querySelector('canvas');
  const key = (k, code) => { for (const t of ['keydown','keyup']) c.dispatchEvent(new KeyboardEvent(t, {bubbles:true, key:k, code:code})); };
  const click = (x, y) => { for (const t of ['mousemove','mousedown','mouseup']) c.dispatchEvent(new MouseEvent(t, {bubbles:true, clientX:x, clientY:y, button:0, buttons: t==='mouseup'?0:1})); };
  click(720, 560);
  return new Promise(res => setTimeout(() => {
    const s = '$CODE';
    for (let i = 0; i < s.length; i++) { const ch = s[i]; const code = /[a-z]/i.test(ch) ? 'Key' + ch.toUpperCase() : /[0-9]/.test(ch) ? 'Digit' + ch : ch === '/' ? 'Slash' : 'Equal'; key(ch, code); }
    setTimeout(() => { click(720, 650); setTimeout(() => res('typed ' + s.length + ' and clicked import'), 200); }, 1500);
  }, 200));
}
