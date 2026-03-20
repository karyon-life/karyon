use crate::resource::{GraphPointer, create_pointer_impl, get_pointer_id_impl};
use crate::optimizer::identify_louvain_communities;
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
    let communities = identify_louvain_communities(edges, 4).unwrap();
    assert_eq!(communities.len(), 2);
    
    // Dense clique
    let edges = vec![
        (0, 1, 1.0),
        (1, 2, 1.0),
        (2, 0, 1.0),
    ];
    let communities = identify_louvain_communities(edges, 3).unwrap();
    assert_eq!(communities.len(), 1);
    assert_eq!(communities[0].len(), 3);
}

#[test]
fn test_concurrent_pointer_access() {
    use std::sync::{Arc, Barrier};
    use std::thread;

    let resource = Arc::new(crate::resource::GraphResource {
        pointer: std::sync::RwLock::new(GraphPointer {
            node_id: 100,
            generation: 1,
            flags: 0,
        }),
    });

    let threads = 10;
    let barrier = Arc::new(Barrier::new(threads));
    let mut handles = vec![];

    for _ in 0..threads {
        let r = Arc::clone(&resource);
        let b = Arc::clone(&barrier);
        handles.push(thread::spawn(move || {
            b.wait();
            // Concurrent read
            let id = r.pointer.read().unwrap().node_id;
            assert_eq!(id, 100);
            
            // Concurrent write (with lock)
            let mut w = r.pointer.write().unwrap();
            w.generation += 1;
        }));
    }

    for h in handles {
        h.join().unwrap();
    }

    assert_eq!(resource.pointer.read().unwrap().generation, (threads + 1) as u32);
}

#[test]
fn test_identify_communities_complex() {
    // Two clear cliques connected by a single edge
    let edges = vec![
        // Clique 1: 0, 1, 2
        (0, 1, 1.0), (1, 2, 1.0), (2, 0, 1.0),
        // Clique 2: 3, 4, 5
        (3, 4, 1.0), (4, 5, 1.0), (5, 3, 1.0),
        // Bridge
        (2, 3, 0.1),
    ];
    
    let communities = identify_louvain_communities(edges, 6).unwrap();
    assert_eq!(communities.len(), 2);
    
    // Check members are partitioned correctly (order doesn't matter)
    let c1 = &communities[0];
    let c2 = &communities[1];
    
    let is_c1_correct = (c1.contains(&0) && c1.contains(&1) && c1.contains(&2)) || 
                        (c1.contains(&3) && c1.contains(&4) && c1.contains(&5));
    let is_c2_correct = (c2.contains(&0) && c2.contains(&1) && c2.contains(&2)) || 
                        (c2.contains(&3) && c2.contains(&4) && c2.contains(&5));
                        
    assert!(is_c1_correct);
    assert!(is_c2_correct);
}
