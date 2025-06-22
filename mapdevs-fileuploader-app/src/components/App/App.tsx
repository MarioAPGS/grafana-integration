import React, { useState } from 'react';
import { AppRootProps } from '@grafana/data';
import { Input, Button } from '@grafana/ui';


function App(props: AppRootProps) {
  const [file, setFile] = useState<File | null>(null);
  const [name, setName] = useState('');
  const [loading, setLoading] = useState(false);
  const [success, setSuccess] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async () => {
    setSuccess(null);
    setError(null);
    if (!file) {
      setError('Seleccione un archivo primero');
      return;
    }
    setLoading(true);
    try {
      const form = new FormData();
      form.append('file', file);
      form.append('name', name || file.name);
      const res = await fetch('/api/plugins/mapdevs-fileuploader-app/resources/upload', {
        method: 'POST',
        body: form,
      });
      if (res.ok) {
        setSuccess('Archivo subido correctamente');
        setFile(null);
        setName('');
      } else {
        const txt = await res.text();
        setError('Error: ' + txt);
      }
    } catch (e: any) {
      setError('Error: ' + (e.message || e.toString()));
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{ maxWidth: 400 }}>
      <h2>Subir archivo al servidor de Grafana</h2>
      <div className="gf-form" style={{ marginBottom: 8 }}>
        <input type="file" onChange={e => setFile(e.target.files?.[0] ?? null)} />
      </div>
      <div className="gf-form" style={{ marginBottom: 8 }}>
        <Input value={name} placeholder="Nombre destino (opcional)" onChange={e => setName(e.currentTarget.value)} />
      </div>
      <Button onClick={handleSubmit} disabled={loading} variant="primary">
        {loading ? 'Subiendo...' : 'Subir'}
      </Button>
      {success && <div style={{ color: 'green', marginTop: 8 }}>{success}</div>}
      {error && <div style={{ color: 'red', marginTop: 8 }}>{error}</div>}
    </div>
  );
}

export default App;
