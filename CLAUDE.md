# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Klindo** is a multi-tenant laundry management system (SaaS for laundromats/dry cleaners) built with vanilla HTML, CSS, and JavaScript. It uses Supabase as the backend (PostgreSQL + Auth + Realtime).

## Architecture

### Tech Stack
- **Frontend**: Vanilla HTML5, CSS3, JavaScript (no framework)
- **Backend**: Supabase (PostgreSQL, Auth, Realtime subscriptions)
- **Icons**: Lucide (via CDN)
- **Styling**: CSS custom properties (design tokens) in `assets/css/main.css`

### Project Structure

```
/
├── index.html              # Redirects to login.html
├── login.html              # Authentication page
├── recepcion.html          # Main POS/cashier module (reception)
├── planta.html             # Kitchen Display System (KDS) for production floor
├── admin/                  # Admin panel (tenant management)
│   ├── index.html          # Dashboard
│   ├── servicios.html      # Service catalog management
│   ├── ordenes.html        # Order history
│   ├── clientes.html       # Customer directory
│   ├── configuracion.html  # Tenant settings
│   └── repartidores.html   # Delivery staff management
├── superadmin/             # Superadmin panel (multi-tenant management)
│   ├── index.html
│   ├── tenants.html
│   └── crear-tenant.html
├── assets/
│   ├── css/main.css        # Design system + component styles
│   ├── js/
│   │   ├── supabase.js     # Supabase client initialization
│   │   └── auth.js         # Auth logic + route protection
│   └── img/
└── supabase/
    ├── functions/          # Edge functions
    └── supabase_klindo.sql # Database schema
```

### Core Tables (Supabase)

- `tenants` - Multi-tenant isolation
- `profiles` - Users (linked to auth.users), roles: superadmin, admin, operador, repartidor
- `categorias_servicio` - Service categories
- `servicios` - Services/products with pricing (per unit, kg, meter, or fixed)
- `ordenes` - Orders with states: recibido → en_lavado → en_seco → en_planchado → listo → entregado
- `items_orden` - Line items (individual garments)
- `clientes` - Customer directory

### Key Patterns

**Authentication** (`assets/js/auth.js`):
- Supabase Auth with session persistence
- Role-based access: protectAdminRoute(), protectSuperadminRoute()
- Session storage: `tenant_id`, `user_role`, `user_name`
- Query pattern: Use `.maybeSingle()` instead of `.single()` to avoid "Cannot coerce to single JSON object" errors

**Database Queries**:
- Always filter by `tenant_id` for tenant-scoped data
- Use separate queries instead of joins when experiencing JSON coercion errors

**Design System** (`assets/css/main.css`):
- Light theme (clean/hygienic aesthetic for laundry business)
- CSS variables for colors: `--brand-500` (sky blue), `--cyan-500`, `--teal-500`
- Status colors: `--estado-recibido`, `--estado-en-lavado`, `--estado-listo`, etc.
- Components: `.btn`, `.card`, `.form-group`, `.sidebar`, `.topbar`

**Order Flow States**:
```
recibido → en_lavado → en_seco → en_planchado → listo → (en_camino) → entregado
```

## Development Workflow

### No Build Step
This is a static HTML/JS project. No npm, bundler, or build process required.

### Local Development
Serve files with any static server:

```bash
# Python
python -m http.server 8080

# Node.js
npx serve .

# PHP
php -S localhost:8080
```

Then open http://localhost:8080/login.html

### Key Files to Understand

1. **recepcion.html** - Main cashier interface: create orders, add items, process payments
2. **planta.html** - Production floor monitor (KDS): view orders by status, update progress
3. **admin/index.html** - Dashboard with stats and daily summary
4. **assets/js/auth.js:143** - protectAdminRoute() - guards admin pages

### Common Modifications

**Adding a new service**: Edit `admin/servicios.html` or insert directly into `servicios` table.

**Changing order workflow**: Modify `estado_orden_type` enum in SQL and update `planta.html` columns.

**Styling changes**: Edit `assets/css/main.css` - uses CSS variables for easy theming.

### Important Notes

- Supabase credentials are hardcoded in `assets/js/supabase.js` (client-side anon key is safe for public exposure)
- Row Level Security (RLS) policies enforce tenant isolation
- Real-time subscriptions used in `planta.html` for live order updates
- Delivery module is optional per-tenant (controlled by `modulo_delivery_activo`)
- Plan expiration handling: redirects to `admin/renovar.html` when plan expires
