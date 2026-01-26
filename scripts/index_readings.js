#!/usr/bin/env node
/**
 * PDF Text Extraction and Indexing Script
 *
 * Extracts text from all reading PDFs and uploads to Supabase for full-text search.
 *
 * Usage:
 *   npm install pdf-parse @supabase/supabase-js
 *   node scripts/index_readings.js
 *
 * Environment variables needed:
 *   SUPABASE_URL - Your Supabase project URL
 *   SUPABASE_SERVICE_KEY - Service role key (not anon key) for inserting
 */

const fs = require('fs');
const path = require('path');
const pdfParse = require('pdf-parse');
const { createClient } = require('@supabase/supabase-js');

// Configuration
const READINGS_DIR = path.join(__dirname, '..', 'readings');
const SUPABASE_URL = process.env.SUPABASE_URL || 'https://your-project.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || 'your-service-key';

// Reading metadata (matches schedule in index.html)
const readingsMeta = [
  { id: 'w01_parmenides', week: 1, title: 'Parmenides, "On Nature"', file: 'Week 1_Parmenides/Week 1_Parmenides.pdf' },
  { id: 'w01_kingsley', week: 1, title: 'Kingsley, In the Dark Places of Wisdom', file: 'Week 1_Parmenides/Week 1_Kingsley.pdf' },
  { id: 'w02_meta', week: 2, title: 'Aristotle, Metaphysics Book Θ', file: 'Week 2_Aristotle/Week 2_Aristotle.pdf' },
  { id: 'w02_di', week: 2, title: 'Aristotle, De Interpretatione ch. 9', file: 'Week 2_Aristotle/Week 2_Conway.pdf' },
  { id: 'w02_witt', week: 2, title: 'Witt, "The Priority of Actuality in Aristotle"', file: 'Week 2_Aristotle/Week 2_Witt.pdf' },
  { id: 'w03_avicenna', week: 3, title: 'Avicenna, The Metaphysics of The Healing', file: 'Week 3_Avicenna/Week 3_Avicenna.pdf' },
  { id: 'w03_adamson', week: 3, title: 'Adamson, "From the Necessary Existent to God"', file: 'Week 3_Avicenna/Week 3_Adamson.pdf' },
  { id: 'w04_nagarjuna', week: 4, title: 'Nāgārjuna, Mūlamadhyamakakārikā', file: 'Week 4_Nagarjuna/Week 4_Nagarjuna.pdf' },
  { id: 'w04_garfield', week: 4, title: 'Garfield, "Dependent Arising and the Emptiness of Emptiness"', file: 'Week 4_Nagarjuna/Week 4_Garfield (Essay).pdf' },
  { id: 'w04_commentary', week: 4, title: 'Garfield, Commentary', file: 'Week 4_Nagarjuna/Week 4_Garfield (Commentary).pdf' },
  { id: 'w05_monad', week: 5, title: 'Leibniz, Monadology', file: 'Week 5_Leibniz and Du Châtelet/Leibniz_Monadology.pdf' },
  { id: 'w05_duchat', week: 5, title: 'Du Châtelet, Institutions de physique', file: 'Week 5_Leibniz and Du Châtelet/Week 5_Du Chatelet.pdf' },
  { id: 'w05_orig', week: 5, title: 'Leibniz, "On the Ultimate Origination of Things"', file: 'Week 5_Leibniz and Du Châtelet/Week 5_Leibniz (Origination).pdf' },
  { id: 'w06_kant', week: 6, title: 'Kant, Critique of Pure Reason: "Postulates of Empirical Thought"', file: 'Week 6_Kant and Leech/Week 6_Kant.pdf' },
  { id: 'w06_leech', week: 6, title: 'Leech, "The Function of Modal Judgment and the Kantian Gap"', file: 'Week 6_Kant and Leech/Week 6_Leech.pdf' },
  { id: 'w07_arabi', week: 7, title: 'Ibn ʿArabī, Fuṣūṣ al-Ḥikam', file: 'Week 7_al-Adawiyya and Ibn Arabi/Week 7_Arabi.pdf' },
  { id: 'w08_husserl', week: 8, title: 'Husserl, "The Origin of Geometry"', file: 'Week 8_Husserl and Derrida/Week 8_Husserl and Derrida.pdf' },
  { id: 'w09_heid', week: 9, title: 'Heidegger, Being and Time Division II ch. 1', file: 'Week 9_Heidegger and Arendt/Week 9_Heidegger.pdf' },
  { id: 'w09_arendt', week: 9, title: 'Arendt, The Human Condition ch. 5', file: 'Week 9_Heidegger and Arendt/Week 9_Arendt.pdf' },
  { id: 'w10_peirce', week: 10, title: 'Peirce, "A Guess at the Riddle"', file: 'Week 10_Peirce/Week 10_Peirce.pdf' },
  { id: 'w10_continuity', week: 10, title: '"The Continuity of Life: On Peirce\'s Objective Idealism"', file: 'Week 10_Peirce/Week 10_Ibri (On Peirce\'s Objective Idealism).pdf' },
  { id: 'w11_nishida', week: 11, title: 'Nishida Kitarō, An Inquiry into the Good', file: 'Week 11_Nishida and Lalla/Week 11_Nishida.pdf' },
  { id: 'w11_lalla', week: 11, title: 'Lalla, Naked Song', file: 'Week 11_Nishida and Lalla/Week 11_Lalla.pdf' },
  { id: 'w12_white', week: 12, title: 'Whitehead, Science and the Modern World ch. 11', file: 'Week 12_Whitehead/Week 12_Whitehead.pdf' },
  { id: 'w12_stengers', week: 12, title: 'Stengers, Thinking with Whitehead', file: 'Week 12_Whitehead/Week 12_Stengers (Thinking With Whitehead).pdf' },
  { id: 'w13_thompson', week: 13, title: 'Thompson, Waking, Dreaming, Being ch. 1', file: 'Week 13_Thompson, Weil, Varela /Week 13_Thompson.pdf' },
  { id: 'w13_weil', week: 13, title: 'Weil, "Reflections on the Right Use of School Studies"', file: 'Week 13_Thompson, Weil, Varela /Week 13_Weil.pdf' },
  { id: 'w13_varela', week: 13, title: 'Varela, "Neurophenomenology"', file: 'Week 13_Thompson, Weil, Varela /Week 13_Varela.pdf' },
  { id: 'w14_plotinus', week: 14, title: 'Plotinus, Enneads V.1', file: 'Week 14_Plotinus, Conway/Week 14_Plotinus.pdf' },
  { id: 'w14_conway', week: 14, title: 'Conway, Principles of the Most Ancient and Modern Philosophy', file: 'Week 14_Plotinus, Conway/Week 14_Conway.pdf' },
  { id: 'w15_marcus', week: 15, title: 'Barcan Marcus, "Modalities and Intensional Languages"', file: 'Week 15_Hamkins, Barcon Marcus/Week 15_Marcus.pdf' },
  { id: 'w15_hamkins', week: 15, title: 'Hamkins, "The Set-Theoretic Multiverse"', file: 'Week 15_Hamkins, Barcon Marcus/Week 15_Hamkins (multiverse).pdf' },
  { id: 'w15_linnebo', week: 15, title: 'Hamkins & Linnebo, "The Modal Logic of Set-Theoretic Potentialism"', file: 'Week 15_Hamkins, Barcon Marcus/Week 15_Hamkins and Linnebo.pdf' },
  { id: 'w16_metal', week: 16, title: 'Koch, Silvestro & Foster, "The Evolutionary Dynamics of Cultural Change"', file: 'Week 16_Foster/Week 16_Foster and Koch.pdf' },
  { id: 'w16_borges', week: 16, title: 'Borges, "The Garden of Forking Paths"', file: 'Week 16_Foster/Week 16_Borges.pdf' },
];

