-- ══════════════════════════════════════════════════════════════
--  Soil-IQ — Supabase PostgreSQL Schema
--  Run in: Supabase Dashboard → SQL Editor
-- ══════════════════════════════════════════════════════════════

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ── PROFILES ──────────────────────────────────────────────────
-- Extended user info (mirrors auth.users)
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  role        text not null check (role in ('agro','admin','contratista','productor')),
  title       text,                           -- "Ing. Agrónomo · CREA"
  initials    text,
  plan        text default 'Free' check (plan in ('Free','Pro','Enterprise')),
  created_at  timestamptz default now()
);

-- Automatically create profile row on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, name, role, title, initials)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', new.email),
    coalesce(new.raw_user_meta_data->>'role', 'agro'),
    new.raw_user_meta_data->>'title',
    new.raw_user_meta_data->>'initials'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── FIELDS ────────────────────────────────────────────────────
create table if not exists public.fields (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null,
  owner       text not null,                  -- nombre del productor
  ha          numeric(10,2) not null,
  provincia   text,
  loc         text,                           -- descripción de ubicación
  lat         numeric(10,6),
  lng         numeric(10,6),
  polygon     jsonb,                          -- [[lat,lng], ...]
  cultivo     text,
  plan        text default 'Free' check (plan in ('Free','Pro','Enterprise')),
  status      text default 'ok' check (status in ('ok','warn','alert')),
  sensors     boolean default false,
  savings     numeric(8,2) default 0,
  created_at  timestamptz default now(),
  updated_at  timestamptz default now()
);

-- ── FIELD ACCESS (many-to-many: user ↔ field) ─────────────────
-- A field can have multiple agrónomos, and an agrónomo can have multiple fields
create table if not exists public.field_access (
  id         uuid primary key default uuid_generate_v4(),
  field_id   uuid not null references public.fields(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       text default 'asesor' check (role in ('owner','asesor','viewer')),
  granted_at timestamptz default now(),
  unique(field_id, user_id)
);

-- ── ANALYSES ─────────────────────────────────────────────────
create table if not exists public.analyses (
  id              uuid primary key default uuid_generate_v4(),
  field_id        uuid not null references public.fields(id) on delete cascade,
  uploaded_by     uuid references auth.users(id),
  lote            text,
  fecha_muestreo  date not null,
  laboratorio     text,
  profundidad     text,
  cultivo_antes   text,

  -- Parámetros fisicoquímicos
  ph              numeric(4,2),
  n_total         numeric(8,2),    -- kg/ha
  p_asimilable    numeric(8,2),    -- ppm
  k_intercamb     numeric(8,2),    -- ppm
  materia_org     numeric(5,2),    -- %
  conductividad   numeric(6,3),    -- dS/m
  azufre          numeric(8,2),    -- ppm
  calcio          numeric(8,2),
  magnesio        numeric(8,2),
  cap_campo       numeric(5,2),    -- %
  textura         text,
  numero_lab      text,
  observaciones   text,

  -- IA
  estado_ia       text default 'pendiente' check (estado_ia in ('pendiente','procesado','alerta','revision')),
  recomendacion   text,

  created_at      timestamptz default now()
);

-- ── SENSOR READINGS ──────────────────────────────────────────
create table if not exists public.sensor_readings (
  id              uuid primary key default uuid_generate_v4(),
  field_id        uuid not null references public.fields(id) on delete cascade,
  lote            text,
  recorded_at     timestamptz default now(),

  humedad         numeric(5,2),    -- %
  temp_suelo      numeric(5,2),    -- °C
  ph_rt           numeric(4,2),    -- pH en tiempo real
  conductividad   numeric(6,3),    -- dS/m
  temp_ambiente   numeric(5,2),    -- °C
  nivel_freatico  numeric(5,2)     -- m
);

-- ── DEVICES (hardware instalado en maquinaria de contratistas) ──────────
create table if not exists public.devices (
  id              uuid primary key default uuid_generate_v4(),
  contractor_id   uuid not null references auth.users(id) on delete cascade,
  nombre          text not null,                 -- "Cosechadora Case IH 9250"
  serial          text not null unique,          -- S/N físico del dispositivo
  modelo          text,                          -- "SoilSense Pro V2"
  activation_code text unique,                   -- código de activación de 1 uso
  estado          text default 'inactivo' check (estado in ('activo','en_campo','inactivo')),
  ultima_sync     timestamptz,
  ha_total        numeric(10,2) default 0,
  created_at      timestamptz default now()
);

-- ── MACHINE PASSES (pasadas/recorridas de la maquinaria) ─────────────────
create table if not exists public.machine_passes (
  id              uuid primary key default uuid_generate_v4(),
  device_id       uuid not null references public.devices(id) on delete cascade,
  contractor_id   uuid not null references auth.users(id) on delete cascade,
  field_name      text,                          -- nombre del establecimiento (manual o inferido)
  field_id        uuid references public.fields(id),  -- vinculado si existe en la plataforma
  lote            text,
  fecha_pasada    date not null,
  ha              numeric(10,2),
  cultivo         text,
  puntos_datos    integer default 0,             -- cantidad de lecturas registradas
  archivo_url     text,                          -- URL del archivo subido (CSV/JSON)
  estado          text default 'procesado' check (estado in ('procesado','revision','error')),
  created_at      timestamptz default now()
);

-- ── MARKETPLACE PRODUCTS ─────────────────────────────────────
create table if not exists public.marketplace_products (
  id           uuid primary key default uuid_generate_v4(),
  created_by   uuid references auth.users(id),
  categoria    text not null,
  nombre       text not null,
  empresa      text not null,
  icon         text default '🌱',
  descripcion  text,
  precio       text,
  unidad       text,
  zona         text,
  stock        text,
  email        text,
  telefono     text,
  estado       text default 'revision' check (estado in ('revision','publicado','rechazado')),
  created_at   timestamptz default now()
);

-- ══════════════════════════════════════════════════════════════
--  ROW LEVEL SECURITY
-- ══════════════════════════════════════════════════════════════

alter table public.profiles          enable row level security;
alter table public.fields            enable row level security;
alter table public.field_access      enable row level security;
alter table public.analyses          enable row level security;
alter table public.sensor_readings   enable row level security;
alter table public.devices              enable row level security;
alter table public.machine_passes       enable row level security;
alter table public.marketplace_products enable row level security;

-- Profiles: each user reads/edits their own; admins see all
create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id or exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'
  ));
