use rustler::{ResourceArc};
use std::sync::RwLock;

/// Cache-aligned memory structure to prevent NUMA traversal issues.
/// Mandated by SPEC.md for Tier-0 high-performance graph traversal.
#[repr(C)]
#[repr(align(64))]
pub struct GraphPointer {
    pub node_id: u64,
    pub generation: u32,
    pub flags: u32,
}

/// Opaque wrapper for Elixir Resource Objects.
pub struct GraphResource {
    pub pointer: RwLock<GraphPointer>,
}

pub fn create_pointer_impl(id: u64) -> ResourceArc<GraphResource> {
    ResourceArc::new(GraphResource {
        pointer: RwLock::new(GraphPointer {
            node_id: id,
            generation: 1,
            flags: 0,
        }),
    })
}

#[rustler::nif]
pub fn create_pointer(id: u64) -> ResourceArc<GraphResource> {
    create_pointer_impl(id)
}

pub fn get_pointer_id_impl(resource: ResourceArc<GraphResource>) -> u64 {
    let pointer = resource.pointer.read().unwrap();
    pointer.node_id
}

#[rustler::nif]
pub fn get_pointer_id(resource: ResourceArc<GraphResource>) -> u64 {
    get_pointer_id_impl(resource)
}
