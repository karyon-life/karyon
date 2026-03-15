#[cfg(test)]
mod tests {
    use rhizome_nif::optimizer::identify_communities;
    use rhizome_nif::resource::{GraphPointer, GraphResource};
    use std::sync::RwLock;

    #[test]
    fn test_graph_community_detection_stability() {
        // Test with a larger generated graph to ensure stability and performance
        let mut edges = Vec::new();
        let node_count = 1000;
        for i in 0..node_count {
            // Create some clusters
            let cluster = i / 100;
            for j in 1..5 {
                let target = (cluster * 100) + ((i + j) % 100);
                edges.push((i, target, 1.0));
            }
        }

        let communities = identify_communities(edges, node_count);
        assert!(!communities.is_empty());
        assert!(communities.len() >= 10); // Should find at least 10 clusters
    }

    #[test]
    fn test_memory_deallocation_burst() {
        // Rapid allocation and deallocation to verify RwLock and ResourceArc safety
        for i in 0..50000 {
            let _res = GraphResource {
                pointer: RwLock::new(GraphPointer {
                    node_id: i,
                    generation: 1,
                    flags: 0,
                }),
            };
        }
        // Success if no panic or hang
    }
}
