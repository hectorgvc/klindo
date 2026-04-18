# Módulo e-CF (Facturación Electrónica DGII)
## Klindo — Plan de Implementación

---

## Estado Actual ✅
- Facturación interna (Fase 1) operativa
- Tipos B01 y B02 con correlativo interno
- Tablas `facturas`, `rnc`, `razon_social` en Supabase
- Columnas `ecf_activo` y `ecf_cert_path` en `tenants`

---

## Requisitos Previos
- [ ] Certificado digital .p12 emitido por entidad autorizada DGII
- [ ] RNC del negocio registrado como emisor electrónico en DGII
- [ ] Secuencias NCF aprobadas por la DGII (rangos B01, B02)
- [ ] Acceso al ambiente de Pre-Certificación DGII para pruebas

---

## Paso 1 — Configuración del Certificado
**Archivo:** `admin/configuracion.html`

- Agregar sección "Facturación Electrónica (e-CF)"
- Toggle para activar/desactivar e-CF por tenant
- Upload del certificado .p12 → Supabase Storage bucket privado `certificados/{tenant_id}.p12`
- Campo contraseña del certificado (se guarda encriptada en Supabase Secrets)
- Guardar en tenants: `ecf_activo = true`, `ecf_cert_path`

**SQL necesario:**
```sql
-- Bucket privado para certificados (crear en Supabase Storage)
-- Nombre: certificados
-- Público: NO
```

---

## Paso 2 — Edge Function: Autenticación DGII
**Archivo:** `supabase/functions/ecf-auth/index.ts`

Flujo:
1. GET `/autenticacion/semilla` → obtiene semilla XML
2. Firmar la semilla con el certificado .p12 usando SHA256
3. POST `/autenticacion/validarsemilla` → obtiene token JWT
4. Guardar token en caché (expira ~4 horas)

**Librerías Deno necesarias:**
- `node-forge` para firmado del certificado
- `xmldom` para manipulación XML

**Endpoints DGII:**
- Pre-certificación: `https://ecf.dgii.gov.do/testecf/autenticacion`
- Producción: `https://ecf.dgii.gov.do/ecf/autenticacion`

---

## Paso 3 — Edge Function: Generación XML e-CF
**Archivo:** `supabase/functions/ecf-generate/index.ts`

Toma una factura de la tabla `facturas` y genera el XML según esquema DGII:

```xml
<eCF>
  <encabezado>
    <tipoeCF>31</tipoeCF>
    <eNCF>E310000000001</eNCF>
    <fechaEmision>31-12-2025</fechaEmision>
    <tipoIngresos>1</tipoIngresos>
    <tipoCuentaPorPagar>01</tipoCuentaPorPagar>
  </encabezado>
  <emisor>
    <RNCComprador>101XXXXXX</RNCComprador>
    <RazonSocialEmisor>Nombre Negocio</RazonSocialEmisor>
  </emisor>
  <comprador>
    <RNCComprador>...</RNCComprador>
    <RazonSocialComprador>...</RazonSocialComprador>
    <ContactoComprador>...</ContactoComprador>
  </comprador>
  <totales>
    <totalITBIS>...</totalITBIS>
    <totalMontoExento>...</totalMontoExento>
    <totalMontoGravado>...</totalMontoGravado>
    <montoVenta>...</montoVenta>
    <montoTotal>...</montoTotal>
  </totales>
  <detallesItems>
    <item>
      <numeroItem>1</numeroItem>
      <descripcionItem>Lavado Regular</descripcionItem>
      <cantidadItem>2</cantidadItem>
      <precioUnitarioItem>120.00</precioUnitarioItem>
      <montoItem>
        <montoGravado>240.00</montoGravado>
      </montoItem>
    </item>
  </detallesItems>
</eCF>
```

Tipos e-CF:
| Código | NCF  | Descripción |
|--------|------|-------------|
| 31     | B01  | Crédito Fiscal |
| 32     | B02  | Consumidor Final |
| 41     | B14  | Gubernamental |
| 43     | B15  | Régimen Especial |

