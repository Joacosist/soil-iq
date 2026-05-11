# 🌱 Soil-IQ — Plataforma AgTech

MVP desarrollado para el proyecto de emprendimiento de la **Universidad Austral**.  
Plataforma SaaS de agricultura de precisión con análisis de suelo, sensores IoT, mapas satelitales y marketplace de bioinsumos.

---

## Estructura del proyecto

```
/
├── index.html          ← Landing page pública
├── app.html            ← Plataforma (login + dashboard)
├── js/
│   └── db.js           ← Cliente Supabase (dual-mode: real o demo)
├── supabase/
│   └── schema.sql      ← Esquema PostgreSQL + RLS policies
└── README.md
```

---

## Cuentas demo (sin configurar Supabase)

| Email | Contraseña | Rol |
|-------|-----------|-----|
| pablo@soil-iq.com | demo123 | Ing. Agrónomo (4 campos) |
| maria@soil-iq.com | demo123 | Ing. Agrónoma (4 campos, 1 compartido) |
| jorge@soil-iq.com | demo123 | Ing. Agrónomo (3 campos) |
| admin@soil-iq.com | admin123 | Administrador (10 campos) |

> El campo **El Triunfo** está compartido entre Pablo y María — simula que el dueño y el asesor ven el mismo campo.

---

## Configurar Supabase (base de datos real)

### 1. Crear proyecto en Supabase

1. Ir a [supabase.com](https://supabase.com) → **New project**
2. Elegir nombre, contraseña y región (recomendado: South America)

### 2. Crear el esquema

1. En el Dashboard → **SQL Editor**
2. Pegar el contenido de `supabase/schema.sql`
3. Ejecutar con **RUN**

### 3. Crear usuarios

En Supabase Dashboard → **Authentication → Users → Add user**  
O usar la API de Auth con el SDK.

Al crear un usuario, pasá metadata:
```json
{
  "name": "Pablo López",
  "role": "agro",
  "title": "Ing. Agrónomo · CREA",
  "initials": "PL"
}
```

### 4. Conectar la app

Abrí `app.html` y antes del cierre `</head>` añadí:

```html
<script>
  window.SUPABASE_URL      = 'https://TU-PROYECTO.supabase.co';
  window.SUPABASE_ANON_KEY = 'eyJh...TU-ANON-KEY';
</script>
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
<script src="js/db.js"></script>
```

Reemplazá los valores con los de tu proyecto en:  
**Settings → API → Project URL** y **anon public key**

---

## Deploy (Netlify / Vercel / GitHub Pages)

La app es 100% estática (HTML + JS inline). Podés deployarla directamente:

- **GitHub Pages**: Settings → Pages → Deploy from branch `main`
- **Netlify**: arrastrar la carpeta al dashboard de Netlify
- **Vercel**: `vercel --prod` desde la terminal

---

## Stack técnico

| Tecnología | Uso |
|-----------|-----|
| HTML/CSS/JS vanilla | Frontend sin framework |
| Leaflet.js | Mapas satelitales + polígonos de lotes |
| Chart.js | Radar, barras, dona |
| ESRI World Imagery | Tiles satelitales |
| Supabase Auth | Autenticación email+contraseña |
| Supabase PostgreSQL | Base de datos con RLS |

---

© 2026 Soil-IQ · Universidad Austral · MVP v0.1
