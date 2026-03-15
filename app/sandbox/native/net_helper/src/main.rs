use std::process::Command;
use std::env;

/**
 * Karyon Net Helper
 * A secure wrapper for Firecracker tap device management.
 * In a production environment, this binary would be installed with CAP_NET_ADMIN
 * or as a setuid binary restricted specifically to these operations.
 */

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage: karyon-net-helper <setup|cleanup> <tap_device> [bridge]");
        std::process::exit(1);
    }

    let command = &args[1];
    let tap_device = &args[2];

    // Security check: ensure tap_device matches expected pattern
    if !tap_device.starts_with("tap-vm-") {
        eprintln!("Error: Invalid tap device name. Must start with 'tap-vm-'.");
        std::process::exit(1);
    }

    match command.as_str() {
        "setup" => {
            let bridge = args.get(3).expect("Bridge name required for setup");
            setup_tap(tap_device, bridge);
        }
        "cleanup" => {
            cleanup_tap(tap_device);
        }
        _ => {
            eprintln!("Unknown command: {}", command);
            std::process::exit(1);
        }
    }
}

fn setup_tap(tap: &str, bridge: &str) {
    println!("Setting up tap device: {} on bridge: {}", tap, bridge);

    // 1. Create the tap device
    run_cmd("ip", &["tuntap", "add", "dev", tap, "mode", "tap"]);
    
    // 2. Set the device up
    run_cmd("ip", &["link", "set", tap, "up"]);
    
    // 3. Attach to bridge
    run_cmd("ip", &["link", "set", tap, "master", bridge]);

    // 4. Hardened Firewall: Drop all forwarding by default for this tap
    // This replicates the logic in provisioner.ex but in a centralized place.
    run_cmd("iptables", &["-A", "FORWARD", "-i", tap, "-j", "DROP"]);
    run_cmd("iptables", &["-A", "FORWARD", "-o", tap, "-j", "DROP"]);
    run_cmd("iptables", &["-A", "INPUT", "-i", tap, "-j", "DROP"]);
    
    println!("Tap setup complete and hardened.");
}

fn cleanup_tap(tap: &str) {
    println!("Cleaning up tap device: {}", tap);
    
    // Remove firewall rules first
    run_cmd("iptables", &["-D", "FORWARD", "-i", tap, "-j", "DROP"]);
    run_cmd("iptables", &["-D", "FORWARD", "-o", tap, "-j", "DROP"]);
    run_cmd("iptables", &["-D", "INPUT", "-i", tap, "-j", "DROP"]);

    // Delete the tap device
    run_cmd("ip", &["tuntap", "del", "dev", tap, "mode", "tap"]);
    
    println!("Cleanup complete.");
}

fn run_cmd(cmd: &str, args: &[&str]) {
    let status = Command::new(cmd)
        .args(args)
        .status()
        .expect("Failed to execute command");
    
    if !status.success() {
        eprintln!("Warning: Command '{} {:?}' failed with status {}", cmd, args, status);
    }
}
