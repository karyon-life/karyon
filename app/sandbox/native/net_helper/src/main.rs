use std::env;
use std::ffi::{CString, OsStr, OsString};
use std::fs;
use std::io;
use std::os::fd::{AsRawFd, FromRawFd, OwnedFd, RawFd};
use std::os::raw::{c_char, c_int, c_short, c_uint, c_ulong};
use std::os::unix::ffi::OsStringExt;
use std::path::Path;

const AF_INET: c_int = 2;
const SOCK_DGRAM: c_int = 2;

const IFNAMSIZ: usize = 16;

const IFF_UP: c_short = 0x1;
const IFF_TAP: c_short = 0x2;
const IFF_NO_PI: c_short = 0x1000;

const O_RDWR: c_int = 0x2;

const TUNSETIFF: c_ulong = 0x4004_54ca;
const TUNSETPERSIST: c_ulong = 0x4004_54cb;

const SIOCGIFFLAGS: c_ulong = 0x8913;
const SIOCSIFFLAGS: c_ulong = 0x8914;
const SIOCBRADDIF: c_ulong = 0x89a2;
const SIOCBRDELIF: c_ulong = 0x89a3;

#[repr(C)]
union Ifru {
    flags: c_short,
    ifindex: c_int,
}

#[repr(C)]
struct Ifreq {
    name: [c_char; IFNAMSIZ],
    ifru: Ifru,
}

unsafe extern "C" {
    fn open(pathname: *const c_char, flags: c_int, ...) -> c_int;
    fn socket(domain: c_int, ty: c_int, protocol: c_int) -> c_int;
    fn ioctl(fd: c_int, request: c_ulong, ...) -> c_int;
    fn if_nametoindex(ifname: *const c_char) -> c_uint;
}

fn main() {
    if let Err(error) = run() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = env::args().collect();

    if args.len() < 3 {
        return Err("Usage: karyon-net-helper <setup|cleanup|verify> <tap_device> [bridge]".into());
    }

    let command = &args[1];
    let tap_device = &args[2];

    validate_tap_name(tap_device)?;

    match command.as_str() {
        "setup" => {
            let bridge = args
                .get(3)
                .ok_or_else(|| "Bridge name required for setup".to_string())?;
            validate_bridge_name(bridge)?;
            setup_tap(tap_device, bridge)
        }
        "cleanup" => cleanup_tap(tap_device),
        "verify" => verify_tap(tap_device),
        _ => Err(format!("Unknown command: {command}")),
    }
}

fn setup_tap(tap: &str, bridge: &str) -> Result<(), String> {
    println!("Setting up tap device: {tap} on bridge: {bridge}");

    let tun = open_tun()?;

    create_persistent_tap(tun.as_raw_fd(), tap)?;
    if let Err(error) = attach_to_bridge(tap, bridge).and_then(|_| bring_link_up(tap)) {
        let _ = remove_persistent_tap(tap);
        return Err(error);
    }

    println!("Tap setup complete.");
    Ok(())
}

fn cleanup_tap(tap: &str) -> Result<(), String> {
    println!("Cleaning up tap device: {tap}");

    if !interface_exists(tap) {
        println!("Tap device {tap} is already absent.");
        return Ok(());
    }

    if let Some(bridge) = bridge_for_tap(tap)? {
        detach_from_bridge(tap, &bridge)?;
    }

    remove_persistent_tap(tap)?;

    println!("Cleanup complete.");
    Ok(())
}

fn verify_tap(tap: &str) -> Result<(), String> {
    if !interface_exists(tap) {
        return Err(format!("Verification failed: tap {tap} does not exist."));
    }

    if !interface_is_up(tap)? {
        return Err(format!("Verification failed: tap {tap} is not up."));
    }

    let bridge = bridge_for_tap(tap)?
        .ok_or_else(|| format!("Verification failed: tap {tap} is not attached to a bridge."))?;

    ensure_vm_only_bridge(&bridge)?;
    ensure_bridge_has_no_ipv4_routes(&bridge)?;

    println!("Verification successful: tap {tap} is isolated on bridge {bridge}.");
    Ok(())
}

