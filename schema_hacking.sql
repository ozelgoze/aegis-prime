-- ═══════════════════════════════════════════════════════════════
--  AEGIS PRIME — HACKING TERMINAL SCHEMA
--  Paste this in your Supabase SQL Editor and click Run.
-- ═══════════════════════════════════════════════════════════════

-- Add tech_bonus to existing characters table (for d20 roll advantages)
ALTER TABLE characters ADD COLUMN IF NOT EXISTS tech_bonus INT DEFAULT 0;

-- Hacking sessions
CREATE TABLE IF NOT EXISTS hacking_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  hacker_id TEXT NOT NULL,
  target_id TEXT NOT NULL,
  current_layer INT DEFAULT 0,
  trace_level INT DEFAULT 0,
  buffer JSONB DEFAULT '{}',
  status TEXT DEFAULT 'active',
  last_failed_layer INT
);

ALTER TABLE hacking_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all hacking_sessions" ON hacking_sessions;
CREATE POLICY "Allow all hacking_sessions" ON hacking_sessions FOR ALL USING (true) WITH CHECK (true);

-- Player knowledge (permanent intel)
CREATE TABLE IF NOT EXISTS player_knowledge (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  extracted_at TIMESTAMPTZ DEFAULT now(),
  owner_id TEXT NOT NULL,
  target_id TEXT NOT NULL,
  layer INT NOT NULL,
  data JSONB NOT NULL,
  UNIQUE(owner_id, target_id, layer)
);

