#[cfg(test)]
mod tests {
    use rhizome_nif::resource::{GraphPointer, GraphResource};
    use std::sync::RwLock;

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
