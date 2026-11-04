import fs from 'fs';
import path from 'path';
import { Request, Response } from 'express';

/**
 * Documentación interactiva (Swagger UI) a partir de contracts/openapi.yaml.
 * Si el contrato no está junto al backend (por ejemplo, si el despliegue solo incluye
 * la carpeta backend/), se sirve la versión publicada en la rama main del repositorio.
 */
const CONTRATO_LOCAL = path.join(__dirname, '../../../contracts/openapi.yaml');
const CONTRATO_MAIN =
  'https://raw.githubusercontent.com/Arbolito-ctrl/LuxxitoSports/main/contracts/openapi.yaml';
const SWAGGER_UI = 'https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.17.14';

const PAGINA = `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Luxxito Sports · API REST</title>
  <link rel="stylesheet" href="${SWAGGER_UI}/swagger-ui.css">
  <style>body { margin: 0; } .topbar { display: none; }</style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="${SWAGGER_UI}/swagger-ui-bundle.js"></script>
  <script>
    window.ui = SwaggerUIBundle({
      url: 'openapi.yaml',
      dom_id: '#swagger-ui',
      deepLinking: true,
      persistAuthorization: true,
      displayRequestDuration: true,
      tryItOutEnabled: true,
    });
  </script>
</body>
</html>`;

export const docsController = {
  pagina(_req: Request, res: Response): void {
    res.type('html').send(PAGINA);
  },

  contrato(_req: Request, res: Response): void {
    if (fs.existsSync(CONTRATO_LOCAL)) {
      res.type('application/yaml').sendFile(CONTRATO_LOCAL);
      return;
    }
    res.redirect(302, CONTRATO_MAIN);
  },
};