ALTER TABLE player_knowledge ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow all player_knowledge" ON player_knowledge;
CREATE POLICY "Allow all player_knowledge" ON player_knowledge FOR ALL USING (true) WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════
--  RPC FUNCTION: execute_hack_command
--  Called via: supabase.rpc('execute_hack_command', {...})
--  Dice: 1d20 + SYS + tech_bonus - difficulty_modifier
--  DC: 10 always
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION execute_hack_command(
  p_hacker_id TEXT,
  p_command TEXT,
  p_arg TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_hacker RECORD;
  v_target RECORD;
  v_session RECORD;
  v_roll INT;
  v_d6_1 INT; v_d6_2 INT; v_d6_3 INT;
  v_modifier INT := 0;
  v_total INT;
  v_dc INT := 10;
  v_success BOOLEAN;
  v_layer INT;
  v_diff INT;
  v_data JSONB;
  v_roll_detail TEXT;
  v_trace INT;
  v_nodes JSONB;
  v_max_d6 INT;
  v_base_stat INT;
  v_i INT;
BEGIN
  -- ─── GET HACKER ───
  SELECT * INTO v_hacker FROM characters WHERE student_id = p_hacker_id;
  IF v_hacker IS NULL THEN
    RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('ERROR: HACKER ID [' || p_hacker_id || '] NOT FOUND.'),'trace_level',0);
  END IF;
  v_base_stat := COALESCE(v_hacker.sys, 0) + COALESCE(v_hacker.tech_bonus, 0);

  -- ─── CHECK DAILY HACK LIMIT ───
  IF p_command IN ('scan_local', 'crack') THEN
    -- If there's an older session in the last 24h that is NOT active, block it
    IF EXISTS (
      SELECT 1 FROM hacking_sessions
      WHERE hacker_id = p_hacker_id
      AND created_at > now() - interval '1 day'
      AND status != 'active'
    ) THEN
      -- Allow them to crack if they already have an active session
      IF p_command = 'crack' AND EXISTS (SELECT 1 FROM hacking_sessions WHERE hacker_id = p_hacker_id AND target_id = UPPER(COALESCE(p_arg,'')) AND status = 'active') THEN
        -- Continue
      ELSE
        RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('SYSTEM LOCKED: DAILY INTRUSION LIMIT REACHED','Your terminal fingerprint is currently cooling down.','Try again in 24 hours. Use "intel" to review data.'),'trace_level',0);
      END IF;
    END IF;
  END IF;

  -- ═══ SCAN LOCAL ═══
  IF p_command = 'scan_local' THEN
    SELECT jsonb_agg(jsonb_build_object(
      'id', student_id,
      'signal', (floor(random()*40+60))::int,
      'type', UPPER(type),
      'partial', LEFT(name,2) || '████████'
    )) INTO v_nodes
    FROM characters WHERE student_id != p_hacker_id;

    RETURN jsonb_build_object(
      'status','SUCCESS',
      'output', jsonb_build_array('SCANNING LOCAL NETWORK...','ENUMERATING NODES...','> ' || COALESCE(jsonb_array_length(v_nodes),0) || ' TARGET(S) DETECTED'),
      'trace_level', 0,
      'nodes', COALESCE(v_nodes,'[]'::jsonb)
    );

  -- ═══ CRACK (Layer 1, 0 Diff) ═══
  ELSIF p_command = 'crack' THEN
    IF p_arg IS NULL OR p_arg = '' THEN
      RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('USAGE: crack <TARGET_ID>','Run "scan local" first.'),'trace_level',0);
    END IF;
    SELECT * INTO v_target FROM characters WHERE student_id = UPPER(p_arg);
    IF v_target IS NULL THEN
      RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('ERROR: NODE [' || UPPER(p_arg) || '] NOT FOUND.'),'trace_level',0);
    END IF;

    SELECT * INTO v_session FROM hacking_sessions WHERE hacker_id=p_hacker_id AND target_id=UPPER(p_arg) AND status='active';
    IF v_session IS NULL THEN
      INSERT INTO hacking_sessions(hacker_id,target_id) VALUES(p_hacker_id,UPPER(p_arg)) RETURNING * INTO v_session;
    END IF;
    IF v_session.current_layer >= 1 THEN
      RETURN jsonb_build_object('status','INFO','output',jsonb_build_array('LAYER 1 ALREADY BREACHED.','Use "crack --level 2" for deeper access.'),'trace_level',v_session.trace_level,'session_id',v_session.id);
    END IF;

    v_roll := floor(random()*20+1)::int;
    v_total := v_roll + v_base_stat;
    v_roll_detail := '1d20('||v_roll||') + SYS('||COALESCE(v_hacker.sys,0)||')';
    IF COALESCE(v_hacker.tech_bonus,0)>0 THEN v_roll_detail:=v_roll_detail||' + TECH('||v_hacker.tech_bonus||')'; END IF;
    v_roll_detail := v_roll_detail||' = '||v_total||' vs DC '||v_dc;
    v_success := v_total >= v_dc;

    IF v_success THEN
      v_data := jsonb_build_object('name',v_target.name,'callsign',v_target.callsign,'class_rank',v_target.class_rank,'threat_level',v_target.threat_level,'faction',v_target.faction,'origin',v_target.origin,'type',v_target.type,'role_title',v_target.role_title);
      UPDATE hacking_sessions SET current_layer=1,trace_level=LEAST(trace_level+5,100),buffer=buffer||jsonb_build_object('layer_1',v_data),last_failed_layer=NULL WHERE id=v_session.id RETURNING trace_level INTO v_trace;
      RETURN jsonb_build_object('status','SUCCESS','output',jsonb_build_array('INITIATING LAYER 1 BREACH...','> ROLL: '||v_roll_detail,'> ██████ ACCESS GRANTED ██████','> SOFT DATA EXTRACTED'),'trace_level',v_trace,'roll_detail',v_roll_detail,'data',v_data,'layer',1,'session_id',v_session.id);
    ELSE
      UPDATE hacking_sessions SET trace_level=LEAST(trace_level+10,100),last_failed_layer=1 WHERE id=v_session.id RETURNING trace_level INTO v_trace;
      IF v_trace >= 100 THEN
        UPDATE hacking_sessions SET status='burned' WHERE id=v_session.id;
        RETURN jsonb_build_object('status','CRITICAL_FAIL','output',jsonb_build_array('LAYER 1 BREACH...','> ROLL: '||v_roll_detail,'> !! TRACE CRITICAL !!','> CONNECTION TERMINATED BY ICE'),'trace_level',100,'roll_detail',v_roll_detail);
      END IF;
      RETURN jsonb_build_object('status','FAIL','output',jsonb_build_array('LAYER 1 BREACH...','> ROLL: '||v_roll_detail,'> ██ BREACH FAILED ██','Use "force" to retry (RISKY) or try again.'),'trace_level',v_trace,'roll_detail',v_roll_detail,'session_id',v_session.id);
    END IF;

  -- ═══ CRACK LEVEL 2 (1 Diff) ═══
  ELSIF p_command = 'crack_l2' THEN
    SELECT * INTO v_session FROM hacking_sessions WHERE hacker_id=p_hacker_id AND status='active' ORDER BY created_at DESC LIMIT 1;
    IF v_session IS NULL THEN RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('NO ACTIVE SESSION.'),'trace_level',0); END IF;
    IF v_session.current_layer < 1 THEN RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('LAYER 1 NOT BREACHED YET.'),'trace_level',v_session.trace_level); END IF;
    IF v_session.current_layer >= 2 THEN RETURN jsonb_build_object('status','INFO','output',jsonb_build_array('LAYER 2 ALREADY BREACHED.','Use "crack --level 3" for deeper access.'),'trace_level',v_session.trace_level); END IF;
    SELECT * INTO v_target FROM characters WHERE student_id=v_session.target_id;

    v_roll := floor(random()*20+1)::int;
    v_d6_1 := floor(random()*6+1)::int;
    v_modifier := v_d6_1;
    v_total := v_roll + v_base_stat - v_modifier;
    v_roll_detail := '1d20('||v_roll||') + SYS('||COALESCE(v_hacker.sys,0)||')';
    IF COALESCE(v_hacker.tech_bonus,0)>0 THEN v_roll_detail:=v_roll_detail||' + TECH('||v_hacker.tech_bonus||')'; END IF;
    v_roll_detail := v_roll_detail||' - 1d6('||v_d6_1||') = '||v_total||' vs DC '||v_dc;
    v_success := v_total >= v_dc;

    IF v_success THEN
      v_data := jsonb_build_object('hull',v_target.hull,'agi',v_target.agi,'sys',v_target.sys,'eng',v_target.eng,'mech_frame',v_target.mech_frame,'talents',v_target.talents,'specialization',v_target.specialization,'triggers',v_target.triggers);
      UPDATE hacking_sessions SET current_layer=2,trace_level=LEAST(trace_level+5,100),buffer=buffer||jsonb_build_object('layer_2',v_data),last_failed_layer=NULL WHERE id=v_session.id RETURNING trace_level INTO v_trace;
      RETURN jsonb_build_object('status','SUCCESS','output',jsonb_build_array('ESCALATING TO LAYER 2...','> ROLL: '||v_roll_detail,'> ██████ FIREWALL BYPASSED ██████','> CRUNCH DATA EXTRACTED'),'trace_level',v_trace,'roll_detail',v_roll_detail,'data',v_data,'layer',2,'session_id',v_session.id);
    ELSE
      UPDATE hacking_sessions SET trace_level=LEAST(trace_level+10,100),last_failed_layer=2 WHERE id=v_session.id RETURNING trace_level INTO v_trace;
      IF v_trace >= 100 THEN
        UPDATE hacking_sessions SET status='burned' WHERE id=v_session.id;
        RETURN jsonb_build_object('status','CRITICAL_FAIL','output',jsonb_build_array('LAYER 2...','> ROLL: '||v_roll_detail,'> !! TRACE CRITICAL !!','> CONNECTION TERMINATED BY ICE'),'trace_level',100,'roll_detail',v_roll_detail);
      END IF;
      RETURN jsonb_build_object('status','FAIL','output',jsonb_build_array('LAYER 2...','> ROLL: '||v_roll_detail,'> ██ FIREWALL HELD ██','Use "force" to retry or try again.'),'trace_level',v_trace,'roll_detail',v_roll_detail,'session_id',v_session.id);
    END IF;

  -- ═══ CRACK LEVEL 3 (2 Diff) ═══
  ELSIF p_command = 'crack_l3' THEN
    SELECT * INTO v_session FROM hacking_sessions WHERE hacker_id=p_hacker_id AND status='active' ORDER BY created_at DESC LIMIT 1;
    IF v_session IS NULL THEN RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('NO ACTIVE SESSION.'),'trace_level',0); END IF;
    IF v_session.current_layer < 2 THEN RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('LAYER 2 NOT BREACHED YET.'),'trace_level',v_session.trace_level); END IF;
    IF v_session.current_layer >= 3 THEN RETURN jsonb_build_object('status','INFO','output',jsonb_build_array('ALL LAYERS BREACHED.','Use "extract" to save findings.'),'trace_level',v_session.trace_level); END IF;
    SELECT * INTO v_target FROM characters WHERE student_id=v_session.target_id;

    v_roll := floor(random()*20+1)::int;
    v_d6_1 := floor(random()*6+1)::int; v_d6_2 := floor(random()*6+1)::int;
    v_max_d6 := GREATEST(v_d6_1,v_d6_2);
    v_total := v_roll + v_base_stat - v_max_d6;
    v_roll_detail := '1d20('||v_roll||') + SYS('||COALESCE(v_hacker.sys,0)||')';
    IF COALESCE(v_hacker.tech_bonus,0)>0 THEN v_roll_detail:=v_roll_detail||' + TECH('||v_hacker.tech_bonus||')'; END IF;
    v_roll_detail := v_roll_detail||' - max(2d6['||v_d6_1||','||v_d6_2||'])='||v_max_d6||' = '||v_total||' vs DC '||v_dc;
    v_success := v_total >= v_dc;

    IF v_success THEN
      v_data := jsonb_build_object('secrets',v_target.secrets,'motivations',v_target.motivations,'background',v_target.background,'innate_talent',v_target.innate_talent,'discipline',v_target.discipline,'notes',v_target.notes);
      UPDATE hacking_sessions SET current_layer=3,trace_level=LEAST(trace_level+5,100),buffer=buffer||jsonb_build_object('layer_3',v_data),last_failed_layer=NULL WHERE id=v_session.id RETURNING trace_level INTO v_trace;
      RETURN jsonb_build_object('status','SUCCESS','output',jsonb_build_array('DEEP BREACH — LAYER 3...','> ROLL: '||v_roll_detail,'> ██████ ENCRYPTION BROKEN ██████','> !! CLASSIFIED DATA EXTRACTED !!'),'trace_level',v_trace,'roll_detail',v_roll_detail,'data',v_data,'layer',3,'session_id',v_session.id);
    ELSE
      UPDATE hacking_sessions SET trace_level=LEAST(trace_level+10,100),last_failed_layer=3 WHERE id=v_session.id RETURNING trace_level INTO v_trace;
      IF v_trace >= 100 THEN
        UPDATE hacking_sessions SET status='burned' WHERE id=v_session.id;
        RETURN jsonb_build_object('status','CRITICAL_FAIL','output',jsonb_build_array('LAYER 3...','> ROLL: '||v_roll_detail,'> !! TRACE CRITICAL !!','> CONNECTION TERMINATED'),'trace_level',100,'roll_detail',v_roll_detail);
      END IF;
      RETURN jsonb_build_object('status','FAIL','output',jsonb_build_array('LAYER 3...','> ROLL: '||v_roll_detail,'> ██ ENCRYPTION HELD ██','Use "force" for extreme risk retry.'),'trace_level',v_trace,'roll_detail',v_roll_detail,'session_id',v_session.id);
    END IF;

  -- ═══ FORCE ═══
  ELSIF p_command = 'force' THEN
    SELECT * INTO v_session FROM hacking_sessions WHERE hacker_id=p_hacker_id AND status='active' ORDER BY created_at DESC LIMIT 1;
    IF v_session IS NULL THEN RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('NO ACTIVE SESSION.'),'trace_level',0); END IF;
    IF v_session.last_failed_layer IS NULL THEN RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('NO FAILED BREACH TO RETRY.'),'trace_level',v_session.trace_level); END IF;

    v_layer := v_session.last_failed_layer;
    SELECT * INTO v_target FROM characters WHERE student_id=v_session.target_id;
    v_diff := (v_layer - 1) + 1; -- base diff + 1 for force

    v_roll := floor(random()*20+1)::int;
    IF v_diff = 1 THEN
      v_d6_1 := floor(random()*6+1)::int; v_max_d6 := v_d6_1;
      v_roll_detail := '1d20('||v_roll||') + SYS('||COALESCE(v_hacker.sys,0)||')';
      IF COALESCE(v_hacker.tech_bonus,0)>0 THEN v_roll_detail:=v_roll_detail||' + TECH('||v_hacker.tech_bonus||')'; END IF;
      v_roll_detail := v_roll_detail||' - 1d6('||v_d6_1||') = ';
    ELSIF v_diff = 2 THEN
      v_d6_1 := floor(random()*6+1)::int; v_d6_2 := floor(random()*6+1)::int;
      v_max_d6 := GREATEST(v_d6_1,v_d6_2);
      v_roll_detail := '1d20('||v_roll||') + SYS('||COALESCE(v_hacker.sys,0)||')';
      IF COALESCE(v_hacker.tech_bonus,0)>0 THEN v_roll_detail:=v_roll_detail||' + TECH('||v_hacker.tech_bonus||')'; END IF;
      v_roll_detail := v_roll_detail||' - max(2d6['||v_d6_1||','||v_d6_2||'])='||v_max_d6||' = ';
    ELSE
      v_d6_1 := floor(random()*6+1)::int; v_d6_2 := floor(random()*6+1)::int; v_d6_3 := floor(random()*6+1)::int;
      v_max_d6 := GREATEST(v_d6_1,v_d6_2,v_d6_3);
      v_roll_detail := '1d20('||v_roll||') + SYS('||COALESCE(v_hacker.sys,0)||')';
      IF COALESCE(v_hacker.tech_bonus,0)>0 THEN v_roll_detail:=v_roll_detail||' + TECH('||v_hacker.tech_bonus||')'; END IF;
      v_roll_detail := v_roll_detail||' - max(3d6['||v_d6_1||','||v_d6_2||','||v_d6_3||'])='||v_max_d6||' = ';
    END IF;
    v_total := v_roll + v_base_stat - v_max_d6;
    v_roll_detail := v_roll_detail || v_total || ' vs DC ' || v_dc;
    v_success := v_total >= v_dc;

    IF v_success THEN
      IF v_layer=1 THEN v_data:=jsonb_build_object('name',v_target.name,'callsign',v_target.callsign,'class_rank',v_target.class_rank,'threat_level',v_target.threat_level,'faction',v_target.faction,'origin',v_target.origin,'type',v_target.type,'role_title',v_target.role_title);
      ELSIF v_layer=2 THEN v_data:=jsonb_build_object('hull',v_target.hull,'agi',v_target.agi,'sys',v_target.sys,'eng',v_target.eng,'mech_frame',v_target.mech_frame,'talents',v_target.talents,'specialization',v_target.specialization,'triggers',v_target.triggers);
      ELSE v_data:=jsonb_build_object('secrets',v_target.secrets,'motivations',v_target.motivations,'background',v_target.background,'innate_talent',v_target.innate_talent,'discipline',v_target.discipline,'notes',v_target.notes);
      END IF;
      UPDATE hacking_sessions SET current_layer=v_layer,trace_level=LEAST(trace_level+10,100),buffer=buffer||jsonb_build_object('layer_'||v_layer,v_data),last_failed_layer=NULL WHERE id=v_session.id RETURNING trace_level INTO v_trace;
      RETURN jsonb_build_object('status','SUCCESS','output',jsonb_build_array('!! FORCING LAYER '||v_layer||' !!','> ROLL: '||v_roll_detail,'> ██████ FORCED ACCESS ██████','> LAYER '||v_layer||' DATA EXTRACTED'),'trace_level',v_trace,'roll_detail',v_roll_detail,'data',v_data,'layer',v_layer,'session_id',v_session.id);
    ELSE
      UPDATE hacking_sessions SET trace_level=LEAST(trace_level+50,100),status='burned',last_failed_layer=NULL WHERE id=v_session.id RETURNING trace_level INTO v_trace;
      RETURN jsonb_build_object('status','CRITICAL_FAIL','output',jsonb_build_array('!! FORCING LAYER '||v_layer||' !!','> ROLL: '||v_roll_detail,'> ██████████████████████████████','> !! ICE COUNTERMEASURES ACTIVE !!','> !! TRACE: '||v_trace||'% — BURNED !!','> CONNECTION TERMINATED'),'trace_level',v_trace,'roll_detail',v_roll_detail);
    END IF;

  -- ═══ EXTRACT ═══
  ELSIF p_command = 'extract' THEN
    SELECT * INTO v_session FROM hacking_sessions WHERE hacker_id=p_hacker_id AND status='active' ORDER BY created_at DESC LIMIT 1;
    IF v_session IS NULL THEN RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('NO ACTIVE SESSION.'),'trace_level',0); END IF;
    IF v_session.current_layer = 0 THEN RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('NO DATA IN BUFFER.','Crack a layer first.'),'trace_level',v_session.trace_level); END IF;

    FOR v_i IN 1..v_session.current_layer LOOP
      IF v_session.buffer ? ('layer_'||v_i) THEN
        INSERT INTO player_knowledge(owner_id,target_id,layer,data) VALUES(p_hacker_id,v_session.target_id,v_i,v_session.buffer->'layer_'||v_i) ON CONFLICT(owner_id,target_id,layer) DO UPDATE SET data=EXCLUDED.data, extracted_at=now();
      END IF;
    END LOOP;

    UPDATE hacking_sessions SET status='extracted' WHERE id=v_session.id;
    RETURN jsonb_build_object('status','SUCCESS','output',jsonb_build_array('EXTRACTING TO SECURE STORAGE...','> '||v_session.current_layer||' LAYER(S) SAVED.','> TARGET: '||v_session.target_id,'> SESSION CLOSED.','','Intel now available in your knowledge base.'),'trace_level',v_session.trace_level,'layers_saved',v_session.current_layer);

  -- ═══ INTEL ═══
  ELSIF p_command = 'intel' THEN
    IF p_arg IS NULL OR p_arg = '' THEN
      -- List known targets
      SELECT jsonb_agg(DISTINCT target_id) INTO v_data FROM player_knowledge WHERE owner_id = p_hacker_id;
      IF v_data IS NULL THEN
        RETURN jsonb_build_object('status','SUCCESS','output',jsonb_build_array('SECURE INTEL DATABASE','No extracted intel found. Hack a target and extract data first.'),'trace_level',0);
      END IF;
      RETURN jsonb_build_object('status','SUCCESS','output',jsonb_build_array('SECURE INTEL DATABASE','> KNOWN TARGETS:','Type "intel <TARGET_ID>" to view profiles.'),'trace_level',0,'targets',v_data);
    ELSE
      -- View specific target
      SELECT jsonb_agg(jsonb_build_object('layer', layer, 'data', data)) INTO v_data FROM player_knowledge WHERE owner_id = p_hacker_id AND target_id = UPPER(p_arg);
      IF v_data IS NULL THEN
        RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('ERROR: NO INTEL FOUND FOR ['||UPPER(p_arg)||'].'),'trace_level',0);
      END IF;
      RETURN jsonb_build_object('status','SUCCESS','output',jsonb_build_array('DECRYPTING INTEL: '||UPPER(p_arg),'=================================='),'trace_level',0,'intel_data',v_data);
    END IF;

  ELSE
    RETURN jsonb_build_object('status','ERROR','output',jsonb_build_array('UNKNOWN COMMAND: '||p_command),'trace_level',0);
  END IF;
END;
$$;
