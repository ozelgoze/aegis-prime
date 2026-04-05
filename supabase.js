// ═══════════════════════════════════════════════════════════════
//  AEGIS PRIME — SUPABASE CLIENT
//  Fill in your Supabase project URL and anon key below.
// ═══════════════════════════════════════════════════════════════

const SUPABASE_URL = 'https://wygeqbmobhcdxrykoifr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_0iA5mMIVwiG9I2UVBogeKg_3mNdlJd6';

// Initialize client (using supabase-js CDN loaded before this file)
let _supabase = null;
try {
  if (SUPABASE_URL !== 'YOUR_SUPABASE_URL' && SUPABASE_ANON_KEY !== 'YOUR_SUPABASE_ANON_KEY') {
    _supabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  } else {
    console.warn('AEGIS PRIME: Supabase credentials not configured. Edit supabase.js with your project URL and anon key.');
  }
} catch (e) {
  console.error('AEGIS PRIME: Failed to initialize Supabase client:', e.message);
}

// ── Google Drive URL Converter ──────────────────────────────────
// Accepts various Google Drive URL formats and returns an embeddable image URL.
// Supports:
//   https://drive.google.com/file/d/FILE_ID/view?usp=sharing
//   https://drive.google.com/open?id=FILE_ID
//   https://drive.google.com/uc?id=FILE_ID
//   Raw FILE_ID (if no URL pattern detected)
function convertDriveUrl(url) {
  if (!url || url.trim() === '') return '';

  url = url.trim();

  // Already an embeddable lh3 URL
  if (url.includes('lh3.googleusercontent.com')) return url;

  // Extract file ID from various Drive URL formats
  let fileId = null;

  // Format: /file/d/FILE_ID/...
  const fileMatch = url.match(/\/file\/d\/([a-zA-Z0-9_-]+)/);
  if (fileMatch) fileId = fileMatch[1];

  // Format: ?id=FILE_ID or &id=FILE_ID
  if (!fileId) {
    const idMatch = url.match(/[?&]id=([a-zA-Z0-9_-]+)/);
    if (idMatch) fileId = idMatch[1];
  }

  // Format: /d/FILE_ID (shorter share links)
  if (!fileId) {
    const shortMatch = url.match(/\/d\/([a-zA-Z0-9_-]+)/);
    if (shortMatch) fileId = shortMatch[1];
  }

  // If we found a file ID, return the lh3 embeddable URL
  if (fileId) {
    return `https://lh3.googleusercontent.com/d/${fileId}`;
  }

  // If it's a direct image URL (not Drive), return as-is
  if (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('data:')) {
    return url;
  }

  // Assume raw file ID
  if (/^[a-zA-Z0-9_-]{20,}$/.test(url)) {
    return `https://lh3.googleusercontent.com/d/${url}`;
  }

  return url;
}

// ── Database Helpers ────────────────────────────────────────────

async function saveCharacter(data) {
  if (!_supabase) return { error: { message: 'Supabase not configured. Edit supabase.js with your project URL and anon key.' } };
  // Ensure required fields
  if (!data.student_id || !data.name) {
    return { error: { message: 'Student ID and Name are required.' } };
  }

  const record = {
    student_id: data.student_id,
    type: data.type || 'cadet',
    name: data.name,
    callsign: data.callsign || null,
    role_title: data.role_title || null,
    faction: data.faction || null,
    age: data.age || null,
    origin: data.origin || null,
    portrait_url: data.portrait_url || null,
    class_rank: data.class_rank || null,
    threat_level: data.threat_level || null,
    relationship: data.relationship || null,
    background: data.background || null,
    innate_talent: data.innate_talent || null,
    discipline: data.discipline || null,
    hull: data.hull || 0,
    agi: data.agi || 0,
    sys: data.sys || 0,
    eng: data.eng || 0,
    triggers: data.triggers || {},
    talents: data.talents || [],
    specialization: data.specialization || null,
    motivations: data.motivations || null,
    secrets: data.secrets || null,
    mech_frame: data.mech_frame || 'Cadet Mark I',
    mech_manufacturer: data.mech_manufacturer || 'GMS',
    notes: data.notes || null,
    updated_at: new Date().toISOString()
  };

  const { data: result, error } = await _supabase
    .from('characters')
    .upsert(record, { onConflict: 'student_id' })
    .select()
    .single();

  return { data: result, error };
}