fn validate_tap_name(name: &str) -> Result<(), String> {
    if name.starts_with("tap-vm-")
        && name.len() < IFNAMSIZ
        && name.bytes().all(|byte| byte.is_ascii_alphanumeric() || byte == b'-')
    {
        Ok(())
    } else {
        Err("Error: Invalid tap device name. Must start with 'tap-vm-' and fit IFNAMSIZ.".into())
    }
}

fn validate_bridge_name(name: &str) -> Result<(), String> {
    if !name.is_empty()
        && name.len() < IFNAMSIZ
        && name.bytes().all(|byte| byte.is_ascii_alphanumeric() || byte == b'-' || byte == b'_')
    {
        Ok(())
    } else {
        Err("Error: Invalid bridge name.".into())
    }
}

fn open_tun() -> Result<OwnedFd, String> {
    let path = CString::new("/dev/net/tun").expect("CString literal");
    let fd = unsafe { open(path.as_ptr(), O_RDWR) };

    if fd < 0 {
        return Err(format!("Failed to open /dev/net/tun: {}", io::Error::last_os_error()));
    }

    let owned = unsafe { OwnedFd::from_raw_fd(fd) };
    Ok(owned)
}

fn create_persistent_tap(fd: RawFd, tap: &str) -> Result<(), String> {
    let mut ifreq = new_ifreq(tap);

    ifreq.ifru.flags = IFF_TAP | IFF_NO_PI;

    ioctl_ifreq(fd, TUNSETIFF, &mut ifreq, "TUNSETIFF")?;

    let persist: c_int = 1;
    ioctl_int(fd, TUNSETPERSIST, persist, "TUNSETPERSIST(1)")?;

    Ok(())
}

fn remove_persistent_tap(tap: &str) -> Result<(), String> {
    let tun = open_tun()?;
    let mut ifreq = new_ifreq(tap);

    ifreq.ifru.flags = IFF_TAP | IFF_NO_PI;

    ioctl_ifreq(tun.as_raw_fd(), TUNSETIFF, &mut ifreq, "TUNSETIFF")?;

    let persist: c_int = 0;
    ioctl_int(tun.as_raw_fd(), TUNSETPERSIST, persist, "TUNSETPERSIST(0)")?;

    Ok(())
}

fn attach_to_bridge(tap: &str, bridge: &str) -> Result<(), String> {
    let socket = inet_socket()?;
    let tap_index = interface_index(tap)?;

    let mut ifreq = new_ifreq(bridge);
    ifreq.ifru.ifindex = tap_index;

    ioctl_ifreq(socket.as_raw_fd(), SIOCBRADDIF, &mut ifreq, "SIOCBRADDIF")
}

fn detach_from_bridge(tap: &str, bridge: &str) -> Result<(), String> {
    let socket = inet_socket()?;
    let tap_index = interface_index(tap)?;

    let mut ifreq = new_ifreq(bridge);
    ifreq.ifru.ifindex = tap_index;

    ioctl_ifreq(socket.as_raw_fd(), SIOCBRDELIF, &mut ifreq, "SIOCBRDELIF")
}

fn bring_link_up(interface: &str) -> Result<(), String> {
    let socket = inet_socket()?;
    let mut ifreq = new_ifreq(interface);

    ioctl_ifreq(socket.as_raw_fd(), SIOCGIFFLAGS, &mut ifreq, "SIOCGIFFLAGS")?;

    let current_flags = unsafe { ifreq.ifru.flags };

    ifreq.ifru.flags = current_flags | IFF_UP;

    ioctl_ifreq(socket.as_raw_fd(), SIOCSIFFLAGS, &mut ifreq, "SIOCSIFFLAGS")
}

fn interface_is_up(interface: &str) -> Result<bool, String> {
    let socket = inet_socket()?;
    let mut ifreq = new_ifreq(interface);

    ioctl_ifreq(socket.as_raw_fd(), SIOCGIFFLAGS, &mut ifreq, "SIOCGIFFLAGS")?;
    let flags = unsafe { ifreq.ifru.flags };

    Ok((flags & IFF_UP) != 0)
}

fn interface_exists(interface: &str) -> bool {
    Path::new("/sys/class/net").join(interface).exists()
}

