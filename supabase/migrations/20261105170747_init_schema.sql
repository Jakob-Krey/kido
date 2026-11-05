-- kido: Initiales Schema (sources, offers, public_offers) inkl. RLS
-- Schreibzugriff ausschliesslich ueber service_role (Crawler).

-- ---------------------------------------------------------------
-- Hilfsfunktion: updated_at automatisch setzen
-- ---------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ---------------------------------------------------------------
-- sources: geprueft Quellen
-- ---------------------------------------------------------------
create table public.sources (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  url              text not null unique,
  anbieter         text,
  anbieter_typ     text,  -- z. B. 'staedtisch', 'e. V.', 'kirchlich'
  erlaubnis_status text not null default 'offen'
                   check (erlaubnis_status in ('offen', 'angefragt', 'erteilt', 'abgelehnt')),
  erlaubnis_datum  date,
  robots_geprueft  boolean not null default false,
  content_hash     text,
  zuletzt_gecrawlt timestamptz,
  aktiv            boolean not null default true,
  notizen          text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create trigger sources_set_updated_at
  before update on public.sources
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------
-- offers: Angebote (keine Felder fuer Ansprechpersonen -> DSGVO)
-- ---------------------------------------------------------------
create table public.offers (
  id                   uuid primary key default gen_random_uuid(),  -- stabil, wird bei Updates nie geaendert
  source_id            uuid not null references public.sources (id) on delete restrict,

  titel                text not null,
  kurzbeschreibung     text,  -- eigene Formulierung, kein Originaltext
  kategorie            text not null default 'sonstiges'
                       check (kategorie in ('sport', 'musik', 'kreativ', 'schwimmen', 'ferien',
                                            'eltern_kind', 'bildung', 'natur', 'sonstiges')),

  alter_von            int check (alter_von between 0 and 12),
  alter_bis            int check (alter_bis between 0 and 12),

  anbieter             text,
  strasse              text,
  plz                  text,
  ort                  text not null default 'Mülheim an der Ruhr',
  stadtteil            text,

  termin_typ           text check (termin_typ in ('einmalig', 'mehrtaegig', 'regelmaessig')),
  start_at             timestamptz,
  end_at               timestamptz,
  ganztaegig           boolean not null default false,
  wochentage           text[],
  uhrzeit_von          time,
  uhrzeit_bis          time,
  zeitraum_von         date,
  zeitraum_bis         date,
  gueltig_bis          date,

  kosten               text,
  anmeldung_noetig     boolean,
  link_original        text,

  zuletzt_aktualisiert timestamptz not null default now(),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),

  constraint offers_alter_reihenfolge check (alter_von is null or alter_bis is null or alter_von <= alter_bis)
);

create trigger offers_set_updated_at
  before update on public.offers
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------
-- Indizes
-- ---------------------------------------------------------------
create index offers_alter_idx       on public.offers (alter_von, alter_bis);
create index offers_gueltig_bis_idx on public.offers (gueltig_bis);
create index offers_stadtteil_idx   on public.offers (stadtteil);
create index offers_kategorie_idx   on public.offers (kategorie);
create index offers_source_id_idx   on public.offers (source_id);  -- FK-Index

-- ---------------------------------------------------------------
-- Sicherheit
-- ---------------------------------------------------------------
-- anon/authenticated duerfen `sources` nicht lesen. Damit die offers-Policy und die
-- View trotzdem Quellname/-URL/-Status nutzen koennen, laufen diese Zugriffe ueber eine
-- SECURITY-DEFINER-Funktion in einem eigenen Schema, das nicht ueber die API exponiert wird.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated, service_role;

create or replace function private.source_info(p_source_id uuid)
returns table (name text, url text, aktiv boolean)
language sql
stable
security definer
set search_path = ''
as $$
  select s.name, s.url, s.aktiv
  from public.sources s
  where s.id = p_source_id;
$$;

revoke execute on function private.source_info(uuid) from public;
grant execute on function private.source_info(uuid) to anon, authenticated, service_role;

alter table public.sources enable row level security;
alter table public.offers  enable row level security;

-- Tabellen werden im Projekt nicht automatisch freigegeben -> alles explizit.
revoke all on public.sources from anon, authenticated;
revoke all on public.offers  from anon, authenticated;

-- service_role (Crawler): voller Zugriff (umgeht RLS ohnehin, braucht aber Table-Grants)
grant all on public.sources to service_role;
grant all on public.offers  to service_role;

-- Oeffentlich: nur SELECT auf offers, nur aktuelle Angebote aktiver Quellen
grant select on public.offers to anon, authenticated;

create policy offers_public_read
  on public.offers
  for select
  to anon, authenticated
  using (
    (gueltig_bis is null or gueltig_bis >= current_date)
    and exists (
      select 1 from private.source_info(offers.source_id) si where si.aktiv
    )
  );

-- Keine Policies fuer sources und keine Schreib-Policies -> nur service_role kommt heran.

-- ---------------------------------------------------------------
-- View public_offers (security_invoker: RLS von offers gilt fuer den Aufrufer)
-- ---------------------------------------------------------------
create view public.public_offers
with (security_invoker = true) as
select
  o.id,
  o.titel,
  o.kurzbeschreibung,
  o.kategorie,
  o.alter_von,
  o.alter_bis,
  o.anbieter,
  o.strasse,
  o.plz,
  o.ort,
  o.stadtteil,
  o.termin_typ,
  o.start_at,
  o.end_at,
  o.ganztaegig,
  o.wochentage,
  o.uhrzeit_von,
  o.uhrzeit_bis,
  o.zeitraum_von,
  o.zeitraum_bis,
  o.gueltig_bis,
  o.kosten,
  o.anmeldung_noetig,
  o.link_original,
  o.zuletzt_aktualisiert,
  si.name as quelle_name,
  si.url  as quelle_url
from public.offers o
cross join lateral private.source_info(o.source_id) si
where si.aktiv
  and (o.gueltig_bis is null or o.gueltig_bis >= current_date);

revoke all on public.public_offers from anon, authenticated;
grant select on public.public_offers to anon, authenticated;
grant select on public.public_offers to service_role;
