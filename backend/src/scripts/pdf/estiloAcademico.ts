import fs from 'fs';
import path from 'path';
import PDFDocument from 'pdfkit';

/**
 * Estilo académico común de los PDF del Taller 3: tipografía serif, carátula institucional,
 * índice, tablas y figuras numeradas, encabezado y pie en cada página de contenido.
 */
export const RAIZ = path.join(__dirname, '../../../..');
export const ENTREGABLES = path.join(RAIZ, 'entregables');
export const REPO_MAIN = 'https://github.com/Arbolito-ctrl/LuxxitoSports/tree/main';
export const API_PUBLICA = 'https://luxxito-sports-api.onrender.com/api';
export const INTEGRANTES = [
  { nombre: 'Steven Cadillo', rol: 'Cliente móvil, pagos, pruebas y demostración' },
  { nombre: 'Elvis Arboleda', rol: 'Base de datos Supabase y despliegue' },
  { nombre: 'Juan Medina', rol: 'Backend, Render e infraestructura' },
];

const TINTA = '#111827';
const AZUL = '#1F3A5F';
const GRIS = '#4B5563';
const REGLA = '#9CA3AF';
const FONDO_CODIGO = '#F3F4F6';

// Helvetica/Times/Courier estándar solo cubren WinAnsi: se sustituyen los símbolos que no existen
const SUSTITUTOS: Record<string, string> = { '→': '»', '↔': '<->', '≥': '>=', '≤': '<=', '✅': 'Sí', '⋮': '(menú)', '×': '×' };
const WINANSI_EXTRA = '€‚ƒ„…†‡ˆ‰Š‹ŒŽ‘’“”•–—˜™š›œžŸ';
export function limpiar(texto: string, unirEspacios = true): string {
  const limpio = [...texto.replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')]
    .map((c) => SUSTITUTOS[c] ?? c)
    .join('')
    .split('')
    .filter((c) => c.charCodeAt(0) < 256 || WINANSI_EXTRA.includes(c))
    .join('');
  return unirEspacios ? limpio.replace(/ {2,}/g, ' ') : limpio;
}
// PDFKit justifica mal un texto con formato en medio de una línea: solo se justifica el texto
// sin formato o con una única etiqueta en negrita al inicio
const alineacion = (t: string): 'left' | 'justify' => (/[`*]/.test(t.replace(/^\*\*[^*]+\*\*/, '')) ? 'left' : 'justify');
const sinMarcas = (t: string) => limpiar(t).replace(/\*/g, '').replace(/`/g, '');

export interface OpcionesDocumento {
  titulo: string;
  subtitulo: string;
  tituloCorto: string;
  archivo: string;
  indice?: boolean;
  /** 1 = el índice solo lista los títulos ##; 2 (por defecto) también los ###. */
  nivelesIndice?: 1 | 2;
  tamTexto?: number;
  carpeta?: string; // por defecto, entregables/
}

export interface Columna {
  titulo: string;
  ancho: number; // fracción del ancho útil
}

export class DocumentoAcademico {
  readonly doc: PDFKit.PDFDocument;
  private readonly tam: number;
  private titulos: { nivel: number; texto: string; pagina: number }[] = [];
  private nTablas = 0;
  private nFiguras = 0;
  private stream: fs.WriteStream;

  constructor(private readonly o: OpcionesDocumento) {
    this.tam = o.tamTexto ?? 10.8;
    this.doc = new PDFDocument({
      size: 'A4',
      margins: { top: 68, bottom: 60, left: 64, right: 64 },
      bufferPages: true,
      info: {
        Title: `${o.titulo} - Luxxito Sports`,
        Author: INTEGRANTES.map((i) => i.nombre).join(', '),
        Subject: 'SI806 - Taller 3: Desarrollo e integración de una API REST',
      },
    });
    // PDF_DIR permite generar en otra carpeta (por ejemplo, si el PDF está abierto en un visor)
    const carpeta = process.env.PDF_DIR || o.carpeta || ENTREGABLES;
    fs.mkdirSync(carpeta, { recursive: true });
    this.stream = fs.createWriteStream(path.join(carpeta, o.archivo));
    this.doc.pipe(this.stream);
  }

  get izquierda() {
    return this.doc.page.margins.left;
  }
  get ancho() {
    return this.doc.page.width - this.doc.page.margins.left - this.doc.page.margins.right;
  }
  private get limite() {
    return this.doc.page.height - this.doc.page.margins.bottom;
  }
  private paginaActual() {
    const r = this.doc.bufferedPageRange();
    return r.start + r.count - 1;
  }
  espacio(alto: number) {
    if (this.doc.y + alto > this.limite) this.doc.addPage();
  }

  // ------------------------------------------------------------------ carátula
  portada(resumen: string) {
    const d = this.doc;
    const W = d.page.width;
    const H = d.page.height;
    const x = this.izquierda;
    const w = this.ancho;
    d.lineWidth(1.4).strokeColor(AZUL).moveTo(x, 58).lineTo(x + w, 58).stroke();
    d.lineWidth(0.5).moveTo(x, 62).lineTo(x + w, 62).stroke();

    d.y = 86;
    d.font('Times-Bold').fontSize(15).fillColor(TINTA).text('UNIVERSIDAD NACIONAL DE INGENIERÍA', x, d.y, { width: w, align: 'center' });
    d.font('Times-Roman').fontSize(12).fillColor(GRIS).text('Facultad de Ingeniería Industrial y de Sistemas', { width: w, align: 'center' });
    d.fontSize(11).text('SI806 · Desarrollo Adaptativo e Integrado del Software', { width: w, align: 'center' });

    d.y = 225;
    d.font('Times-Roman').fontSize(11.5).fillColor(AZUL).text('TALLER 3 · DESARROLLO E INTEGRACIÓN DE UNA API REST', x, d.y, {
      width: w,
      align: 'center',
      characterSpacing: 0.8,
    });
    d.moveDown(0.9);
    d.font('Times-Bold').fontSize(25).fillColor(TINTA).text(this.o.titulo, { width: w, align: 'center' });
    d.moveDown(0.35);
    d.font('Times-Italic').fontSize(14).fillColor(GRIS).text(this.o.subtitulo, { width: w, align: 'center' });
    d.moveDown(1.1);
    const yRegla = d.y;
    d.lineWidth(0.8).strokeColor(AZUL).moveTo(W / 2 - 60, yRegla).lineTo(W / 2 + 60, yRegla).stroke();
    d.moveDown(1.1);
    d.font('Times-Roman').fontSize(11).fillColor(TINTA).text(limpiar(resumen), x + 40, d.y, { width: w - 80, align: 'center', lineGap: 1.5 });

    d.y = 505;
    d.font('Times-Bold').fontSize(12).fillColor(TINTA).text('Integrantes', x, d.y, { width: w, align: 'center' });
    d.moveDown(0.4);
    for (const i of INTEGRANTES) {
      d.font('Times-Bold').fontSize(11.5).fillColor(TINTA).text(i.nombre, { width: w, align: 'center' });
      d.font('Times-Italic').fontSize(10).fillColor(GRIS).text(i.rol, { width: w, align: 'center' });
      d.moveDown(0.3);
    }
    d.moveDown(0.8);
    const enlace = (etiqueta: string, url: string) => {
      d.font('Times-Bold').fontSize(10.5).fillColor(TINTA).text(etiqueta, { width: w, align: 'center' });
      d.font('Courier').fontSize(9.5).fillColor(AZUL).text(url, { width: w, align: 'center', link: url, underline: false });
      d.moveDown(0.35);
    };
    enlace('Repositorio en GitHub (rama main)', REPO_MAIN);
    enlace('API pública', API_PUBLICA);

    d.font('Times-Roman').fontSize(11).fillColor(TINTA).text('Lima, noviembre de 2026', x, H - 92, { width: w, align: 'center' });
    d.lineWidth(0.5).strokeColor(AZUL).moveTo(x, H - 62).lineTo(x + w, H - 62).stroke();
    d.lineWidth(1.4).moveTo(x, H - 58).lineTo(x + w, H - 58).stroke();
    d.x = x;

    if (this.o.indice) d.addPage(); // página reservada para el índice
  }

  nuevaPagina() {
    this.doc.addPage();
  }

  // ------------------------------------------------------------------ títulos y texto
  h1(texto: string) {
    const t = sinMarcas(texto);
    this.espacio(70);
    if (this.doc.y > this.doc.page.margins.top + 4) this.doc.moveDown(0.7);
    this.titulos.push({ nivel: 1, texto: t, pagina: this.paginaActual() });
    this.doc.font('Times-Bold').fontSize(14).fillColor(AZUL).text(t, this.izquierda, this.doc.y, { width: this.ancho });
    this.doc.moveDown(0.35);
  }

  h2(texto: string) {
    const t = sinMarcas(texto);
    this.espacio(50);
    this.doc.moveDown(0.3);
    this.titulos.push({ nivel: 2, texto: t, pagina: this.paginaActual() });
    this.doc.font('Times-Bold').fontSize(11.8).fillColor(TINTA).text(t, this.izquierda, this.doc.y, { width: this.ancho });
    this.doc.moveDown(0.2);
  }

  /** Texto con **negrita** y `código` en línea. */
  private rico(texto: string, opciones: PDFKit.Mixins.TextOptions, tam = this.tam, base = 'Times-Roman') {
    const partes = limpiar(texto)
      .split(/(\*\*[^*]+\*\*|\*[^*\s][^*]*\*|`[^`]+`)/)
      .filter(Boolean);
    const tramos = partes.map((parte) => {
      if (parte.startsWith('**')) return { fuente: 'Times-Bold', t: parte.slice(2, -2).replace(/`/g, ''), size: tam, color: TINTA };
      if (parte.startsWith('*')) return { fuente: 'Times-Italic', t: parte.slice(1, -1), size: tam, color: TINTA };
      if (parte.startsWith('`')) return { fuente: 'Courier', t: parte.slice(1, -1), size: tam - 1.4, color: AZUL };
      return { fuente: base, t: parte, size: tam, color: TINTA };
    });
    // PDFKit descarta el espacio inicial de un tramo encadenado: se pasa al final del tramo anterior
    for (let i = 1; i < tramos.length; i++) {
      if (tramos[i].t.startsWith(' ')) {
        tramos[i].t = tramos[i].t.trimStart();
        tramos[i - 1].t += ' ';
      }
    }
    // Un tramo que solo tenía espacios queda vacío: PDFKit lo dibuja como un hueco
    // grande (por ejemplo entre "**Acceso:**" y un `código`), así que se descarta.
    const visibles = tramos.filter((s) => s.t !== '');
    visibles.forEach((s, i) => {
      this.doc.font(s.fuente).fontSize(s.size).fillColor(s.color).text(s.t, { ...opciones, continued: i < visibles.length - 1 });
    });
  }

  parrafo(texto: string) {
    this.doc.x = this.izquierda;
    this.rico(texto, { width: this.ancho, align: alineacion(texto), lineGap: 1.4 });
    this.doc.moveDown(0.45);
  }

  /** Párrafo que empieza con una etiqueta en negrita. */
  p(etiqueta: string, cuerpo: string) {
    this.parrafo(`**${etiqueta}** ${cuerpo}`);
  }

  lista(items: string[], numerada = false) {
    const d = this.doc;
    for (const [n, item] of items.entries()) {
      this.espacio(this.tam * 2.4);
      const y = d.y;
      d.font('Times-Roman').fontSize(this.tam).fillColor(TINTA).text(numerada ? `${n + 1}.` : '•', this.izquierda + 4, y, { lineBreak: false });
      d.x = this.izquierda + 20;
      d.y = y;
      this.rico(item, { width: this.ancho - 20, align: alineacion(item), lineGap: 1.4 });
      d.moveDown(0.25);
    }
    d.x = this.izquierda;
    d.moveDown(0.2);
  }

  nota(texto: string) {
    const d = this.doc;
    this.espacio(30);
    const y = d.y;
    d.x = this.izquierda + 14;
    this.rico(texto, { width: this.ancho - 14, align: alineacion(texto) }, this.tam - 0.8, 'Times-Italic');
    d.lineWidth(1.5).strokeColor(REGLA).moveTo(this.izquierda + 4, y).lineTo(this.izquierda + 4, d.y).stroke();
    d.x = this.izquierda;
    d.moveDown(0.5);
  }

  // ------------------------------------------------------------------ tablas (estilo booktabs)
  tabla(columnas: Columna[], filas: string[][], opciones: { titulo?: string; tam?: number } = {}) {
    const d = this.doc;
    const tam = opciones.tam ?? this.tam - 1.8;
    const x0 = this.izquierda;
    const anchos = columnas.map((c) => c.ancho * this.ancho);
    const pad = 3.2;
    const fuenteCelda = (c: string, negrita: boolean) =>
      negrita ? 'Times-Bold' : /^`[^`]+`$/.test(c.trim()) ? 'Courier' : 'Times-Roman';
    const altoFila = (celdas: string[], negrita: boolean) =>
      Math.max(
        ...celdas.map((c, i) => {
          d.font(fuenteCelda(c, negrita)).fontSize(tam);
          return d.heightOfString(sinMarcas(c), { width: anchos[i] - pad * 2 });
        })
      ) +
      pad * 2;
    const dibujar = (celdas: string[], negrita: boolean) => {
      const alto = altoFila(celdas, negrita);
      const y = d.y;
      let x = x0;
      celdas.forEach((c, i) => {
        d.font(fuenteCelda(c, negrita))
          .fontSize(fuenteCelda(c, negrita) === 'Courier' ? tam - 0.8 : tam)
          .fillColor(TINTA)
          .text(sinMarcas(c), x + pad, y + pad, { width: anchos[i] - pad * 2 });
        x += anchos[i];
      });
      d.y = y + alto;
      return alto;
    };
    const encabezado = () => {
      d.lineWidth(1).strokeColor(TINTA).moveTo(x0, d.y).lineTo(x0 + this.ancho, d.y).stroke();
      dibujar(
        columnas.map((c) => c.titulo),
        true
      );
      d.lineWidth(0.6).strokeColor(TINTA).moveTo(x0, d.y).lineTo(x0 + this.ancho, d.y).stroke();
    };

    if (opciones.titulo) {
      this.nTablas += 1;
      this.espacio(60);
      d.font('Times-Bold').fontSize(9.8).fillColor(TINTA).text(`Tabla ${this.nTablas}. `, x0, d.y, { continued: true });
      d.font('Times-Italic').text(limpiar(opciones.titulo), { width: this.ancho });
      d.moveDown(0.25);
    } else {
      this.espacio(40);
    }
    encabezado();
    filas.forEach((fila, i) => {
      if (d.y + altoFila(fila, false) > this.limite) {
        d.lineWidth(1).strokeColor(TINTA).moveTo(x0, d.y).lineTo(x0 + this.ancho, d.y).stroke();
        d.addPage();
        encabezado();
      }
      const y = d.y;
      dibujar(fila, false);
      if (i < filas.length - 1) d.lineWidth(0.25).strokeColor('#D1D5DB').moveTo(x0, d.y).lineTo(x0 + this.ancho, d.y).stroke();
      else d.lineWidth(1).strokeColor(TINTA).moveTo(x0, d.y).lineTo(x0 + this.ancho, d.y).stroke();
      void y;
    });
    d.x = x0;
    d.moveDown(0.7);
  }

  // ------------------------------------------------------------------ código
  codigo(texto: string) {
    const d = this.doc;
    // Las líneas que no caben en el ancho útil se parten
    const maxCaracteres = Math.floor((this.ancho - 16) / (8.2 * 0.6));
    const lineas = texto
      .replace(/\s+$/, '')
      .split('\n')
      .flatMap((l) => (l.length <= maxCaracteres ? [l] : l.match(new RegExp(`.{1,${maxCaracteres}}`, 'g')) ?? [l]));
    const lh = 10.4;
    const x0 = this.izquierda;
    this.espacio(Math.min(lineas.length, 6) * lh + 10);
    let y = d.y + 2;
    const banda = (alto: number) => {
      d.rect(x0, y, this.ancho, alto).fill(FONDO_CODIGO);
      d.lineWidth(1.6).strokeColor(AZUL).moveTo(x0, y).lineTo(x0, y + alto).stroke();
    };
    banda(4);
    y += 4;
    for (const linea of lineas) {
      if (y + lh > this.limite) {
        d.addPage();
        y = d.y;
      }
      banda(lh);
      d.font('Courier').fontSize(8.2).fillColor(TINTA).text(limpiar(linea, false), x0 + 10, y + 1.2, { lineBreak: false, width: this.ancho - 14 });
      y += lh;
    }
    banda(4);
    d.x = x0;
    d.y = y + 12;
  }

  // ------------------------------------------------------------------ figuras
  figuras(items: { ruta: string; pie: string }[], anchoImagen = 150) {
    const d = this.doc;
    // Dimensiones desde la cabecera IHDR del PNG
    const cabecera = fs.readFileSync(items[0].ruta).subarray(16, 24);
    const alto = (anchoImagen * cabecera.readUInt32BE(4)) / cabecera.readUInt32BE(0);
    const gap = 18;
    const total = items.length * anchoImagen + (items.length - 1) * gap;
    d.font('Times-Italic').fontSize(9);
    const altoPie = 11 + Math.max(...items.map((it) => d.heightOfString(limpiar(it.pie), { width: anchoImagen + 10 })));
    this.espacio(alto + altoPie + 20);
    const y = d.y + 4;
    let x = this.izquierda + (this.ancho - total) / 2;
    for (const it of items) {
      this.nFiguras += 1;
      d.image(it.ruta, x, y, { width: anchoImagen });
      d.lineWidth(0.5).strokeColor(REGLA).rect(x, y, anchoImagen, alto).stroke();
      d.font('Times-Bold').fontSize(9).fillColor(TINTA).text(`Figura ${this.nFiguras}`, x - 5, y + alto + 6, {
        width: anchoImagen + 10,
        align: 'center',
      });
      d.font('Times-Italic').fillColor(GRIS).text(limpiar(it.pie), x - 5, y + alto + 17, { width: anchoImagen + 10, align: 'center' });
      x += anchoImagen + gap;
    }
    d.x = this.izquierda;
    d.y = y + alto + 6 + altoPie + 14;
  }

  // ------------------------------------------------------------------ Markdown sencillo
  /**
   * Renderiza títulos ##/###, párrafos, listas, tablas, citas, bloques de código e
   * imágenes PNG (`![pie](ruta)`, con la ruta relativa a `carpetaImagenes`).
   */
  markdown(
    md: string,
    anchosTabla?: (encabezados: string[]) => number[] | undefined,
    carpetaImagenes?: string
  ) {
    const lineas = md.replace(/\r/g, '').split('\n');
    let i = 0;
    let parrafo: string[] = [];
    const cerrarParrafo = () => {
      if (parrafo.length) this.parrafo(parrafo.join(' ').replace(/ \n /g, '\n'));
      parrafo = [];
    };
    while (i < lineas.length) {
      const l = lineas[i];
      if (l.startsWith('```')) {
        cerrarParrafo();
        const bloque: string[] = [];
        i += 1;
        while (i < lineas.length && !lineas[i].startsWith('```')) bloque.push(lineas[i++]);
        this.codigo(bloque.join('\n'));
      } else if (/^!\[[^\]]*\]\([^)]+\.png\)\s*$/.test(l) && carpetaImagenes) {
        cerrarParrafo();
        const [, pie, ruta] = l.match(/^!\[([^\]]*)\]\(([^)]+)\)/)!;
        this.figuras([{ ruta: path.join(carpetaImagenes, ruta), pie }], 330);
      } else if (l.startsWith('## ')) {
        cerrarParrafo();
        this.h1(l.slice(3));
      } else if (l.startsWith('### ')) {
        cerrarParrafo();
        this.h2(l.slice(4));
      } else if (l.startsWith('# ') || /^-{3,}$/.test(l.trim())) {
        cerrarParrafo();
      } else if (l.startsWith('|')) {
        cerrarParrafo();
        const filas: string[][] = [];
        while (i < lineas.length && lineas[i].startsWith('|')) {
          const celdas = lineas[i].trim().replace(/^\||\|$/g, '').split('|').map((c) => c.trim());
          if (!celdas.every((c) => /^:?-+:?$/.test(c))) filas.push(celdas);
          i += 1;
        }
        i -= 1;
        const [enc, ...cuerpo] = filas;
        const fr = anchosTabla?.(enc) ?? enc.map(() => 1 / enc.length);
        this.tabla(
          enc.map((t, k) => ({ titulo: t, ancho: fr[k] })),
          cuerpo
        );
      } else if (/^\s*- /.test(l)) {
        cerrarParrafo();
        const items: string[] = [];
        while (i < lineas.length && /^\s*- /.test(lineas[i])) items.push(lineas[i++].replace(/^\s*- (\[ \] )?/, ''));
        i -= 1;
        this.lista(items);
      } else if (/^\d+\. /.test(l)) {
        cerrarParrafo();
        const items: string[] = [];
        while (i < lineas.length && /^\d+\. /.test(lineas[i])) items.push(lineas[i++].replace(/^\d+\. /, ''));
        i -= 1;
        this.lista(items, true);
      } else if (l.startsWith('> ')) {
        cerrarParrafo();
        this.nota(l.slice(2));
      } else if (!l.trim()) {
        cerrarParrafo();
      } else {
        parrafo.push(l.endsWith('  ') ? `${l.trim()} \n` : l.trim());
      }
      i += 1;
    }
    cerrarParrafo();
  }

  // ------------------------------------------------------------------ cierre
  async finalizar(): Promise<number> {
    const d = this.doc;
    const r = d.bufferedPageRange();
    const x = this.izquierda;
    const w = this.ancho;

    if (this.o.indice) {
      d.switchToPage(1);
      d.x = x;
      d.y = d.page.margins.top;
      d.font('Times-Bold').fontSize(16).fillColor(AZUL).text('Índice', { width: w });
      d.moveDown(0.8);
      const niveles = this.o.nivelesIndice ?? 2;
      for (const t of this.titulos.filter((x) => x.nivel <= niveles)) {
        const sangria = t.nivel === 1 ? 0 : 16;
        const y = d.y;
        d.font(t.nivel === 1 ? 'Times-Bold' : 'Times-Roman').fontSize(t.nivel === 1 ? 11 : 10.3).fillColor(TINTA);
        // Títulos largos se recortan para que cada entrada ocupe una sola línea
        let texto = t.texto;
        while (d.widthOfString(texto) > w - sangria - 50) texto = `${texto.slice(0, -2).trimEnd()}…`.replace(/……$/, '…');
        const anchoTitulo = d.widthOfString(texto);
        d.text(texto, x + sangria, y, { width: w - sangria - 40, lineBreak: false });
        d.font('Times-Roman').text(String(t.pagina), x, y, { width: w, align: 'right', lineBreak: false });
        d.lineWidth(0.6).strokeColor(REGLA).dash(1, { space: 2.5 })
          .moveTo(x + sangria + anchoTitulo + 5, y + 9).lineTo(x + w - 18, y + 9).stroke().undash();
        d.y = y + (t.nivel === 1 ? 19 : 16);
      }
    }

    for (let i = 1; i < r.count; i++) {
      d.switchToPage(i);
      const margen = d.page.margins.bottom;
      d.page.margins.bottom = 0;
      const H = d.page.height;
      d.font('Times-Italic').fontSize(8.8).fillColor(GRIS);
      d.text('Luxxito Sports · SI806 Taller 3', x, 38, { width: w / 2, lineBreak: false });
      d.text(this.o.tituloCorto, x + w / 2, 38, { width: w / 2, align: 'right', lineBreak: false });
      d.lineWidth(0.5).strokeColor(REGLA).moveTo(x, 51).lineTo(x + w, 51).stroke();
      d.lineWidth(0.5).moveTo(x, H - 46).lineTo(x + w, H - 46).stroke();
      d.font('Times-Roman').fontSize(9.5).fillColor(GRIS).text(`${i} de ${r.count - 1}`, x, H - 38, { width: w, align: 'center', lineBreak: false });
      d.page.margins.bottom = margen;
    }

    d.end();
    await new Promise<void>((resolve, reject) => {
      this.stream.on('finish', resolve);
      this.stream.on('error', reject);
    });
    console.log(`[PDF] ${this.o.carpeta ? path.relative(RAIZ, this.o.carpeta) : 'entregables'}/${this.o.archivo}: ${r.count} páginas`);
    return r.count;
  }
}
