mod resource;
mod client;
mod memgraph;
mod xtdb;
mod optimizer;

use rustler::{Env, Term};
use crate::resource::GraphResource;

rustler::init!(
    "Elixir.Rhizome.Native",
    [
        resource::create_pointer,
        resource::get_pointer_id,
        memgraph::memgraph_query,
        xtdb::xtdb_submit,
        optimizer::optimize_graph,
        memgraph::weaken_edge,
    ],
    load = load
);

fn load(env: Env, _info: Term) -> bool {
    // Register the GraphResource for use with ResourceArc
    let _ = rustler::resource!(GraphResource, env);
    true
}
