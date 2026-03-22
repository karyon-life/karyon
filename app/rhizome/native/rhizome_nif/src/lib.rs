pub mod resource;
pub mod client;
pub mod memgraph;
pub mod xtdb;
pub mod optimizer;
#[cfg(test)]
pub mod tests;

use rustler::{Env, Term};
use crate::resource::GraphResource;

rustler::init!(
    "Elixir.Rhizome.Native",
    [
        crate::resource::create_pointer,
        crate::resource::get_pointer_id,
        crate::memgraph::memgraph_query,
        crate::memgraph::weaken_edge,
        crate::memgraph::apply_causal_epoch,
        crate::memgraph::initialize_graph,
        crate::memgraph::traverse_subgraph,
        crate::xtdb::xtdb_query,
        crate::xtdb::xtdb_submit,
        crate::optimizer::optimize_graph,
        crate::memgraph::bridge_to_xtdb,
    ],
    load = load
);

fn load(env: Env, _info: Term) -> bool {
    // Register the GraphResource for use with ResourceArc
    let _ = rustler::resource!(GraphResource, env);
    true
}