async function extractPdfText(filePath) {
  try {
    const dataBuffer = fs.readFileSync(filePath);
    const data = await pdfParse(dataBuffer);
    return {
      text: data.text,
      pageCount: data.numpages
    };
  } catch (err) {
    console.error(`Error extracting text from ${filePath}:`, err.message);
    return null;
  }
}

async function indexReadings() {
  console.log('Starting PDF indexing...\n');

  // Initialize Supabase client with service key
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

  let successCount = 0;
  let errorCount = 0;

  for (const reading of readingsMeta) {
    const filePath = path.join(READINGS_DIR, reading.file);

    if (!fs.existsSync(filePath)) {
      console.log(`⚠️  File not found: ${reading.file}`);
      errorCount++;
      continue;
    }

    console.log(`📄 Processing: ${reading.title}...`);

    const extracted = await extractPdfText(filePath);

    if (!extracted) {
      errorCount++;
      continue;
    }

    // Upsert to Supabase
    const { error } = await supabase
      .from('reading_content')
      .upsert({
        id: reading.id,
        reading_id: reading.id,
        week_num: reading.week,
        title: reading.title,
        content: extracted.text,
        page_count: extracted.pageCount,
        updated_at: new Date().toISOString()
      }, { onConflict: 'id' });

    if (error) {
      console.log(`   ❌ Error uploading: ${error.message}`);
      errorCount++;
    } else {
      console.log(`   ✅ Indexed (${extracted.pageCount} pages, ${extracted.text.length} chars)`);
      successCount++;
    }
  }

  console.log(`\n========================================`);
  console.log(`Indexing complete!`);
  console.log(`  ✅ Success: ${successCount}`);
  console.log(`  ❌ Errors: ${errorCount}`);
  console.log(`========================================\n`);
}

// Run
indexReadings().catch(console.error);
