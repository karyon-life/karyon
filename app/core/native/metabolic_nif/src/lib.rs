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

pub fn parse_diskstats<R: BufRead>(reader: R) -> u64 {
    let mut total_io: u64 = 0;
    for line in reader.lines() {
        if let Ok(l) = line {
            let parts: Vec<&str> = l.split_whitespace().collect();
            if parts.len() >= 13 {
                // Sum reads (field 4) and writes (field 8)
                let reads: u64 = parts[3].parse().unwrap_or(0);
                let writes: u64 = parts[7].parse().unwrap_or(0);
                total_io += reads + writes;
            }
        }
    }
    total_io
}

pub fn read_l3_misses_impl() -> NifResult<u64> {
    // CI/CD Mock Mode
    if std::env::var("KARYON_MOCK_HARDWARE").is_ok() {
        return Ok(1337);
    }

    let Ok(mut counter_lock) = COUNTER.lock() else { return Err(rustler::Error::Atom("mutex_error")) };

    if counter_lock.is_none() {
        // Initialize the hardware counter for L3 cache misses
        let mut counter = Builder::new()
            .kind(Hardware::CACHE_MISSES)
            .build()
            .map_err(|_| rustler::Error::Atom("perf_event_error"))?;
        
        counter.enable().map_err(|_| rustler::Error::Atom("perf_event_enable_error"))?;
        *counter_lock = Some(counter);
    }

    let counter = counter_lock.as_mut().unwrap();
    let count = counter.read().map_err(|_| rustler::Error::Atom("perf_event_read_error"))?;
    
    Ok(count)
}

#[rustler::nif]
pub fn read_l3_misses() -> NifResult<u64> {
    read_l3_misses_impl()
}

#[rustler::nif]
pub fn read_iops() -> NifResult<u64> {
    // Read from /proc/diskstats
    let file = File::open("/proc/diskstats").map_err(|_| rustler::Error::Atom("diskstats_error"))?;
    let reader = BufReader::new(file);
    Ok(parse_diskstats(reader))
}

rustler::init!("Elixir.Core.Native");

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn test_parse_diskstats() {
        let data = "   8       0 sda 100 0 1000 0 200 0 2000 0 0 0 0";
        let reader = Cursor::new(data);
        let iops = parse_diskstats(reader);
        assert_eq!(iops, 300); // 100 reads + 200 writes
    }

    #[test]
    fn test_parse_diskstats_empty() {
        let data = "";
        let reader = Cursor::new(data);
        let iops = parse_diskstats(reader);
        assert_eq!(iops, 0);
    }

    #[test]
    fn test_parse_diskstats_malformed() {
        let data = "garbage data";
        let reader = Cursor::new(data);
        let iops = parse_diskstats(reader);
        assert_eq!(iops, 0);
    }

    #[test]
    fn test_read_l3_misses_mock() {
        std::env::set_var("KARYON_MOCK_HARDWARE", "true");
        let misses = read_l3_misses_impl().unwrap();
        assert_eq!(misses, 1337);
    }
}
