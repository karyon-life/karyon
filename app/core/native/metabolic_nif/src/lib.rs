use rustler::{NifResult};
use std::fs::File;
use std::io::{BufRead, BufReader};

#[rustler::nif]
pub fn read_l3_misses() -> NifResult<u64> {
    // Placeholder for perf_event_open logic.
    // In a production environment, this would initialize a hardware counter
    // targeting PERF_COUNT_HW_CACHE_MISSES for L3.
    // For MVP, we return a simulated high-precision counter or read from a mock.
    Ok(1024) 
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
                // Field 13 is 'IOs in progress' or similar depending on kernel version
                // but usually we sum reads (field 4) and writes (field 8)
                let reads: u64 = parts[3].parse().unwrap_or(0);
                let writes: u64 = parts[7].parse().unwrap_or(0);
                total_io += reads + writes;
            }
        }
    }
    Ok(total_io)
}

rustler::init!("Elixir.Core.Native", [read_l3_misses, read_iops]);
