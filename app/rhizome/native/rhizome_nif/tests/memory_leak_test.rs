#[cfg(test)]
mod tests {
    use rhizome_nif::resource::{GraphPointer, GraphResource};
    use rustler::ResourceArc;
    use std::sync::RwLock;

    #[test]
    fn test_resource_allocation_stability() {
        // Stress test the allocation and drop cycle of opaque Resource Objects
        // for memory leak detection under Valgrind.
        for i in 0..10000 {
            let res = GraphResource {
                pointer: RwLock::new(GraphPointer {
                    node_id: i,
                    generation: 1,
                    flags: 0,
                }),
            };
            // Implicitly dropped
        }
    }
}
