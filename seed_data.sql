-- ═══════════════════════════════════════════════════════════════
--  AEGIS PRIME — SEED DATA FOR CHARACTERS
--  Paste this entire file into your Supabase SQL Editor and click RUN.
--  This will populate your database with pre-made Cadets, Players, and NPCs.
-- ═══════════════════════════════════════════════════════════════

INSERT INTO characters (
  student_id, type, name, callsign, role_title, faction, age, origin, 
  class_rank, threat_level, relationship, hull, agi, sys, eng, tech_bonus, 
  motivations, secrets, mech_frame, mech_manufacturer, notes, password
) VALUES 

-- ─── PLAYERS ───
(
  'AP-002-P', 'player', 'Jaxon Vance', 'GHOST', 'Vanguard Pilot', 'Harrison Armory', '21', 'Karrakin Trade Baronies',
  'A', NULL, 'Friendly', 2, 1, 0, 1, 0,
  'Wants to prove his family wrong and become a top-tier Lancer.', 
  'Is secretly funnelling Academy data to a Karrakin syndic in exchange for his tuition.',
  'Sherman', 'Harrison Armory', 'Excellent marksman, terrible at taking orders.', 'vance21'
),
(
  'AP-007-P', 'player', 'Elara Quinn', 'SPARK', 'Electronic Warfare Spec', 'Omninet', '19', 'Deep Space Station',
  'S', NULL, 'Allied', 0, 1, 3, 0, 2,
  'Seeks the truth about the missing Deep Space Colony 4.', 
  'Possesses a corrupted NHP cascade drive that she speaks to when no one is watching.',
  'Goblin', 'HORUS', 'Easily the best hacker in her class. Keeps to herself.', 'sparkhack'
),

-- ─── CADETS (Students) ───
(
  'AP-114-S', 'cadet', 'Tobias Ray', 'CRASH', 'Cadet Rookie', 'Union', '20', 'Cradle',
  'B', NULL, 'Rival', 3, 0, 0, 0, 0,
  'Trying to live up to his father''s legendary Lancer status.', 
  'Failed his entrance exam. His father bribed an administrator to get him in.',
  'Cadet Mark I', 'GMS', 'A bit arrogant, but cracks under pressure.', 'crash123'
),
(
  'AP-099-S', 'cadet', 'Maya Lin', 'FROST', 'Sniper Trainee', 'SSC', '22', 'Sanctuary Node',
  'A', NULL, 'Neutral', 0, 3, 1, 0, 0,
  'Desires a high-ranking corporate job in Smith-Shimano Corpro.', 
  'Is an unauthorized clone produced by SSC, unaware of her true origins.',
  'Monarch', 'SSC', 'Extremely precise, cold, and calculated during live-fire exercises.', 'ssclin'
),
(
  'AP-210-S', 'cadet', 'Kaelen', 'TINKER', 'Mechanic Cadet', 'IPS-N', '24', 'Asteroid Rig',
  'B', NULL, 'Friendly', 1, 0, 0, 3, 1,
  'Wants to own his own mech workshop and retire early.', 
  'Is smuggling restricted military-grade mech parts out of the Academy hangar.',
  'Cadet Mark I', 'GMS', 'Always covered in grease. Helpful but easily bribed.', 'wrench'
),

-- ─── NPCs (Instructors & Threats) ───
(
  'NPC-INS-01', 'npc', 'Commander Rael', 'IRONCLAD', 'Chief Instructor', 'Union Naval', '45', 'Cradle',
  NULL, 'Tier 3', 'Authority', 4, 1, 2, 2, 1,
  'To forge Cadets into weapons capable of handling the incoming war.', 
  'Lost her entire squadron to an uncaged NHP. She is quietly preparing a contingency to wipe the Academy if an NHP breaks loose here.',
  'Everest', 'GMS', 'Strict, unforgiving, heavily augmented with cybernetics.', 'command'
),
(
  'NPC-SYND-99', 'npc', 'Unknown Operative', 'CIPHER', 'Harrison Spy', 'Harrison Armory', '??', 'Unknown',
  NULL, 'Tier 2', 'Hostile', 1, 3, 3, 1, 3,
  'Infiltrate Aegis Prime and steal experimental Lancer chassis blueprints.', 
  'Is actively manipulating Jaxon Vance to secure the drop point coordinates.',
  'Pegasus', 'HORUS', 'Uses optical camo. Rarely seen, highly dangerous hacker.', 'cipher99'
),
(
  'NPC-GANG-05', 'npc', 'Korg', 'MEATSHIELD', 'Local Thug', 'Unaligned', '30', 'Aegis Slums',
  NULL, 'Tier 1', 'Hostile', 3, -1, -2, 1, 0,
  'Wants to scrap Academy mechs for credits on the black market.', 
  'Owes a massive debt to the Karrakin syndic and is desperate.',
  'Industrial Loader', 'IPS-N', 'Loud, brash, not very bright, but hits incredibly hard.', 'meat'
)

ON CONFLICT (student_id) DO UPDATE SET
  type = EXCLUDED.type,
  name = EXCLUDED.name,
  callsign = EXCLUDED.callsign,
  role_title = EXCLUDED.role_title,
  faction = EXCLUDED.faction,
  age = EXCLUDED.age,
  origin = EXCLUDED.origin,
  class_rank = EXCLUDED.class_rank,
  threat_level = EXCLUDED.threat_level,
  relationship = EXCLUDED.relationship,
  hull = EXCLUDED.hull,
  agi = EXCLUDED.agi,
  sys = EXCLUDED.sys,
  eng = EXCLUDED.eng,
  tech_bonus = EXCLUDED.tech_bonus,
  motivations = EXCLUDED.motivations,
  secrets = EXCLUDED.secrets,
  mech_frame = EXCLUDED.mech_frame,
  mech_manufacturer = EXCLUDED.mech_manufacturer,
  notes = EXCLUDED.notes,
  password = EXCLUDED.password;
