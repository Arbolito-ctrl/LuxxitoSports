import fs from 'fs';
import path from 'path';
import { DocumentoAcademico, RAIZ } from './pdf/estiloAcademico';

/**
 * Documentación de la API en PDF a partir de docs/API_DOCUMENTATION.md.
 * Uso: npx ts-node src/scripts/generateApiPdf.ts (desde backend/).
 */
async function generateApiPdf() {
  const md = fs.readFileSync(path.join(RAIZ, 'docs/API_DOCUMENTATION.md'), 'utf-8').replace(/\r/g, '');
  const inicioCuerpo = md.indexOf('\n## ');
  const cabecera = md.slice(0, inicioCuerpo);
  const cuerpo = md.slice(inicioCuerpo);

  // Las líneas "**Dato:** valor" de la cabecera pasan a una tabla de datos generales
  const datos = [...cabecera.matchAll(/^\*\*([^*]+):\*\*\s*(.+?)\s*$/gm)].map((m) => [m[1], m[2]]);

  const d = new DocumentoAcademico({
    titulo: 'Documentación de la API REST',
    subtitulo: 'Luxxito Sports: endpoints, contratos JSON, seguridad y códigos HTTP',
    tituloCorto: 'Documentación de la API REST',
    archivo: 'DOCUMENTACION_API_TALLER3.pdf',
    indice: true,
    // Con un ### por endpoint el índice no cabe en una página: se listan solo las secciones
    nivelesIndice: 1,
  });
  d.portada(
    'Referencia de la API REST propia del proyecto: recursos, reglas de negocio que aplica el servidor, autenticación con JWT y roles, titularidad de reservas, concurrencia y ejemplos de solicitudes y respuestas.'
  );

  d.nuevaPagina();
  d.h1('Datos generales');
  d.tabla(
    [
      { titulo: 'Aspecto', ancho: 0.27 },
      { titulo: 'Detalle', ancho: 0.73 },
    ],
    datos,
    { titulo: 'Datos generales de la API.' }
  );
  d.parrafo(
    'Este documento se genera a partir de `docs/API_DOCUMENTATION.md`. Todos los ejemplos de respuesta se obtuvieron llamando a la API. El contrato formal está en `contracts/openapi.yaml` (OpenAPI 3.0.3) y cada endpoint se puede probar en Swagger UI: `https://luxxito-sports-api.onrender.com/api/docs`.'
  );

  d.markdown(cuerpo, (enc) => {
    if (enc.length === 5 && enc[0] === '#') return [0.05, 0.1, 0.27, 0.38, 0.2];
    return undefined;
  });

  await d.finalizar();
}

generateApiPdf();