---

## Paso 4 — Edge Function: Firmado del XML
**Archivo:** `supabase/functions/ecf-sign/index.ts`

Usar la implementación TypeScript de la DGII (ya documentada en `Firmado_de_e-CF.pdf`):
- Cargar .p12 desde Supabase Storage
- Usar `node-forge` para extraer llave privada y certificado
- Aplicar canonicalización C14N
- Firmar con SHA256/RSA
- Insertar bloque `<Signature>` en el XML

---

## Paso 5 — Edge Function: Envío a DGII
**Archivo:** `supabase/functions/ecf-submit/index.ts`

1. Obtener token (Paso 2)
2. Generar XML (Paso 3)
3. Firmar XML (Paso 4)
4. POST a `/api/emision/emisioncomprobantes`
5. Recibir `trackId`
6. Guardar `trackId` en tabla `facturas`
7. Consultar estado cada 30s hasta obtener aprobación/rechazo
8. Guardar `eNCF` aprobado y estado final

**Actualizar tabla facturas:**
```sql
ALTER TABLE facturas ADD COLUMN IF NOT EXISTS track_id varchar(100);
ALTER TABLE facturas ADD COLUMN IF NOT EXISTS encf varchar(20);
ALTER TABLE facturas ADD COLUMN IF NOT EXISTS estado_dgii varchar(20);
-- estados: pendiente, aceptado, rechazado, aceptado_condicional
ALTER TABLE facturas ADD COLUMN IF NOT EXISTS fecha_aprobacion timestamptz;
ALTER TABLE facturas ADD COLUMN IF NOT EXISTS xml_firmado text;
ALTER TABLE facturas ADD COLUMN IF NOT EXISTS respuesta_dgii jsonb;
```

---

## Paso 6 — UI: Actualizar factura-detalle.html
**Archivo:** `admin/factura-detalle.html`

Cuando `ecf_activo = true` y la factura tiene `encf`:
- Mostrar el e-NCF oficial (Ej: E310000000001)
- Mostrar QR de validación DGII:
  `https://ecf.dgii.gov.do/consultatimbre?...`
- Badge "Aprobado por DGII" en verde
- Si está pendiente: badge amarillo "Enviando a DGII..."
- Si rechazado: badge rojo con mensaje de error

---

## Paso 7 — UI: Panel de Control e-CF (superadmin)
**Archivo:** `superadmin/ecf-monitor.html`

Vista para el superadmin:
- Estado de certificados por tenant
- Facturas pendientes de envío
- Facturas rechazadas por DGII con razón
- Botón reenviar factura rechazada

---

## Secuencia de Pruebas

### Ambiente Pre-Certificación
1. Cargar certificado de prueba provisto por DGII
2. Usar RNC de prueba
3. Generar facturas de prueba
4. Verificar aprobación en portal DGII pre-certificación
5. Corregir errores de validación XML

### Certificación
1. Presentar evidencia de pruebas exitosas a DGII
2. DGII valida el sistema
3. Aprobación para producción

### Producción
1. Cargar certificado real
2. Activar `ecf_activo = true` en el tenant
3. Las facturas nuevas se envían automáticamente a DGII

---

## Notas Importantes

- El certificado `.p12` **nunca se expone al frontend**
- Los tokens DGII expiran ~4 horas, manejar renovación automática
- Guardar siempre el XML firmado en `facturas.xml_firmado` para auditoría
- En caso de rechazo DGII, la factura interna sigue válida para el negocio
- Implementar reintentos automáticos para errores de red
- El ambiente de pre-certificación acepta datos hasta 60 días

---

## Contacto DGII
- Centro de Contacto: (809) 689-3444, opción 4
- Contacto Directo: (809) 287-2009
- Correo: facturacionelectronica@dgii.gov.do
- Portal: dgii.gov.do → Facturación Electrónica
