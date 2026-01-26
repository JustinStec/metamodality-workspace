-- Supabase Full-Text Search Setup for Metamodality
-- Run this in your Supabase SQL Editor

-- Create the reading_content table
CREATE TABLE IF NOT EXISTS reading_content (
  id TEXT PRIMARY KEY,
  reading_id TEXT NOT NULL,
  week_num INT NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  page_count INT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add the full-text search vector column
ALTER TABLE reading_content
ADD COLUMN IF NOT EXISTS content_tsv TSVECTOR
GENERATED ALWAYS AS (
  setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
  setweight(to_tsvector('english', coalesce(content, '')), 'B')
) STORED;

-- Create GIN index for fast full-text search
CREATE INDEX IF NOT EXISTS idx_reading_content_tsv
ON reading_content USING GIN(content_tsv);

-- Create index on reading_id for lookups
CREATE INDEX IF NOT EXISTS idx_reading_content_reading_id
ON reading_content(reading_id);

-- Create index on week_num for filtering
CREATE INDEX IF NOT EXISTS idx_reading_content_week_num
ON reading_content(week_num);

-- Enable Row Level Security
ALTER TABLE reading_content ENABLE ROW LEVEL SECURITY;

-- Allow public read access (everyone can search)
CREATE POLICY "Public read access" ON reading_content
  FOR SELECT USING (true);

-- Only authenticated users can insert/update (for indexing)
CREATE POLICY "Authenticated insert" ON reading_content
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "Authenticated update" ON reading_content
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

-- Function to search reading content
CREATE OR REPLACE FUNCTION search_readings(search_query TEXT, limit_count INT DEFAULT 20)
RETURNS TABLE (
  id TEXT,
  reading_id TEXT,
  week_num INT,
  title TEXT,
  snippet TEXT,
  rank REAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    rc.id,
    rc.reading_id,
    rc.week_num,
    rc.title,
    ts_headline('english', rc.content, plainto_tsquery('english', search_query),
      'StartSel=<mark>, StopSel=</mark>, MaxWords=50, MinWords=20') as snippet,
    ts_rank(rc.content_tsv, plainto_tsquery('english', search_query)) as rank
  FROM reading_content rc
  WHERE rc.content_tsv @@ plainto_tsquery('english', search_query)
  ORDER BY rank DESC
  LIMIT limit_count;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION search_readings TO anon, authenticated;

-- =============================================
-- NOTES TABLE (private per-user notes)
-- =============================================

CREATE TABLE IF NOT EXISTS notes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT,
  content TEXT,
  linked_readings TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for user lookups
CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id);

-- Enable Row Level Security
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- Users can only see their own notes (PRIVATE)
CREATE POLICY "Users can view own notes" ON notes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own notes" ON notes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own notes" ON notes
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own notes" ON notes
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- DRAFTS TABLE (for Substack-style essay drafts)
-- =============================================

CREATE TABLE IF NOT EXISTS drafts (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT,
  subtitle TEXT,
  content TEXT,
  linked_readings TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for user lookups
CREATE INDEX IF NOT EXISTS idx_drafts_user_id ON drafts(user_id);

-- Enable Row Level Security
ALTER TABLE drafts ENABLE ROW LEVEL SECURITY;

-- Users can only see their own drafts
CREATE POLICY "Users can view own drafts" ON drafts
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own drafts" ON drafts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own drafts" ON drafts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own drafts" ON drafts
  FOR DELETE USING (auth.uid() = user_id);

-- =============================================
-- POSTS TABLE UPDATES
-- =============================================

ALTER TABLE posts ADD COLUMN IF NOT EXISTS subtitle TEXT;
ALTER TABLE posts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

-- Ensure RLS is enabled on posts
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;

-- Everyone can read posts
CREATE POLICY IF NOT EXISTS "Public read posts" ON posts
  FOR SELECT USING (true);

-- Authenticated users can create posts
CREATE POLICY IF NOT EXISTS "Authenticated insert posts" ON posts
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = author_id);

-- Users can update their own posts
CREATE POLICY IF NOT EXISTS "Users can update own posts" ON posts
  FOR UPDATE USING (auth.uid() = author_id);

-- Users can delete their own posts
CREATE POLICY IF NOT EXISTS "Users can delete own posts" ON posts
  FOR DELETE USING (auth.uid() = author_id);

-- =============================================
-- WORKSHOP COMMENTS TABLE
-- =============================================

CREATE TABLE IF NOT EXISTS workshop_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  workshop_id INT NOT NULL,
  author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  author_email TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workshop_comments_workshop_id ON workshop_comments(workshop_id);

ALTER TABLE workshop_comments ENABLE ROW LEVEL SECURITY;

-- Everyone can read workshop comments
CREATE POLICY "Public read workshop comments" ON workshop_comments
  FOR SELECT USING (true);

-- Authenticated users can post comments
CREATE POLICY "Authenticated insert workshop comments" ON workshop_comments
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = author_id);

-- Users can delete their own comments
CREATE POLICY "Users can delete own workshop comments" ON workshop_comments
  FOR DELETE USING (auth.uid() = author_id);

-- =============================================
-- POST COMMENTS TABLE (comments on essays)
-- =============================================

CREATE TABLE IF NOT EXISTS post_comments (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
  author_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  author_email TEXT,
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_post_comments_post_id ON post_comments(post_id);

ALTER TABLE post_comments ENABLE ROW LEVEL SECURITY;

-- Everyone can read post comments
CREATE POLICY "Public read post comments" ON post_comments
  FOR SELECT USING (true);

-- Authenticated users can post comments
CREATE POLICY "Authenticated insert post comments" ON post_comments
  FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = author_id);

-- Users can delete their own comments
CREATE POLICY "Users can delete own post comments" ON post_comments
  FOR DELETE USING (auth.uid() = author_id);

-- =============================================
-- ALLOWED EMAILS (invite whitelist)
-- =============================================

CREATE TABLE IF NOT EXISTS allowed_emails (
  email TEXT PRIMARY KEY,
  added_by TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Allow public read (so we can check emails before full auth)
ALTER TABLE allowed_emails ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read allowed emails" ON allowed_emails
  FOR SELECT USING (true);

-- Function to check if email is allowed
CREATE OR REPLACE FUNCTION is_email_allowed(check_email TEXT)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM allowed_emails WHERE LOWER(email) = LOWER(check_email));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION is_email_allowed TO anon, authenticated;
