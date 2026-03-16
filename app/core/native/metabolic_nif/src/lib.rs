use rustler::NifResult;
use std::fs::File;
use std::io::{BufRead, BufReader};
use perf_event::Builder;
use perf_event::events::Hardware;
use std::sync::Mutex;
use lazy_static::lazy_static;

lazy_static! {
    static ref COUNTER: Mutex<Option<perf_event::Counter>> = Mutex::new(None);
    static ref MOCK_IOPS_OVERRIDE: Mutex<Option<u64>> = Mutex::new(None);
    static ref MOCK_L3_OVERRIDE: Mutex<Option<u64>> = Mutex::new(None);
    static ref SHOULD_FAIL: Mutex<bool> = Mutex::new(false);
}

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
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

pub fn read_iops_impl() -> NifResult<u64> {
    if *SHOULD_FAIL.lock().unwrap() || std::env::var("KARYON_FAIL_NATIVE").is_ok() {
        return Err(rustler::Error::Atom("simulated_failure"));
    }

    if let Some(val) = *MOCK_IOPS_OVERRIDE.lock().unwrap() {
        return Ok(val);
    }

    let mock_env = std::env::var("KARYON_MOCK_HARDWARE").unwrap_or_default();
    if mock_env == "1" || mock_env == "true" {
        return Ok(42);
    }

    let file = File::open("/proc/diskstats").map_err(|_| rustler::Error::Atom("diskstats_open_error"))?;
    let reader = BufReader::new(file);
    Ok(parse_diskstats(reader))
}

#[rustler::nif]
pub fn read_iops() -> (rustler::Atom, u64) {
    match read_iops_impl() {
        Ok(v) => (atoms::ok(), v),
        Err(_) => (atoms::error(), 0),
    }
}

pub fn read_l3_misses_impl() -> NifResult<u64> {
    if *SHOULD_FAIL.lock().unwrap() || std::env::var("KARYON_FAIL_NATIVE").is_ok() {
        return Err(rustler::Error::Atom("simulated_failure"));
    }

    if let Some(val) = *MOCK_L3_OVERRIDE.lock().unwrap() {
        return Ok(val);
    }

    // CI/CD Mock Mode
    let mock_env = std::env::var("KARYON_MOCK_HARDWARE").unwrap_or_default();
    if mock_env == "1" || mock_env == "true" {
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
pub fn read_l3_misses() -> (rustler::Atom, u64) {
    match read_l3_misses_impl() {
        Ok(v) => (atoms::ok(), v),
        Err(_) => (atoms::error(), 0),
    }
}

#[rustler::nif]
pub fn read_numa_node() -> (rustler::Atom, i32) {
    let cpu = unsafe { libc::sched_getcpu() };
    if cpu < 0 {
        return (atoms::ok(), -1);
    }

    // Scan /sys/devices/system/cpu/cpu{cpu}/ node*
    let path = format!("/sys/devices/system/cpu/cpu{}/", cpu);
    if let Ok(entries) = std::fs::read_dir(path) {
        for entry in entries {
            if let Ok(entry) = entry {
                let name = entry.file_name().into_string().unwrap_or_default();
                if name.starts_with("node") {
                    if let Ok(node_id) = name.trim_start_matches("node").parse::<i32>() {
                        return (atoms::ok(), node_id);
                    }
                }
            }
        }
    }
    (atoms::ok(), 0) // Default to node 0 if we can't find it (UMA)
}

#[rustler::nif]
pub fn read_cpu_index() -> (rustler::Atom, i32) {
    let cpu = unsafe { libc::sched_getcpu() };
    (atoms::ok(), cpu)
}

#[rustler::nif]
pub fn set_native_mock(iops: Option<u64>, l3: Option<u64>, fail: bool) -> rustler::Atom {
    if let Ok(mut iops_lock) = MOCK_IOPS_OVERRIDE.lock() {
        *iops_lock = iops;
    }
    if let Ok(mut l3_lock) = MOCK_L3_OVERRIDE.lock() {
        *l3_lock = l3;
    }
    if let Ok(mut fail_lock) = SHOULD_FAIL.lock() {
        *fail_lock = fail;
    }
    atoms::ok()
}

rustler::init!("Elixir.Core.Native", [read_l3_misses, read_iops, read_numa_node, read_cpu_index, set_native_mock]);

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

    #[test]
    fn test_read_iops_mock() {
        std::env::set_var("KARYON_MOCK_HARDWARE", "true");
        let iops = read_iops_impl().unwrap();
        assert_eq!(iops, 42);
    }
}
