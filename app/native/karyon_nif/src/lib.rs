use rustler::{Atom, Binary, Env, LocalPid, NifResult, OwnedEnv, Encoder};
use lazy_static::lazy_static;
use dashmap::DashMap;
use std::sync::atomic::{AtomicU64, Ordering};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        minted_token,
        missing_token,
    }
}

// =====================================================================
// STEP 1: The Shared State Architecture (The Dictionary)
// =====================================================================

lazy_static! {
    // Structural Memory: IDs start at 256. 0-255 are implicit raw bytes.
    static ref NEXT_ID: AtomicU64 = AtomicU64::new(256);
    
    // (Left, Right) -> Minted Token ID
    static ref PAIR_TO_ID: DashMap<(u64, u64), u64> = DashMap::new();
    
    // Minted Token ID -> (Left, Right)
    static ref ID_TO_PAIR: DashMap<u64, (u64, u64)> = DashMap::new();

    // Metabolic Tracking for PMI (Entropy Calculation)
    static ref TOTAL_TOKENS: AtomicU64 = AtomicU64::new(0);
    static ref TOTAL_PAIRS: AtomicU64 = AtomicU64::new(0);
    static ref PAIR_FREQ: DashMap<(u64, u64), u64> = DashMap::new();
    static ref TOKEN_FREQ: DashMap<u64, u64> = DashMap::new();
}

// =====================================================================
// STEP 2: Sensory Compressor (The Ingestion Path)
// =====================================================================

/// Compresses a raw byte stream into high-level semantic tokens (u64).
/// This runs on a Dirty CPU scheduler to prevent BEAM starvation during heavy stream ingestion.
#[rustler::nif(schedule = "DirtyCpu")]
fn compress_stream(
    env: Env, 
    caller_pid: LocalPid, 
    binary: Binary, 
    pmi_threshold: f64, 
    min_freq: u64
) -> NifResult<Vec<u64>> {
    let data = binary.as_slice();
    let mut buffer: Vec<u64> = Vec::with_capacity(data.len());
    
    for &byte in data {
        let current_token = byte as u64;
        
        // Track baseline occurrence of the atomic/incoming token
        *TOKEN_FREQ.entry(current_token).or_insert(0) += 1;
        TOTAL_TOKENS.fetch_add(1, Ordering::Relaxed);
        
        buffer.push(current_token);

        // Recursive Sliding Window (2-Token Wide)
        while buffer.len() >= 2 {
            let len = buffer.len();
            let t_a = buffer[len - 2];
            let t_b = buffer[len - 1]; // Current top of the buffer
            
            // Fast Path: Is this pair already compressed in our structural memory?
            if let Some(id_ref) = PAIR_TO_ID.get(&(t_a, t_b)) {
                let minted_id = *id_ref;
                buffer.pop();
                buffer.pop();
                buffer.push(minted_id);
                // Continue loop: the newly collapsed token might merge with the one preceding it!
                continue; 
            }
            
            // Slow Path: Pair not recognized. Update metabolic frequencies.
            let pair_count = {
                let mut freq = PAIR_FREQ.entry((t_a, t_b)).or_insert(0);
                *freq += 1;
                *freq
            };
            
            let total_pairs = TOTAL_PAIRS.fetch_add(1, Ordering::Relaxed) + 1;
            
            // Check Metabolic Threshold (PMI)
            if pair_count >= min_freq {
                let freq_a = TOKEN_FREQ.get(&t_a).map(|r| *r).unwrap_or(1); 
                let freq_b = TOKEN_FREQ.get(&t_b).map(|r| *r).unwrap_or(1); 
                let total_tokens = TOTAL_TOKENS.load(Ordering::Relaxed) as f64;
                
                // P(A) * P(B)
                let p_a = freq_a as f64 / total_tokens;
                let p_b = freq_b as f64 / total_tokens;
                
                // P(A, B)
                let p_ab = pair_count as f64 / total_pairs as f64;
                
                // Pointwise Mutual Information (log2)
                let pmi = (p_ab / (p_a * p_b)).log2();
                
                if pmi >= pmi_threshold {
                    // MINT A NEW SUPER-NODE TOKEN!
                    let new_id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
                    PAIR_TO_ID.insert((t_a, t_b), new_id);
                    ID_TO_PAIR.insert(new_id, (t_a, t_b));
                    
                    // Asynchronously notify the BEAM (Cytoplasm) so it can update Memgraph (Rhizome)
                    let mut msg_env = OwnedEnv::new();
                    let _ = msg_env.send_and_clear(&caller_pid, |inner_env| {
                        (atoms::minted_token(), new_id, vec![t_a, t_b]).encode(inner_env)
                    });
                    
                    // Collapse the pair in our ingestion buffer
                    buffer.pop();
                    buffer.pop();
                    buffer.push(new_id);
                    
                    // Register the new token's baseline existence for future mathematical ratios
                    *TOKEN_FREQ.entry(new_id).or_insert(0) += 1;
                    TOTAL_TOKENS.fetch_add(1, Ordering::Relaxed);
                    
                    // Continue loop: recursive merging of the new token
                    continue;
                }
            }
            // Pair didn't cross threshold; break the recursive collapse.
            break;
        }
    }
    
    Ok(buffer)
}

// =====================================================================
// STEP 3: Motor Decompressor (The Output Path)
// =====================================================================

/// Recursively unpacks a high-level semantic integer into its raw binary payload.
/// Runs on a regular scheduler as decompression scales O(N) where N is token depth (microseconds).
#[rustler::nif]
fn decompress_token(env: Env, token: u64) -> NifResult<Vec<u8>> {
    let _ = env;
    let mut out_buffer = Vec::new();
    if recursive_unpack(token, &mut out_buffer) {
        Ok(out_buffer)
    } else {
        Err(rustler::Error::Term(Box::new(atoms::missing_token())))
    }
}

/// Recursive helper to walk the localized plastic memory structure
#[inline]
fn recursive_unpack(token: u64, out: &mut Vec<u8>) -> bool {
    if token < 256 {
        // Base case: Terminated at a raw byte
        out.push(token as u8);
        true
    } else if let Some(pair_ref) = ID_TO_PAIR.get(&token) {
        // Branch: Split and resolve left then right to preserve temporal sequence
        let (left, right) = *pair_ref;
        recursive_unpack(left, out) && recursive_unpack(right, out)
    } else {
        // Apoptosis handling: If a token points to something pruned, we abort.
        false
    }
}

// =====================================================================
// STEP 4: Apoptosis (Pruning Memory)
// =====================================================================

/// Flushes dead tokens that Elixir determines have no synaptic linkages remaining
#[rustler::nif]
fn trigger_apoptosis(env: Env, token: u64) -> NifResult<Atom> {
    let _ = env;
    if token >= 256 {
        if let Some((_, (t_a, t_b))) = ID_TO_PAIR.remove(&token) {
            PAIR_TO_ID.remove(&(t_a, t_b));
            TOKEN_FREQ.remove(&token);
            PAIR_FREQ.remove(&(t_a, t_b));
        }
    }
    Ok(atoms::ok())
}

rustler::init!("Elixir.Karyon.NervousSystem.PeripheralNif", [compress_stream, decompress_token, trigger_apoptosis]);
