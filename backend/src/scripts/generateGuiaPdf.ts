import fs from 'fs';
import path from 'path';
import { DocumentoAcademico, RAIZ } from './pdf/estiloAcademico';

/**
 * Guía de estudio en PDF a partir de docs/GUIA_DE_ESTUDIO.md (se guarda junto al Markdown).
 * Uso: npx ts-node src/scripts/generateGuiaPdf.ts (desde backend/).
 */
async function generateGuiaPdf() {
  const md = fs.readFileSync(path.join(RAIZ, 'docs/GUIA_DE_ESTUDIO.md'), 'utf-8').replace(/\r/g, '');
  const primerParrafo = md.split('\n').find((l) => l.trim() && !l.startsWith('#')) ?? '';

  const d = new DocumentoAcademico({
    titulo: 'Guía de Estudio',
    subtitulo: 'Cómo funciona Luxxito Sports: API REST, seguridad, concurrencia y preguntas de sustentación',
    tituloCorto: 'Guía de estudio',
    archivo: 'GUIA_DE_ESTUDIO.pdf',
    carpeta: path.join(RAIZ, 'docs'),
    indice: true,
  });
  d.portada(primerParrafo);
  d.nuevaPagina();
  d.markdown(md.slice(md.indexOf('\n## ')), (enc) => {
    if (enc.join() === 'Concepto,Significado,En el proyecto') return [0.2, 0.45, 0.35];
    if (enc.join() === 'Término,Significado corto') return [0.3, 0.7];
    if (enc[0] === 'Tiempo') return [0.12, 0.44, 0.44];
    if (enc[0] === 'Método') return [0.12, 0.34, 0.14, 0.4];
    if (enc[0] === 'Código') return [0.22, 0.3, 0.48];
    return undefined;
  });
  await d.finalizar();
}

generateGuiaPdf();
