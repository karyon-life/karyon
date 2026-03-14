use rustler::NifResult;
use std::fs::File;
use std::io::{BufRead, BufReader};
use perf_event::Builder;
use perf_event::events::Hardware;
use std::sync::Mutex;
use lazy_static::lazy_static;

lazy_static! {
    static ref COUNTER: Mutex<Option<perf_event::Counter>> = Mutex::new(None);
}

#[rustler::nif]
pub fn read_l3_misses() -> NifResult<u64> {
    // CI/CD Mock Mode
    if std::env::var("KARYON_MOCK_HARDWARE").is_ok() {
        return Ok(1337);
    }

    let mut counter_lock = COUNTER.lock().unwrap();

    if counter_lock.is_none() {
        // Initialize the hardware counter for L3 cache misses
        let counter = Builder::new()
            .kind(Hardware::CACHE_MISSES)
            .build()
            .map_err(|_| rustler::Error::Term)?;
        
        counter.enable().map_err(|_| rustler::Error::Term)?;
        *counter_lock = Some(counter);
    }

    let counter = counter_lock.as_mut().unwrap();
    let count = counter.read().map_err(|_| rustler::Error::Term)?;
    
    // We return the delta or absolute? For metabolic daemon, absolute is fine for thresholding 
    // or we can reset. Let's return absolute for now.
    Ok(count)
}

#[rustler::nif]
pub fn read_iops() -> NifResult<u64> {
    // Read from /proc/diskstats
    let file = File::open("/proc/diskstats").map_err(|_| rustler::Error::Term)?;
    let reader = BufReader::new(file);
    
    let mut total_io: u64 = 0;
    for line in reader.lines() {
        if let Ok(l) = line {
            let parts: Vec<&str> = l.split_whitespace().collect();
            if parts.len() > 12 {
                // Sum reads (field 4) and writes (field 8)
                let reads: u64 = parts[3].parse().unwrap_or(0);
                let writes: u64 = parts[7].parse().unwrap_or(0);
                total_io += reads + writes;
            }
        }
    }
    Ok(total_io)
}

rustler::init!("Elixir.Core.Native", [read_l3_misses, read_iops]);
