document.querySelectorAll('.btn-eliminar').forEach(btn => {
  btn.addEventListener('click', e => {
    if (!confirm('¿Seguro que deseas eliminar este registro?')) e.preventDefault();
  });
});

setTimeout(() => {
  document.querySelectorAll('.alert').forEach(a => a.remove());
}, 4000);