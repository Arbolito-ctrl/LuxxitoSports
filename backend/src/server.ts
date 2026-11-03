import dotenv from 'dotenv';
import app from './app';
import { getDbMode } from './config/database';

dotenv.config();

const PORT = Number(process.env.PORT) || 3000;

app.listen(PORT, '0.0.0.0', () => {
  const mode = getDbMode();
  console.log('==============================================================');
  console.log(` Luxxito Sports API REST ejecutándose en http://localhost:${PORT}/api`);
  console.log(` Modo de persistencia activo: ${mode}`);
  if (mode === 'LOCAL_STORE') {
    console.log(
      ' [Aviso] Agrega tu DATABASE_URL o SUPABASE_URL en backend/.env para conectar a Supabase.'
    );
  }
  console.log('==============================================================');
});
