use rustler::{ResourceArc};
use std::sync::RwLock;
use std::collections::HashMap;
use petgraph::graph::{NodeIndex, DiGraph};

pub struct ActiveGraph {
    pub graph: DiGraph<String, f64>,
    pub nodes: HashMap<String, NodeIndex>,
}

impl ActiveGraph {
    pub fn new() -> Self {
        Self {
            graph: DiGraph::new(),
            nodes: HashMap::new(),
        }
    }

    pub fn batch_update(&mut self, updates: Vec<crate::memgraph::CausalPair>) {
        for update in updates {
            let src_idx = *self.nodes.entry(update.source_node.clone())
                .or_insert_with(|| self.graph.add_node(update.source_node.clone()));
            let tgt_idx = *self.nodes.entry(update.target_node.clone())
                .or_insert_with(|| self.graph.add_node(update.target_node.clone()));
            
            if let Some(edge_idx) = self.graph.find_edge(src_idx, tgt_idx) {
                if let Some(weight) = self.graph.edge_weight_mut(edge_idx) {
                    *weight += update.delta_w;
                }
            } else {
                self.graph.add_edge(src_idx, tgt_idx, 1.0 + update.delta_w);
            }
        }
    }
}

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
    pub graph: RwLock<ActiveGraph>,
}

pub fn create_pointer_impl(id: u64) -> ResourceArc<GraphResource> {
    ResourceArc::new(GraphResource {
        pointer: RwLock::new(GraphPointer {
            node_id: id,
            generation: 1,
            flags: 0,
        }),
        graph: RwLock::new(ActiveGraph::new()),
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
