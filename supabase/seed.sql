-- =============================================================================
-- supabase/seed.sql
-- =============================================================================
-- This file is run automatically when a new feature schema is created.
-- It should populate the schema with enough realistic data for agents to
-- develop and test against without needing production data.
--
-- IMPORTANT: This runs inside the feature's isolated schema (search_path is set).
-- You can freely INSERT, UPDATE, DELETE — it will never affect other branches.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Example: seed users / profiles
-- Uncomment and adapt to your actual schema
-- -----------------------------------------------------------------------------

-- INSERT INTO auth.users (id, email, created_at) VALUES
--   ('00000000-0000-0000-0000-000000000001', 'alice@example.com', NOW()),
--   ('00000000-0000-0000-0000-000000000002', 'bob@example.com', NOW()),
--   ('00000000-0000-0000-0000-000000000003', 'carol@example.com', NOW());

-- INSERT INTO profiles (id, display_name, avatar_url) VALUES
--   ('00000000-0000-0000-0000-000000000001', 'Alice Admin', NULL),
--   ('00000000-0000-0000-0000-000000000002', 'Bob User', NULL),
--   ('00000000-0000-0000-0000-000000000003', 'Carol Member', NULL);

-- -----------------------------------------------------------------------------
-- Example: seed an organization / workspace
-- -----------------------------------------------------------------------------

-- INSERT INTO organizations (id, name, slug, owner_id) VALUES
--   ('00000000-0000-0000-0000-000000000010', 'Acme Corp', 'acme', '00000000-0000-0000-0000-000000000001');

-- INSERT INTO organization_members (org_id, user_id, role) VALUES
--   ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', 'owner'),
--   ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000002', 'member'),
--   ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000003', 'member');

-- -----------------------------------------------------------------------------
-- Add your project-specific seed data below
-- -----------------------------------------------------------------------------
