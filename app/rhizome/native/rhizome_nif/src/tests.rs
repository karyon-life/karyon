use crate::resource::{GraphPointer, create_pointer_impl, get_pointer_id_impl};
use crate::optimizer::identify_communities;
use std::mem;

#[test]
fn test_graph_pointer_alignment() {
    // Mandated by SPEC.md: Tier-0 structures must be 64-byte aligned
    assert_eq!(mem::align_of::<GraphPointer>(), 64);
    assert_eq!(mem::size_of::<GraphPointer>(), 64);
}

#[test]
fn test_graph_pointer_size() {
    // Ensure we don't accidentally bloat the pointer beyond a cache line
    assert!(mem::size_of::<GraphPointer>() <= 64);
}

#[test]
fn test_graph_resource_lock() {
    use std::sync::RwLock;
    let pointer = GraphPointer { node_id: 12345, generation: 1, flags: 0 };
    let resource = crate::resource::GraphResource { pointer: RwLock::new(pointer) };
    assert_eq!(resource.pointer.read().unwrap().node_id, 12345);
}

#[test]
fn test_community_detection_logic() {
    // Disjoint sets
    let edges = vec![
        (0, 1, 1.0),
        (2, 3, 1.0),
    ];
    let communities = identify_communities(edges, 4);
    assert_eq!(communities.len(), 2);
    
    // Dense clique
    let edges = vec![
        (0, 1, 1.0),
        (1, 2, 1.0),
        (2, 0, 1.0),
    ];
    let communities = identify_communities(edges, 3);
    assert_eq!(communities.len(), 1);
    assert_eq!(communities[0].len(), 3);
}

#[test]
fn test_leiden_stability() {
    // Ensure it doesn't panic on empty input
    let communities = identify_communities(vec![], 0);
    assert!(communities.is_empty());
}