async function batchSaveCharacters(recordsArray) {
  if (!_supabase) return { error: { message: 'Supabase not configured.' } };
  
  // Format each record properly
  const formattedRecords = recordsArray.map(data => ({
    student_id: data.student_id,
    type: data.type || 'cadet',
    name: data.name,
    password: data.password || null,
    callsign: data.callsign || null,
    role_title: data.role_title || null,
    faction: data.faction || null,
    age: data.age || null,
    origin: data.origin || null,
    portrait_url: data.portrait_url || null,
    class_rank: data.class_rank || null,
    threat_level: data.threat_level || null,
    relationship: data.relationship || null,
    background: data.background || null,
    innate_talent: data.innate_talent || null,
    discipline: data.discipline || null,
    hull: parseInt(data.hull) || 0,
    agi: parseInt(data.agi) || 0,
    sys: parseInt(data.sys) || 0,
    eng: parseInt(data.eng) || 0,
    tech_bonus: parseInt(data.tech_bonus) || 0,
    triggers: data.triggers || {},
    talents: data.talents || [],
    specialization: data.specialization || null,
    motivations: data.motivations || null,
    secrets: data.secrets || null,
    mech_frame: data.mech_frame || 'Cadet Mark I',
    mech_manufacturer: data.mech_manufacturer || 'GMS',
    notes: data.notes || null,
    updated_at: new Date().toISOString()
  })).filter(r => r.student_id && r.name); // Ignore empty rows entirely

  if (formattedRecords.length === 0) return { data: [], error: {message: 'No valid records with ID and Name found in sheet.'} };

  const { data, error } = await _supabase
    .from('characters')
    .upsert(formattedRecords, { onConflict: 'student_id' })
    .select();

  return { data, error };
}

async function getCharacters(typeFilter) {
  if (!_supabase) return { data: [], error: { message: 'Supabase not configured. Edit supabase.js with your project URL and anon key.' } };
  let query = _supabase
    .from('characters')
    .select('*')
    .order('created_at', { ascending: false });

  if (typeFilter && typeFilter !== 'all') {
    query = query.eq('type', typeFilter);
  }

  const { data, error } = await query;
  return { data: data || [], error };
}

async function getCharacter(studentId) {
  if (!_supabase) return { data: null, error: { message: 'Supabase not configured.' } };
  const { data, error } = await _supabase
    .from('characters')
    .select('*')
    .eq('student_id', studentId)
    .single();

  return { data, error };
}

async function deleteCharacter(studentId) {
  if (!_supabase) return { error: { message: 'Supabase not configured.' } };
  const { data, error } = await _supabase
    .from('characters')
    .delete()
    .eq('student_id', studentId)
    .select();
  if (!error && (!data || data.length === 0)) {
    return { error: { message: "No row matched this ID or RLS silently blocked deletion." } };
  }
  return { error };
}

async function updateCharacter(studentId, updates) {
  if (!_supabase) return { data: null, error: { message: 'Supabase not configured.' } };
  updates.updated_at = new Date().toISOString();

  const { data, error } = await _supabase
    .from('characters')
    .update(updates)
    .eq('student_id', studentId)
    .select()
    .single();

  return { data, error };
}

async function searchCharacters(query) {
  if (!_supabase) return { data: [], error: { message: 'Supabase not configured.' } };
  const { data, error } = await _supabase
    .from('characters')
    .select('*')
    .or(`name.ilike.%${query}%,callsign.ilike.%${query}%,student_id.ilike.%${query}%`)
    .order('created_at', { ascending: false });

  return { data: data || [], error };
}
