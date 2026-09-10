-- ========================================================================
-- TIMELINE OS - Supabase Database Schema (v5.0 DESDE CERO CON RLS ACTIVO)
-- ========================================================================

-- 1. LIMPIEZA TOTAL PREVIA
DROP TABLE IF EXISTS detected_conflicts CASCADE;
DROP TABLE IF EXISTS milestones CASCADE;
DROP TABLE IF EXISTS stages CASCADE;
DROP TABLE IF EXISTS projects CASCADE;
DROP TABLE IF EXISTS team_members CASCADE;
DROP TABLE IF EXISTS organizations CASCADE;

-- 2. EXTENSIONES Y TIPOS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$ BEGIN
    CREATE TYPE project_status AS ENUM ('en_licitacion', 'en_desarrollo', 'en_revision', 'en_pausa', 'finalizado');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE stage_status AS ENUM ('pendiente', 'en_desarrollo', 'completada', 'atrasada');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE milestone_type AS ENUM (
        'reunion',          -- ● Círculo
        'entrega',          -- ◆ Rombo
        'participacion',    -- ▲ Triángulo
        'estado_pago',      -- ■ Cuadrado
        'terreno',          -- ◉ Visita con blanco concéntrico
        'contractual',      -- ✦ Estrella
        'revision',         -- ○ Círculo vacío
        'hito_critico'      -- ◈ Rombo destacado
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE milestone_status AS ENUM ('programado', 'cumplido', 'atrasado', 'en_curso', 'cancelado');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE priority_level AS ENUM ('baja', 'media', 'alta', 'critica');
EXCEPTION WHEN duplicate_object THEN null; END $$;

DO $$ BEGIN
    CREATE TYPE conflict_type AS ENUM ('persona', 'territorial', 'etapa', 'fecha');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- 3. TABLAS PRINCIPALES
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    rut TEXT,
    base_city TEXT DEFAULT 'Quillota',
    google_client_id TEXT,
    logo_symbol TEXT,
    logo_color TEXT DEFAULT '#2563EB',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE team_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    role TEXT NOT NULL DEFAULT 'consultor',
    avatar_color TEXT DEFAULT '#2563EB',
    base_location TEXT DEFAULT 'Quillota',
    phone TEXT,
    password TEXT DEFAULT 'consultor2026',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    client TEXT NOT NULL,
    mandante TEXT,
    project_type TEXT NOT NULL DEFAULT 'Diseño de Espacio Público',
    region TEXT NOT NULL DEFAULT 'Región de Valparaíso',
    commune TEXT NOT NULL DEFAULT 'Quillota',
    responsible_id UUID REFERENCES team_members(id) ON DELETE SET NULL,
    status project_status DEFAULT 'en_desarrollo' NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    end_date DATE NOT NULL,
    color TEXT NOT NULL DEFAULT '#2563EB',
    progress INT DEFAULT 0 CHECK (progress >= 0 AND progress <= 100),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE stages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 1,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    responsible_id UUID REFERENCES team_members(id) ON DELETE SET NULL,
    status stage_status DEFAULT 'pendiente' NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE milestones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE NOT NULL,
    stage_id UUID REFERENCES stages(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    date DATE NOT NULL,
    time_start TIME,
    time_end TIME,
    milestone_type milestone_type NOT NULL DEFAULT 'reunion',
    responsible_id UUID REFERENCES team_members(id) ON DELETE SET NULL,
    status milestone_status DEFAULT 'programado' NOT NULL,
    priority priority_level DEFAULT 'media' NOT NULL,
    location_override TEXT,
    observations TEXT,
    gcal_event_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE detected_conflicts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    org_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    conflict_type conflict_type NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    severity TEXT DEFAULT 'warning',
    milestone_id_1 UUID REFERENCES milestones(id) ON DELETE CASCADE,
    milestone_id_2 UUID REFERENCES milestones(id) ON DELETE CASCADE,
    responsible_id UUID REFERENCES team_members(id) ON DELETE CASCADE,
    is_resolved BOOLEAN DEFAULT FALSE,
    detected_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 4. ÍNDICES
CREATE INDEX idx_milestones_date ON milestones(date);
CREATE INDEX idx_milestones_project_id ON milestones(project_id);
CREATE INDEX idx_milestones_responsible_id ON milestones(responsible_id);
CREATE INDEX idx_stages_project_id ON stages(project_id);
CREATE INDEX idx_projects_status ON projects(status);
CREATE INDEX idx_team_members_username ON team_members(username);

-- 5. TRIGGER UPDATED_AT AUTOMÁTICO
CREATE OR REPLACE FUNCTION set_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = timezone('utc'::text, now());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_projects_updated_at BEFORE UPDATE ON projects FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();
CREATE TRIGGER trg_milestones_updated_at BEFORE UPDATE ON milestones FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();
CREATE TRIGGER trg_stages_updated_at BEFORE UPDATE ON stages FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();
CREATE TRIGGER trg_team_members_updated_at BEFORE UPDATE ON team_members FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();
CREATE TRIGGER trg_organizations_updated_at BEFORE UPDATE ON organizations FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

-- 6. SIEMBRA INICIAL DIRECTA EN LA BASE DE DATOS (Nativa en Postgres)
INSERT INTO organizations (id, name, base_city)
VALUES ('e0000000-0000-4000-8000-000000000001', 'Consultora de Arquitectura y Urbanismo', 'Quillota / Valparaíso, Chile');

INSERT INTO team_members (id, username, name, email, role, avatar_color, base_location, password) VALUES
('a0000000-0000-4000-8000-000000000001', 'territorial', 'Administrador General', 'territorial.arq@gmail.com', 'admin', '#EF4444', 'Quillota', 'consultor2026'),
('a0000000-0000-4000-8000-000000000002', 'angel', 'Angel Asencio', 'angel.asencio@consultora.cl', 'Director de Proyectos', '#2563EB', 'Quillota', 'consultor2026'),
('a0000000-0000-4000-8000-000000000003', 'maria', 'María González', 'mgonzalez@consultora.cl', 'Arquitecta Urbanista', '#EC4899', 'Valparaíso', 'consultor2026'),
('a0000000-0000-4000-8000-000000000004', 'carlos', 'Carlos Soto', 'csoto@consultora.cl', 'Ingeniero Civil Estructural', '#10B981', 'Santiago', 'consultor2026'),
('a0000000-0000-4000-8000-000000000005', 'pedro', 'Pedro Morales', 'pmorales@consultora.cl', 'Topógrafo / Geomensor', '#F59E0B', 'Quillota', 'consultor2026');

INSERT INTO projects (id, code, name, client, mandante, project_type, region, commune, responsible_id, status, start_date, end_date, color, progress, description) VALUES
('b0000000-0000-4000-8000-000000000001', 'VALD-01', 'Paseo Peatonal Valdivia', 'Municipalidad de Valdivia', 'SECPLAN Valdivia', 'Diseño de Espacio Público', 'Región de Los Ríos', 'Valdivia', 'a0000000-0000-4000-8000-000000000003', 'en_desarrollo', '2026-08-01', '2026-11-30', '#2563EB', 45, 'Diseño integral de arquitectura y paisajismo ribereño con accesibilidad universal.'),
('b0000000-0000-4000-8000-000000000002', 'TRG-02', 'Pérgola Urbana Calle Pérez Traiguén', 'Municipalidad de Traiguén', 'SERVIU Araucanía', 'Intervención Urbana y Patrimonial', 'Región de La Araucanía', 'Traiguén', 'a0000000-0000-4000-8000-000000000002', 'en_desarrollo', '2026-08-15', '2026-10-30', '#059669', 35, 'Recuperación urbana, adoquines históricos y estructura de pérgola sombreadora bioclimática.'),
('b0000000-0000-4000-8000-000000000003', 'HBQP-03', 'Hospital Biprovincial - Obras e Infraestructura', 'Servicio de Salud Viña del Mar Quillota', 'Unidad de Infraestructura HBQP', 'Infraestructura Hospitalaria', 'Región de Valparaíso', 'Quillota', 'a0000000-0000-4000-8000-000000000004', 'en_desarrollo', '2026-07-01', '2026-10-15', '#DC2626', 70, 'Especificaciones técnicas (EETT) de impermeabilización de estanques de agua potable.'),
('b0000000-0000-4000-8000-000000000004', 'MIR-04', 'Complejo Deportivo Lomas de Miramar II', 'Municipalidad de Arica', 'IND / Secplan', 'Equipamiento Deportivo', 'Región de Arica y Parinacota', 'Arica', 'a0000000-0000-4000-8000-000000000002', 'en_desarrollo', '2026-08-10', '2026-12-20', '#D97706', 25, 'Plan maestro deportivo, multicanchas, iluminación y cálculo de presupuesto estimativo.'),
('b0000000-0000-4000-8000-000000000005', 'SER-05', 'Macrourbanización y Accesibilidad La Serena', 'Inmobiliaria del Norte', 'DOM La Serena', 'Planificación y Loteo Urbano', 'Región de Coquimbo', 'La Serena', 'a0000000-0000-4000-8000-000000000003', 'en_desarrollo', '2026-09-01', '2026-11-15', '#7C3AED', 15, 'Memoria explicativa de accesibilidad universal conforme OGUC y cesiones de áreas verdes.');

INSERT INTO stages (id, project_id, name, sort_order, start_date, end_date, status, responsible_id) VALUES
('c0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'Diagnóstico y Levantamiento', 1, '2026-08-01', '2026-08-25', 'completada', 'a0000000-0000-4000-8000-000000000005'),
('c0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'Anteproyecto y Criterios', 2, '2026-08-26', '2026-09-20', 'en_desarrollo', 'a0000000-0000-4000-8000-000000000003'),
('c0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000001', 'Participación Ciudadana', 3, '2026-09-10', '2026-09-28', 'en_desarrollo', 'a0000000-0000-4000-8000-000000000003'),
('c0000000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000002', 'Diagnóstico Histórico y Topográfico', 1, '2026-08-15', '2026-09-05', 'completada', 'a0000000-0000-4000-8000-000000000005'),
('c0000000-0000-4000-8000-000000000008', 'b0000000-0000-4000-8000-000000000002', 'Anteproyecto y Justificación Técnica', 2, '2026-09-06', '2026-09-25', 'en_desarrollo', 'a0000000-0000-4000-8000-000000000002'),
('c0000000-0000-4000-8000-000000000011', 'b0000000-0000-4000-8000-000000000003', 'Inspección y Diagnóstico Físico', 1, '2026-07-01', '2026-07-31', 'completada', 'a0000000-0000-4000-8000-000000000004'),
('c0000000-0000-4000-8000-000000000012', 'b0000000-0000-4000-8000-000000000003', 'Elaboración EETT y Presupuestos', 2, '2026-08-01', '2026-09-15', 'en_desarrollo', 'a0000000-0000-4000-8000-000000000004'),
('c0000000-0000-4000-8000-000000000014', 'b0000000-0000-4000-8000-000000000004', 'Levantamiento y Estudio de Cabida', 1, '2026-08-10', '2026-09-10', 'en_desarrollo', 'a0000000-0000-4000-8000-000000000005'),
('c0000000-0000-4000-8000-000000000016', 'b0000000-0000-4000-8000-000000000005', 'Estudio Normativo PRC y Memoria', 1, '2026-09-01', '2026-09-30', 'en_desarrollo', 'a0000000-0000-4000-8000-000000000003');

INSERT INTO milestones (id, project_id, stage_id, name, date, time_start, time_end, milestone_type, responsible_id, status, priority, location_override, observations) VALUES
('d0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002', 'Reunión de Coordinación SECPLAN', '2026-09-07', '10:00:00', '11:30:00', 'reunion', 'a0000000-0000-4000-8000-000000000003', 'programado', 'alta', 'Valdivia / Virtual', 'Revisión de observaciones al trazado peatonal de Av. Costanera.'),
('d0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002', 'Entrega Informe Anteproyecto Preliminar', '2026-09-09', '14:00:00', '15:00:00', 'entrega', 'a0000000-0000-4000-8000-000000000003', 'programado', 'alta', 'Valdivia', 'Envío de planimetría y láminas 3D al mandante.'),
('d0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000003', 'Participación Ciudadana N°1 Ribera', '2026-09-12', '18:00:00', '20:00:00', 'participacion', 'a0000000-0000-4000-8000-000000000003', 'programado', 'critica', 'Gimnasio Municipal Valdivia', 'Taller participativo con juntas de vecinos del borde río.'),
('d0000000-0000-4000-8000-000000000004', 'b0000000-0000-4000-8000-000000000001', 'c0000000-0000-4000-8000-000000000002', 'Estado de Pago N°2 Aprobado', '2026-09-18', '12:00:00', '13:00:00', 'estado_pago', 'a0000000-0000-4000-8000-000000000001', 'programado', 'media', 'Valdivia', 'Liberación de factura según avance del 45%.'),
('d0000000-0000-4000-8000-000000000005', 'b0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000008', 'Visita Técnica de Terreno Adoquines', '2026-09-08', '09:30:00', '12:00:00', 'terreno', 'a0000000-0000-4000-8000-000000000002', 'programado', 'alta', 'Traiguén', 'Muestreo de rasante y estado de conservación de adoquines.'),
('d0000000-0000-4000-8000-000000000006', 'b0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000008', 'Mesa Técnica SECPLAN - SERVIU', '2026-09-11', '10:30:00', '12:00:00', 'reunion', 'a0000000-0000-4000-8000-000000000002', 'programado', 'alta', 'Santiago / Virtual', 'Revisión de especificaciones NCh 1508.'),
('d0000000-0000-4000-8000-000000000007', 'b0000000-0000-4000-8000-000000000002', 'c0000000-0000-4000-8000-000000000008', 'Entrega Memoria de Justificación Urbana', '2026-09-14', '17:00:00', '18:00:00', 'entrega', 'a0000000-0000-4000-8000-000000000002', 'programado', 'media', 'Traiguén', 'Respuesta formal a observaciones.'),
('d0000000-0000-4000-8000-000000000008', 'b0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000012', 'Revisión EETT Impermeabilización Estanques', '2026-09-07', '15:00:00', '16:30:00', 'reunion', 'a0000000-0000-4000-8000-000000000004', 'programado', 'media', 'Quillota', 'Validación de productos Sikadur 31 HMG y Flexcrete 1060 Seal.'),
('d0000000-0000-4000-8000-000000000009', 'b0000000-0000-4000-8000-000000000003', 'c0000000-0000-4000-8000-000000000012', 'Visita de Inspección Techo y Estructuras', '2026-09-11', '11:00:00', '13:00:00', 'terreno', 'a0000000-0000-4000-8000-000000000005', 'programado', 'alta', 'Quillota', 'Chequeo de niveles y drenaje de aguas lluvias.'),
('d0000000-0000-4000-8000-000000000010', 'b0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000014', 'Reunión Comité Técnico de Obras Arica', '2026-09-10', '11:00:00', '12:30:00', 'reunion', 'a0000000-0000-4000-8000-000000000002', 'programado', 'critica', 'Arica / Remoto', 'Revisión de perfil de multicancha y accesibilidad.'),
('d0000000-0000-4000-8000-000000000011', 'b0000000-0000-4000-8000-000000000004', 'c0000000-0000-4000-8000-000000000014', 'Entrega de Levantamiento Topográfico y Rasantes', '2026-09-13', '16:00:00', '17:00:00', 'entrega', 'a0000000-0000-4000-8000-000000000005', 'programado', 'alta', 'Arica', 'Nubes de puntos y curvas de nivel cada 0.50m.');

-- 7. POLÍTICAS RLS CON ACTIVACIÓN TOTAL
-- Con RLS activado (ENABLED), estas políticas permiten a la aplicación operar sin bloqueos
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE projects ENABLE ROW LEVEL SECURITY;
ALTER TABLE stages ENABLE ROW LEVEL SECURITY;
ALTER TABLE milestones ENABLE ROW LEVEL SECURITY;
ALTER TABLE detected_conflicts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "p_orgs_all" ON organizations FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "p_members_all" ON team_members FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "p_projects_all" ON projects FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "p_stages_all" ON stages FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "p_milestones_all" ON milestones FOR ALL TO public USING (true) WITH CHECK (true);
CREATE POLICY "p_conflicts_all" ON detected_conflicts FOR ALL TO public USING (true) WITH CHECK (true);

-- 8. HABILITACIÓN DE REALTIME PARA SINCRONIZACIÓN INSTANTÁNEA
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE projects; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE stages; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE milestones; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE team_members; EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE organizations; EXCEPTION WHEN duplicate_object THEN null; END $$;
