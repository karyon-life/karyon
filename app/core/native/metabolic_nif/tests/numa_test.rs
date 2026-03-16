extern crate metabolic_nif;

#[cfg(test)]
mod tests {
    use metabolic_nif::*;

    #[test]
    fn test_numa_node_detection() {
        let (atom, node) = read_numa_node();
        assert_eq!(atom.to_string(), "ok");
        // On single-node systems or mock environments, 0 or -1 is common.
        // SPEC.md mandates single-socket, so 0 is the expected production value.
        assert!(node >= -1);
    }

    #[test]
    fn test_cpu_index_detection() {
        let (atom, index) = read_cpu_index();
        assert_eq!(atom.to_string(), "ok");
        assert!(index >= 0);
    }

    #[test]
    fn test_affinity_mask_retrieval() {
        let (atom, mask) = get_affinity_mask();
        assert_eq!(atom.to_string(), "ok");
        assert!(!mask.is_empty());
    }
}
