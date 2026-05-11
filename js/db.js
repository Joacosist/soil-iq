/**
 * Soil-IQ — Dual-mode Supabase client
 *
 * - If window.SUPABASE_URL and window.SUPABASE_ANON_KEY are set → real Supabase
 * - Otherwise → demo fallback (no network calls, works offline)
 *
 * Usage in app.html:
 *   <script>
 *     window.SUPABASE_URL      = 'https://xxxx.supabase.co';
 *     window.SUPABASE_ANON_KEY = 'eyJh...';
 *   </script>
 *   <script src="js/db.js"></script>
 */

const DB_MODE = (window.SUPABASE_URL && window.SUPABASE_ANON_KEY) ? 'supabase' : 'demo';

/* ── Supabase client (only created when credentials are present) ── */
let supabase = null;
if (DB_MODE === 'supabase') {
  // Supabase JS v2 must be loaded before this script
  supabase = window.supabase.createClient(
    window.SUPABASE_URL,
    window.SUPABASE_ANON_KEY
  );
  console.log('[Soil-IQ] Using Supabase database at', window.SUPABASE_URL);
} else {
  console.log('[Soil-IQ] No Supabase credentials found — running in demo mode');
}

/* ══════════════════════════════════════════════════════════════
   AUTH
══════════════════════════════════════════════════════════════ */

/**
 * Sign in with email + password.
 * Returns { user, error }.
 */
async function dbSignIn(email, password) {
  if (DB_MODE === 'demo') {
    // Demo mode: validate against DEMO_ACCOUNTS (defined in app.html)
    const account = (window.DEMO_ACCOUNTS || []).find(
      a => a.email === email && a.pass === password
    );
    if (!account) return { user: null, error: 'Credenciales incorrectas' };
    return { user: account, error: null };
  }

  const { data, error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) return { user: null, error: error.message };

  // Fetch profile to get role, name, etc.
  const { data: profile } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', data.user.id)
    .single();

  return {
    user: { ...data.user, ...profile },
    error: null,
  };
}

/**
 * Sign out.
 */
async function dbSignOut() {
  if (DB_MODE === 'supabase') await supabase.auth.signOut();
}

/* ══════════════════════════════════════════════════════════════
   FIELDS
══════════════════════════════════════════════════════════════ */

/**
 * Get all fields the current user can access.
 * Returns array of field objects.
 */
async function dbGetMyFields(userId) {
  if (DB_MODE === 'demo') {
    // Fallback: return USER_FARMS from app.html global
    return window.USER_FARMS || [];
  }

  const { data, error } = await supabase
    .from('field_access')
    .select('field:fields(*)')
    .eq('user_id', userId);

  if (error) { console.error('[db] getMyFields:', error); return []; }
  return data.map(row => row.field);
}

/**
 * Get all fields (admin only).
 */
async function dbGetAllFields() {
  if (DB_MODE === 'demo') return window.ALL_FIELDS || [];

  const { data, error } = await supabase.from('fields').select('*');
  if (error) { console.error('[db] getAllFields:', error); return []; }
  return data;
}

/* ══════════════════════════════════════════════════════════════
   ANALYSES
══════════════════════════════════════════════════════════════ */

/**
 * Save a new lab analysis for a field.
 */
async function dbSaveAnalysis(analysis) {
  if (DB_MODE === 'demo') {
    console.log('[demo] Analysis saved (not persisted):', analysis);
    return { id: 'demo-' + Date.now(), ...analysis };
  }

  const { data, error } = await supabase
    .from('analyses')
    .insert(analysis)
    .select()
    .single();

  if (error) { console.error('[db] saveAnalysis:', error); return null; }
  return data;
}

/**
 * Get all analyses for a field.
 */
async function dbGetFieldAnalyses(fieldId) {
  if (DB_MODE === 'demo') return [];

  const { data, error } = await supabase
    .from('analyses')
    .select('*')
    .eq('field_id', fieldId)
    .order('fecha_muestreo', { ascending: false });

  if (error) { console.error('[db] getFieldAnalyses:', error); return []; }
  return data;
}

/* ══════════════════════════════════════════════════════════════
   MARKETPLACE
══════════════════════════════════════════════════════════════ */

/**
 * Submit a new marketplace product for review.
 */
async function dbSubmitProduct(product) {
  if (DB_MODE === 'demo') {
    console.log('[demo] Product submitted (not persisted):', product);
    return { id: 'demo-' + Date.now(), ...product };
  }

  const { data, error } = await supabase
    .from('marketplace_products')
    .insert({ ...product, estado: 'revision' })
    .select()
    .single();

  if (error) { console.error('[db] submitProduct:', error); return null; }
  return data;
}

/**
 * Get all published marketplace products.
 */
async function dbGetProducts(categoria) {
  if (DB_MODE === 'demo') return (window.MKT_PRODUCTS || {})[categoria] || [];

  let query = supabase.from('marketplace_products').select('*').eq('estado', 'publicado');
  if (categoria) query = query.eq('categoria', categoria);
  const { data, error } = await query;
  if (error) { console.error('[db] getProducts:', error); return []; }
  return data;
}

/* ══════════════════════════════════════════════════════════════
   EXPORTS
══════════════════════════════════════════════════════════════ */
window.SoilDB = {
  mode: DB_MODE,
  signIn: dbSignIn,
  signOut: dbSignOut,
  getMyFields: dbGetMyFields,
  getAllFields: dbGetAllFields,
  saveAnalysis: dbSaveAnalysis,
  getFieldAnalyses: dbGetFieldAnalyses,
  submitProduct: dbSubmitProduct,
  getProducts: dbGetProducts,
};
