use crate::resource::GraphPointer;
use crate::optimizer::{sequential_pairwise_chunking, TemporalTriple};
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
fn test_temporal_chunking_distinguishes_permutations() {
    let chunks = sequential_pairwise_chunking(
        vec![
            TemporalTriple {
                start_id: 1,
                middle_id: 2,
                end_id: 3,
                ab_weight: 1.0,
                bc_weight: 1.0,
                ab_occurrences: 2.0,
                bc_occurrences: 2.0,
            },
            TemporalTriple {
                start_id: 3,
                middle_id: 2,
                end_id: 1,
                ab_weight: 1.0,
                bc_weight: 1.0,
                ab_occurrences: 2.0,
                bc_occurrences: 2.0,
            },
        ],
        2.0,
    );

    assert_eq!(chunks.len(), 2);
    assert!(chunks.iter().any(|chunk| chunk.ordered_ids == [1, 2, 3]));
    assert!(chunks.iter().any(|chunk| chunk.ordered_ids == [3, 2, 1]));
}

#[test]
fn test_temporal_chunking_is_stable_for_repeated_inputs() {
    let triples = vec![TemporalTriple {
        start_id: 10,
        middle_id: 11,
        end_id: 12,
        ab_weight: 1.0,
        bc_weight: 1.0,
        ab_occurrences: 3.0,
        bc_occurrences: 3.0,
    }];

    let first = sequential_pairwise_chunking(triples.clone(), 2.0);
    let second = sequential_pairwise_chunking(triples, 2.0);

    assert_eq!(first, second);
}