create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);

-- Fields: visible to users who have access via field_access (or admins)
create policy "fields_select" on public.fields
  for select using (
    exists (select 1 from public.field_access fa where fa.field_id = id and fa.user_id = auth.uid())
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );
create policy "fields_insert_admin" on public.fields
  for insert with check (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );
create policy "fields_update_admin" on public.fields
  for update using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- Field access: users see their own access rows; admins see all
create policy "field_access_select" on public.field_access
  for select using (
    user_id = auth.uid()
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );
create policy "field_access_manage_admin" on public.field_access
  for all using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- Analyses: accessible if user has access to the field
create policy "analyses_select" on public.analyses
  for select using (
    exists (select 1 from public.field_access fa where fa.field_id = field_id and fa.user_id = auth.uid())
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );
create policy "analyses_insert" on public.analyses
  for insert with check (
    exists (select 1 from public.field_access fa where fa.field_id = field_id and fa.user_id = auth.uid())
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- Sensor readings: same as analyses
create policy "sensor_readings_select" on public.sensor_readings
  for select using (
    exists (select 1 from public.field_access fa where fa.field_id = field_id and fa.user_id = auth.uid())
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- Devices: contractor sees their own; admins see all
create policy "devices_select" on public.devices
  for select using (
    contractor_id = auth.uid()
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );
create policy "devices_insert" on public.devices
  for insert with check (contractor_id = auth.uid());
create policy "devices_update_own" on public.devices
  for update using (contractor_id = auth.uid());

-- Machine passes: contractor sees their own; admins see all
create policy "passes_select" on public.machine_passes
  for select using (
    contractor_id = auth.uid()
    or exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );
create policy "passes_insert" on public.machine_passes
  for insert with check (contractor_id = auth.uid());

-- Marketplace: published products visible to all logged-in users; insert for admins
create policy "mkt_select" on public.marketplace_products
  for select using (estado = 'publicado' or exists (
    select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'
  ));
create policy "mkt_insert" on public.marketplace_products
  for insert with check (auth.uid() is not null);
create policy "mkt_update_admin" on public.marketplace_products
  for update using (
    exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin')
  );

-- ══════════════════════════════════════════════════════════════
--  INDEXES
-- ══════════════════════════════════════════════════════════════
create index if not exists idx_field_access_user   on public.field_access(user_id);
create index if not exists idx_field_access_field  on public.field_access(field_id);
create index if not exists idx_analyses_field      on public.analyses(field_id);
create index if not exists idx_sensor_field        on public.sensor_readings(field_id);
create index if not exists idx_sensor_recorded     on public.sensor_readings(recorded_at desc);
create index if not exists idx_devices_contractor  on public.devices(contractor_id);
create index if not exists idx_passes_device       on public.machine_passes(device_id);
create index if not exists idx_passes_contractor   on public.machine_passes(contractor_id);
create index if not exists idx_passes_fecha        on public.machine_passes(fecha_pasada desc);