fn bridge_for_tap(tap: &str) -> Result<Option<String>, String> {
    let master_path = Path::new("/sys/class/net").join(tap).join("master");

    if !master_path.exists() {
        return Ok(None);
    }

    let target = fs::read_link(&master_path).map_err(|error| {
        format!(
            "Failed to read bridge membership for {tap} at {}: {error}",
            master_path.display()
        )
    })?;

    let bridge_name = target
        .file_name()
        .map(os_str_to_string)
        .ok_or_else(|| format!("Failed to parse bridge membership for {tap}."))?;

    Ok(Some(bridge_name))
}

fn ensure_vm_only_bridge(bridge: &str) -> Result<(), String> {
    let members_dir = Path::new("/sys/class/net").join(bridge).join("brif");

    let entries = fs::read_dir(&members_dir)
        .map_err(|error| format!("Failed to inspect bridge members for {bridge}: {error}"))?;

    let mut members = Vec::new();

    for entry in entries {
        let entry = entry.map_err(|error| format!("Failed to read bridge member: {error}"))?;
        let name = os_string_to_string(entry.file_name());
        members.push(name);
    }

    if members.is_empty() {
        return Err(format!("Verification failed: bridge {bridge} has no attached members."));
    }

    if let Some(non_vm_member) = members
        .iter()
        .find(|member| !member.starts_with("tap-vm-"))
    {
        return Err(format!(
            "Verification failed: bridge {bridge} includes non-VM member {non_vm_member}."
        ));
    }

    Ok(())
}

fn ensure_bridge_has_no_ipv4_routes(bridge: &str) -> Result<(), String> {
    let route_table = fs::read_to_string("/proc/net/route")
        .map_err(|error| format!("Failed to inspect IPv4 route table: {error}"))?;

    let has_route = route_table
        .lines()
        .skip(1)
        .filter_map(|line| line.split_whitespace().next())
        .any(|iface| iface == bridge);

    if has_route {
        Err(format!(
            "Verification failed: bridge {bridge} has an IPv4 route and is not air-gapped."
        ))
    } else {
        Ok(())
    }
}

fn interface_index(name: &str) -> Result<c_int, String> {
    let c_name = CString::new(name).map_err(|_| format!("Invalid interface name: {name}"))?;
    let index = unsafe { if_nametoindex(c_name.as_ptr()) };

    if index == 0 {
        Err(format!(
            "Failed to resolve interface index for {name}: {}",
            io::Error::last_os_error()
        ))
    } else {
        Ok(index as c_int)
    }
}

fn inet_socket() -> Result<OwnedFd, String> {
    let fd = unsafe { socket(AF_INET, SOCK_DGRAM, 0) };

    if fd < 0 {
        return Err(format!(
            "Failed to open AF_INET datagram socket: {}",
            io::Error::last_os_error()
        ));
    }

    let socket = unsafe { OwnedFd::from_raw_fd(fd) };
    Ok(socket)
}

fn new_ifreq(name: &str) -> Ifreq {
    let mut ifreq = Ifreq {
        name: [0; IFNAMSIZ],
        ifru: Ifru { ifindex: 0 },
    };

    copy_name(&mut ifreq.name, name);
    ifreq
}

fn copy_name(target: &mut [c_char; IFNAMSIZ], name: &str) {
    let bytes = name.as_bytes();

    for (index, byte) in bytes.iter().enumerate() {
        if index >= IFNAMSIZ - 1 {
            break;
        }

        target[index] = *byte as c_char;
    }
}

fn ioctl_ifreq(fd: RawFd, request: c_ulong, ifreq: &mut Ifreq, operation: &str) -> Result<(), String> {
    let result = unsafe { ioctl(fd, request, ifreq as *mut Ifreq) };

    if result < 0 {
        Err(format!("{operation} failed: {}", io::Error::last_os_error()))
    } else {
        Ok(())
    }
}

fn ioctl_int(fd: RawFd, request: c_ulong, value: c_int, operation: &str) -> Result<(), String> {
    let result = unsafe { ioctl(fd, request, value) };

    if result < 0 {
        Err(format!("{operation} failed: {}", io::Error::last_os_error()))
    } else {
        Ok(())
    }
}

fn os_string_to_string(value: OsString) -> String {
    String::from_utf8_lossy(&value.into_vec()).into_owned()
}

fn os_str_to_string(value: &OsStr) -> String {
    let bytes = value.to_os_string().into_vec();
    String::from_utf8_lossy(&bytes).into_owned()
}
